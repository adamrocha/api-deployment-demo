FROM python:3.12-alpine3.23

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

# Set work directory
WORKDIR /app

# Install runtime dependencies
# hadolint ignore=DL3018
RUN apk add --no-cache curl

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip==26.2.1 \
    && pip install --no-cache-dir --requirement requirements.txt

# Copy project
COPY . .

# Create a non-root user
RUN addgroup -S -g 10001 appuser \
    && adduser -S -D -H -u 10001 -G appuser appuser \
    && chown -R 10001:10001 /app
USER 10001

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD ["curl", "-f", "http://localhost:8000/health"]

# Run gunicorn
CMD ["gunicorn", "--config", "gunicorn.conf.py", "main:app"]