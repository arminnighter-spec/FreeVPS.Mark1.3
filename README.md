# FreeVPS.Mark1.3 - 24/7 VPS Server

> **Persistent VPS with Web Dashboard, RDP, SSH, ttyd, VS Code, Tailscale, Ngrok & Cloudflare Tunnels**
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
║  Access:   SSH, RDP, Web Terminal, VS Code, ttyd    ║
╚════════════════════════════════════════════════════╝
```

---

## ⚠️ Read this first - GitHub ToS Compliance

GitHub-hosted Actions runners stop after **6 hours** and GitHub's Terms of Service forbid using Actions as an always-on server or crypto/relay host. 

So this repo provides **two compliant options**:

1. **Manually started, time-limited dev box (up to 6h per run)** - Uses Cloudflare Tunnels for RDP+SSH, no auto-restart loop (see `workflows/vps.yml` / Option A). **This is the ToS-compliant way to use GitHub Actions.**

2. **Real 24/7 box via Docker** - Run on a host you control (home server, Oracle Cloud free tier, cheap VPS). This is genuine 24/7 with `restart: unless-stopped` (Option B).

3. **Extended 24/7 via auto-restart workflow** - Optional workflow `.github/workflows/vps-24-7.yml` that auto-restarts every 5h via cron for true 24/7 (Option C). Use with caution and only if you understand ToS - best combined with Tailscale for persistent IP.

**Default login is `Mikasa`**; the password (`Eren@Home$123`) is **never hardcoded in workflows** for the RDP version — you supply it as a secret `VPS_PASS`. For the web dashboard, it's configured via env but bcrypt-hashed.

---

## 🚀 Quick Start - 4 Methods

### Option A — GitHub Actions Dev Box (RDP + SSH, up to ~6h, ToS-compliant)

1. Repo → **Settings → Secrets and variables → Actions**
   - New **repository secret**: `VPS_PASS` = `Eren@Home$123`
   - (optional) New **variable**: `VPS_USER` = `Mikasa`
2. Copy workflow into place (GitHub App tokens can't write to `.github/workflows` directly):
   ```bash
   mkdir -p .github/workflows && cp workflows/vps.yml .github/workflows/vps.yml
   git add .github/workflows/vps.yml && git commit -m "Add VPS workflow" && git push
   ```
3. **Actions → Remote Dev Box (RDP + SSH) → Run workflow**, pick duration (max 350 min).
4. Open the **"Start Cloudflare tunnels"** step log and copy the two `*.trycloudflare.com` hostnames.
5. On your PC (install [`cloudflared`](https://github.com/cloudflare/cloudflared/releases)):
   ```bash
   # Desktop
   cloudflared access tcp --hostname <RDP-HOST> --url localhost:3389
   # then RDP client -> localhost:3389, user Mikasa, pass Eren@Home$123

   # Shell
   cloudflared access tcp --hostname <SSH-HOST> --url localhost:2222
   ssh Mikasa@localhost -p 2222
   ```

### Option B — Real 24/7 Box (Docker, Recommended for True 24/7)

Run on any always-on host: home server, Oracle Cloud free tier, a cheap VPS, etc.

```bash
# Option B1: Our enhanced Docker (with dashboard)
docker-compose up -d --build
# Access:
# - Dashboard: http://<host>:8080 (Mikasa / Eren@Home$123)
# - ttyd: http://<host>:7681
# - VS Code: http://<host>:8081
# - SSH: ssh mikasa@<host> -p 2222

