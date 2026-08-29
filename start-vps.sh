#!/bin/bash
# FreeVPS Mark1.3 - 24/7 VPS Starter + Hermes LLM
# Starts all services for persistent VPS + LLM API Router

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

VPS_USER="Mikasa"
VPS_USER_LOWER="mikasa"
VPS_PASS='Eren@Home$123'
MAIN_PORT=8080
TTYD_PORT=7681
CODE_PORT=8081
SSH_PORT=22
OLLAMA_PORT=11434
LITELLM_PORT=4000
ROUTER_PORT=4001
WEBUI_PORT=3000

echo -e "${PURPLE}"
cat << "EOF"
╔════════════════════════════════════════════════════╗
║         FreeVPS Mark1.3 - 24/7 VPS Launcher        ║
║         + Hermes LLM API Router (LiteLLM)          ║
║         Starting Persistent VPS Services           ║
╚════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if setup done
if ! id "$VPS_USER_LOWER" &>/dev/null; then
  echo -e "${YELLOW}[WARN] User $VPS_USER_LOWER not found, running setup...${NC}"
  bash scripts/setup-vps.sh
fi

# Function to kill existing services
cleanup() {
  echo -e "${YELLOW}[CLEANUP] Stopping existing services...${NC}"
  pkill -f "node server.js" 2>/dev/null || true
  pkill -f "ttyd" 2>/dev/null || true
  pkill -f "code-server" 2>/dev/null || true
  pkill -f "ollama serve" 2>/dev/null || true
  pkill -f "litellm --config" 2>/dev/null || true
  pkill -f "node router.js" 2>/dev/null || true
  sleep 1
}

# Function to start SSH
start_ssh() {
  echo -e "${BLUE}[START] Starting SSH server...${NC}"
  sudo mkdir -p /var/run/sshd /run/sshd 2>/dev/null || true
  sudo /usr/sbin/sshd 2>/dev/null || sudo service ssh start 2>/dev/null || sudo systemctl start sshd 2>/dev/null || echo -e "${YELLOW}[WARN] SSH start failed, trying alternative${NC}"
  
  if pgrep -x sshd > /dev/null; then
    echo -e "${GREEN}[OK] SSH running on port $SSH_PORT${NC}"
  else
    echo -e "${RED}[FAIL] SSH failed to start${NC}"
  fi
}

# Function to start main dashboard
start_dashboard() {
  echo -e "${BLUE}[START] Starting main dashboard on port $MAIN_PORT...${NC}"
  
  if [ ! -d "node_modules" ]; then
    echo -e "${BLUE}[INFO] Installing npm dependencies...${NC}"
    npm install --production 2>&1 | tail -5
  fi
  
  PORT=$MAIN_PORT VPS_USER=$VPS_USER VPS_PASS="$VPS_PASS" OLLAMA_HOST=http://localhost:$OLLAMA_PORT LITELLM_HOST=http://localhost:$LITELLM_PORT LLM_ROUTER_HOST=http://localhost:$ROUTER_PORT nohup node server.js > /tmp/freevps-dashboard.log 2>&1 &
  DASH_PID=$!
  echo $DASH_PID > /tmp/freevps-dashboard.pid
  
  sleep 3
  if ps -p $DASH_PID > /dev/null; then
    echo -e "${GREEN}[OK] Dashboard running (PID $DASH_PID) on http://0.0.0.0:$MAIN_PORT${NC}"
    echo -e "${GREEN}[OK] Login: $VPS_USER / $VPS_PASS${NC}"
  else
    echo -e "${RED}[FAIL] Dashboard failed to start, check /tmp/freevps-dashboard.log${NC}"
    cat /tmp/freevps-dashboard.log | tail -20
  fi
}

