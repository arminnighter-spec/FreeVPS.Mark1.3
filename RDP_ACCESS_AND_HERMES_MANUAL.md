# FreeVPS Mark1.3 - RDP Access + Hermes Manual Installation

> **Username:** Mikasa | **Password:** Eren@Home$123 | **LLM:** Hermes + LiteLLM Router 24/7
> **Sandbox ID:** ids0odn64kubu769ekwrt

---

## 🌐 Current Sandbox - Immediate Access (No RDP Client Needed)

You are in Arena.ai E2B Sandbox. Direct public RDP IP is **not exposed** for security, but you have **web-based RDP alternatives** that are already running 24/7:

### 1. Main Dashboard (Web RDP Alternative) - ONLINE NOW

**URL:** https://8080-ids0odn64kubu769ekwrt.e2b.app
- This is your **live preview** - already running!
- **Login:** `Mikasa` / `Eren@Home$123`
- **Features:** Full terminal, file manager, process manager, LLM tab, system stats
- **Use this to finalize Hermes manual installation via Terminal tab**

**Other Preview URLs (same sandbox):**
- Dashboard: https://8080-ids0odn64kubu769ekwrt.e2b.app
- ttyd Terminal: https://7681-ids0odn64kubu769ekwrt.e2b.app (if started, auth mikasa / Eren@Home$123)
- VS Code: https://8081-ids0odn64kubu769ekwrt.e2b.app (if started, password Eren@Home$123)
- Ollama: https://11434-ids0odn64kubu769ekwrt.e2b.app (after installing)
- LiteLLM Router: https://4000-ids0odn64kubu769ekwrt.e2b.app (OpenAI compatible, Bearer sk-1234)
- Custom Router: https://4001-ids0odn64kubu769ekwrt.e2b.app
- Open WebUI: https://3000-ids0odn64kubu769ekwrt.e2b.app

**How to use:** Click the preview link above, login, go to Terminal tab, and run Hermes manual install commands below.

### 2. Internal IP (Sandbox)

- **Internal IP:** `169.254.0.21` (from `hostname -I`)
- **Not directly accessible from internet** - use preview URLs above
- **SSH in sandbox:** `ssh mikasa@localhost` (password Eren@Home$123) via terminal tab

---

## 🖥️ Real RDP IP via GitHub Actions (For Remote Desktop Connection Client)

To get a **real IP/hostname you can connect via Windows Remote Desktop Connection**, use the GitHub Actions workflow. This gives you Cloudflare Tunnel hostnames that work as RDP IP.

### Steps to Get RDP IP:

1. **Push workflows to GitHub:**
   ```bash
   mkdir -p .github/workflows
   cp workflows/vps.yml .github/workflows/vps.yml
   cp workflows/vps-24-7.yml .github/workflows/vps-24-7.yml
   git add .github/workflows/
   git commit -m "Add VPS workflows"
   git push origin arena/01a04e09-freevps-mark1-3
   ```

