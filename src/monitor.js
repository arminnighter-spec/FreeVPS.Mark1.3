/**
 * FreeVPS Mark1.3 - System Monitor Module
 * Advanced monitoring for 24/7 VPS
 */

const si = require('systeminformation');
const fs = require('fs');
const path = require('path');
const os = require('os');

class VPSMonitor {
  constructor() {
    this.startTime = Date.now();
    this.user = 'Mikasa';
    this.version = '1.3.0';
    this.logFile = path.join(__dirname, '../keepalive/monitor.json');
  }

  async getFullStats() {
    try {
      const [cpu, mem, disk, osInfo, time, processes, network, docker] = await Promise.all([
        si.currentLoad(),
        si.mem(),
        si.fsSize(),
        si.osInfo(),
        si.time(),
        si.processes(),
        si.networkInterfaces(),
        si.dockerInfo().catch(() => null)
      ]);

      return {
        timestamp: new Date().toISOString(),
        vps: {
          name: 'FreeVPS Mark1.3',
          version: this.version,
          user: this.user,
          uptime: {
            system: time.uptime,
            process: process.uptime(),
            startTime: new Date(this.startTime).toISOString(),
            formatted: this.formatUptime(time.uptime)
          },
          status: 'online',
          mode: '24/7'
        },
        system: {
          cpu: {
            load: cpu.currentLoad,
            cores: cpu.cpus.length,
            model: cpu.cpus[0]?.model,
            speed: cpu.cpus[0]?.speed
          },
          memory: {
            total: mem.total,
            used: mem.used,
            free: mem.free,
            usage: (mem.used / mem.total * 100).toFixed(2)
          },
          disk: disk,
          os: osInfo,
          network: Object.keys(network).length
        },
        processes: {
          total: processes.all,
          top: processes.list.slice(0, 10).map(p => ({
            pid: p.pid,
            name: p.name,
            cpu: p.cpu,
            mem: p.mem
          }))
        },
        services: {
          dashboard: this.isServiceRunning('server.js'),
          ttyd: this.isServiceRunning('ttyd'),
          code_server: this.isServiceRunning('code-server'),
          ssh: this.isServiceRunning('sshd')
        }
      };
    } catch (e) {
      return { error: e.message, timestamp: new Date().toISOString() };
    }
  }

  isServiceRunning(pattern) {
    try {
      const { execSync } = require('child_process');
      const result = execSync(`pgrep -f "${pattern}" || echo ""`).toString().trim();
      return result.length > 0;
    } catch {
      return false;
    }
  }

  formatUptime(seconds) {
    const d = Math.floor(seconds / 86400);
    const h = Math.floor((seconds % 86400) / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = Math.floor(seconds % 60);
    return `${d}d ${h}h ${m}m ${s}s`;
  }

  async saveStats() {
    const stats = await this.getFullStats();
    try {
      fs.mkdirSync(path.dirname(this.logFile), { recursive: true });
      fs.writeFileSync(this.logFile, JSON.stringify(stats, null, 2));
    } catch {}
    return stats;
  }

  startMonitoring(intervalMs = 30000) {
    console.log(`[MONITOR] Starting 24/7 monitoring every ${intervalMs/1000}s for user ${this.user}`);
    this.saveStats();
    setInterval(() => this.saveStats(), intervalMs);
  }
}

module.exports = VPSMonitor;

if (require.main === module) {
  const monitor = new VPSMonitor();
  monitor.startMonitoring(10000);
  
  // Log every 10s
  setInterval(async () => {
    const stats = await monitor.getFullStats();
    console.log(`[${stats.timestamp}] CPU: ${stats.system.cpu.load.toFixed(1)}% | MEM: ${stats.system.memory.usage}% | Uptime: ${stats.vps.uptime.formatted} | Services: ${Object.values(stats.services).filter(Boolean).length}/4`);
  }, 10000);
}
