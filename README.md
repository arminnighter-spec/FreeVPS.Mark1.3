# FreeVPS Mark1.3 - 24/7 VPS Server

> **Persistent 24/7 VPS with Web Dashboard, SSH, ttyd, VS Code, Tailscale & Ngrok**
> Username: `Mikasa` | Password: `Eren@Home$123`

![VPS Status](https://img.shields.io/badge/Status-24%2F7%20Online-brightgreen)
![Version](https://img.shields.io/badge/Version-Mark1.3-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)

```
╔════════════════════════════════════════════════════╗
║         FreeVPS Mark1.3 - 24/7 VPS ONLINE          ║
╠════════════════════════════════════════════════════╣
║  Username: Mikasa                                   ║
║  Password: Eren@Home$123                            ║
║  Status:   24/7 Active                              ║
║  Access:   SSH, Web Terminal, VS Code, ttyd         ║
╚════════════════════════════════════════════════════╝
```

---

## 🚀 Quick Start - 3 Methods for 24/7 VPS

### Method 1: GitHub Actions (Recommended for True 24/7)

This is the **best way to get a free 24/7 VPS** that auto-restarts every 5 hours.

1. **Fork / Push this repo to GitHub**
2. Go to **Actions tab** → Select `FreeVPS Mark1.3 - 24/7 VPS` → Click **Run workflow**
3. Wait for workflow to start (1-2 min)
4. Check logs for access:
   - **tmate SSH**: Look for `SSH: ssh <tmate-command>` in logs (immediate access)
   - **Web Dashboard**: Port 8080 (Mikasa / Eren@Home$123)
   - **Tailscale IP**: If you set `TAILSCALE_AUTHKEY` secret, use `ssh mikasa@<tailscale-ip>`

**How 24/7 works:**
- Workflow runs for 5h50m (GitHub limit is 6h)
- Auto-restarts every 5 hours via cron `0 */5 * * *`
- Heartbeat checks every 5 min, auto-restarts services if down
- Optional: Add `GH_PAT` secret for instant restart via API

**Required Secrets (optional but recommended):**
- `TAILSCALE_AUTHKEY` - For persistent VPN SSH (get from https://login.tailscale.com/admin/settings/keys)
- `NGROK_AUTH_TOKEN` - For public URLs (get from https://dashboard.ngrok.com/get-started/your-authtoken)
- `GH_PAT` - GitHub Personal Access Token with `workflow` scope for instant auto-restart

### Method 2: Local Docker (24/7 on your machine)

```bash
# Clone
git clone https://github.com/arminnighter-spec/FreeVPS.Mark1.3.git
cd FreeVPS.Mark1.3

# Start 24/7 VPS
docker-compose up -d

# Access
# Dashboard: http://localhost:8080 (Mikasa / Eren@Home$123)
# ttyd: http://localhost:7681 (mikasa / Eren@Home$123)
# VS Code: http://localhost:8081 (password: Eren@Home$123)
# SSH: ssh mikasa@localhost -p 2222

# Logs
docker-compose logs -f

# Stop
docker-compose down
```

### Method 3: Direct Local Run

```bash
# Install deps
npm install
bash scripts/setup-vps.sh   # Creates user Mikasa

# Start all services 24/7
./start-vps.sh start

# Or just main dashboard
npm start

# Access http://localhost:8080
# Login: Mikasa / Eren@Home$123

# Other commands
./start-vps.sh status   # Check status
./start-vps.sh logs     # View logs
./start-vps.sh stop     # Stop all
./start-vps.sh keepalive # Enter 24/7 loop
```

---

## 🔑 Credentials (As Requested)

| Service | Username | Password | Port | URL |
|---------|----------|----------|------|-----|
| **Main Dashboard** | `Mikasa` | `Eren@Home$123` | 8080 | http://localhost:8080 |
| **System User** | `mikasa` / `Mikasa` | `Eren@Home$123` | 22 | ssh mikasa@localhost |
| **ttyd Terminal** | `mikasa` | `Eren@Home$123` | 7681 | http://localhost:7681 |
| **code-server** | - | `Eren@Home$123` | 8081 | http://localhost:8081 |

Both `Mikasa` (capital M) and `mikasa` (lowercase) users are created. Lowercase is primary for Linux compatibility.

---

## 📡 Access Methods Explained

### 1. Web Dashboard (Main)
- **URL**: http://localhost:8080
- **Features**:
  - 📊 Real-time system stats (CPU, RAM, Disk, Uptime)
  - 💻 Interactive Web Terminal (xterm.js + WebSocket + node-pty)
  - 📁 File Manager
  - ⚙️ Process Manager
  - 🚀 Quick command executor
  - 🔐 Secure login with bcrypt

### 2. SSH Access
```bash
# Local Docker
ssh mikasa@localhost -p 2222
# Password: Eren@Home$123

# GitHub Actions + Tailscale (persistent IP, best for 24/7)
ssh mikasa@<tailscale-ip>
# Get Tailscale IP from Actions logs

# GitHub Actions + tmate (temporary, check Actions logs)
# Look for: ssh <tmate-connection-string>
```

### 3. ttyd - Web Terminal
- URL: http://localhost:7681
- Auth: mikasa / Eren@Home$123
- Full bash terminal in browser

### 4. code-server - VS Code in Browser
- URL: http://localhost:8081
- Password: Eren@Home$123
- Full VS Code experience

### 5. Tailscale (Recommended for 24/7 Persistent SSH)
- Private VPN that gives you a stable IP
- Setup: Create auth key at https://login.tailscale.com/admin/settings/keys
- Add as `TAILSCALE_AUTHKEY` secret in GitHub repo
- Workflow will auto-connect and show IP in logs
- Then SSH from anywhere: `ssh mikasa@<tailscale-ip>`

### 6. Ngrok (Public URLs)
- Exposes your local ports to internet with public URLs
- Setup: Get token from https://dashboard.ngrok.com/get-started/your-authtoken
- Add as `NGROK_AUTH_TOKEN` secret
- Workflow will show URLs like `https://xxxx.ngrok.io -> localhost:8080`

---

## 🔄 How 24/7 Persistence Works

GitHub Actions has a 6-hour limit per run, but we achieve 24/7 via:

1. **Cron Schedule**: `0 */5 * * *` - Restarts workflow every 5 hours automatically
2. **Heartbeat Loop**: Checks services every 5 min, restarts if down
3. **Auto-Restart Logic**: Tries to trigger new workflow via API if `GH_PAT` secret set
4. **Docker Restart Policy**: `unless-stopped` for local Docker
5. **Service Monitoring**: Dashboard, ttyd, code-server auto-restart on failure
6. **External Ping (Optional)**: Use UptimeRobot to ping your ngrok URL every 5 min

**For 100% 24/7:**
- Enable Tailscale + Ngrok secrets
- Add UptimeRobot monitor for your ngrok URL
- Workflow will never truly die, just restart every 5h

---

## 📁 Project Structure

```
FreeVPS.Mark1.3/
├── server.js                 # Main dashboard server (Express + WS + node-pty)
├── package.json              # Dependencies
├── start-vps.sh              # 24/7 launcher script
├── Dockerfile                # Docker image
├── docker-compose.yml        # Docker Compose 24/7
├── .env.example              # Env template
├── config/
│   └── vps-config.json       # VPS configuration
├── scripts/
│   ├── setup-vps.sh          # User creation (Mikasa) + setup
│   └── install.sh            # Dependency installer
├── public/
│   ├── login.html            # Login page (Mikasa / Eren@Home$123)
│   └── dashboard.html        # Main dashboard with terminal
├── src/
│   └── monitor.js            # System monitor module
├── keepalive/
│   ├── keepalive.js          # Node keepalive service
│   ├── uptime-monitor.sh     # Bash monitor
│   ├── heartbeat.log         # Heartbeat logs
│   └── uptime.log            # Uptime history
└── .github/
    └── workflows/
        └── vps-24-7.yml      # 24/7 GitHub Actions workflow
```

---

## 🛠️ Manual Setup (if scripts fail)

```bash
# Create user Mikasa
sudo useradd -m -s /bin/bash mikasa
echo "mikasa:Eren@Home\$123" | sudo chpasswd
sudo usermod -aG sudo mikasa

# Also try capital
sudo useradd -m -s /bin/bash Mikasa 2>/dev/null || true
echo "Mikasa:Eren@Home\$123" | sudo chpasswd 2>/dev/null || true

# Install essentials
sudo apt update && sudo apt install -y curl wget git nodejs npm ttyd openssh-server

# Install npm deps
npm install

# Start
PORT=8080 VPS_USER=Mikasa VPS_PASS='Eren@Home$123' node server.js
```

---

## 🔒 Security Notes

- ✅ Password hashed with bcrypt in dashboard
- ✅ Session-based auth with httpOnly cookies
- ✅ SSH password auth enabled (change in production)
- ⚠️ Default credentials are `Mikasa / Eren@Home$123` as requested - **change in production via .env**
- ⚠️ For public deployments, set `SESSION_SECRET` env and enable HTTPS
- 💡 Use GitHub Secrets for tokens, never commit them
- 💡 Enable UFW: `sudo ufw allow 22,8080,7681,8081/tcp && sudo ufw enable`

---

## 📊 Monitoring 24/7 Status

- **Dashboard**: http://localhost:8080/api/stats (after login)
- **Health**: http://localhost:8080/health (public)
- **Heartbeat Log**: `keepalive/heartbeat.log`
- **Uptime Log**: `keepalive/uptime.log`
- **Logs**: `/tmp/freevps-dashboard.log`, `/tmp/ttyd.log`, `/tmp/code-server.log`

Use Uptime Kuma (included in docker-compose monitoring profile):
```bash
docker-compose --profile monitoring up -d
# Access http://localhost:3001
```

---

## ❓ FAQ

**Q: How is this 24/7 if GitHub Actions limit is 6h?**
A: Workflow auto-restarts every 5h via cron schedule. With Tailscale, you keep same IP across restarts, so SSH stays persistent.

**Q: Can I get a public IP?**
A: Yes via Ngrok (set `NGROK_AUTH_TOKEN` secret) or Tailscale (private but persistent).

**Q: Will my files persist across restarts?**
A: In GitHub Actions, workspace is ephemeral but you can commit to repo or use artifacts. For persistence, use Docker locally with volumes.

**Q: How to keep files in GitHub Actions?**
A: Add to repo, or use `actions/upload-artifact`, or sync to external storage.

**Q: Username is Mikasa but login fails?**
A: Try `mikasa` lowercase for system SSH/ttyd, and `Mikasa` capital for web dashboard. Both should work.

---

## 🤝 Contributing

PRs welcome! This is Mark1.3 - next is Mark2.5 😄

---

## 📜 License

MIT - Free for all

---

## 🙏 Credits

Built for 24/7 free VPS hosting using:
- GitHub Actions (free 2000 min/month)
- Tailscale (free VPN)
- Ngrok (free tunnels)
- ttyd + code-server + tmate
- Node.js + Express + xterm.js

**Enjoy your 24/7 VPS, Mikasa!** 🚀

> "nothing in here bro Mark 2.5" → Now it's full Mark1.3 24/7 💪