2. **Set Secrets in GitHub:**
   - Go to Repo → Settings → Secrets and variables → Actions
   - New secret: `VPS_PASS` = `Eren@Home$123`
   - Optional variable: `VPS_USER` = `Mikasa`
   - Optional for persistent IP: `TAILSCALE_AUTHKEY` (from https://login.tailscale.com/admin/settings/keys)
   - Optional for public URLs: `NGROK_AUTH_TOKEN`

3. **Run Workflow:**
   - Go to Actions tab → **Remote Dev Box (RDP + SSH)** → Run workflow
   - Pick duration: 350 min (max)
   - Wait 2-3 min for workflow to start

4. **Get RDP Hostname/IP from Logs:**
   - Open the running workflow → Click **"Start Cloudflare tunnels"** step
   - Look for logs like:
     ```
     =================== CONNECTION INFO ===================
     Username: Mikasa
     Password: (your VPS_PASS secret)
     --- RDP hostname ---
     https://xxxx-yyyy-zzzz.trycloudflare.com
     --- SSH hostname ---
     https://aaaa-bbbb-cccc.trycloudflare.com
     =======================================================
     ```
   - **This https://xxxx.trycloudflare.com IS your RDP IP/hostname!**

5. **Connect via Remote Desktop Connection (On Your PC):**

   Install `cloudflared` on your PC: https://github.com/cloudflare/cloudflared/releases

   ```bash
   # For RDP
   cloudflared access tcp --hostname xxxx-yyyy-zzzz.trycloudflare.com --url localhost:3389
   # Then open Remote Desktop Connection client → Connect to localhost:3389
   # Username: Mikasa, Password: Eren@Home$123

   # For SSH (alternative)
   cloudflared access tcp --hostname aaaa-bbbb-cccc.trycloudflare.com --url localhost:2222
   ssh Mikasa@localhost -p 2222
   # Password: Eren@Home$123
   ```

6. **For 24/7 with Tailscale (Persistent IP):**
   - If you set `TAILSCALE_AUTHKEY` secret, workflow logs will show:
     ```
     Tailscale IP: 100.x.x.x
     ```
   - This IP is **persistent across workflow restarts** and you can directly RDP/SSH:
     ```bash
     # RDP via Tailscale (if xrdp installed)
     # Use Remote Desktop client → 100.x.x.x:3389

     # SSH via Tailscale (always works)
     ssh mikasa@100.x.x.x
     # Password: Eren@Home$123
     ```

### Alternative: Extended 24/7 Workflow (VPS + Hermes LLM)

- Actions → **FreeVPS Mark1.3 - 24/7 VPS + Hermes LLM** → Run workflow
- Enable inputs: `enable_llm=true`, `llm_model=nous-hermes2:2b` (lightweight for GitHub runner)
- Logs will show:
  - tmate SSH: `ssh <tmate-command>` (immediate)
  - Tailscale IP: `100.x.x.x` (if authkey set) - **This is your persistent IP for RDP/SSH/LLM**
  - Ngrok URLs: `https://xxxx.ngrok.io` → public URLs for dashboard, LLM APIs
  - Dashboard: port 8080, Ollama: 11434, LiteLLM: 4000

---

## 🧠 Manual Hermes Installation (After RDP Connection)

Once you are connected via RDP (or via Dashboard Terminal tab in current sandbox), run these commands to finalize Hermes + LiteLLM Router manually:

### Step 1: Install Ollama (Hermes Runner)

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama service
sudo systemctl enable ollama
sudo systemctl start ollama
# Or manual:
nohup ollama serve > /tmp/ollama.log 2>&1 &
sleep 5

# Check
curl http://localhost:11434/api/tags
ollama --version
```

### Step 2: Pull Hermes Models (Based on RAM)

```bash
# Check RAM
free -h

# For Free VPS / GitHub Actions (7GB RAM, <4GB available) - Ultra Light:
ollama pull nous-hermes2:2b      # 2B, 2GB RAM - BEST FOR FREE VPS
ollama pull hermes3:3b           # 3B, 3GB RAM - Lightweight

# For Docker with 4-8GB RAM - Balanced:
ollama pull nous-hermes2         # 10B, 8GB RAM - Balanced
ollama pull openhermes           # 7B, 6GB RAM - General
ollama pull hermes3:8b           # 8B, 6GB RAM - RECOMMENDED

# For Big VPS 16GB+ - High Quality:
ollama pull hermes3:70b          # 70B, 40GB RAM - Best quality

# List models
ollama list
```

### Step 3: Test Hermes Directly

```bash
# Test via Ollama API
curl http://localhost:11434/api/chat -d '{
  "model": "nous-hermes2:2b",
  "messages": [{"role": "user", "content": "Hello, are you Hermes?"}]
}'

# Or interactive
ollama run nous-hermes2:2b
# Type: Hello, who are you?
# Exit: /bye
```

### Step 4: Install LiteLLM Proxy (Selected Router for 24/7)

```bash
# Install Python pip if needed
sudo apt update && sudo apt install -y python3 python3-pip

# Install LiteLLM
pip3 install 'litellm[proxy]' --break-system-packages
# Or
pip3 install 'litellm[proxy]'

# Check
litellm --help
python3 -m litellm --help

# Create config (already exists in llm/litellm/litellm-config.yaml)
cat llm/litellm/litellm-config.yaml
# If not exists, create:
mkdir -p llm/litellm
cat > llm/litellm/litellm-config.yaml << 'EOC'
model_list:
  - model_name: hermes
    litellm_params:
      model: ollama/nous-hermes2:2b
      api_base: http://localhost:11434
  - model_name: hermes3
    litellm_params:
      model: ollama/hermes3:3b
      api_base: http://localhost:11434
  - model_name: openhermes
    litellm_params:
      model: ollama/openhermes
      api_base: http://localhost:11434
EOC

# Start LiteLLM Proxy on port 4000 (24/7)
nohup litellm --config llm/litellm/litellm-config.yaml --port 4000 > /tmp/litellm.log 2>&1 &
echo $! > /tmp/litellm.pid
sleep 5

# Check
curl http://localhost:4000/health
curl http://localhost:4000/v1/models -H "Authorization: Bearer sk-1234"
cat /tmp/litellm.log | tail -20
```

### Step 5: Start Custom Router (Lightweight Fallback)

```bash
# Install Node deps
cd llm/router
npm install --production