# Function to start ttyd
start_ttyd() {
  echo -e "${BLUE}[START] Starting ttyd terminal on port $TTYD_PORT...${NC}"
  
  if command -v ttyd &> /dev/null; then
    nohup ttyd -p $TTYD_PORT -t fontSize=14 -t theme='{"background":"#010409"}' -c $VPS_USER_LOWER:$VPS_PASS bash > /tmp/ttyd.log 2>&1 &
    TTYD_PID=$!
    echo $TTYD_PID > /tmp/ttyd.pid
    sleep 2
    if ps -p $TTYD_PID > /dev/null; then
      echo -e "${GREEN}[OK] ttyd running on http://0.0.0.0:$TTYD_PORT (auth: $VPS_USER_LOWER)${NC}"
    else
      echo -e "${RED}[FAIL] ttyd failed${NC}"
      cat /tmp/ttyd.log | tail -10
    fi
  else
    echo -e "${YELLOW}[WARN] ttyd not installed, skipping${NC}"
  fi
}

# Function to start code-server
start_code_server() {
  echo -e "${BLUE}[START] Starting code-server on port $CODE_PORT...${NC}"
  
  if command -v code-server &> /dev/null; then
    mkdir -p ~/.config/code-server
    cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:$CODE_PORT
auth: password
password: $VPS_PASS
cert: false
EOF
    nohup code-server --bind-addr 0.0.0.0:$CODE_PORT --auth password > /tmp/code-server.log 2>&1 &
    CODE_PID=$!
    echo $CODE_PID > /tmp/code-server.pid
    sleep 3
    if ps -p $CODE_PID > /dev/null; then
      echo -e "${GREEN}[OK] code-server running on http://0.0.0.0:$CODE_PORT (password: $VPS_PASS)${NC}"
    else
      echo -e "${RED}[FAIL] code-server failed${NC}"
      cat /tmp/code-server.log | tail -10
    fi
  else
    echo -e "${YELLOW}[WARN] code-server not installed, skipping${NC}"
  fi
}

# Function to start Ollama + Hermes
start_ollama() {
  echo -e "${BLUE}[START] Starting Ollama (Hermes LLM) on port $OLLAMA_PORT...${NC}"
  
  if command -v ollama &> /dev/null; then
    # Start Ollama if not running
    if ! curl -s http://localhost:$OLLAMA_PORT/api/tags > /dev/null 2>&1; then
      echo -e "${BLUE}[INFO] Starting Ollama service...${NC}"
      nohup ollama serve > /tmp/ollama.log 2>&1 &
      echo $! > /tmp/ollama.pid
      sleep 5
      
      # Wait for ready
      for i in {1..15}; do
        if curl -s http://localhost:$OLLAMA_PORT/api/tags > /dev/null 2>&1; then
          echo -e "${GREEN}[OK] Ollama ready!${NC}"
          break
        fi
        sleep 2
      done
    fi
    
    if curl -s http://localhost:$OLLAMA_PORT/api/tags > /dev/null 2>&1; then
      echo -e "${GREEN}[OK] Ollama running on http://0.0.0.0:$OLLAMA_PORT${NC}"
      echo -e "${BLUE}[INFO] Available models:${NC}"
      ollama list 2>/dev/null || curl -s http://localhost:$OLLAMA_PORT/api/tags | head -20
      
      # Auto-pull Hermes if no models
      MODEL_COUNT=$(ollama list 2>/dev/null | wc -l)
      if [ "$MODEL_COUNT" -le 1 ]; then
        echo -e "${YELLOW}[INFO] No models found, pulling Hermes lightweight model (hermes3:3b)...${NC}"
        ollama pull hermes3:3b 2>&1 | tail -5 &
        # Also try nous-hermes2:2b for low RAM
        ollama pull nous-hermes2:2b 2>&1 | tail -5 &
      fi
    else
      echo -e "${RED}[FAIL] Ollama failed to start, check /tmp/ollama.log${NC}"
      cat /tmp/ollama.log | tail -10 || true
    fi
  else
    echo -e "${YELLOW}[WARN] Ollama not installed, run: bash scripts/install-hermes.sh${NC}"
    echo -e "${YELLOW}[WARN] Or: curl -fsSL https://ollama.com/install.sh | sh${NC}"
  fi
}

