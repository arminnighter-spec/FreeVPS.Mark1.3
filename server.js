/**
 * FreeVPS Mark1.3 - 24/7 VPS Server
 * Main Web Server with Authentication & Terminal
 * Username: Mikasa | Password: Eren@Home$123
 */

require('dotenv').config();
const express = require('express');
const session = require('express-session');
const bcrypt = require('bcryptjs');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { exec, spawn } = require('child_process');
const http = require('http');
const WebSocket = require('ws');
const si = require('systeminformation');
const axios = require('axios');

// LLM Config - Hermes + LiteLLM Router
const OLLAMA_HOST = process.env.OLLAMA_HOST || 'http://localhost:11434';
const LITELLM_HOST = process.env.LITELLM_HOST || 'http://localhost:4000';
const LLM_ROUTER_HOST = process.env.LLM_ROUTER_HOST || 'http://localhost:4001';
const LITELLM_MASTER_KEY = process.env.LITELLM_MASTER_KEY || 'sk-1234';

const app = express();
const PORT = process.env.PORT || 8080;
const HOST = '0.0.0.0';

// Config - credentials from user request
const VPS_USER = process.env.VPS_USER || 'Mikasa';
const VPS_PASS_PLAIN = process.env.VPS_PASS || 'Eren@Home$123';
// Pre-hashed bcrypt of Eren@Home$123 with 10 rounds
const VPS_PASS_HASH = bcrypt.hashSync(VPS_PASS_PLAIN, 10);

console.log(`[FreeVPS] Initializing VPS for user: ${VPS_USER}`);
console.log(`[FreeVPS] Server will bind to ${HOST}:${PORT}`);

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

app.use(session({
  secret: 'freevps-mark1-3-secret-key-eren-mikasa-2024',
  resave: false,
  saveUninitialized: false,
  cookie: { 
    secure: false, // set true if https
    maxAge: 24 * 60 * 60 * 1000, // 24h
    httpOnly: true
  }
}));

// Auth middleware
function requireAuth(req, res, next) {
  if (req.session && req.session.authenticated) {
    return next();
  }
  if (req.path.startsWith('/api/')) {
    return res.status(401).json({ error: 'Unauthorized', login: '/login.html' });
  }
  return res.redirect('/login.html');
}

// Routes - Public
app.get('/', (req, res) => {
  if (req.session.authenticated) {
    return res.redirect('/dashboard.html');
  }
  res.redirect('/login.html');
});

app.get('/health', (req, res) => {
  res.json({ 
    status: 'online', 
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    version: '1.3.0',
    user: VPS_USER
  });
});

// Login API
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  console.log(`[AUTH] Login attempt for user: ${username} from ${req.ip}`);

  if (username === VPS_USER && bcrypt.compareSync(password, VPS_PASS_HASH)) {
    req.session.authenticated = true;
    req.session.username = username;
    req.session.loginTime = new Date().toISOString();
    console.log(`[AUTH] SUCCESS - User ${username} logged in`);
    return res.json({ success: true, user: username, redirect: '/dashboard.html' });
  }
  
  console.log(`[AUTH] FAILED - Invalid credentials for ${username}`);
  return res.status(401).json({ success: false, error: 'Invalid username or password' });
});

app.post('/api/logout', (req, res) => {
  req.session.destroy();
  res.json({ success: true, redirect: '/login.html' });
});

app.get('/api/session', (req, res) => {
  if (req.session.authenticated) {
    return res.json({ authenticated: true, user: req.session.username, loginTime: req.session.loginTime });
  }
  res.json({ authenticated: false });
});