# Start custom router on port 4001
PORT=4001 OLLAMA_HOST=http://localhost:11434 LITELLM_HOST=http://localhost:4000 nohup node router.js > /tmp/hermes-router.log 2>&1 &
echo $! > /tmp/hermes-router.pid
cd ../..

# Check
curl http://localhost:4001/health
curl http://localhost:4001/v1/models
```

### Step 6: Test OpenAI Compatible API (Final)

```bash
# Via LiteLLM (port 4000) - Selected Router
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-1234" \
  -d '{
    "model": "hermes",
    "messages": [
      {"role": "system", "content": "You are Hermes, a helpful AI assistant."},
      {"role": "user", "content": "Hello, who are you? Explain 24/7 VPS."}
    ],
    "temperature": 0.7,
    "max_tokens": 200
  }' | jq

# Via Custom Router (port 4001) - Fallback
curl http://localhost:4001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-1234" \
  -d '{
    "model": "hermes",
    "messages": [{"role": "user", "content": "Hello Hermes!"}]
  }' | jq

# Via Ollama Direct (port 11434)
curl http://localhost:11434/api/chat -d '{
  "model": "nous-hermes2:2b",
  "messages": [{"role": "user", "content": "Hello"}]
}' | jq

# Python OpenAI SDK
python3 << 'PY'
from openai import OpenAI
client = OpenAI(base_url="http://localhost:4000/v1", api_key="sk-1234")
resp = client.chat.completions.create(model="hermes", messages=[{"role":"user","content":"Hello Hermes, are you running 24/7?"}])
print(resp.choices[0].message.content)
PY
```

### Step 7: Setup 24/7 Keep Alive

```bash
# Docker (True 24/7) - Recommended
docker-compose --profile llm up -d
# or
docker-compose -f llm/docker-compose.yml up -d
# Check
docker-compose -f llm/docker-compose.yml logs -f
docker ps

# Local keepalive script
chmod +x scripts/keepalive-llm.sh
./scripts/keepalive-llm.sh &
# Monitors Ollama+LiteLLM+Router every 60s, auto-restarts

# Main keepalive (VPS + LLM)
./start-vps.sh keepalive
# Monitors all services every 5min

# For GitHub Actions, workflow already has keepalive loop
```

### Step 8: Access via Dashboard

```bash
# Main dashboard now includes LLM tab
# http://localhost:8080 (or preview URL) -> Login Mikasa / Eren@Home$123 -> LLM tab
# Shows status, models, chat test UI, logs

# Or via API from dashboard terminal:
curl http://localhost:8080/api/llm/status -b cookie.txt
curl http://localhost:8080/api/llm/models -b cookie.txt
```

---

## 📊 Current Sandbox Status

- **Sandbox ID:** ids0odn64kubu769ekwrt
- **Internal IP:** 169.254.0.21
- **Dashboard:** https://8080-ids0odn64kubu769ekwrt.e2b.app (Mikasa / Eren@Home$123) - ONLINE
- **Ollama:** Not installed yet (run manual steps above)
- **LiteLLM:** Not installed yet (run manual steps above)
- **To install now via dashboard:** Go to Terminal tab and run `bash scripts/install-hermes.sh nous-hermes2:2b`

---

## 🔑 Credentials Reminder

- **VPS User:** Mikasa / mikasa
- **VPS Pass:** Eren@Home$123
- **LLM API Key:** sk-1234 (Bearer token)
- **LiteLLM Master Key:** sk-1234
- **All services:** Use same VPS credentials where applicable

---

## 🆘 Troubleshooting

**RDP not connecting:**
- Ensure workflow is running (Actions tab → green)
- Check Cloudflare tunnel logs for hostname
- Ensure cloudflared installed on your PC
- Try Tailscale IP method (more reliable)

**Ollama not starting:**
```bash
cat /tmp/ollama.log
sudo systemctl status ollama
curl http://localhost:11434/api/tags
```

**LiteLLM not connecting to Ollama:**
```bash
cat /tmp/litellm.log
docker exec litellm curl http://ollama:11434/api/tags
# Check if Ollama host is correct in config
```

**Model not found:**
```bash
ollama list
ollama pull nous-hermes2:2b
```

**Out of memory:**
- Use smaller model: hermes3:3b or nous-hermes2:2b
- Check RAM: free -h
- For GitHub Actions, always use 2b/3b models

---

**Enjoy your 24/7 RDP + Hermes LLM, Mikasa!** 🚀
