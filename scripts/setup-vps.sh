#!/bin/bash
# FreeVPS Mark1.3 - Main VPS Setup Script
# Creates user Mikasa with password Eren@Home$123 and configures 24/7 environment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

VPS_USER="Mikasa"
VPS_USER_LOWER="mikasa"
VPS_PASS="Eren@Home\$123"
# For chpasswd we need unescaped
VPS_PASS_RAW='Eren@Home$123'

echo -e "${PURPLE}"
cat << "EOF"
╔════════════════════════════════════════════════════╗
║         FreeVPS Mark1.3 - VPS Setup                ║
║         24/7 Persistent VPS Installer              ║
╚════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${BLUE}[INFO] Starting VPS setup for user: $VPS_USER${NC}"
echo -e "${BLUE}[INFO] Date: $(date)${NC}"
echo -e "${BLUE}[INFO] Host: $(hostname)${NC}"
echo -e "${BLUE}[INFO] User: $(whoami)${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}[WARN] Not running as root. Some operations may require sudo.${NC}"
  SUDO="sudo"
else
  SUDO=""
  echo -e "${GREEN}[INFO] Running as root - full setup available${NC}"
fi

# Function to create user
create_user() {
  echo -e "${BLUE}[SETUP] Creating user $VPS_USER...${NC}"
  
  if id "$VPS_USER_LOWER" &>/dev/null; then
    echo -e "${YELLOW}[WARN] User $VPS_USER_LOWER already exists${NC}"
  else
    $SUDO useradd -m -s /bin/bash "$VPS_USER_LOWER" || $SUDO adduser --disabled-password --gecos "" "$VPS_USER_LOWER"
    echo -e "${GREEN}[OK] User $VPS_USER_LOWER created${NC}"
  fi

  # Also create Mikasa with capital M if possible (Linux usernames are usually lowercase, so we create alias)
  if ! id "$VPS_USER" &>/dev/null && [ "$VPS_USER" != "$VPS_USER_LOWER" ]; then
    # Try to create with capital, if fails create symlink/hint
    $SUDO useradd -m -s /bin/bash "$VPS_USER" 2>/dev/null || echo -e "${YELLOW}[INFO] Capital username not allowed, using lowercase $VPS_USER_LOWER as primary${NC}"
  fi

  # Set password
  echo -e "${BLUE}[SETUP] Setting password for $VPS_USER_LOWER...${NC}"
  echo "$VPS_USER_LOWER:$VPS_PASS_RAW" | $SUDO chpasswd
  if id "$VPS_USER" &>/dev/null; then
    echo "$VPS_USER:$VPS_PASS_RAW" | $SUDO chpasswd 2>/dev/null || true
  fi
  echo -e "${GREEN}[OK] Password set for $VPS_USER / $VPS_USER_LOWER${NC}"

  # Add to sudoers
  echo -e "${BLUE}[SETUP] Adding to sudo group...${NC}"
  $SUDO usermod -aG sudo "$VPS_USER_LOWER" 2>/dev/null || $SUDO usermod -aG wheel "$VPS_USER_LOWER" 2>/dev/null || true
  if id "$VPS_USER" &>/dev/null; then
    $SUDO usermod -aG sudo "$VPS_USER" 2>/dev/null || true
  fi
  
  # Allow passwordless sudo for automation (optional, comment out if not wanted)
  echo "$VPS_USER_LOWER ALL=(ALL) NOPASSWD:ALL" | $SUDO tee /etc/sudoers.d/$VPS_USER_LOWER > /dev/null
  $SUDO chmod 440 /etc/sudoers.d/$VPS_USER_LOWER
  
  echo -e "${GREEN}[OK] User setup complete${NC}"
}