# Option B2: Minimal RDP desktop from original
cd docker
cp .env.example .env      # set VPS_PASS=Eren@Home$123   (quote it in shells)
docker compose up -d --build
# - Web desktop (noVNC): http://<host>:6080/vnc.html
# - SSH: ssh Mikasa@<host> -p 2222
```

Data persists in the `vps-home` volume, and `restart: unless-stopped` brings it back after reboots.

### Option C — 24/7 Auto-Restart Workflow (Extended)

This uses `.github/workflows/vps-24-7.yml` which **auto-restarts every 5 hours via cron** to achieve 24/7.

1. **Fork / Push this repo**
2. Go to **Actions → FreeVPS Mark1.3 - 24/7 VPS → Run workflow**
3. Check logs for:
   - **tmate SSH**: `SSH: ssh <tmate-command>` (immediate)
   - **Tailscale IP**: if `TAILSCALE_AUTHKEY` secret set → `ssh mikasa@<tailscale-ip>` (persistent!)
   - **Ngrok URLs**: if `NGROK_AUTH_TOKEN` set → public https URLs
   - **Dashboard**: Port 8080

**How 24/7 works:**
- Runs 5h50m (limit 6h), then cron `0 */5 * * *` restarts
- Heartbeat every 5 min, auto-restarts services
- Optional `GH_PAT` secret for instant API restart

**Secrets for Option C:**
- `TAILSCALE_AUTHKEY` - Persistent VPN (https://login.tailscale.com/admin/settings/keys)
- `NGROK_AUTH_TOKEN` - Public URLs (https://dashboard.ngrok.com/get-started/your-authtoken)
- `GH_PAT` - PAT with workflow scope for instant restart

### Option D — Direct Local Run (Fastest)

```bash
# Install deps
npm install
bash scripts/setup-vps.sh   # Creates user Mikasa with Eren@Home$123

# Start all services 24/7
./start-vps.sh start

# Or just main dashboard
npm start
# Access http://localhost:8080
# Login: Mikasa / Eren@Home$123

# Commands
./start-vps.sh status
./start-vps.sh logs
./start-vps.sh stop
./start-vps.sh keepalive
```

---

## 🔑 Credentials (As Requested)

| Service | Username | Password | Port | URL |
|---------|----------|----------|------|-----|
| **Main Dashboard** | `Mikasa` | `Eren@Home$123` | 8080 | http://localhost:8080 |
| **System User** | `mikasa` / `Mikasa` | `Eren@Home$123` | 22 | ssh mikasa@localhost |
| **RDP (GitHub Actions)** | `Mikasa` | `Eren@Home$123` (via secret) | 3389 | via Cloudflare Tunnel |
| **ttyd Terminal** | `mikasa` | `Eren@Home$123` | 7681 | http://localhost:7681 |
| **code-server** | - | `Eren@Home$123` | 8081 | http://localhost:8081 |
| **Docker noVNC** | `Mikasa` | `Eren@Home$123` | 6080 | http://localhost:6080/vnc.html |

Both `Mikasa` (capital M) and `mikasa` (lowercase) users are created. Lowercase is primary for Linux compatibility.

---

## 📡 Access Methods Detailed

### 1. Web Dashboard (Main - Option C/D)
- **URL**: http://localhost:8080
- Features: Real-time stats, interactive terminal (xterm.js + WS), file manager, process manager, quick exec, bcrypt auth
- Login: Mikasa / Eren@Home$123

### 2. RDP Desktop (Option A - GitHub Actions)
- Via Cloudflare Tunnel: `cloudflared access tcp --hostname <RDP-HOST> --url localhost:3389` then RDP to localhost:3389
- XFCE4 desktop, Firefox preinstalled

### 3. SSH Access
```bash
# Local Docker
ssh mikasa@localhost -p 2222

# GitHub Actions + Cloudflare
cloudflared access tcp --hostname <SSH-HOST> --url localhost:2222
ssh Mikasa@localhost -p 2222

# GitHub Actions + Tailscale (persistent IP, best for 24/7)
ssh mikasa@<tailscale-ip>

