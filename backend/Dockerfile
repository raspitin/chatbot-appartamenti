# 🐚 Paguro - Dockerfile per Villa Celi
# Receptionist Virtuale AI per Palinuro, Cilento
# VERSIONE FINALE CORRETTA

FROM python:3.11-slim

# Metadata Paguro
LABEL maintainer="Villa Celi <info@villaceli.it>"
LABEL description="🐚 Paguro - Receptionist Virtuale AI per Villa Celi a Palinuro"
LABEL version="2.1.0"
LABEL location="Palinuro, Cilento, Italia"

# Variabili d'ambiente per Paguro
ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=wordpress_chatbot_api.py
ENV FLASK_ENV=production
ENV DB_PATH=/app/data/affitti2025.db
ENV OLLAMA_URL=http://ollama:11434/api/generate
ENV MODEL=llama3.2:1b
ENV PORT=5000

# Crea utente non-root per sicurezza
RUN groupadd -g 1000 paguro && \
    useradd -u 1000 -g paguro -m -s /bin/bash paguro

# Installa dipendenze di sistema
RUN apt-get update && apt-get install -y \
    gcc \
    sqlite3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Crea directory di lavoro
WORKDIR /app

# Copia requirements
COPY requirements-minimal.txt* ./

# Installa dipendenze Python (CORRETTO: senza sqlite3)
RUN if [ -f requirements-minimal.txt ]; then \
        pip install --no-cache-dir -r requirements-minimal.txt; \
    else \
        pip install --no-cache-dir \
            flask==2.3.3 \
            flask-cors==4.0.0 \
            requests==2.31.0 \
            python-dotenv==1.0.0 \
            colorlog==6.8.0 \
            gunicorn==21.2.0; \
    fi

# Crea directory per dati
RUN mkdir -p /app/data /app/logs /app/cache && \
    chown -R paguro:paguro /app

# Copia codice sorgente
COPY wordpress_chatbot_api.py ./
COPY handle_query_complete.py* ./
COPY .env* ./

# Cambia proprietà
RUN chown -R paguro:paguro /app

# Cambia utente
USER paguro

# Esponi porta
EXPOSE $PORT

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:$PORT/api/health || exit 1

# Comando di avvio
CMD ["python", "wordpress_chatbot_api.py"]

# Volume per persistenza dati
VOLUME ["/app/data", "/app/logs"]