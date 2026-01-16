FROM python:3.11-slim

WORKDIR /app

# Copy and install dependencies
COPY src/backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend source code
COPY src/backend/ ./src/backend/

# Expose port
EXPOSE 8080

# Run the application
CMD ["uvicorn", "src.backend.main:app", "--host", "0.0.0.0", "--port", "8080"]
