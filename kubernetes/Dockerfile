# Dockerfile for AIOps Processor (Kubernetes deployment)
FROM python:3.11-slim

WORKDIR /app

# Copy requirements
COPY aiops-processor/requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY aiops-processor/ .

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

# Run the application
CMD ["python", "app.py"]

