# FreeVPS Mark1.3 - Hermes LLM + API Router (24/7)

> **Selected Stack: Ollama + LiteLLM Proxy**
> **Why this stack for 24/7?** See decision below.

```
╔════════════════════════════════════════════════════╗
║         Hermes LLM - 24/7 API Router ONLINE        ║
╠════════════════════════════════════════════════════╣
║  Model: Nous-Hermes2 / Hermes3 / OpenHermes        ║
║  Runner: Ollama (lightweight, auto-restart)        ║
║  Router: LiteLLM Proxy (OpenAI compatible, 24/7)   ║
║  User: Mikasa / Pass: Eren@Home$123                ║
╚════════════════════════════════════════════════════╝
```

---

## 🤔 Decision: Which LLM API Router?

### Evaluated Options:

| Router | Pros | Cons | 24/7 Ready? |
|--------|------|------|-------------|
| **LiteLLM Proxy** ✅ **SELECTED** | OpenAI compatible, 100+ LLMs, routing, load balancing, fallback, retry, auth, logging, cost tracking, Docker, production grade | Needs config | **Yes - Best** |
| vLLM | Fastest inference, PagedAttention, high throughput | Needs GPU, heavy RAM, not ideal for free VPS | Medium |
| Ollama alone | Simple, OpenAI compatible API built-in | No advanced routing, no load balancing | Yes but limited |
| LocalAI | OpenAI compatible, many models | Heavier, complex | Yes |
| FastChat | Good for serving, controller+worker | Complex setup | Medium |
| OpenRouter | Hosted, no self-host | Not self-hosted, costs | N/A |

### Why LiteLLM + Ollama for 24/7?

1. **Ollama for Hermes:**
   - Lightweight (runs on CPU, 4GB RAM enough for 7B quantized)
   - Supports all Hermes variants: `nous-hermes2`, `openhermes`, `hermes3:8b`, `hermes3:70b`
   - Auto-restart, health checks, Docker `restart: unless-stopped`
   - Simple API: `http://localhost:11434`
   - Quantized models (Q4, Q5) for VPS with limited RAM

2. **LiteLLM Proxy for Routing:**
   - **OpenAI compatible:** `/v1/chat/completions`, `/v1/models`, `/v1/embeddings`
   - **Routing strategies:** simple-shuffle, least-busy, latency-based, usage-based
   - **24/7 features:** 
     - Health checks every 30s, auto-failover
     - Retry + fallback (if Hermes down, fallback to other model)
     - Load balancing across multiple Ollama instances
     - Auth via API keys, rate limiting
     - Logging to file/DB for monitoring
   - **Production grade:** Used by many companies, Docker ready
   - **Can route to:** Ollama (Hermes), OpenAI, Anthropic, Groq, Together, etc.

3. **Combined = True 24/7:**
   - Both have `restart: unless-stopped`
   - Keepalive script monitors both, restarts if down
   - LiteLLM health check pings Ollama, restarts if needed
   - Works on GitHub Actions (with some limits), Docker (true 24/7), local

---

## 🚀 Quick Start - 3 Methods

### Method 1: Docker (Recommended for 24/7)

```bash
# Clone
cd FreeVPS.Mark1.3

# Start full stack: VPS + Hermes + LiteLLM Router
docker-compose -f docker-compose.yml -f llm/docker-compose.yml --profile llm up -d

# Or just LLM stack
docker-compose -f llm/docker-compose.yml up -d

# Check logs
docker-compose -f llm/docker-compose.yml logs -f

# Pull Hermes model (first time)
docker exec -it ollama ollama pull nous-hermes2
# or
docker exec -it ollama ollama pull hermes3:8b
# or
docker exec -it ollama ollama pull openhermes

# Test
curl http://localhost:11434/api/tags
curl http://localhost:4000/v1/models -H "Authorization: Bearer sk-1234"

# OpenAI compatible chat
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-1234" \
  -d '{
    "model": "hermes",
    "messages": [{"role": "user", "content": "Hello, who are you?"}]
  }'
```

