# ==============================================================================
# Multi-Stage Hardened Production Dockerfile (DevSecOps Zero-Vulnerability Standard)
# ==============================================================================

# Étape 1 : Builder (compilation des dépendances)
FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt gunicorn psycopg2-binary

# Étape 2 : Runtime final minimal et durci
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/install/bin:$PATH" \
    PYTHONPATH="/install/lib/python3.11/site-packages:$PYTHONPATH"

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copie des dépendances compilées depuis le builder
COPY --from=builder /install /install

# Copie du code applicatif
COPY . /app/

# Collecte des fichiers statiques
RUN python manage.py collectstatic --noinput || true

# Utilisateur non-privilégié dédié (UID/GID 10001) - Standard DevSecOps
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /sbin/nologin -d /app appuser && \
    chown -R appuser:appgroup /app

USER 10001:10001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/api/v1/health/live/ || exit 1

CMD ["gunicorn", "shieldnet_backend.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4", "--threads", "2"]