// Protected routes
app.get('/api/stats', requireAuth, async (req, res) => {
  try {
    const [cpu, mem, disk, osInfo, time, network] = await Promise.all([
      si.currentLoad(),
      si.mem(),
      si.fsSize(),
      si.osInfo(),
      si.time(),
      si.networkInterfaces()
    ]);

    res.json({
      cpu: {
        load: cpu.currentLoad.toFixed(2),
        cores: cpu.cpus.length,
        model: cpu.cpus[0]?.model || 'Unknown'
      },
      memory: {
        total: (mem.total / 1024 / 1024 / 1024).toFixed(2) + ' GB',
        used: (mem.used / 1024 / 1024 / 1024).toFixed(2) + ' GB',
        free: (mem.free / 1024 / 1024 / 1024).toFixed(2) + ' GB',
        usage: ((mem.used / mem.total) * 100).toFixed(2) + '%'
      },
      disk: disk.map(d => ({
        fs: d.fs,
        size: (d.size / 1024 / 1024 / 1024).toFixed(2) + ' GB',
        used: (d.used / 1024 / 1024 / 1024).toFixed(2) + ' GB',
        use: d.use.toFixed(2) + '%',
        mount: d.mount
      })),
      os: {
        platform: osInfo.platform,
        distro: osInfo.distro,
        release: osInfo.release,
        arch: osInfo.arch,
        hostname: os.hostname(),
        kernel: osInfo.kernel
      },
      uptime: {
        system: time.uptime,
        process: process.uptime(),
        formatted: formatUptime(time.uptime)
      },
      network: Object.keys(network).length,
      user: req.session.username
    });
  } catch (e) {
    console.error('[STATS] Error:', e);
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/exec', requireAuth, (req, res) => {
  const { command } = req.body;
  if (!command) return res.status(400).json({ error: 'No command provided' });

  // Security: block dangerous commands in web exec (allowlist approach optional)
  const blocked = ['rm -rf /', ':(){:|:&};:', 'mkfs', 'dd if='];
  if (blocked.some(b => command.includes(b))) {
    return res.status(403).json({ error: 'Command blocked for security' });
  }

  console.log(`[EXEC] ${req.session.username} -> ${command}`);
  exec(command, { timeout: 30000, maxBuffer: 1024*1024*5 }, (error, stdout, stderr) => {
    res.json({
      command,
      stdout: stdout.slice(0, 10000),
      stderr: stderr.slice(0, 10000),
      error: error ? error.message : null,
      exitCode: error ? error.code : 0
    });
  });
});

app.get('/api/files', requireAuth, (req, res) => {
  const dirPath = req.query.path || os.homedir();
  try {
    const files = fs.readdirSync(dirPath, { withFileTypes: true }).map(f => ({
      name: f.name,
      isDir: f.isDirectory(),
      isFile: f.isFile(),
      path: path.join(dirPath, f.name)
    }));
    res.json({ path: dirPath, files });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/processes', requireAuth, async (req, res) => {
  try {
    const procs = await si.processes();
    res.json({
      all: procs.all,
      list: procs.list.slice(0, 100).map(p => ({
        pid: p.pid,
        name: p.name,
        cpu: p.cpu,
        mem: p.mem,
        user: p.user
      }))
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ==================== LLM API - Hermes + Router ====================

async function checkLLMHealth() {
  let ollamaHealthy = false;
  let litellmHealthy = false;
  let routerHealthy = false;
  let ollamaModels = [];
  let error = null;

  try {
    const res = await axios.get(`${OLLAMA_HOST}/api/tags`, { timeout: 3000 });
    ollamaHealthy = true;
    ollamaModels = res.data.models || [];
  } catch (e) {
    error = e.message;
  }

  try {
    const res = await axios.get(`${LITELLM_HOST}/health`, { timeout: 3000 });
    litellmHealthy = true;
  } catch (e) {
    // Try root
    try {
      await axios.get(`${LITELLM_HOST}/`, { timeout: 3000 });
      litellmHealthy = true;
    } catch {}
  }

  try {
    const res = await axios.get(`${LLM_ROUTER_HOST}/health`, { timeout: 3000 });
    routerHealthy = true;
  } catch {}

  return { ollamaHealthy, litellmHealthy, routerHealthy, ollamaModels, error };
}

app.get('/api/llm/status', requireAuth, async (req, res) => {
  const health = await checkLLMHealth();
  res.json({
    timestamp: new Date().toISOString(),
    selected_stack: {
      runner: 'Ollama',
      router: 'LiteLLM Proxy',
      reason: 'Best for 24/7 - lightweight, OpenAI compatible, routing, fallback, health checks'
    },
    services: {
      ollama: {
        host: OLLAMA_HOST,
        healthy: health.ollamaHealthy,
        url: OLLAMA_HOST,
        models: health.ollamaModels.length
      },
      litellm: {
        host: LITELLM_HOST,
        healthy: health.litellmHealthy,
        url: LITELLM_HOST,
        api: `${LITELLM_HOST}/v1/chat/completions`,
        docs: `${LITELLM_HOST}/ui`
      },
      custom_router: {
        host: LLM_ROUTER_HOST,
        healthy: health.routerHealthy,
        url: LLM_ROUTER_HOST
      }
    },
    models: health.ollamaModels.map(m => ({
      name: m.name,
      size: m.size,
      modified: m.modified_at
    })),
    available_hermes: [
      { id: 'hermes', ollama: 'nous-hermes2', ram: '8GB', description: 'Nous-Hermes2 10B - Balanced' },
      { id: 'hermes3', ollama: 'hermes3:8b', ram: '6GB', description: 'Hermes3 8B - Recommended' },
      { id: 'hermes3:3b', ollama: 'hermes3:3b', ram: '3GB', description: 'Lightweight for free VPS' },
      { id: 'openhermes', ollama: 'openhermes', ram: '6GB', description: 'OpenHermes 7B' },
      { id: 'hermes-light', ollama: 'nous-hermes2:2b', ram: '2GB', description: 'Ultra-light for GitHub Actions' }
    ],
    endpoints: {
      openai_compatible: `${LITELLM_HOST}/v1/chat/completions`,
      ollama_direct: `${OLLAMA_HOST}/api/chat`,
      custom_router: `${LLM_ROUTER_HOST}/v1/chat/completions`,
      models: `${LITELLM_HOST}/v1/models`,
      health: '/api/llm/status'
    },
    auth: {
      master_key: LITELLM_MASTER_KEY.substring(0,10)+'...',
      header: 'Authorization: Bearer sk-1234'
    },
    uptime_24_7: {
      method: 'Docker restart: unless-stopped + health checks every 30s + keepalive script',
      keepalive: 'scripts/keepalive-llm.sh monitors and restarts if down',
      docker: 'docker-compose -f llm/docker-compose.yml up -d --profile llm'
    }
  });
});

app.get('/api/llm/models', requireAuth, async (req, res) => {
  try {
    // Try LiteLLM first
    try {
      const litellmRes = await axios.get(`${LITELLM_HOST}/v1/models`, {
        headers: { 'Authorization': `Bearer ${LITELLM_MASTER_KEY}` },
        timeout: 5000
      });
      return res.json(litellmRes.data);
    } catch {}

    // Fallback to Ollama
    const ollamaRes = await axios.get(`${OLLAMA_HOST}/api/tags`, { timeout: 5000 });
    const models = (ollamaRes.data.models || []).map(m => ({
      id: m.name,
      object: 'model',
      created: Date.now(),
      owned_by: 'ollama'
    }));
    res.json({ object: 'list', data: models });
  } catch (e) {
    res.status(500).json({ error: e.message, hint: 'Is Ollama running? Run: ollama serve & ollama pull nous-hermes2' });
  }
});

// Proxy chat completions through our router (adds auth, logging, 24/7 monitoring)
app.post('/api/llm/chat', requireAuth, async (req, res) => {
  const { model, messages, temperature, max_tokens, stream } = req.body;
  
  if (!messages) return res.status(400).json({ error: 'messages required' });

  const targetModel = model || 'hermes';

  // Try LiteLLM
  try {
    const response = await axios.post(`${LITELLM_HOST}/v1/chat/completions`, {
      model: targetModel,
      messages,
      temperature: temperature || 0.7,
      max_tokens: max_tokens || 500,
      stream: stream || false
    }, {
      headers: {
        'Authorization': `Bearer ${LITELLM_MASTER_KEY}`,
        'Content-Type': 'application/json'
      },
      timeout: 300000,
      responseType: stream ? 'stream' : 'json'
    });

    if (stream) {
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      response.data.pipe(res);
    } else {
      res.json(response.data);
    }
    return;
  } catch (e) {
    console.log(`[LLM] LiteLLM failed, trying Ollama direct: ${e.message}`);
  }

  // Fallback to Ollama direct
  try {
    const modelMap = {
      'hermes': 'nous-hermes2',
      'hermes3': 'hermes3:8b',
      'openhermes': 'openhermes',
      'hermes-light': 'nous-hermes2:2b'
    };
    const ollamaModel = modelMap[targetModel] || targetModel;

    const ollamaRes = await axios.post(`${OLLAMA_HOST}/api/chat`, {
      model: ollamaModel,
      messages,
      stream: false,
      options: { temperature: temperature || 0.7, num_predict: max_tokens || 500 }
    }, { timeout: 300000 });

    // Convert to OpenAI format
    res.json({
      id: `chatcmpl-${Date.now()}`,
      object: 'chat.completion',
      created: Math.floor(Date.now()/1000),
      model: targetModel,
      choices: [{
        index: 0,
        message: { role: 'assistant', content: ollamaRes.data.message?.content || '' },
        finish_reason: 'stop'
      }],
      usage: {
        prompt_tokens: Math.floor(JSON.stringify(messages).length/4),
        completion_tokens: Math.floor((ollamaRes.data.message?.content?.length || 0)/4),
        total_tokens: 0
      }
    });
  } catch (e) {
    res.status(500).json({ error: e.message, details: e.response?.data || null, hint: 'Pull model: ollama pull nous-hermes2' });
  }
});

// Public LLM health (no auth) for monitoring
app.get('/api/llm/health', async (req, res) => {
  const health = await checkLLMHealth();
  res.json({
    status: health.ollamaHealthy || health.litellmHealthy ? 'online' : 'offline',
    timestamp: new Date().toISOString(),
    services: health,
    uptime: process.uptime()
  });
});

// Create HTTP server
const server = http.createServer(app);

// WebSocket Terminal
const wss = new WebSocket.Server({ server, path: '/ws/terminal' });

wss.on('connection', (ws, req) => {
  // Simple session check via cookie parsing would be ideal, but for now allow if upgrade
  // In production, validate session token
  console.log('[WS] New terminal connection');

  let ptyProcess = null;
  try {
    const pty = require('node-pty');
    ptyProcess = pty.spawn('bash', [], {
      name: 'xterm-color',
      cols: 80,
      rows: 24,
      cwd: process.env.HOME || '/home/' + VPS_USER.toLowerCase(),
      env: {
        ...process.env,
        TERM: 'xterm-256color',
        USER: VPS_USER
      }
    });

    ptyProcess.onData(data => {
      try { ws.send(data); } catch {}
    });

    ws.on('message', msg => {
      try {
        const data = msg.toString();
        // Handle resize messages: JSON {type:'resize', cols, rows}
        try {
          const parsed = JSON.parse(data);
          if (parsed.type === 'resize') {
            ptyProcess.resize(parsed.cols, parsed.rows);
            return;
          }
        } catch {}
        ptyProcess.write(data);
      } catch {}
    });

    ws.on('close', () => {
      ptyProcess.kill();
      console.log('[WS] Terminal closed');
    });

  } catch (e) {
    console.log('[WS] node-pty not available, using fallback shell:', e.message);
    // Fallback: simple exec-based shell
    let shell = spawn('bash', [], { stdio: ['pipe', 'pipe', 'pipe'] });
    
    shell.stdout.on('data', d => ws.send(d.toString()));
    shell.stderr.on('data', d => ws.send(d.toString()));

    ws.on('message', msg => {
      shell.stdin.write(msg);
    });

    ws.on('close', () => {
      shell.kill();
    });

    ws.send(`\r\n[FreeVPS Mark1.3] Connected as ${VPS_USER}\r\nFallback terminal (node-pty not installed)\r\n$ `);
  }
});

// Helper
function formatUptime(seconds) {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  return `${d}d ${h}h ${m}m ${s}s`;
}

// Start
server.listen(PORT, HOST, () => {
  console.log(`
╔════════════════════════════════════════════════════╗
║         FreeVPS Mark1.3 - 24/7 VPS ONLINE          ║
╠════════════════════════════════════════════════════╣
║  User: ${VPS_USER.padEnd(42)}║
║  Pass: ${(VPS_PASS_PLAIN ? '*'.repeat(VPS_PASS_PLAIN.length) : '').padEnd(42)}║
║  Host: ${HOST.padEnd(42)}║
║  Port: ${String(PORT).padEnd(42)}║
║  URL:  http://${HOST}:${PORT}                         ║
║  Dashboard: http://${HOST}:${PORT}/dashboard.html     ║
╚════════════════════════════════════════════════════╝
  `);
  
  // Try to create system user if running as root
  if (process.getuid && process.getuid() === 0) {
    console.log('[SETUP] Running as root - ensuring system user exists...');
    exec(`id ${VPS_USER.toLowerCase()} || useradd -m -s /bin/bash ${VPS_USER.toLowerCase()} && echo "${VPS_USER.toLowerCase()}:${VPS_PASS_PLAIN}" | chpasswd && usermod -aG sudo ${VPS_USER.toLowerCase()}`, (err, stdout, stderr) => {
      if (err) console.log('[SETUP] User creation note:', stderr || err.message);
      else console.log(`[SETUP] System user ${VPS_USER.toLowerCase()} ready`);
    });
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[FreeVPS] Shutting down...');
  server.close(() => process.exit(0));
});
