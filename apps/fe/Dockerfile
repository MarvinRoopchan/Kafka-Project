FROM python:3.11-slim

# For TLS roots in case you later call HTTPS
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && update-ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py ./app.py
COPY templates/ ./templates/
EXPOSE 5000
CMD ["python","app.py"]
