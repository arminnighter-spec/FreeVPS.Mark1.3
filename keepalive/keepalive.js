/**
 * FreeVPS Mark1.3 - Keepalive Service
 * Ensures 24/7 uptime via heartbeat and auto-restart
 */

const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const os = require('os');

const HEARTBEAT_FILE = path.join(__dirname, 'heartbeat.log');
const UPTIME_FILE = path.join(__dirname, 'uptime.log');
const INTERVAL = 5 * 60 * 1000; // 5 minutes

console.log(`
╔════════════════════════════════════════════════════╗
║         FreeVPS Mark1.3 - Keepalive Service        ║
║         24/7 Heartbeat & Monitoring                ║
╚════════════════════════════════════════════════════╝
`);

function logHeartbeat() {
  const now = new Date().toISOString();
  const uptime = os.uptime();
  const load = os.loadavg();
  const mem = process.memoryUsage();
  
  const entry = `[${now}] Heartbeat - Uptime: ${Math.floor(uptime/3600)}h ${Math.floor((uptime%3600)/60)}m - Load: ${load[0].toFixed(2)} - Mem: ${(mem.rss/1024/1024).toFixed(2)}MB - User: Mikasa - Status: ONLINE 24/7\n`;
  
  console.log(entry.trim());
  
  // Append to heartbeat log (keep last 100 lines)
  try {
    fs.appendFileSync(HEARTBEAT_FILE, entry);
    const lines = fs.readFileSync(HEARTBEAT_FILE, 'utf8').split('\n');
    if (lines.length > 100) {
      fs.writeFileSync(HEARTBEAT_FILE, lines.slice(-100).join('\n'));
    }
  } catch (e) {
    console.error('Failed to write heartbeat:', e.message);
  }
  
  // Check services
  checkServices();
}

function checkServices() {
  const services = [
    { name: 'Dashboard', pattern: 'node server.js', restart: 'PORT=8080 VPS_USER=Mikasa VPS_PASS="Eren@Home$123" nohup node server.js > /tmp/dashboard.log 2>&1 &' },
    { name: 'ttyd', pattern: 'ttyd', restart: null },
    { name: 'code-server', pattern: 'code-server', restart: null }
  ];
  
  services.forEach(svc => {
    exec(`pgrep -f "${svc.pattern}"`, (err, stdout) => {
      if (err || !stdout.trim()) {
        console.log(`[WARN] ${svc.name} is down!`);
        if (svc.restart) {
          console.log(`[RESTART] Restarting ${svc.name}...`);
          exec(svc.restart, (e) => {
            if (e) console.error(`Failed to restart ${svc.name}:`, e.message);
            else console.log(`[OK] ${svc.name} restarted`);
          });
        }
      }
    });
  });
}

function logUptime() {
  const now = new Date().toISOString();
  const entry = `${now} - FreeVPS Mark1.3 Started - User: Mikasa - PID: ${process.pid} - Host: ${os.hostname()}\n`;
  try {
    fs.appendFileSync(UPTIME_FILE, entry);
  } catch {}
}

// Initial logs
logUptime();
logHeartbeat();

// Heartbeat interval
setInterval(logHeartbeat, INTERVAL);

// Also ping external uptime monitor if configured
const UPTIME_URL = process.env.UPTIME_PING_URL;
if (UPTIME_URL) {
  console.log(`[KEEPALIVE] External ping enabled: ${UPTIME_URL}`);
  setInterval(() => {
    exec(`curl -s ${UPTIME_URL} > /dev/null && echo "[PING] Uptime ping OK" || echo "[PING] Uptime ping failed"`, (err, stdout) => {
      console.log(stdout.trim());
    });
  }, INTERVAL);
}

console.log(`[KEEPALIVE] Heartbeat every ${INTERVAL/1000}s - Logging to ${HEARTBEAT_FILE}`);
console.log(`[KEEPALIVE] VPS User: Mikasa - Services monitored: Dashboard, ttyd, code-server`);
console.log(`[KEEPALIVE] Running 24/7... Press Ctrl+C to stop`);

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n[KEEPALIVE] Shutting down keepalive service...');
  fs.appendFileSync(HEARTBEAT_FILE, `[${new Date().toISOString()}] Keepalive stopped\n`);
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n[KEEPALIVE] Received SIGTERM, shutting down...');
  process.exit(0);
});
