#!/bin/bash
# FreeVPS Mark1.3 - Uptime Monitor & Auto-Restart for 24/7

VPS_USER="Mikasa"
LOG_FILE="/tmp/uptime-monitor.log"
HEARTBEAT_FILE="$(dirname $0)/heartbeat.log"

echo "=== FreeVPS Mark1.3 Uptime Monitor ===" | tee -a $LOG_FILE
echo "Started: $(date) - User: $VPS_USER" | tee -a $LOG_FILE

while true; do
  echo "[$(date)] Checking services..." | tee -a $LOG_FILE
  
  # Check dashboard
  if ! pgrep -f "node server.js" > /dev/null; then
    echo "[$(date)] Dashboard down, restarting..." | tee -a $LOG_FILE
    PORT=8080 VPS_USER=Mikasa VPS_PASS='Eren@Home$123' nohup node server.js > /tmp/dashboard.log 2>&1 &
  fi
  
  # Check disk space
  DISK_USE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
  if [ "$DISK_USE" -gt 90 ]; then
    echo "[$(date)] WARNING: Disk usage ${DISK_USE}% - cleaning logs" | tee -a $LOG_FILE
    truncate -s 0 /tmp/*.log 2>/dev/null || true
    npm cache clean --force 2>/dev/null || true
  fi
  
  # Log heartbeat
  echo "[$(date)] Online - Uptime: $(uptime -p) - Disk: ${DISK_USE}% - Mem: $(free -h | grep Mem | awk '{print $3"/"$2}')" | tee -a $HEARTBEAT_FILE -a $LOG_FILE
  
  sleep 300
done
