# =========================
# Base Image
# =========================
FROM python:3.11-slim

# =========================
# Environment Variables
# =========================
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=rag_project.settings

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
# Install core ML dependencies safely
# Quotes are required for >= and < operators to avoid /bin/sh errors
# =========================
RUN pip install --no-cache-dir \
    torch==2.2.0+cpu \
    torchvision==0.17.0+cpu \
    torchaudio==2.2.0+cpu \
    "faiss-cpu>=1.7.4" \
    "sentence-transformers>=2.2.2" \
    "transformers>=4.34.0" \
    "datasets>=2.13.0" \
    "numpy<2" \
    scipy \
    scikit-learn

# =========================
# Install the rest of the requirements
# Exclude already installed core packages
# =========================
RUN grep -Ev '^(torch|torchaudio|torchvision|faiss-cpu|sentence-transformers|transformers|datasets|numpy|scipy|scikit-learn)' requirements.txt > requirements_no_core.txt \
    && pip install --no-cache-dir -r requirements_no_core.txt

# =========================
# Copy Project Files
# =========================
COPY . /app/

# =========================
# Ensure static folder exists
# =========================
RUN mkdir -p /app/staticfiles

# =========================
# Expose dynamic port for Railway
# =========================
EXPOSE 8000

# =========================
# Run Django: Migrations, Collectstatic, Gunicorn
# =========================
CMD ["sh", "-c", "python manage.py migrate --noinput && python manage.py collectstatic --noinput && gunicorn rag_project.wsgi:application --bind 0.0.0.0:${PORT:-8000} --workers 2 --threads 4 --timeout 120"]
