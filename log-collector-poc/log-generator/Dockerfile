FROM python:3.9-slim

WORKDIR /app

# Copy the generator script
COPY generator.py .

# Make it executable
RUN chmod +x generator.py

# Create directory for logs
RUN mkdir -p /shared-logs

CMD ["python", "generator.py"]
