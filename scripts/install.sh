#!/bin/bash
# FreeVPS Mark1.3 - Dependency Installer

set -e

echo "[INSTALL] Installing FreeVPS dependencies..."

# Update
if command -v apt-get &> /dev/null; then
  sudo apt-get update -y
  sudo apt-get install -y curl wget git python3 python3-pip nodejs npm tmux screen htop neofetch openssh-server
elif command -v yum &> /dev/null; then
  sudo yum install -y curl wget git python3 python3-pip nodejs npm tmux screen htop openssh-server
fi

# Node deps
if [ -f package.json ]; then
  npm install
fi

# ttyd
if ! command -v ttyd &> /dev/null; then
  echo "[INSTALL] Installing ttyd..."
  wget -q https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 -O /tmp/ttyd || wget -q https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 -O /tmp/ttyd
  chmod +x /tmp/ttyd
  sudo mv /tmp/ttyd /usr/local/bin/ttyd
fi

# code-server
if ! command -v code-server &> /dev/null; then
  echo "[INSTALL] Installing code-server..."
  curl -fsSL https://code-server.dev/install.sh | sh
fi

echo "[INSTALL] Done!"
