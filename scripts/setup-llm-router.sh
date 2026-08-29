#!/bin/bash
# FreeVPS Mark1.3 - LLM Router Setup for 24/7

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
cat << "EOF"
╔════════════════════════════════════════════════════╗
║         FreeVPS Mark1.3 - LLM Router Setup         ║
║         LiteLLM + Custom Router - 24/7             ║
╚════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check Ollama
echo -e "${BLUE}[CHECK] Checking Ollama...${NC}"
if curl -s http://localhost:11434/api/tags > /dev/null; then
  echo -e "${GREEN}[OK] Ollama is running${NC}"
  ollama list || curl -s http://localhost:11434/api/tags
else
  echo -e "${YELLOW}[WARN] Ollama not running, starting...${NC}"
  bash scripts/install-hermes.sh nous-hermes2:2b
fi

# Setup LiteLLM config
echo -e "${BLUE}[SETUP] Setting up LiteLLM config...${NC}"
mkdir -p llm/litellm

# Check if config exists, if not create
if [ ! -f llm/litellm/litellm-config.yaml ]; then
  echo -e "${YELLOW}[WARN] Config not found, creating default${NC}"
  cat > llm/litellm/litellm-config.yaml << 'EOC'
model_list:
  - model_name: hermes
    litellm_params:
      model: ollama/nous-hermes2
      api_base: http://localhost:11434
  - model_name: hermes3
    litellm_params:
      model: ollama/hermes3:8b
      api_base: http://localhost:11434
  - model_name: openhermes
    litellm_params:
      model: ollama/openhermes
      api_base: http://localhost:11434
EOC
fi

# Install LiteLLM if needed
if ! command -v litellm &> /dev/null && ! python3 -m litellm --help &> /dev/null 2>&1; then
  echo -e "${BLUE}[INSTALL] Installing LiteLLM...${NC}"
  pip3 install 'litellm[proxy]' --break-system-packages || pip3 install 'litellm[proxy]' || pip install 'litellm[proxy]' || true
fi

# Start LiteLLM
echo -e "${BLUE}[START] Starting LiteLLM Proxy...${NC}"
pkill -f "litellm --config" 2>/dev/null || true
sleep 1
nohup litellm --config llm/litellm/litellm-config.yaml --port 4000 > /tmp/litellm.log 2>&1 &
echo $! > /tmp/litellm.pid
sleep 5

# Start custom router
echo -e "${BLUE}[START] Starting Custom Router...${NC}"
if [ -f llm/router/router.js ]; then
  cd llm/router
  npm install --production 2>/dev/null || true
  pkill -f "node router.js" 2>/dev/null || true
  PORT=4001 OLLAMA_HOST=http://localhost:11434 LITELLM_HOST=http://localhost:4000 nohup node router.js > /tmp/hermes-router.log 2>&1 &
  echo $! > /tmp/hermes-router.pid
  cd ../..
  sleep 2
fi

# Status
echo -e "${GREEN}[STATUS] LLM Router Status:${NC}"
echo "Ollama: $(curl -s http://localhost:11434/api/tags > /dev/null && echo "✅ Running" || echo "❌ Down") - http://localhost:11434"
echo "LiteLLM: $(curl -s http://localhost:4000/health > /dev/null && echo "✅ Running" || echo "❌ Down") - http://localhost:4000"
echo "Custom Router: $(curl -s http://localhost:4001/health > /dev/null && echo "✅ Running" || echo "❌ Down") - http://localhost:4001"

echo ""
echo -e "${GREEN}✅ LLM Router Setup Complete!${NC}"
echo -e "${BLUE}Test with:${NC}"
echo "curl http://localhost:4000/v1/models -H 'Authorization: Bearer sk-1234'"
echo "curl http://localhost:4000/v1/chat/completions -H 'Content-Type: application/json' -H 'Authorization: Bearer sk-1234' -d '{\"model\":\"hermes\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}'"
