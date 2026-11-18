# Project 11: Project 3's app, hardened. Built once in CI; the tested image is the one signed and deployed.
# Base image pinned by digest (python:3.12-slim, multi-arch index), so a re-tagged or tampered base can't slip in.
FROM python:3.12-slim@sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Apply Debian's published security fixes at build time (the pinned base can lag behind them).
# The first scan found zlib1g CVE-2026-85091 fixed upstream but not yet in the base image.
RUN apt-get update \
 && apt-get -y upgrade --no-install-recommends \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Hash-locked dependencies; pip is removed afterwards so the runtime image can't install anything.
COPY requirements.txt .
RUN pip install --require-hashes -r requirements.txt \
 && python -m pip uninstall -y pip \
 && useradd --system --uid 10001 --no-create-home --shell /usr/sbin/nologin app

COPY app.py .

# Unprivileged user; port above 1024 so no root is needed to bind.
USER 10001
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

# Production WSGI server instead of Flask's development server.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-", "app:app"]
