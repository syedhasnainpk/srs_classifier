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

# Install latest PyTorch CPU version compatible with Python 3.11
RUN pip install torch==2.9.1+cpu --index-url https://download.pytorch.org/whl/cpu

# Install the rest of the requirements (excluding torch)
RUN grep -v 'torch==' requirements.txt > requirements_no_torch.txt \
    && pip install -r requirements_no_torch.txt

# Copy the project files
COPY . /app/

# Expose port
EXPOSE 8000

# Run Django using Gunicorn
CMD ["gunicorn", "rag_project.wsgi:application", "--bind", "0.0.0.0:8000"]
