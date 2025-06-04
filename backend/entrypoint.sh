#!/bin/bash
# 🐚 Paguro - Entrypoint script per Ollama
# Villa Celi - Palinuro, Cilento
set -e
echo "🐚 [Ollama] Avvio container Ollama per Paguro..."
# Avvia il daemon Ollama in background
ollama serve &
OLLAMA_PID=$!
echo "🐚 [Ollama] Daemon avviato (PID: $OLLAMA_PID)"
# Aspetta che Ollama sia pronto
echo "🐚 [Ollama] Attendendo che il servizio sia pronto..."
for i in {1..30}; do
    if curl -f http://localhost:11434/api/version >/dev/null 2>&1; then
        echo "✅ [Ollama] Servizio pronto!"
        break
    fi
    echo "⏳ [Ollama] Tentativo $i/30..."
    sleep 2
done
# Verifica che il modello sia disponibile, altrimenti lo scarica
MODEL_NAME="${OLLAMA_MODELS:-llama3.2:1b}"
echo "🐚 [Ollama] Verificando modello: $MODEL_NAME"
if ! ollama list | grep -q "$MODEL_NAME"; then
    echo "📥 [Ollama] Scaricando modello $MODEL_NAME..."
    ollama pull "$MODEL_NAME"
    echo "✅ [Ollama] Modello $MODEL_NAME scaricato"
else
    echo "✅ [Ollama] Modello $MODEL_NAME già presente"
fi
echo "🐚 [Ollama] Setup completato per Villa Celi Palinuro"
echo "🚀 [Ollama] Pronto per le richieste di Paguro!"
# Mantieni il processo principale in vita
wait $OLLAMA_PID
