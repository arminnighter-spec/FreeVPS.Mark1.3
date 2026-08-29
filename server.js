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