# Function to start LiteLLM Proxy
start_litellm() {
  echo -e "${BLUE}[START] Starting LiteLLM Proxy (LLM API Router) on port $LITELLM_PORT...${NC}"
  
  # Check if Ollama is running first
  if ! curl -s http://localhost:$OLLAMA_PORT/api/tags > /dev/null 2>&1; then
    echo -e "${YELLOW}[WARN] Ollama not running, starting Ollama first...${NC}"
    start_ollama
  fi

  if command -v litellm &> /dev/null || python3 -m litellm --help &> /dev/null 2>&1; then
    # Create config if not exists
    mkdir -p llm/litellm
    CONFIG_FILE="llm/litellm/litellm-config.yaml"
    if [ ! -f "$CONFIG_FILE" ]; then
      CONFIG_FILE="/tmp/litellm-config.yaml"
      cat > "$CONFIG_FILE" << 'EOC'
model_list:
  - model_name: hermes
    litellm_params:
      model: ollama/nous-hermes2
      api_base: http://localhost:11434
  - model_name: hermes3
    litellm_params:
      model: ollama/hermes3:8b
      api_base: http://localhost:11434
  - model_name: hermes3:3b
    litellm_params:
      model: ollama/hermes3:3b
      api_base: http://localhost:11434
EOC
    fi

    # Start LiteLLM
    nohup litellm --config "$CONFIG_FILE" --port $LITELLM_PORT > /tmp/litellm.log 2>&1 &
    LITELLM_PID=$!
    echo $LITELLM_PID > /tmp/litellm.pid
    sleep 5

    if curl -s http://localhost:$LITELLM_PORT/health > /dev/null 2>&1 || curl -s http://localhost:$LITELLM_PORT/ > /dev/null 2>&1; then
      echo -e "${GREEN}[OK] LiteLLM Proxy running on http://0.0.0.0:$LITELLM_PORT${NC}"
      echo -e "${GREEN}[OK] OpenAI compatible API: http://localhost:$LITELLM_PORT/v1/chat/completions${NC}"
      echo -e "${GREEN}[OK] Auth: Bearer sk-1234${NC}"
    else
      echo -e "${RED}[FAIL] LiteLLM failed, check /tmp/litellm.log${NC}"
      cat /tmp/litellm.log | tail -15 || true
    fi
  else
    echo -e "${YELLOW}[WARN] LiteLLM not installed, installing...${NC}"
    pip3 install 'litellm[proxy]' --break-system-packages 2>/dev/null || pip3 install 'litellm[proxy]' 2>/dev/null || echo -e "${YELLOW}[WARN] LiteLLM install failed, trying custom router...${NC}"
    # Try again after install
    if command -v litellm &> /dev/null; then
      start_litellm
    fi
  fi
}

# Function to start custom router
start_custom_router() {
  echo -e "${BLUE}[START] Starting Custom Hermes Router on port $ROUTER_PORT...${NC}"
  
  if [ -f "llm/router/router.js" ]; then
    cd llm/router
    if [ ! -d "node_modules" ]; then
      echo -e "${BLUE}[INFO] Installing router dependencies...${NC}"
      npm install --production 2>&1 | tail -3
    fi
    PORT=$ROUTER_PORT OLLAMA_HOST=http://localhost:$OLLAMA_PORT LITELLM_HOST=http://localhost:$LITELLM_PORT nohup node router.js > /tmp/hermes-router.log 2>&1 &
    ROUTER_PID=$!
    echo $ROUTER_PID > /tmp/hermes-router.pid
    cd ../..
    sleep 3
    if curl -s http://localhost:$ROUTER_PORT/health > /dev/null 2>&1; then
      echo -e "${GREEN}[OK] Custom Router running on http://0.0.0.0:$ROUTER_PORT${NC}"
    else
      echo -e "${YELLOW}[WARN] Custom Router not ready, check /tmp/hermes-router.log${NC}"
      cat /tmp/hermes-router.log | tail -10 || true
    fi
  else
    echo -e "${YELLOW}[WARN] Custom router not found at llm/router/router.js, skipping${NC}"
  fi
}

