import os
import tempfile
import logging
from django.shortcuts import render
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import parsers, status
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from .utils import extract_text_from_docx, extract_text_from_pdf, chunk_text, vector_store
import requests
import json

logger = logging.getLogger(__name__)


def index(request):
    return render(request, 'index.html')


@method_decorator(csrf_exempt, name='dispatch')
class UploadDocumentAPIView(APIView):
    parser_classes = [parsers.MultiPartParser]

    def post(self, request):
        logger.info("📄 Document upload started")

        file = request.FILES.get('file')
        if not file:
            return Response(
                {"error": "No file uploaded"},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Validate file
        filename = file.name.lower()
        max_size = 10 * 1024 * 1024  # 10MB

        if file.size > max_size:
            return Response(
                {"error": f"File too large. Maximum size is 10MB"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not (filename.endswith('.docx') or filename.endswith('.pdf')):
            return Response(
                {"error": "Unsupported file type. Only PDF and DOCX files are supported."},
                status=status.HTTP_400_BAD_REQUEST
            )

        temp_path = None
        try:
            # Save uploaded file temporarily
            suffix = os.path.splitext(file.name)[1]
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
                for chunk in file.chunks():
                    tmp.write(chunk)
                temp_path = tmp.name

            # Extract text
            logger.info("🔍 Extracting text from document...")
            if filename.endswith('.docx'):
                text = extract_text_from_docx(temp_path)
            elif filename.endswith('.pdf'):
                text = extract_text_from_pdf(temp_path)

            if not text or not text.strip():
                return Response(
                    {"error": "No text could be extracted from the document"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            logger.info(f"✅ Extracted {len(text)} characters")

            # Chunk text
            logger.info("✂️ Chunking text...")
            chunks = chunk_text(text, max_chunk_size=400, overlap_size=50)

            # Prepare metadata
            metadata = []
            for i, chunk in enumerate(chunks):
                metadata.append({
                    'filename': file.name,
                    'chunk_index': i,
                    'total_chunks': len(chunks)
                })

            # Add to vector store
            logger.info("📊 Adding to vector store...")
            vector_store.add_documents(chunks, metadata)

            logger.info("✅ Document indexed successfully!")
            return Response({
                "message": "Document indexed successfully",
                "points_added": len(chunks),
                "filename": file.name,
                "text_length": len(text),
                "chunks_created": len(chunks)
            })

        except Exception as e:
            logger.error(f"❌ Error during upload: {str(e)}")
            return Response(
                {"error": f"Processing failed: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        finally:
            if temp_path and os.path.exists(temp_path):
                try:
                    os.remove(temp_path)
                except Exception as e:
                    logger.warning(f"⚠️ Failed to remove temp file: {e}")


@method_decorator(csrf_exempt, name='dispatch')
class QueryAPIView(APIView):
    def post(self, request):
        question = request.data.get('question', '').strip()
        if not question:
            return Response(
                {"error": "No question provided"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if len(question) > 1000:
            return Response(
                {"error": "Question too long (max 1000 characters)"},
                status=status.HTTP_400_BAD_REQUEST
            )

        logger.info(f"🔍 Processing query: {question[:100]}...")

        try:
            # Search vector store
            logger.info("🔍 Searching vector store...")
            search_results = vector_store.search(question, k=5, score_threshold=0.3)

            if not search_results:
                return Response({
                    "answer": "I couldn't find any relevant information in the uploaded documents to answer your question. Please make sure you've uploaded relevant documents or try rephrasing your question.",
                    "retrieved_docs": [],
                    "context_found": False
                })

            # Prepare context
            context_texts = [result['text'] for result in search_results[:3]]
            context = "\n\n".join(context_texts)

            # Generate answer using Ollama (free local LLM)
            logger.info("🤖 Generating answer with Ollama...")
            answer = self.generate_answer_with_ollama(question, context)

            # Prepare response
            retrieved_docs = [result['text'] for result in search_results]
            sources = list(set([result['metadata']['filename'] for result in search_results]))
            scores = [f"{result['score']:.3f}" for result in search_results]

            logger.info("✅ Query processed successfully")
            return Response({
                "answer": answer,
                "retrieved_docs": retrieved_docs,
                "context_found": True,
                "relevance_scores": scores,
                "sources": sources
            })

        except Exception as e:
            logger.error(f"❌ Error during query: {str(e)}")
            return Response(
                {"error": f"Query processing failed: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def generate_answer_with_ollama(self, question, context):
        """Generate answer using Ollama (free local LLM)"""
        try:
            prompt = f"""Based on the following context, please answer the question. If the context doesn't contain enough information, say so clearly.

Context:
{context}

Question: {question}

Answer:"""

            # Try Ollama API (runs locally)
            ollama_response = requests.post(
                'http://localhost:11434/api/generate',
                json={
                    'model': 'llama3.2',  # Free model
                    'prompt': prompt,
                    'stream': False,
                    'options': {
                        'temperature': 0.7,
                        'top_p': 0.9,
                        'max_tokens': 300
                    }
                },
                timeout=30
            )

            if ollama_response.status_code == 200:
                result = ollama_response.json()
                answer = result.get('response', '').strip()
                if answer:
                    return answer

            # Fallback: Use context directly
            logger.warning("Ollama not available, using context fallback")
            return f"Based on the uploaded documents:\n\n{context[:300]}..."

        except requests.exceptions.ConnectionError:
            logger.warning("Ollama not running, using context fallback")
            return f"Based on the uploaded documents:\n\n{context[:300]}..."
        except Exception as e:
            logger.error(f"Error generating answer: {e}")
            return f"I found relevant information: {context[:200]}..."