# Install essentials
install_essentials() {
  echo -e "${BLUE}[SETUP] Installing essential packages...${NC}"
  
  if command -v apt-get &> /dev/null; then
    $SUDO apt-get update -y
    $SUDO apt-get install -y \
      curl wget git htop nano vim \
      openssh-server \
      supervisor \
      net-tools \
      lsof \
      unzip zip \
      build-essential \
      python3 python3-pip \
      nodejs npm \
      tmux screen \
      neofetch \
      fail2ban \
      ufw \
      jq
      
  elif command -v yum &> /dev/null; then
    $SUDO yum update -y
    $SUDO yum install -y curl wget git htop nano vim openssh-server supervisor net-tools lsof unzip zip python3 nodejs npm tmux screen jq
  elif command -v apk &> /dev/null; then
    $SUDO apk add curl wget git htop nano vim openssh supervisor net-tools lsof unzip zip python3 py3-pip nodejs npm tmux screen jq bash
  fi
  
  echo -e "${GREEN}[OK] Essentials installed${NC}"
}

# Setup SSH
setup_ssh() {
  echo -e "${BLUE}[SETUP] Configuring SSH...${NC}"
  
  $SUDO mkdir -p /var/run/sshd
  $SUDO mkdir -p /run/sshd 2>/dev/null || true
  
  # Configure SSH to allow password auth
  $SUDO sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  $SUDO sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  $SUDO sed -i 's/#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  
  # Ensure SSH host keys exist
  $SUDO ssh-keygen -A 2>/dev/null || true
  
  echo -e "${GREEN}[OK] SSH configured${NC}"
  
  # Start SSH if possible
  $SUDO service ssh start 2>/dev/null || $SUDO systemctl start sshd 2>/dev/null || $SUDO /usr/sbin/sshd 2>/dev/null || echo -e "${YELLOW}[WARN] Could not auto-start SSH, manual start needed${NC}"
}

# Setup web services (ttyd, code-server)
setup_web_services() {
  echo -e "${BLUE}[SETUP] Installing web services (ttyd, code-server)...${NC}"
  
  # Install ttyd
  if ! command -v ttyd &> /dev/null; then
    echo -e "${BLUE}[INFO] Installing ttyd...${NC}"
    if command -v apt-get &> /dev/null; then
      # Try apt
      $SUDO apt-get install -y ttyd 2>/dev/null || {
        # Build from binary
        TTYD_VERSION="1.7.7"
        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then ARCH="x86_64"; else ARCH="x86_64"; fi
        wget -q https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${ARCH} -O /tmp/ttyd || wget -q https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 -O /tmp/ttyd || echo "ttyd download failed"
        if [ -f /tmp/ttyd ]; then
          chmod +x /tmp/ttyd
          $SUDO mv /tmp/ttyd /usr/local/bin/ttyd
        fi
      }
    fi
  fi
  
  # Install code-server
  if ! command -v code-server &> /dev/null; then
    echo -e "${BLUE}[INFO] Installing code-server...${NC}"
    curl -fsSL https://code-server.dev/install.sh | sh 2>/dev/null || {
      echo -e "${YELLOW}[WARN] code-server install failed, trying npm fallback${NC}"
      $SUDO npm install -g code-server 2>/dev/null || true
    }
  fi
  
  # Install node-pty dependencies for main server
  if [ -f "package.json" ]; then
    echo -e "${BLUE}[INFO] Installing Node dependencies...${NC}"
    npm install 2>/dev/null || $SUDO npm install 2>/dev/null || true
  fi
  
  echo -e "${GREEN}[OK] Web services setup${NC}"
}

# Setup Tailscale (for persistent SSH)
setup_tailscale() {
  echo -e "${BLUE}[SETUP] Setting up Tailscale (optional persistent VPN)...${NC}"
  if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh 2>/dev/null || echo -e "${YELLOW}[WARN] Tailscale install failed${NC}"
  fi
  echo -e "${GREEN}[OK] Tailscale check done${NC}"
  echo -e "${YELLOW}[INFO] To use Tailscale: set TAILSCALE_AUTHKEY secret and run 'sudo tailscale up --authkey=\$AUTHKEY'${NC}"
}

