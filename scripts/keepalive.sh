#!/bin/bash
# FreeVPS Mark1.3 - Keepalive Loop for 24/7
# Use in GitHub Actions or local tmux

VPS_USER="Mikasa"
INTERVAL=300  # 5 minutes

echo "FreeVPS Mark1.3 Keepalive started - User: $VPS_USER - $(date)"

COUNT=0
while true; do
  COUNT=$((COUNT+1))
  echo "[$(date)] Heartbeat #$COUNT - Uptime: $(uptime -p) - User: $VPS_USER - Load: $(cat /proc/loadavg | awk '{print $1}')"
  
  # Check dashboard
  if ! pgrep -f "node server.js" > /dev/null; then
    echo "[$(date)] Dashboard down, restarting..."
    PORT=8080 VPS_USER=Mikasa VPS_PASS='Eren@Home$123' nohup node server.js > /tmp/dashboard.log 2>&1 &
  fi
  
  # Check SSH
  if ! pgrep sshd > /dev/null; then
    echo "[$(date)] SSH down, restarting..."
    sudo /usr/sbin/sshd 2>/dev/null || sudo service ssh start 2>/dev/null || true
  fi
  
  sleep $INTERVAL
done
