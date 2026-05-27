FROM python:3.11-slim

WORKDIR /app
COPY src/ ./src/

RUN pip install --no-cache-dir -r src/requirements.txt 2>/dev/null || \
  echo "No requirements.txt found — add your dependencies"

CMD ["python", "src/main.py"]