# Setup Ngrok (optional)
setup_ngrok() {
  echo -e "${BLUE}[SETUP] Checking ngrok...${NC}"
  if ! command -v ngrok &> /dev/null; then
    echo -e "${BLUE}[INFO] Installing ngrok...${NC}"
    if command -v apt-get &> /dev/null; then
      curl -s https://ngrok.com/download/deb | $SUDO tee /etc/apt/sources.list.d/ngrok.list >/dev/null
      $SUDO apt-get update && $SUDO apt-get install ngrok -y 2>/dev/null || {
        # Direct download
        wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -O /tmp/ngrok.tgz && tar -xzf /tmp/ngrok.tgz -C /tmp && $SUDO mv /tmp/ngrok /usr/local/bin/
      }
    fi
  fi
  echo -e "${GREEN}[OK] Ngrok check done${NC}"
}

# Create motd and welcome
setup_motd() {
  echo -e "${BLUE}[SETUP] Creating MOTD...${NC}"
  
  $SUDO tee /etc/motd > /dev/null << EOF
╔════════════════════════════════════════════════════╗
║         FreeVPS Mark1.3 - 24/7 VPS ONLINE          ║
╠════════════════════════════════════════════════════╣
║  Username: Mikasa                                   ║
║  Password: Eren@Home\$123                            ║
║  Status:   24/7 Active                              ║
║  Access:   SSH, Web Terminal, VS Code, ttyd         ║
╚════════════════════════════════════════════════════╝

Welcome, Mikasa! Your VPS is ready.

Quick commands:
  htop          - System monitor
  neofetch      - System info
  code-server   - VS Code in browser (port 8081)
  ttyd          - Web terminal (port 7681)
  npm start     - Start main dashboard (port 8080)

GitHub: FreeVPS.Mark1.3
Keep alive: 24/7 via GitHub Actions

EOF

  # Add to bashrc for user
  for USER_HOME in /home/$VPS_USER_LOWER /home/$VPS_USER; do
    if [ -d "$USER_HOME" ]; then
      echo 'cat /etc/motd' >> $USER_HOME/.bashrc
      echo 'echo ""' >> $USER_HOME/.bashrc
      $SUDO chown $(basename $USER_HOME):$(basename $USER_HOME) $USER_HOME/.bashrc 2>/dev/null || true
    fi
  done
  
  echo -e "${GREEN}[OK] MOTD created${NC}"
}

# Main execution
main() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE} FreeVPS Mark1.3 Setup Starting${NC}"
  echo -e "${BLUE}========================================${NC}"
  
  create_user
  install_essentials
  setup_ssh
  setup_web_services
  setup_tailscale
  setup_ngrok
  setup_motd
  
  echo -e "${GREEN}"
  cat << EOF
╔════════════════════════════════════════════════════╗
║         ✅ FreeVPS Mark1.3 Setup Complete!         ║
╠════════════════════════════════════════════════════╣
║  Username: Mikasa                                   ║
║  Password: Eren@Home\$123                            ║
║                                                    ║
║  Access Methods:                                   ║
║  • SSH: ssh mikasa@localhost (or Mikasa)            ║
║  • Web Dashboard: http://localhost:8080            ║
║  • ttyd: http://localhost:7681                     ║
║  • code-server: http://localhost:8081              ║
║  • tmate: Check GitHub Actions logs                ║
║                                                    ║
║  To start VPS:                                     ║
║  ./start-vps.sh  OR  npm start                     ║
╚════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  
  # Show system info
  echo -e "${BLUE}[INFO] System Information:${NC}"
  neofetch 2>/dev/null || uname -a
  echo ""
  echo -e "${BLUE}[INFO] Disk Usage:${NC}"
  df -h | head -20
  echo ""
  echo -e "${BLUE}[INFO] Memory:${NC}"
  free -h
}

main "$@"
