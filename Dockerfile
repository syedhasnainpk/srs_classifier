# Use official Python 3.11 image
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt /app/

# Upgrade pip
RUN pip install --upgrade pip

# Install PyTorch and related CPU wheels matching requirements
RUN pip install torch==2.2.0+cpu torchaudio==2.2.0+cpu torchvision==0.17.0+cpu --index-url https://download.pytorch.org/whl/cpu

# Install the rest of the requirements (excluding torch/torchaudio/torchvision)
# Use a pattern that matches package names regardless of == or >= pins
RUN grep -Ev '^(torch|torchaudio|torchvision)' requirements.txt > requirements_no_torch.txt \
    && pip install -r requirements_no_torch.txt

# Copy the project files
COPY . /app/

# Expose port
EXPOSE 8000

# Run Django using Gunicorn
CMD ["sh", "-c", "python manage.py migrate --noinput && python manage.py collectstatic --noinput && gunicorn rag_project.wsgi:application --bind 0.0.0.0:${PORT:-8000}"]