# Function to show status
show_status() {
  echo -e "${PURPLE}"
  cat << EOF
╔════════════════════════════════════════════════════╗
║         ✅ FreeVPS Mark1.3 - All Services Up!      ║
╠════════════════════════════════════════════════════╣
║  Username: Mikasa                                   ║
║  Password: Eren@Home\$123                            ║
╠════════════════════════════════════════════════════╣
║  Core Services:                                    ║
║  • Main Dashboard: http://localhost:$MAIN_PORT            ║
║  • ttyd Terminal:  http://localhost:$TTYD_PORT            ║
║  • VS Code:        http://localhost:$CODE_PORT            ║
║  • SSH:            ssh $VPS_USER_LOWER@localhost             ║
╠════════════════════════════════════════════════════╣
║  Hermes LLM Services (24/7):                       ║
║  • Ollama:         http://localhost:$OLLAMA_PORT            ║
║  • LiteLLM Router: http://localhost:$LITELLM_PORT            ║
║  • Custom Router:  http://localhost:$ROUTER_PORT            ║
║  • Open WebUI:     http://localhost:$WEBUI_PORT (if enabled) ║
╠════════════════════════════════════════════════════╣
║  LLM API (OpenAI compatible):                      ║
║  • http://localhost:$LITELLM_PORT/v1/chat/completions       ║
║  • http://localhost:$LITELLM_PORT/v1/models                 ║
║  • Auth: Bearer sk-1234                            ║
║  • Model: hermes (nous-hermes2)                    ║
╠════════════════════════════════════════════════════╣
║  Logs:                                             ║
║  • Dashboard: /tmp/freevps-dashboard.log           ║
║  • Ollama: /tmp/ollama.log                         ║
║  • LiteLLM: /tmp/litellm.log                       ║
║  • Router: /tmp/hermes-router.log                  ║
╚════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  
  echo -e "${BLUE}[STATUS] Running processes:${NC}"
  ps aux | grep -E "server.js|ttyd|code-server|sshd|ollama|litellm|router.js" | grep -v grep || echo "No processes found"
  echo ""
  echo -e "${BLUE}[STATUS] Listening ports:${NC}"
  ss -tlnp 2>/dev/null | grep -E "$MAIN_PORT|$TTYD_PORT|$CODE_PORT|$SSH_PORT|$OLLAMA_PORT|$LITELLM_PORT|$ROUTER_PORT" || netstat -tlnp 2>/dev/null | grep -E "$MAIN_PORT|$TTYD_PORT|$CODE_PORT|$SSH_PORT|$OLLAMA_PORT|$LITELLM_PORT|$ROUTER_PORT" || echo "Checking ports..."
  echo ""
  echo -e "${BLUE}[STATUS] LLM Models:${NC}"
  ollama list 2>/dev/null || curl -s http://localhost:$OLLAMA_PORT/api/tags 2>/dev/null | head -20 || echo "Ollama not running"
  echo ""
  echo -e "${GREEN}[INFO] VPS + Hermes LLM running 24/7!${NC}"
  echo -e "${YELLOW}[INFO] Test LLM: curl http://localhost:$LITELLM_PORT/v1/chat/completions -H 'Authorization: Bearer sk-1234' -H 'Content-Type: application/json' -d '{\"model\":\"hermes\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}'${NC}"
}

