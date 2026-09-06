import express from 'express';
import { createServer } from 'http';
import { Server as HttpServer } from 'http';
import { Server } from 'socket.io';
import path from 'path';
import { exec, execSync } from 'child_process';
import { taskQueue, resolvePendingTask, taskEmitter } from './task-queue';

interface ActivityLog {
    id: string;
    time: string;
    type: 'task' | 'response' | 'error' | 'system';
    message: string;
}

const activityLogs: ActivityLog[] = [];
let totalTasks = 0;
let successCount = 0;
let errorCount = 0;
const sessionStart = new Date().toISOString();

function addLog(io: Server, type: ActivityLog['type'], message: string) {
    const log: ActivityLog = {
        id: Date.now().toString(),
        time: new Date().toLocaleTimeString('id-ID'),
        type,
        message,
    };
    activityLogs.unshift(log);
    if (activityLogs.length > 200) activityLogs.pop();

    io.emit('log', log);
    io.emit('stats', { totalTasks, successCount, errorCount, sessionStart });
}

/**
 * Membunuh proses zombie yang masih menyandera port tertentu.
 * Ini menyelesaikan masalah EADDRINUSE yang terjadi setelah restart IDE.
 */
function killZombieOnPort(port: number): boolean {
    try {
        if (process.platform === 'win32') {
            const output = execSync(
                `netstat -ano | findstr :${port} | findstr LISTENING`,
                { encoding: 'utf8', timeout: 5000 }
            );
            const lines = output.trim().split('\n');
            for (const line of lines) {
                const parts = line.trim().split(/\s+/);
                const pid = parts[parts.length - 1];
                if (pid && pid !== '0' && pid !== String(process.pid)) {
                    try {
                        execSync(`taskkill /F /PID ${pid}`, { encoding: 'utf8', timeout: 5000 });
                        console.error(`[Bridge] Zombie process (PID ${pid}) pada port ${port} berhasil dihentikan.`);
                    } catch { /* ignore if already dead */ }
                }
            }
            return true;
        } else {
            // macOS / Linux
            const output = execSync(`lsof -ti :${port}`, { encoding: 'utf8', timeout: 5000 });
            const pids = output.trim().split('\n');
            for (const pid of pids) {
                if (pid && pid !== String(process.pid)) {
                    try { execSync(`kill -9 ${pid}`); } catch { /* ignore */ }
                }
            }
            return true;
        }
    } catch {
        // Tidak ada proses yang menyandera port — ini normal
        return false;
    }
}

export function startBridgeServer(port: number = 3055) {
    const app = express();
    const httpServer = createServer(app);
    const io = new Server(httpServer, { cors: { origin: "*" } });

    app.use(express.json({ limit: '50mb' }));
    app.use(express.static(path.join(__dirname, '../public')));

    let dashboardOpened = false;
    let studioConnected = false;

    // Provide initial state to newly connected dashboard clients
    io.on('connection', (socket) => {
        socket.emit('init', {
            logs: activityLogs,
            stats: { totalTasks, successCount, errorCount, sessionStart, studioConnected, port },
        });
    });

    // API endpoint to get current stats
    app.get('/api/stats', (req, res) => {
        res.json({ totalTasks, successCount, errorCount, sessionStart, studioConnected, port });
    });

    const waitingPollers: express.Response[] = [];

    taskEmitter.on('new_task', () => {
        if (taskQueue.length > 0 && waitingPollers.length > 0) {
            const res = waitingPollers.shift();
            const task = taskQueue.shift();
            totalTasks++;
            addLog(io, 'task', `Mengirim perintah '${task?.command}' ke Studio${task?.target ? ` → ${task.target}` : ''}.`);
            res?.json(task);
        }
    });

    // Endpoint Studio Polling
    app.get('/api/tasks', (req, res) => {
        if (!studioConnected) {
            studioConnected = true;
            io.emit('studio-status', { connected: true });
            addLog(io, 'system', 'Roblox Studio terhubung ke Bridge Server.');
        }

        if (!dashboardOpened) {
            dashboardOpened = true;
            const url = `http://localhost:${port}`;
            const startCmd = process.platform === 'win32' ? `start "" "${url}"` : process.platform === 'darwin' ? `open "${url}"` : `xdg-open "${url}"`;
            exec(startCmd, (error) => {
                if (error) console.error(`[Bridge] Gagal membuka browser:`, error);
            });
            console.error(`[Bridge] Pertama kali terhubung dengan Studio! Membuka Dashboard...`);
        }

        if (taskQueue.length > 0) {
            const task = taskQueue.shift();
            totalTasks++;
            addLog(io, 'task', `Mengirim perintah '${task?.command}' ke Studio${task?.target ? ` → ${task.target}` : ''}.`);
            res.json(task);
        } else {
            // Long-polling: tunggu maksimal 20 detik
            const timeoutId = setTimeout(() => {
                const index = waitingPollers.indexOf(res);
                if (index !== -1) {
                    waitingPollers.splice(index, 1);
                    res.json({ id: null });
                }
            }, 20000);

            waitingPollers.push(res);

            // Bersihkan jika terputus prematur
            req.on('close', () => {
                clearTimeout(timeoutId);
                const index = waitingPollers.indexOf(res);
                if (index !== -1) {
                    waitingPollers.splice(index, 1);
                }
            });
        }
    });

    // Endpoint Studio Response
    app.post('/api/response', (req, res) => {
        const { id, status, result, error } = req.body;

        if (status === 'success') {
            successCount++;
            addLog(io, 'response', `Perintah selesai: ${String(result).substring(0, 120)}`);
        } else {
            errorCount++;
            addLog(io, 'error', `Gagal: ${error}`);
        }

        resolvePendingTask(id, status, result, error);
        res.json({ message: "Response diterima" });
    });

    // ── ANTI-ZOMBIE: Coba listen, jika gagal bunuh zombie lalu retry ──
    function tryListen(retriesLeft: number = 2) {
        const server = httpServer.listen(port, () => {
            console.error(`[Bridge] Dashboard visual & server aktif di http://localhost:${port}`);
        });

        server.on('error', (err: NodeJS.ErrnoException) => {
            if (err.code === 'EADDRINUSE' && retriesLeft > 0) {
                console.error(`[Bridge] Port ${port} sedang digunakan oleh proses zombie. Mencoba membunuh...`);
                killZombieOnPort(port);
                setTimeout(() => {
                    console.error(`[Bridge] Mencoba listen ulang pada port ${port}... (sisa ${retriesLeft - 1} percobaan)`);
                    tryListen(retriesLeft - 1);
                }, 1500);
            } else {
                console.error(`[Bridge] FATAL: Gagal mendengarkan port ${port}:`, err.message);
                process.exit(1);
            }
        });
    }

    tryListen();
}