**Access:**
- Ollama: http://localhost:11434
- LiteLLM Proxy: http://localhost:4000 (OpenAI compatible, auth: sk-1234)
- LiteLLM UI: http://localhost:4000/ui
- Open WebUI: http://localhost:3000 (optional chat UI)
- Main VPS Dashboard: http://localhost:8080 (now includes LLM status)

### Method 2: Local Install (No Docker)

```bash
# Install Ollama
bash scripts/install-hermes.sh

# This will:
# - Install Ollama
# - Pull Hermes model (nous-hermes2)
# - Start Ollama service
# - Install LiteLLM Proxy (pip)
# - Start LiteLLM on port 4000

# Or manual:
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &
ollama pull nous-hermes2
ollama pull hermes3:8b

# Install LiteLLM
pip install 'litellm[proxy]'
litellm --config llm/litellm/litellm-config.yaml --port 4000

# Or use our custom router (lightweight, no pip needed)
node llm/router/router.js
# Router on http://localhost:4000
```

### Method 3: GitHub Actions (Limited 24/7)

The workflow `workflows/vps-24-7.yml` now includes LLM setup:

1. Enable LLM in workflow dispatch: `enable_llm=true`
2. Workflow will:
   - Install Ollama
   - Pull `nous-hermes2` (small, 4GB)
   - Start LiteLLM Proxy on port 4000
   - Expose via tmate/Tailscale/Ngrok
3. Access via Tailscale IP: `http://<tailscale-ip>:4000/v1/chat/completions`

**Note:** GitHub Actions runners have limited RAM (7GB), so use small quantized models like `nous-hermes2:10b` or `hermes3:3b`.

---

## 🔧 Configuration

### LiteLLM Config (`llm/litellm/litellm-config.yaml`)

```yaml
model_list:
  - model_name: hermes
    litellm_params:
      model: ollama/nous-hermes2
      api_base: http://ollama:11434
  - model_name: hermes3
    litellm_params:
      model: ollama/hermes3:8b
      api_base: http://ollama:11434
  - model_name: openhermes
    litellm_params:
      model: ollama/openhermes
      api_base: http://ollama:11434

# Optional fallbacks
  - model_name: gpt-3.5-turbo
    litellm_params:
      model: openai/gpt-3.5-turbo
      api_key: os.environ/OPENAI_API_KEY

router_settings:
  routing_strategy: latency-based-routing
  num_retries: 3
  retry_strategy: exponential_backoff_retry
  fallbacks:
    - {"hermes": ["hermes3", "openhermes"]}
```

### Environment (`llm/.env.example`)

```env
# Ollama
OLLAMA_HOST=0.0.0.0:11434
OLLAMA_MODELS=nous-hermes2,hermes3:8b,openhermes

# LiteLLM
LITELLM_PORT=4000
LITELLM_MASTER_KEY=sk-1234
OPENAI_API_KEY=sk-... # optional for fallback
ANTHROPIC_API_KEY=... # optional

# Auth for VPS dashboard
VPS_USER=Mikasa
VPS_PASS=Eren@Home$123
```

---

## 📡 API Usage (OpenAI Compatible)

### List Models

```bash
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer sk-1234"
```

### Chat Completion (Hermes)

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-1234" \
  -d '{
    "model": "hermes",
    "messages": [
      {"role": "system", "content": "You are Hermes, a helpful AI assistant."},
      {"role": "user", "content": "Explain 24/7 VPS setup"}
    ],
    "temperature": 0.7,
    "max_tokens": 500
  }'
```

### Using OpenAI Python SDK

```python
from openai import OpenAI

client = OpenAI(
  base_url="http://localhost:4000/v1",
  api_key="sk-1234"
)

response = client.chat.completions.create(
  model="hermes",
  messages=[
    {"role": "user", "content": "Hello, are you Hermes?"}
  ]
)

