# =========================
# Base Image
# =========================
FROM python:3.11-slim

# =========================
# Environment Variables
# =========================
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV POETRY_VIRTUALENVS_CREATE=false

WORKDIR /app

# =========================
# System Dependencies
# =========================
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# =========================
# Copy requirements
# =========================
COPY requirements.txt /app/

# =========================
# Upgrade pip
# =========================
RUN pip install --upgrade pip

# =========================
# Install PyTorch CPU wheels
# =========================
RUN pip install torch==2.2.0+cpu torchaudio==2.2.0+cpu torchvision==0.17.0+cpu --index-url https://download.pytorch.org/whl/cpu

# =========================
# Install FAISS, Sentence-Transformers, Datasets
# =========================
RUN pip install faiss-cpu>=1.7.4 \
    sentence-transformers>=2.2.2 \
    transformers>=4.34.0 \
    datasets>=2.13.0 \
    numpy<2 \
    scipy \
    scikit-learn

# =========================
# Install the rest of requirements
# =========================
RUN grep -Ev '^(torch|torchaudio|torchvision|faiss-cpu|sentence-transformers|datasets|numpy|scipy|scikit-learn)' requirements.txt > requirements_no_torch.txt \
    && pip install -r requirements_no_torch.txt

# =========================
# Copy Project Files
# =========================
COPY . /app/

# =========================
# Expose Port for Railway
# =========================
EXPOSE 8000

# =========================
# Run Django: Migrations, Collectstatic, Gunicorn
# =========================
CMD ["sh", "-c", "\
    python manage.py migrate --noinput && \
    python manage.py collectstatic --noinput && \
    gunicorn rag_project.wsgi:application --bind 0.0.0.0:${PORT:-8000} \
"]
