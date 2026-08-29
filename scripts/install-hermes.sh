#!/bin/bash
# FreeVPS Mark1.3 - Hermes LLM Installer
# Installs Ollama + Hermes models + LiteLLM Router for 24/7

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

MODEL=${1:-"nous-hermes2"}  # Default model
LIGHT_MODEL="hermes3:3b"
HEAVY_MODEL="hermes3:8b"

echo -e "${PURPLE}"
cat << "EOF"
╔════════════════════════════════════════════════════╗
║         FreeVPS Mark1.3 - Hermes Installer         ║
║         24/7 LLM + API Router Setup                ║
╚════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${BLUE}[INFO] Installing Hermes LLM: $MODEL${NC}"
echo -e "${BLUE}[INFO] Date: $(date)${NC}"
echo -e "${BLUE}[INFO] User: $(whoami)${NC}"
echo -e "${BLUE}[INFO] RAM: $(free -h | grep Mem | awk '{print $2}')${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

# Function to install Ollama
install_ollama() {
  echo -e "${BLUE}[STEP 1/5] Installing Ollama...${NC}"
  
  if command -v ollama &> /dev/null; then
    echo -e "${GREEN}[OK] Ollama already installed: $(ollama --version)${NC}"
  else
    echo -e "${BLUE}[INFO] Downloading Ollama installer...${NC}"
    curl -fsSL https://ollama.com/install.sh | sh
    echo -e "${GREEN}[OK] Ollama installed${NC}"
  fi

  # Start Ollama service
  echo -e "${BLUE}[INFO] Starting Ollama service...${NC}"
  
  # Try systemd
  $SUDO systemctl enable ollama 2>/dev/null || true
  $SUDO systemctl start ollama 2>/dev/null || true
  
  # Fallback: start manually
  if ! pgrep -x ollama > /dev/null; then
    echo -e "${YELLOW}[WARN] Systemd not available, starting Ollama manually...${NC}"
    nohup ollama serve > /tmp/ollama.log 2>&1 &
    echo $! > /tmp/ollama.pid
    sleep 3
  fi

  # Wait for Ollama to be ready
  echo -e "${BLUE}[INFO] Waiting for Ollama to be ready...${NC}"
  for i in {1..30}; do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
      echo -e "${GREEN}[OK] Ollama is ready!${NC}"
      break
    fi
    echo -n "."
    sleep 2
  done
  echo ""

  # Check
  if curl -s http://localhost:11434/api/tags > /dev/null; then
    echo -e "${GREEN}[OK] Ollama running on http://localhost:11434${NC}"
    curl -s http://localhost:11434/api/tags | head -20
  else
    echo -e "${RED}[FAIL] Ollama failed to start, check /tmp/ollama.log${NC}"
    cat /tmp/ollama.log | tail -20 || true
    return 1
  fi
}

# Function to pull Hermes models
pull_hermes() {
  echo -e "${BLUE}[STEP 2/5] Pulling Hermes models...${NC}"
  
  # Determine which models to pull based on RAM
  RAM_GB=$(free -g | grep Mem | awk '{print $2}')
  echo -e "${BLUE}[INFO] Detected RAM: ${RAM_GB}GB${NC}"

  MODELS_TO_PULL=()

  if [ "$RAM_GB" -lt 4 ]; then
    echo -e "${YELLOW}[WARN] Low RAM (<4GB), using ultra-light models${NC}"
    MODELS_TO_PULL=("nous-hermes2:2b" "hermes3:3b")
  elif [ "$RAM_GB" -lt 8 ]; then
    echo -e "${BLUE}[INFO] Medium RAM (4-8GB), using balanced models${NC}"
    MODELS_TO_PULL=("nous-hermes2" "hermes3:3b" "openhermes")
  else
    echo -e "${BLUE}[INFO] High RAM (8GB+), using recommended models${NC}"
    MODELS_TO_PULL=("nous-hermes2" "hermes3:8b" "openhermes" "hermes3:3b")
  fi

  # Always include requested model
  if [[ ! " ${MODELS_TO_PULL[@]} " =~ " ${MODEL} " ]]; then
    MODELS_TO_PULL=("$MODEL" "${MODELS_TO_PULL[@]}")
  fi

  echo -e "${BLUE}[INFO] Models to pull: ${MODELS_TO_PULL[*]}${NC}"

  for M in "${MODELS_TO_PULL[@]}"; do
    echo -e "${BLUE}[PULL] Pulling $M... (this may take a while)${NC}"
    if ollama pull "$M"; then
      echo -e "${GREEN}[OK] Pulled $M${NC}"
    else
      echo -e "${RED}[FAIL] Failed to pull $M${NC}"
    fi
  done

  echo -e "${BLUE}[INFO] Available models:${NC}"
  ollama list
}

