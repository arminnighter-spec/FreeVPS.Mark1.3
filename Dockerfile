FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VPS_USER=Mikasa
ENV VPS_USER_LOWER=mikasa
ENV VPS_PASS=Eren@Home$123
ENV MAIN_PORT=8080
ENV TTYD_PORT=7681
ENV CODE_PORT=8081

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl wget git htop nano vim tmux screen \
    openssh-server supervisor net-tools lsof \
    unzip zip build-essential python3 python3-pip \
    nodejs npm sudo neofetch jq \
    && rm -rf /var/lib/apt/lists/*

# Create VPS user Mikasa
RUN useradd -m -s /bin/bash mikasa && \
    echo "mikasa:Eren@Home\$123" | chpasswd && \
    usermod -aG sudo mikasa && \
    echo "mikasa ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    useradd -m -s /bin/bash Mikasa 2>/dev/null || true && \
    echo "Mikasa:Eren@Home\$123" | chpasswd 2>/dev/null || true && \
    usermod -aG sudo Mikasa 2>/dev/null || true

# Install ttyd
RUN wget -q https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 -O /usr/local/bin/ttyd && \
    chmod +x /usr/local/bin/ttyd

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Setup SSH
RUN mkdir -p /var/run/sshd /run/sshd && \
    sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    ssh-keygen -A

# Create app directory
WORKDIR /app
COPY package.json ./
RUN npm install --production

COPY . .

# Make scripts executable
RUN chmod +x scripts/*.sh start-vps.sh

# Expose ports
EXPOSE 22 8080 7681 8081

# Create entrypoint
RUN cat > /entrypoint.sh << 'EOF'
#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════╗"
echo "║         FreeVPS Mark1.3 - Docker VPS Starting      ║"
echo "║  User: Mikasa / Password: Eren@Home\$123           ║"
echo "╚════════════════════════════════════════════════════╝"

# Start SSH
/usr/sbin/sshd

# Start dashboard
PORT=8080 VPS_USER=Mikasa VPS_PASS='Eren@Home$123' node server.js &
echo $! > /tmp/dashboard.pid

# Start ttyd
ttyd -p 7681 -c mikasa:'Eren@Home$123' bash &
echo $! > /tmp/ttyd.pid

# Start code-server
mkdir -p /home/mikasa/.config/code-server
cat > /home/mikasa/.config/code-server/config.yaml << EOC
bind-addr: 0.0.0.0:8081
auth: password
password: Eren@Home\$123
cert: false
EOC
chown -R mikasa:mikasa /home/mikasa/.config
sudo -u mikasa code-server --bind-addr 0.0.0.0:8081 --auth password &

echo "✅ All services started"
echo "Dashboard: http://localhost:8080 (Mikasa / Eren@Home\$123)"
echo "ttyd: http://localhost:7681"
echo "code-server: http://localhost:8081"
echo "SSH: ssh mikasa@localhost -p 2222 (if mapped)"

# Keep alive
tail -f /dev/null
EOF

RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
