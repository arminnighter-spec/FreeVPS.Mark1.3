#!/bin/bash
# FreeVPS Mark1.3 - 24/7 VPS Starter
# Starts all services for persistent VPS

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

echo -e "${PURPLE}"
cat << "EOF"
╔════════════════════════════════════════════════════╗
║         FreeVPS Mark1.3 - 24/7 VPS Launcher        ║
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
  
  # Install deps if needed
  if [ ! -d "node_modules" ]; then
    echo -e "${BLUE}[INFO] Installing npm dependencies...${NC}"
    npm install --production 2>&1 | tail -5
  fi
  
  # Start server in background
  PORT=$MAIN_PORT VPS_USER=$VPS_USER VPS_PASS="$VPS_PASS" nohup node server.js > /tmp/freevps-dashboard.log 2>&1 &
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
    # Start ttyd with login
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
    # Set password for code-server
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
║  Services:                                         ║
║  • Main Dashboard: http://localhost:$MAIN_PORT            ║
║  • ttyd Terminal:  http://localhost:$TTYD_PORT            ║
║  • VS Code:        http://localhost:$CODE_PORT            ║
║  • SSH:            ssh $VPS_USER_LOWER@localhost             ║
╠════════════════════════════════════════════════════╣
║  Logs:                                             ║
║  • Dashboard: /tmp/freevps-dashboard.log           ║
║  • ttyd:      /tmp/ttyd.log                        ║
║  • code-server:/tmp/code-server.log                ║
╚════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  
  echo -e "${BLUE}[STATUS] Running processes:${NC}"
  ps aux | grep -E "server.js|ttyd|code-server|sshd" | grep -v grep || echo "No processes found"
  echo ""
  echo -e "${BLUE}[STATUS] Listening ports:${NC}"
  ss -tlnp 2>/dev/null | grep -E "$MAIN_PORT|$TTYD_PORT|$CODE_PORT|$SSH_PORT" || netstat -tlnp 2>/dev/null | grep -E "$MAIN_PORT|$TTYD_PORT|$CODE_PORT|$SSH_PORT" || echo "Checking ports..."
  echo ""
  echo -e "${GREEN}[INFO] VPS is now running 24/7! Keep this terminal open or use tmux/screen${NC}"
  echo -e "${YELLOW}[INFO] For GitHub Actions 24/7: push this repo and run workflow 'FreeVPS 24/7'${NC}"
}

# Function to keep alive (for GitHub Actions)
keep_alive() {
  echo -e "${BLUE}[KEEPALIVE] Starting 24/7 keep-alive loop...${NC}"
  echo -e "${BLUE}[KEEPALIVE] VPS will stay alive as long as this process runs${NC}"
  
  # Heartbeat
  while true; do
    echo "[$(date)] FreeVPS Mark1.3 - Heartbeat - Uptime: $(uptime -p) - User: $VPS_USER - Services: $(ps aux | grep -E 'server.js|ttyd|code-server' | grep -v grep | wc -l) running"
    
    # Check if services are still running, restart if needed
    if ! pgrep -f "node server.js" > /dev/null; then
      echo -e "${YELLOW}[KEEPALIVE] Dashboard down, restarting...${NC}"
      start_dashboard
    fi
    
    # For GitHub Actions, we need to keep output alive
    sleep 300  # 5 minutes
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
    show_status
    
    # If in GitHub Actions, keep alive
    if [ -n "$GITHUB_ACTIONS" ]; then
      echo -e "${BLUE}[INFO] Detected GitHub Actions - entering keep-alive mode${NC}"
      keep_alive
    else
      echo -e "${BLUE}[INFO] Local mode - services running in background${NC}"
      echo -e "${BLUE}[INFO] Run './start-vps.sh logs' to see logs or './start-vps.sh stop' to stop${NC}"
      echo -e "${BLUE}[INFO] Run './start-vps.sh keepalive' to enter 24/7 loop${NC}"
    fi
    ;;
  stop)
    echo -e "${BLUE}[STOP] Stopping all services...${NC}"
    pkill -f "node server.js" || true
    pkill -f "ttyd" || true
    pkill -f "code-server" || true
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
    echo -e "${BLUE}[LOGS] ttyd log:${NC}"
    tail -20 /tmp/ttyd.log 2>/dev/null || echo "No ttyd log"
    echo -e "${BLUE}[LOGS] code-server log:${NC}"
    tail -20 /tmp/code-server.log 2>/dev/null || echo "No code-server log"
    ;;
  keepalive)
    keep_alive
    ;;
  status)
    show_status
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|logs|keepalive|status}"
    exit 1
    ;;
esac
