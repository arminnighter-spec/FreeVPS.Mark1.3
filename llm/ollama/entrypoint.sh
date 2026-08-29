#!/bin/bash
# Ollama entrypoint for Hermes - auto-pulls models for 24/7

set -e

echo "=== Ollama Hermes Entrypoint - 24/7 ==="
echo "Date: $(date)"
echo "Models to pull: ${OLLAMA_MODELS:-nous-hermes2}"

# Start Ollama in background
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "Waiting for Ollama to be ready..."
for i in {1..30}; do
  if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "Ollama is ready!"
    break
  fi
  echo "Waiting... $i"
  sleep 2
done

# Pull models
if [ -n "$OLLAMA_MODELS" ]; then
  IFS=',' read -ra MODELS <<< "$OLLAMA_MODELS"
  for model in "${MODELS[@]}"; do
    model=$(echo $model | xargs)  # trim
    echo "Pulling model: $model"
    ollama pull "$model" || echo "Failed to pull $model, will retry later"
  done
else
  echo "Pulling default Hermes models..."
  ollama pull nous-hermes2 || true
  ollama pull hermes3:3b || true
fi

echo "Available models:"
ollama list

# Keep alive - wait for Ollama process
wait $OLLAMA_PID
