# 🐚 Paguro - Ollama Dockerfile per Villa Celi

FROM ollama/ollama:latest

# Installa curl per healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copia entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Imposta entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]