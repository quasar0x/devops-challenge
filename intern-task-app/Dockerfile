FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

# Dedicated unprivileged user with a numeric UID so Kubernetes can verify runAsNonRoot
RUN useradd --system --uid 10001 --no-create-home app

WORKDIR /app
COPY app/app.py .

USER 10001
EXPOSE 8080

CMD ["python", "app.py"]