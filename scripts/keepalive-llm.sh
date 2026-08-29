#!/bin/bash
# FreeVPS Mark1.3 - LLM Keepalive for 24/7
# Monitors Ollama + LiteLLM + Custom Router and restarts if down

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

OLLAMA_HOST="http://localhost:11434"
LITELLM_HOST="http://localhost:4000"
ROUTER_HOST="http://localhost:4001"
LOG_FILE="/tmp/llm-keepalive.log"
HEARTBEAT_FILE="keepalive/llm-heartbeat.log"

mkdir -p keepalive

echo -e "${BLUE}[LLM-KEEPALIVE] Starting 24/7 LLM keepalive...${NC}" | tee -a $LOG_FILE
echo -e "${BLUE}[LLM-KEEPALIVE] Monitoring Ollama, LiteLLM, Custom Router every 60s${NC}" | tee -a $LOG_FILE

check_and_restart_ollama() {
  if curl -s $OLLAMA_HOST/api/tags > /dev/null 2>&1; then
    echo "[$(date)] ✅ Ollama OK" | tee -a $LOG_FILE
    return 0
  else
    echo "[$(date)] ❌ Ollama DOWN, restarting..." | tee -a $LOG_FILE
    pkill -f "ollama serve" 2>/dev/null || true
    sleep 2
    nohup ollama serve > /tmp/ollama.log 2>&1 &
    echo $! > /tmp/ollama.pid
    sleep 5
    if curl -s $OLLAMA_HOST/api/tags > /dev/null 2>&1; then
      echo "[$(date)] ✅ Ollama restarted OK" | tee -a $LOG_FILE
    else
      echo "[$(date)] ❌ Ollama restart FAILED" | tee -a $LOG_FILE
    fi
  fi
}

check_and_restart_litellm() {
  if curl -s $LITELLM_HOST/health > /dev/null 2>&1 || curl -s $LITELLM_HOST/ > /dev/null 2>&1; then
    echo "[$(date)] ✅ LiteLLM OK" | tee -a $LOG_FILE
    return 0
  else
    echo "[$(date)] ❌ LiteLLM DOWN, restarting..." | tee -a $LOG_FILE
    pkill -f "litellm --config" 2>/dev/null || true
    sleep 2
    if [ -f llm/litellm/litellm-config.yaml ]; then
      nohup litellm --config llm/litellm/litellm-config.yaml --port 4000 > /tmp/litellm.log 2>&1 &
    else
      nohup litellm --config /tmp/litellm-config.yaml --port 4000 > /tmp/litellm.log 2>&1 &
    fi
    echo $! > /tmp/litellm.pid
    sleep 5
    if curl -s $LITELLM_HOST/health > /dev/null 2>&1; then
      echo "[$(date)] ✅ LiteLLM restarted OK" | tee -a $LOG_FILE
    else
      echo "[$(date)] ❌ LiteLLM restart FAILED" | tee -a $LOG_FILE
    fi
  fi
}

check_and_restart_router() {
  if curl -s $ROUTER_HOST/health > /dev/null 2>&1; then
    echo "[$(date)] ✅ Custom Router OK" | tee -a $LOG_FILE
    return 0
  else
    echo "[$(date)] ❌ Custom Router DOWN, restarting..." | tee -a $LOG_FILE
    pkill -f "node router.js" 2>/dev/null || true
    sleep 2
    if [ -f llm/router/router.js ]; then
      cd llm/router
      PORT=4001 OLLAMA_HOST=$OLLAMA_HOST LITELLM_HOST=$LITELLM_HOST nohup node router.js > /tmp/hermes-router.log 2>&1 &
      echo $! > /tmp/hermes-router.pid
      cd ../..
      sleep 3
      if curl -s $ROUTER_HOST/health > /dev/null 2>&1; then
        echo "[$(date)] ✅ Custom Router restarted OK" | tee -a $LOG_FILE
      else
        echo "[$(date)] ❌ Custom Router restart FAILED" | tee -a $LOG_FILE
      fi
    fi
  fi
}

# Main loop
COUNT=0
while true; do
  COUNT=$((COUNT+1))
  echo "[$(date)] 💓 LLM Heartbeat #$COUNT - Checking services..." | tee -a $LOG_FILE
  echo "[$(date)] LLM Heartbeat #$COUNT - Ollama: $(curl -s $OLLAMA_HOST/api/tags > /dev/null && echo OK || echo DOWN), LiteLLM: $(curl -s $LITELLM_HOST/health > /dev/null && echo OK || echo DOWN), Router: $(curl -s $ROUTER_HOST/health > /dev/null && echo OK || echo DOWN)" >> $HEARTBEAT_FILE

  check_and_restart_ollama
  check_and_restart_litellm
  check_and_restart_router

  # Keep heartbeat log size limited
  tail -100 $HEARTBEAT_FILE > /tmp/llm-hb.tmp 2>/dev/null && mv /tmp/llm-hb.tmp $HEARTBEAT_FILE 2>/dev/null || true

  echo "[$(date)] 💤 Sleeping 60s..." | tee -a $LOG_FILE
  sleep 60
done
