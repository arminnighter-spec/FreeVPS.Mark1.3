# FreeVPS.Mark1.3

Two ways to get a remote Linux desktop. Default login is **`Mikasa`**; the password
(`Eren@Home$123`) is **never stored in this repo** — you supply it as a secret / env var.

---

## Read this first

GitHub-hosted Actions runners stop after **6 hours** and GitHub's Terms of Service
forbid using Actions as an always-on server or crypto/relay host. So the Actions
workflow here is a **manually started, time-limited dev box** (no auto-restart loop).
For genuine 24/7, use the Docker option on a host you control.

---

## Option A — GitHub Actions dev box (up to ~6 h per run)

1. Repo → **Settings → Secrets and variables → Actions**
   - New **repository secret**: `VPS_PASS` = `Eren@Home$123`
   - (optional) New **variable**: `VPS_USER` = `Mikasa`
2. **Actions → Remote Dev Box (RDP + SSH) → Run workflow**, pick a duration.
3. Open the **"Start Cloudflare tunnels"** step log and copy the two
   `*.trycloudflare.com` hostnames.
4. On your PC (install [`cloudflared`](https://github.com/cloudflare/cloudflared/releases)):

   ```bash
   # Desktop
   cloudflared access tcp --hostname <RDP-HOST> --url localhost:3389
   # then RDP client -> localhost:3389,  user Mikasa

   # Shell
   cloudflared access tcp --hostname <SSH-HOST> --url localhost:2222
   ssh Mikasa@localhost -p 2222
   ```

---

## Option B — real 24/7 box (Docker)

Run on any always-on host: home server, Oracle Cloud free tier, a cheap VPS, etc.

```bash
cd docker
cp .env.example .env      # set VPS_PASS=Eren@Home$123   (quote it in shells)
docker compose up -d --build
```

- Web desktop (noVNC): `http://<host>:6080/vnc.html`
- SSH: `ssh Mikasa@<host> -p 2222`

Data persists in the `vps-home` volume, and `restart: unless-stopped` brings it
back after reboots.

### Security
Change the password before exposing ports to the internet, and prefer putting
noVNC behind a reverse proxy with TLS (Caddy/Traefik) or a Cloudflare Tunnel.

---

## Installing the workflow file

The workflow lives at [`workflows/vps.yml`](workflows/vps.yml). GitHub App tokens
can't write to `.github/workflows`, so copy it into place yourself:

```bash
mkdir -p .github/workflows && cp workflows/vps.yml .github/workflows/vps.yml
git add .github/workflows/vps.yml && git commit -m "Add VPS workflow" && git push
```