# GitHub Actions + tmate (temporary)
# Use command from Actions logs
```

### 4. ttyd - Web Terminal
- http://localhost:7681, auth mikasa / Eren@Home$123

### 5. code-server - VS Code
- http://localhost:8081, password Eren@Home$123

### 6. Tailscale (Recommended for 24/7 Persistent SSH)
- Private VPN stable IP
- Set `TAILSCALE_AUTHKEY` secret, workflow auto-connects, IP in logs

### 7. Ngrok (Public URLs)
- Set `NGROK_AUTH_TOKEN`, get https://xxxx.ngrok.io URLs

---

## 🔄 How 24/7 Persistence Works

**Compliant way (Option A):** Manual runs up to 6h, no auto-restart.

**Real 24/7 (Option B):** Docker `restart: unless-stopped` on your own host.

**Extended 24/7 (Option C):**
1. Cron `0 */5 * * *` restarts workflow every 5h
2. Heartbeat every 5 min restarts services
3. `GH_PAT` for API instant restart
4. Tailscale keeps same IP across restarts
5. UptimeRobot ping optional

---

## 📁 Project Structure

```
FreeVPS.Mark1.3/
├── server.js                 # Main dashboard (Express + WS)
├── package.json
├── start-vps.sh              # 24/7 launcher
├── Dockerfile                # Enhanced Docker (dashboard+ttyd+code)
├── docker-compose.yml        # Enhanced compose
├── docker/                   # Original RDP desktop
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── entrypoint.sh
│   └── .env.example
├── workflows/
│   └── vps.yml               # Compliant RDP+SSH Cloudflare workflow
├── .github/workflows/
│   ├── vps-24-7.yml          # Extended 24/7 auto-restart
│   └── vps.yml (copy from workflows/vps.yml)
├── config/vps-config.json
├── scripts/
│   ├── setup-vps.sh          # Creates Mikasa
│   ├── create-user.sh
│   ├── install.sh
│   └── keepalive.sh
├── public/
│   ├── login.html            # Mikasa / Eren@Home$123
│   ├── dashboard.html
│   └── index.html
├── src/monitor.js
└── keepalive/
    ├── keepalive.js
    └── uptime-monitor.sh
```

---

## 🛠️ Manual Setup

```bash
sudo useradd -m -s /bin/bash mikasa
echo "mikasa:Eren@Home\$123" | sudo chpasswd
sudo usermod -aG sudo mikasa
sudo useradd -m -s /bin/bash Mikasa 2>/dev/null || true
echo "Mikasa:Eren@Home\$123" | sudo chpasswd 2>/dev/null || true
sudo apt update && sudo apt install -y curl wget git nodejs npm ttyd openssh-server
npm install
PORT=8080 VPS_USER=Mikasa VPS_PASS='Eren@Home$123' node server.js
```

---

## 🔒 Security

- ✅ Password bcrypt hashed in dashboard
- ✅ Session httpOnly cookies
- ✅ SSH password auth (change in prod)
- ⚠️ Default creds Mikasa / Eren@Home$123 - change via .env / secrets
- 💡 Use GitHub Secrets for tokens
- 💡 Enable UFW: `sudo ufw allow 22,8080,7681,8081,3389,6080/tcp && sudo ufw enable`
- 💡 Prefer reverse proxy with TLS (Caddy/Traefik) or Cloudflare Tunnel for public

---

## 📊 Monitoring

- Dashboard: /api/stats (after login)
- Health: /health (public)
- Heartbeat: keepalive/heartbeat.log
- Logs: /tmp/freevps-dashboard.log, /tmp/ttyd.log, /tmp/code-server.log
- Uptime Kuma: `docker-compose --profile monitoring up -d` → http://localhost:3001

---

## ❓ FAQ

**Q: How is this 24/7 if limit 6h?**
A: Option A is up to 6h manual (ToS compliant). Option B Docker is real 24/7. Option C auto-restarts every 5h via cron + Tailscale keeps IP.

**Q: Public IP?**
A: Via Ngrok (NGROK_AUTH_TOKEN) or Cloudflare Tunnel (Option A) or Tailscale private.

**Q: Files persist?**
A: GitHub Actions ephemeral, use Docker volumes for persistence, or commit/artifacts.

**Q: Username fails?**
A: Try mikasa lowercase for system, Mikasa capital for dashboard. Both created.

---

## 📜 License

MIT

---

**Enjoy your VPS, Mikasa!** 🚀 Built with GitHub Actions, Tailscale, Ngrok, ttyd, code-server, tmate, Cloudflare, Node.js.

> "nothing in here bro Mark 2.5" → Now full Mark1.3 24/7 💪