# Function to install LiteLLM
install_litellm() {
  echo -e "${BLUE}[STEP 3/5] Installing LiteLLM Proxy (API Router)...${NC}"

  # Check Python
  if ! command -v python3 &> /dev/null; then
    echo -e "${BLUE}[INFO] Installing Python3...${NC}"
    $SUDO apt-get update && $SUDO apt-get install -y python3 python3-pip 2>/dev/null || $SUDO yum install -y python3 python3-pip 2>/dev/null || true
  fi

  # Install LiteLLM
  echo -e "${BLUE}[INFO] Installing LiteLLM via pip...${NC}"
  pip3 install 'litellm[proxy]' --break-system-packages 2>/dev/null || pip3 install 'litellm[proxy]' || pip install 'litellm[proxy]' || {
    echo -e "${YELLOW}[WARN] pip install failed, trying alternative...${NC}"
    python3 -m pip install 'litellm[proxy]' --break-system-packages || true
  }

  # Check
  if python3 -m litellm --help &> /dev/null || litellm --help &> /dev/null; then
    echo -e "${GREEN}[OK] LiteLLM installed${NC}"
  else
    echo -e "${YELLOW}[WARN] LiteLLM install may have failed, but continuing...${NC}"
  fi
}

# Function to start LiteLLM
start_litellm() {
  echo -e "${BLUE}[STEP 4/5] Starting LiteLLM Proxy on port 4000...${NC}"

  # Create config if not exists
  mkdir -p llm/litellm
  if [ ! -f llm/litellm/litellm-config.yaml ]; then
    echo -e "${YELLOW}[WARN] Config not found, using default${NC}"
    cat > /tmp/litellm-config.yaml << 'EOC'
model_list:
  - model_name: hermes
    litellm_params:
      model: ollama/nous-hermes2
      api_base: http://localhost:11434
  - model_name: hermes3
    litellm_params:
      model: ollama/hermes3:8b
      api_base: http://localhost:11434
EOC
    CONFIG_FILE="/tmp/litellm-config.yaml"
  else
    CONFIG_FILE="llm/litellm/litellm-config.yaml"
  fi

  # Start LiteLLM
  echo -e "${BLUE}[INFO] Starting LiteLLM with config $CONFIG_FILE...${NC}"
  nohup litellm --config "$CONFIG_FILE" --port 4000 --detailed_debug > /tmp/litellm.log 2>&1 &
  echo $! > /tmp/litellm.pid
  sleep 5

  if curl -s http://localhost:4000/health > /dev/null 2>&1 || curl -s http://localhost:4000/ > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] LiteLLM running on http://localhost:4000${NC}"
  else
    echo -e "${YELLOW}[WARN] LiteLLM may not be ready yet, check /tmp/litellm.log${NC}"
    cat /tmp/litellm.log | tail -20 || true
  fi
}

# Function to start custom router
start_custom_router() {
  echo -e "${BLUE}[STEP 5/5] Starting Custom Hermes Router on port 4001...${NC}"

  if [ -f "llm/router/router.js" ]; then
    cd llm/router
    if [ ! -d "node_modules" ]; then
      npm install --production
    fi
    PORT=4001 OLLAMA_HOST=http://localhost:11434 LITELLM_HOST=http://localhost:4000 nohup node router.js > /tmp/hermes-router.log 2>&1 &
    echo $! > /tmp/hermes-router.pid
    cd ../..
    sleep 3
    if curl -s http://localhost:4001/health > /dev/null 2>&1; then
      echo -e "${GREEN}[OK] Custom router running on http://localhost:4001${NC}"
    else
      echo -e "${YELLOW}[WARN] Custom router not ready, check /tmp/hermes-router.log${NC}"
    fi
  else
    echo -e "${YELLOW}[WARN] Custom router not found, skipping${NC}"
  fi
}

# Main
main() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE} FreeVPS Mark1.3 Hermes Setup Starting${NC}"
  echo -e "${BLUE} Model: $MODEL${NC}"
  echo -e "${BLUE}========================================${NC}"

  install_ollama
  pull_hermes
  install_litellm
  start_litellm
  start_custom_router

  echo -e "${GREEN}"
  cat << EOF
╔════════════════════════════════════════════════════╗
║         ✅ Hermes LLM Setup Complete!              ║
╠════════════════════════════════════════════════════╣
║  Model: $MODEL                                      ║
║                                                    ║
║  Services:                                         ║
║  • Ollama: http://localhost:11434                  ║
║  • LiteLLM Router: http://localhost:4000           ║
║  • Custom Router: http://localhost:4001            ║
║  • Main Dashboard: http://localhost:8080           ║
║                                                    ║
║  API Usage (OpenAI compatible):                    ║
║  curl http://localhost:4000/v1/chat/completions \\  ║
║    -H "Authorization: Bearer sk-1234" \\            ║
║    -d '{"model":"hermes","messages":[{"role":"user","content":"Hello"}]}' ║
║                                                    ║
║  Logs:                                             ║
║  • Ollama: /tmp/ollama.log                         ║
║  • LiteLLM: /tmp/litellm.log                       ║
║  • Router: /tmp/hermes-router.log                  ║
╚════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"

  echo -e "${BLUE}[INFO] Testing Hermes...${NC}"
  curl -s http://localhost:11434/api/tags | head -20
  echo ""
  echo -e "${BLUE}[INFO] Testing LiteLLM...${NC}"
  curl -s http://localhost:4000/v1/models -H "Authorization: Bearer sk-1234" | head -20 || echo "LiteLLM models check failed (may need more time)"
  echo ""
  echo -e "${GREEN}[INFO] Hermes is ready for 24/7!${NC}"
  echo -e "${YELLOW}[INFO] For Docker 24/7: docker-compose -f llm/docker-compose.yml up -d${NC}"
}

main "$@"