# Function to keep alive (for GitHub Actions)
keep_alive() {
  echo -e "${BLUE}[KEEPALIVE] Starting 24/7 keep-alive loop (VPS + LLM)...${NC}"
  
  while true; do
    echo "[$(date)] FreeVPS Mark1.3 - Heartbeat - Uptime: $(uptime -p) - User: $VPS_USER - Services: $(ps aux | grep -E 'server.js|ttyd|code-server|ollama|litellm' | grep -v grep | wc -l) running"
    
    if ! pgrep -f "node server.js" > /dev/null; then
      echo -e "${YELLOW}[KEEPALIVE] Dashboard down, restarting...${NC}"
      start_dashboard
    fi
    
    if ! curl -s http://localhost:$OLLAMA_PORT/api/tags > /dev/null 2>&1; then
      echo -e "${YELLOW}[KEEPALIVE] Ollama down, restarting...${NC}"
      start_ollama
    fi
    
    if ! curl -s http://localhost:$LITELLM_PORT/health > /dev/null 2>&1 && ! curl -s http://localhost:$LITELLM_PORT/ > /dev/null 2>&1; then
      echo -e "${YELLOW}[KEEPALIVE] LiteLLM down, restarting...${NC}"
      start_litellm
    fi
    
    sleep 300
  done
}

# Main
case "${1:-start}" in
  start)
    cleanup
    start_ssh
    start_dashboard
    start_ttyd
    start_code_server
    start_ollama
    start_litellm
    start_custom_router
    show_status
    
    if [ -n "$GITHUB_ACTIONS" ]; then
      echo -e "${BLUE}[INFO] Detected GitHub Actions - entering keep-alive mode${NC}"
      keep_alive
    else
      echo -e "${BLUE}[INFO] Local mode - services running in background${NC}"
      echo -e "${BLUE}[INFO] Run './start-vps.sh logs' to see logs or './start-vps.sh stop' to stop${NC}"
      echo -e "${BLUE}[INFO] Run './start-vps.sh keepalive' to enter 24/7 loop${NC}"
      echo -e "${BLUE}[INFO] Run './start-vps.sh llm' to start only LLM services${NC}"
    fi
    ;;
  llm)
    echo -e "${BLUE}[LLM] Starting only LLM services...${NC}"
    start_ollama
    start_litellm
    start_custom_router
    echo -e "${GREEN}[OK] LLM services started${NC}"
    ;;
  stop)
    echo -e "${BLUE}[STOP] Stopping all services...${NC}"
    pkill -f "node server.js" || true
    pkill -f "ttyd" || true
    pkill -f "code-server" || true
    pkill -f "ollama serve" || true
    pkill -f "litellm --config" || true
    pkill -f "node router.js" || true
    sudo pkill sshd || true
    echo -e "${GREEN}[OK] All services stopped${NC}"
    ;;
  restart)
    $0 stop
    sleep 2
    $0 start
    ;;
  logs)
    echo -e "${BLUE}[LOGS] Dashboard log:${NC}"
    tail -50 /tmp/freevps-dashboard.log 2>/dev/null || echo "No dashboard log"
    echo -e "${BLUE}[LOGS] Ollama log:${NC}"
    tail -30 /tmp/ollama.log 2>/dev/null || echo "No ollama log"
    echo -e "${BLUE}[LOGS] LiteLLM log:${NC}"
    tail -30 /tmp/litellm.log 2>/dev/null || echo "No litellm log"
    echo -e "${BLUE}[LOGS] Router log:${NC}"
    tail -30 /tmp/hermes-router.log 2>/dev/null || echo "No router log"
    ;;
  keepalive)
    keep_alive
    ;;
  status)
    show_status
    ;;
  llm-status)
    echo -e "${BLUE}[LLM STATUS]${NC}"
    curl -s http://localhost:11434/api/tags | head -20 || echo "Ollama down"
    curl -s http://localhost:4000/v1/models -H "Authorization: Bearer sk-1234" | head -20 || echo "LiteLLM down"
    curl -s http://localhost:4001/health | head -20 || echo "Router down"
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|logs|keepalive|status|llm|llm-status}"
    echo ""
    echo "  start      - Start all services (VPS + LLM) 24/7"
    echo "  llm        - Start only LLM services (Ollama + LiteLLM + Router)"
    echo "  stop       - Stop all services"
    echo "  restart    - Restart all"
    echo "  logs       - Show logs"
    echo "  keepalive  - Enter 24/7 keepalive loop"
    echo "  status     - Show status"
    echo "  llm-status - Show LLM status"
    exit 1
    ;;
esac
