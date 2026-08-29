# FreeVPS.Mark1.3 - 24/7 VPS + Hermes LLM API Router

> **Persistent VPS with Web Dashboard, RDP, SSH, ttyd, VS Code + Hermes LLM (Ollama + LiteLLM Proxy)**
> Username: `Mikasa` | Password: `Eren@Home$123` | LLM: `Hermes` via `LiteLLM Router` 24/7

![VPS Status](https://img.shields.io/badge/Status-24%2F7%20Online-brightgreen)
![LLM](https://img.shields.io/badge/LLM-Hermes%20%2B%20LiteLLM-blue)
![Version](https://img.shields.io/badge/Version-Mark1.3-blue)

```
╔════════════════════════════════════════════════════╗
║         FreeVPS Mark1.3 - 24/7 VPS ONLINE          ║
║         + Hermes LLM API Router (LiteLLM)          ║
╠════════════════════════════════════════════════════╣
║  Username: Mikasa                                   ║
║  Password: Eren@Home$123                            ║
║  LLM: Hermes (Nous-Hermes2 / Hermes3) + LiteLLM     ║
║  API: /v1/chat/completions (OpenAI compatible)      ║
║  Status: 24/7 Active                                ║
╚════════════════════════════════════════════════════╝
```

---

## 🧠 NEW: Hermes LLM + API Router (24/7)

### Selected Stack: Ollama + LiteLLM Proxy

**Why this stack for 24/7?**

| Router | Pros | Cons | 24/7 |
|--------|------|------|------|
| **LiteLLM Proxy ✅ SELECTED** | OpenAI compatible, 100+ LLMs, routing, load balancing, fallback, retry, auth, logging, Docker, prod grade | Needs config | **Best** |
| vLLM | Fastest, PagedAttention | Needs GPU, heavy RAM | Medium |
| Ollama alone | Simple | No routing | Limited |
| LocalAI | Many models | Heavier | Yes |
| FastChat | Controller+worker | Complex | Medium |

**Why Ollama for Hermes:**
- Lightweight (CPU, 4GB RAM for 7B quantized), auto-restart, health checks, `restart: unless-stopped`
- Supports all Hermes: `nous-hermes2`, `openhermes`, `hermes3:8b`, `hermes3:3b`, `nous-hermes2:2b`
- Quantized Q4/Q5 for VPS
- Simple API: http://localhost:11434

**Why LiteLLM Proxy as Router:**
- OpenAI compatible: `/v1/chat/completions`, `/v1/models`
- Routing: latency-based, least-busy, usage-based, simple-shuffle
- 24/7: health checks 30s, auto-failover, retry+fallback, load balancing, auth, rate limiting, logging
- Production grade, Docker ready, can route to Ollama + OpenAI + Anthropic + Groq + Together etc.

**Combined = True 24/7:**
- Both `restart: unless-stopped`, healthchecks 30s, keepalive monitors 60s, auto-restart if down
- Works on Docker (true 24/7), local, GitHub Actions (limited RAM)

### Quick Start LLM (Docker - Recommended for 24/7)

```bash
# Start full stack: VPS + Hermes + LiteLLM Router
docker-compose --profile llm up -d
# or
docker-compose -f llm/docker-compose.yml up -d

# Pull Hermes model
docker exec -it ollama-hermes ollama pull nous-hermes2
docker exec -it ollama-hermes ollama pull hermes3:8b
docker exec -it ollama-hermes ollama pull hermes3:3b  # lightweight for free VPS

# Test
curl http://localhost:11434/api/tags
curl http://localhost:4000/v1/models -H "Authorization: Bearer sk-1234"
curl http://localhost:4000/v1/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer sk-1234" -d '{"model":"hermes","messages":[{"role":"user","content":"Hello, who are you?"}]}'

# Open WebUI (optional chat UI)
docker-compose --profile ui up -d
# http://localhost:3000
```

**Access:**
- Ollama: http://localhost:11434
- LiteLLM Proxy: http://localhost:4000 (OpenAI compatible, Bearer sk-1234)
- LiteLLM UI: http://localhost:4000/ui
- Custom Router: http://localhost:4001
- Open WebUI: http://localhost:3000
- Main Dashboard: http://localhost:8080 → LLM tab (Mikasa / Eren@Home$123)

### Local Install (No Docker)

```bash
bash scripts/install-hermes.sh nous-hermes2:2b  # lightweight
# or
bash scripts/install-hermes.sh hermes3:8b

# This installs Ollama, pulls Hermes, installs LiteLLM, starts services on 11434,4000,4001

# Or manual:
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &
ollama pull nous-hermes2
pip install 'litellm[proxy]'
litellm --config llm/litellm/litellm-config.yaml --port 4000

# Custom lightweight router (no pip needed)
node llm/router/router.js
```

### GitHub Actions LLM (Limited RAM)

Workflow `workflows/vps-24-7.yml` now has `enable_llm=true` input:
- Installs Ollama, pulls `nous-hermes2:2b` (2GB, fits 7GB runner)
- Starts LiteLLM on 4000, Custom Router on 4001
- Expose via Tailscale: `http://<tailscale-ip>:4000/v1/chat/completions`
- Heartbeat checks LLM every 5min, auto-restarts

### API Usage (OpenAI Compatible)

```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:4000/v1", api_key="sk-1234")
resp = client.chat.completions.create(model="hermes", messages=[{"role":"user","content":"Hello Hermes!"}])
print(resp.choices[0].message.content)
```

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{"model":"hermes","messages":[{"role":"user","content":"Explain 24/7 VPS"}]}'
```

See `llm/README.md` for full docs.

---

## ⚠️ GitHub ToS Compliance

GitHub runners stop after 6h and ToS forbids always-on. So:

1. **Manual dev box (6h, ToS-compliant)** - Cloudflare Tunnels RDP+SSH, no auto-restart (workflows/vps.yml / Option A)
2. **Real 24/7 Docker** - On host you control (Option B)
3. **Extended 24/7 auto-restart** - workflows/vps-24-7.yml auto-restarts every 5h via cron (Option C) - use with caution, best with Tailscale
4. **LLM 24/7** - Docker `restart: unless-stopped` + health checks + keepalive scripts (llm/docker-compose.yml)

Default login `Mikasa`; password `Eren@Home$123` never hardcoded in RDP workflow - supply as secret `VPS_PASS`. Dashboard uses bcrypt.

---

## 🚀 Quick Start - VPS (4 Methods)

### Option A — GitHub Actions Dev Box (RDP + SSH, 6h, ToS-compliant)

1. Settings → Secrets → `VPS_PASS=Eren@Home$123`, variable `VPS_USER=Mikasa`
2. `mkdir -p .github/workflows && cp workflows/vps.yml .github/workflows/vps.yml && git push`
3. Actions → Remote Dev Box → Run workflow
4. Get `*.trycloudflare.com` hostnames from logs, connect via `cloudflared`:
   ```bash
   cloudflared access tcp --hostname <RDP-HOST> --url localhost:3389
   # RDP to localhost:3389 user Mikasa
   cloudflared access tcp --hostname <SSH-HOST> --url localhost:2222
   ssh Mikasa@localhost -p 2222
   ```

### Option B — Real 24/7 Docker (Recommended)

```bash
# VPS only
docker-compose up -d --build
# VPS + Hermes LLM (true 24/7)
docker-compose --profile llm up -d --build
# or full: VPS + LLM + WebUI + monitoring
docker-compose --profile full --profile llm --profile ui --profile monitoring up -d

# Access:
# Dashboard: http://localhost:8080 (Mikasa / Eren@Home$123)
# Ollama: http://localhost:11434
# LiteLLM: http://localhost:4000 (sk-1234)
# Custom Router: http://localhost:4001
# WebUI: http://localhost:3000
# ttyd: http://localhost:7681
# VS Code: http://localhost:8081
# SSH: ssh mikasa@localhost -p 2222
```

### Option C — 24/7 Auto-Restart Workflow (Extended)

Uses `workflows/vps-24-7.yml` (copy to `.github/workflows/` manually):

1. Fork/Push repo, Actions → FreeVPS Mark1.3 - 24/7 VPS → Run workflow (enable_llm=true for Hermes)
2. Logs show: tmate SSH, Tailscale IP (`ssh mikasa@<ip>`), Ngrok URLs, Dashboard port 8080, LLM APIs port 4000/4001/11434
3. Auto-restarts every 5h via cron, heartbeat 5min, optional GH_PAT for instant restart

Secrets: `TAILSCALE_AUTHKEY`, `NGROK_AUTH_TOKEN`, `GH_PAT`

### Option D — Direct Local Run

```bash
npm install
bash scripts/setup-vps.sh
./start-vps.sh start          # VPS + LLM 24/7
# or
./start-vps.sh llm            # only LLM
npm start                     # only dashboard http://localhost:8080
./start-vps.sh status
./start-vps.sh logs
./start-vps.sh llm-status
```

---

## 🔑 Credentials

| Service | Username | Password | Port | URL |
|---------|----------|----------|------|-----|
| **Dashboard** | `Mikasa` | `Eren@Home$123` | 8080 | http://localhost:8080 |
| **System** | `mikasa` / `Mikasa` | `Eren@Home$123` | 22 | ssh mikasa@localhost |
| **RDP** | `Mikasa` | via secret | 3389 | via CF Tunnel |
| **ttyd** | `mikasa` | `Eren@Home$123` | 7681 | http://localhost:7681 |
| **code-server** | - | `Eren@Home$123` | 8081 | http://localhost:8081 |
| **noVNC** | `Mikasa` | `Eren@Home$123` | 6080 | http://localhost:6080/vnc.html |
| **Ollama** | - | - | 11434 | http://localhost:11434 |
| **LiteLLM Router** | - | `sk-1234` Bearer | 4000 | http://localhost:4000/v1/chat/completions |
| **Custom Router** | - | `sk-1234` Bearer | 4001 | http://localhost:4001/v1/chat/completions |
| **Open WebUI** | - | - | 3000 | http://localhost:3000 |

---

## 📡 Access Methods

- **Dashboard:** http://localhost:8080 (stats, terminal, files, processes, LLM tab) - Mikasa / Eren@Home$123
- **Hermes LLM:** http://localhost:4000/v1/chat/completions (OpenAI compatible, Bearer sk-1234) - Selected stack Ollama+LiteLLM
- **RDP:** via Cloudflare Tunnel `cloudflared access tcp --hostname <RDP-HOST> --url localhost:3389`
- **SSH:** `ssh mikasa@localhost -p 2222` or `ssh mikasa@<tailscale-ip>` or tmate
- **ttyd:** http://localhost:7681
- **code-server:** http://localhost:8081
- **Tailscale:** persistent VPN IP, set `TAILSCALE_AUTHKEY` secret
- **Ngrok:** public URLs, set `NGROK_AUTH_TOKEN`

---

## 🔄 24/7 Persistence

**VPS:**
- Compliant: manual 6h (Option A)
- Real 24/7: Docker `restart: unless-stopped` (Option B)
- Extended: cron `0 */5 * * *` restarts every 5h + Tailscale same IP + heartbeat 5min

**LLM (Hermes + LiteLLM):**
- Docker: `restart: unless-stopped`, healthcheck 30s, `depends_on: healthy`
- Keepalive: `scripts/keepalive-llm.sh` monitors Ollama+LiteLLM+Router every 60s, auto-restarts
- GitHub Actions: heartbeat checks LLM every 5min, auto-restarts
- Monitoring: `/api/llm/status`, `/api/llm/health`, LiteLLM UI http://localhost:4000/ui, logs /tmp/ollama.log, /tmp/litellm.log

---

## 📁 Project Structure

```
FreeVPS.Mark1.3/
├── server.js                 # Dashboard + LLM routes (8080)
├── package.json
├── start-vps.sh              # 24/7 launcher (VPS + LLM)
├── docker-compose.yml        # VPS + LLM (profiles: llm, full, ui, monitoring)
├── Dockerfile
├── llm/                      # Hermes LLM + Router
│   ├── README.md             # Full LLM docs
│   ├── docker-compose.yml    # LLM only stack
│   ├── .env.example
│   ├── ollama/entrypoint.sh
│   ├── litellm/litellm-config.yaml  # LiteLLM router config (selected)
│   └── router/
│       ├── router.js         # Custom lightweight router (fallback)
│       ├── package.json
│       └── Dockerfile
├── docker/                   # Original RDP desktop
├── workflows/
│   ├── vps.yml               # Compliant RDP+SSH
│   └── vps-24-7.yml          # Extended 24/7 + LLM (copy to .github/workflows/)
├── config/vps-config.json
├── scripts/
│   ├── setup-vps.sh          # Creates Mikasa
│   ├── install-hermes.sh     # Installs Ollama + Hermes + LiteLLM (selected)
│   ├── setup-llm-router.sh   # Sets up LiteLLM router
│   ├── keepalive-llm.sh      # 24/7 LLM keepalive
│   └── keepalive.sh
├── public/
│   ├── login.html
│   ├── dashboard.html        # Now includes LLM tab
│   └── llm/
└── keepalive/
    ├── keepalive.js
    ├── llm-heartbeat.log
    └── uptime-monitor.sh
```

---

## 🛠️ Manual Setup

```bash
sudo useradd -m -s /bin/bash mikasa
echo "mikasa:Eren@Home\$123" | sudo chpasswd
sudo usermod -aG sudo mikasa
sudo apt update && sudo apt install -y curl wget git nodejs npm ttyd openssh-server python3 python3-pip
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &
ollama pull nous-hermes2:2b
pip install 'litellm[proxy]' --break-system-packages
litellm --config llm/litellm/litellm-config.yaml --port 4000 &
npm install
PORT=8080 VPS_USER=Mikasa VPS_PASS='Eren@Home$123' node server.js
```

---

## 🔒 Security

- ✅ Dashboard bcrypt hashed, session httpOnly
- ✅ LiteLLM master key `sk-1234` (change via LITELLM_MASTER_KEY env)
- ⚠️ Default creds Mikasa / Eren@Home$123 - change via .env / secrets
- 💡 Use GitHub Secrets for tokens, never commit
- 💡 UFW: `sudo ufw allow 22,8080,7681,8081,4000,4001,11434,3000/tcp && sudo ufw enable`
- 💡 Public: reverse proxy TLS (Caddy/Traefik) or Cloudflare Tunnel

---

## 📊 Monitoring

- Dashboard: /api/stats, /api/llm/status, /api/llm/health
- Health: /health
- LLM: http://localhost:4000/v1/models, http://localhost:4000/ui, http://localhost:11434/api/tags
- Heartbeat: keepalive/heartbeat.log, keepalive/llm-heartbeat.log
- Logs: /tmp/freevps-dashboard.log, /tmp/ollama.log, /tmp/litellm.log, /tmp/hermes-router.log
- Uptime Kuma: `docker-compose --profile monitoring up -d` → http://localhost:3001

---

## ❓ FAQ

**Q: Which LLM router selected and why?**
A: **LiteLLM Proxy + Ollama** - Best for 24/7: lightweight, OpenAI compatible, routing (latency-based, least-busy), load balancing, fallback, retry, auth, logging, health checks, Docker `restart: unless-stopped`. vLLM needs GPU, LocalAI heavier, FastChat complex. See llm/README.md decision table.

**Q: How to keep LLM 24/7?**
A: Docker `--profile llm` with `restart: unless-stopped` + healthcheck 30s + `scripts/keepalive-llm.sh` monitors 60s + GitHub Actions cron 5h + Tailscale same IP.

**Q: Which Hermes model for low RAM?**
A: `nous-hermes2:2b` (2GB) or `hermes3:3b` (3GB) for free VPS/GitHub Actions. `hermes3:8b` (6GB) for 4GB Docker. `hermes3:70b` needs 40GB.

**Q: How is VPS 24/7 if limit 6h?**
A: Option A manual 6h ToS-compliant. Option B Docker real 24/7. Option C auto-restart cron 5h + Tailscale. LLM same.

**Q: Public IP?**
A: Ngrok (NGROK_AUTH_TOKEN) or Cloudflare Tunnel (Option A) or Tailscale private.

---

## 📜 License

MIT

---

**Enjoy your 24/7 VPS + Hermes LLM, Mikasa!** 🚀 Built with Ollama, LiteLLM, Hermes, GitHub Actions, Tailscale, Ngrok, ttyd, code-server, Cloudflare, Node.js.

> "nothing in here bro Mark 2.5" → Now full Mark1.3 24/7 VPS + Hermes LLM API Router 💪