print(response.choices[0].message.content)
```

### Using JavaScript

```javascript
const response = await fetch('http://localhost:4000/v1/chat/completions', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer sk-1234'
  },
  body: JSON.stringify({
    model: 'hermes',
    messages: [{role: 'user', content: 'Hello Hermes!'}]
  })
});
const data = await response.json();
console.log(data.choices[0].message.content);
```

---

## 🔄 24/7 Keep Alive for LLM

### Docker (True 24/7)

- `restart: unless-stopped` in compose
- Health checks every 30s
- LiteLLM pings Ollama, restarts if down
- Watchtower auto-updates

### Local

```bash
# Keepalive script monitors Ollama + LiteLLM
./scripts/keepalive-llm.sh

# Or via main keepalive
./start-vps.sh keepalive
# Now includes LLM checks
```

### GitHub Actions

- Workflow auto-restarts every 5h via cron
- Tailscale keeps same IP across restarts
- Heartbeat checks LLM services every 5min

### Monitoring

- Main dashboard now shows LLM status at `/api/llm/status`
- LiteLLM UI at http://localhost:4000/ui
- Logs: `/tmp/ollama.log`, `/tmp/litellm.log`

---

## 🧠 Hermes Models Available

| Model | Size | RAM Needed | Ollama Command | Best For |
|-------|------|------------|----------------|----------|
| `nous-hermes2:2b` | 2B | 2GB | `ollama pull nous-hermes2:2b` | Free VPS, GitHub Actions |
| `nous-hermes2:10b` | 10B | 8GB | `ollama pull nous-hermes2` | Balanced |
| `openhermes` | 7B | 6GB | `ollama pull openhermes` | General |
| `hermes3:3b` | 3B | 3GB | `ollama pull hermes3:3b` | Lightweight |
| `hermes3:8b` | 8B | 6GB | `ollama pull hermes3:8b` | Recommended |
| `hermes3:70b` | 70B | 40GB | `ollama pull hermes3:70b` | High quality, needs big VPS |

**For FreeVPS (limited RAM):** Use `nous-hermes2:2b` or `hermes3:3b`
**For Docker with 4GB:** Use `hermes3:8b` Q4 quantized
**For 16GB+ VPS:** Use `hermes3:70b` or `nous-hermes2`

---

## 🔒 Security

- LiteLLM master key: `sk-1234` (change in production via `LITELLM_MASTER_KEY`)
- VPS dashboard auth: `Mikasa / Eren@Home$123`
- Ollama no auth by default (bind to localhost or use reverse proxy)
- For public: Put behind Caddy/Traefik with TLS + auth

---

## 📊 Dashboard Integration

Main VPS dashboard at http://localhost:8080 now includes:

- LLM Status card (Ollama + LiteLLM health)
- Model list
- Test chat UI
- Logs
- Quick actions: Pull model, Restart LLM, etc.

Access via `/dashboard.html` → LLM tab.

---

## 🛠️ Troubleshooting

**Ollama not starting:**
```bash
curl http://localhost:11434/api/tags || echo "Ollama down"
sudo systemctl status ollama || ollama serve
```

**LiteLLM not connecting to Ollama:**
```bash
# Check Ollama is reachable from LiteLLM container
docker exec litellm curl http://ollama:11434/api/tags
# If fails, check network: docker network ls
```

**Model not found:**
```bash
ollama list
ollama pull nous-hermes2
```

**Out of memory:**
- Use smaller model: `hermes3:3b` instead of `8b`
- Use quantized: `hermes3:8b-q4_0`
- Increase Docker memory limit in compose

---

## 🙏 Credits

- **Hermes:** Nous Research - https://nousresearch.com/
- **Ollama:** https://ollama.com/
- **LiteLLM:** https://github.com/BerriAI/litellm
- **FreeVPS Mark1.3:** 24/7 VPS setup

Enjoy your 24/7 Hermes LLM API Router, Mikasa! 🚀
