# =========================
# Stage 1: Builder
# =========================
FROM python:3.11-slim AS builder

WORKDIR /app

# System dependencies needed for building packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt /app/

# Upgrade pip
RUN pip install --upgrade pip

# Install heavy dependencies into /install
RUN pip install --prefix=/install --no-cache-dir \
        torch==2.2.0 \
        torchvision==0.17.0 \
        torchaudio==2.2.0 \
        faiss-cpu>=1.7.4 \
        sentence-transformers>=2.2.2 \
        transformers>=4.34.0 \
        datasets>=2.13.0 \
        numpy<2 \
        scipy \
        scikit-learn \
    && grep -Ev '^(torch|torchaudio|torchvision|faiss-cpu|sentence-transformers|transformers|datasets|numpy|scipy|scikit-learn)' requirements.txt > requirements_no_core.txt \
    && pip install --prefix=/install --no-cache-dir -r requirements_no_core.txt

# =========================
# Stage 2: Final image
# =========================
FROM python:3.11-slim

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy project files
COPY . /app/

# Create static directories
RUN mkdir -p /app/static /app/staticfiles

# Expose dynamic port for Railway
EXPOSE 8000

# Environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=rag_project.settings

# =========================
# Run Django
# =========================
CMD ["sh", "-c", "python manage.py migrate --noinput && python manage.py collectstatic --noinput && gunicorn rag_project.wsgi:application --bind 0.0.0.0:${PORT:-8000} --workers 2 --threads 4 --timeout 120"]
