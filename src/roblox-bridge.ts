import express from 'express';
import { createServer } from 'http';
import { Server as HttpServer } from 'http';
import { Server } from 'socket.io';
import path from 'path';
import { exec, execSync } from 'child_process';
import { taskQueue, resolvePendingTask, taskEmitter, addTaskToQueue, Task } from './task-queue';

interface ActivityLog {
    id: string;
    time: string;
    type: 'task' | 'response' | 'error' | 'system';
    message: string;
}

export let isBridgeHosting = false;

// Global process error handlers agar server bridge tidak mati mendadak
process.on('uncaughtException', (err) => {
    console.error('[Bridge] Uncaught Exception:', err);
});
process.on('unhandledRejection', (reason) => {
    console.error('[Bridge] Unhandled Rejection:', reason);
});

const activityLogs: ActivityLog[] = [];
let totalTasks = 0;
let successCount = 0;
let errorCount = 0;
const sessionStart = new Date().toISOString();

// ── SSE Peer Registry ─────────────────────────────────────────────────────────
// Menyimpan semua koneksi SSE aktif dari Studio plugin
interface SsePeer {
    studioId: string;
    res: express.Response;
    connectedAt: number;
    heartbeatTimer: NodeJS.Timeout;
    silenceTimer: NodeJS.Timeout;
}

// Per-studio pending events queue: events yang belum diambil oleh Studio
const studioEventQueues = new Map<string, Array<Record<string, unknown>>>();

function enqueueForStudio(studioId: string | null, event: Record<string, unknown>) {
    if (studioId) {
        // Event untuk studio tertentu
        if (!studioEventQueues.has(studioId)) studioEventQueues.set(studioId, []);
        studioEventQueues.get(studioId)!.push(event);
    } else {
        // Broadcast ke semua studio yang terdaftar
        for (const [sid] of studioEventQueues) {
            studioEventQueues.get(sid)!.push(event);
        }
    }
}

const ssePeers = new Map<string, SsePeer>();

// Apakah MCP agent (Antigravity/Cursor) sedang terhubung ke stdio transport?
let mcpConnected = false;

export function setMcpConnected(connected: boolean) {
    mcpConnected = connected;
    broadcastStatus();
}

/**
 * Kirim event SSE ke semua Studio peer yang terhubung.
 */
function broadcastEvent(kind: string, payload: Record<string, unknown>) {
    const data = JSON.stringify({ kind, ...payload });
    for (const peer of ssePeers.values()) {
        try {
            peer.res.write(`data: ${data}\n\n`);
        } catch { /* peer disconnected */ }
    }
}

/**
 * Kirim event SSE ke satu peer tertentu.
 */
function sendEvent(peer: SsePeer, kind: string, payload: Record<string, unknown>) {
    const data = JSON.stringify({ kind, ...payload });
    try {
        peer.res.write(`data: ${data}\n\n`);
    } catch { /* peer disconnected */ }
}

/**
 * Push status koneksi ke semua peer (apakah mcpConnected, jumlah peer aktif dll).
 */
function broadcastStatus() {
    const statusEvent = {
        mcpConnected,
        studioCount: ssePeers.size,
        serverVersion: '2.1.5',
    };
    broadcastEvent('status', statusEvent);
    // Juga enqueue untuk Studio yang belum polling saat ini
    enqueueForStudio(null, { kind: 'status', ...statusEvent });
}

/**
 * Push task ke semua Studio peer (broadcast ke semua Studio yang terbuka).
 * Hanya satu yang akan memprosesnya (first-come first-served via requestId).
 */
function broadcastTask(task: Task) {
    const taskEvent = {
        requestId: task.id,
        command: task.command,
        target: task.target,
        data: task.data ?? null,
        remainingMs: 29000,
    };
    broadcastEvent('request', taskEvent);
    // Juga enqueue untuk Studio yang sedang tidak polling
    enqueueForStudio(null, { kind: 'request', ...taskEvent });
}

// ── Logging ───────────────────────────────────────────────────────────────────
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
        return false;
    }
}

export function startBridgeServer(port: number = 3055) {
    const app = express();
    const httpServer = createServer(app);
    const io = new Server(httpServer, { cors: { origin: '*' } });

    app.use(express.json({ limit: '50mb' }));
    app.use(express.static(path.join(__dirname, '../public')));

    let dashboardOpened = false;

    // Sediakan initial state ke dashboard browser baru
    io.on('connection', (socket) => {
        socket.emit('init', {
            logs: activityLogs,
            stats: { totalTasks, successCount, errorCount, sessionStart, studioConnected: ssePeers.size > 0, port },
        });
    });

    // ── /api/stats ─────────────────────────────────────────────────────────────
    app.get('/api/stats', (req, res) => {
        const activeStudios = Math.max(ssePeers.size, studioEventQueues.size);
        res.json({
            totalTasks, successCount, errorCount, sessionStart,
            studioConnected: activeStudios > 0,
            studioCount: activeStudios,
            mcpConnected,
            port,
        });
    });

    // ── /api/ping ─────────────────────────────────────────────────────────────
    // Dipertahankan untuk backward-compat (installer check, health check).
    app.get('/api/ping', (req, res) => {
        const activeStudios = Math.max(ssePeers.size, studioEventQueues.size);
        res.json({ status: 'ok', studioCount: activeStudios, mcpConnected, timestamp: Date.now() });
    });

    // ── /api/stream (Snapshot endpoint untuk Roblox GetAsync) ───────────────
    // Roblox HttpService:GetAsync() TIDAK bisa streaming — ia block sampai
    // koneksi ditutup. Endpoint ini: daftarkan studio, kirim semua events
    // yang tertunda (status + queued tasks), lalu TUTUP koneksi.
    // Plugin mengulang GET ini setiap ~0.5 detik (pseudo-polling via snapshot).
    app.get('/api/stream', (req, res) => {
        const studioId = (req.query.studioId as string) || `anon-${Date.now()}`;

        // Daftarkan studio jika belum ada
        if (!studioEventQueues.has(studioId)) {
            studioEventQueues.set(studioId, []);
            io.emit('studio-status', { connected: true, studioCount: studioEventQueues.size, studioId });
            addLog(io, 'system', `Studio terdaftar. (ID: ${studioId.substring(0, 8)}…, Total: ${studioEventQueues.size})`);

            if (!dashboardOpened) {
                dashboardOpened = true;
                const url = `http://localhost:${port}`;
                const startCmd = process.platform === 'win32' ? `start "" "${url}"` : process.platform === 'darwin' ? `open "${url}"` : `xdg-open "${url}"`;
                exec(startCmd, (error) => {
                    if (error) console.error(`[Bridge] Gagal membuka browser:`, error);
                });
            }
        }

        // Kumpulkan semua events yang belum dikirim ke studio ini
        const queue = studioEventQueues.get(studioId) ?? [];
        studioEventQueues.set(studioId, []); // kosongkan antrian

        // Selalu sertakan status terkini
        const events: Array<Record<string, unknown>> = [
            { kind: 'status', mcpConnected, studioCount: studioEventQueues.size, serverVersion: '2.1.5' },
        ];

        // Tambahkan events tertunda (misalnya task requests)
        for (const ev of queue) {
            // Hindari duplikat status
            if (ev.kind !== 'status') events.push(ev);
        }

        // Jika ada task di queue global, sertakan juga
        if (taskQueue.length > 0) {
            const task = taskQueue.shift()!;
            totalTasks++;
            addLog(io, 'task', `Mengirim perintah '${task.command}' ke Studio (ID: ${studioId.substring(0, 8)}…).`);
            events.push({
                kind: 'request',
                requestId: task.id,
                command: task.command,
                target: task.target,
                data: task.data ?? null,
                remainingMs: 29000,
            });
        }

        // Format sebagai teks SSE (setiap event = satu baris "data: ...\n\n")
        res.setHeader('Content-Type', 'text/plain');
        res.setHeader('Cache-Control', 'no-cache, no-store');
        const body = events
            .map(ev => `data: ${JSON.stringify(ev)}`)
            .join('\n');
        res.send(body);
    });

    // ── /api/events (SSE persisten untuk browser/klien modern) ───────────────
    app.get('/api/events', (req, res) => {
        const studioId = (req.query.studioId as string) || `browser-${Date.now()}`;

        res.setHeader('Content-Type', 'text/event-stream');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('Connection', 'keep-alive');
        res.setHeader('X-Accel-Buffering', 'no');
        res.flushHeaders();

        const heartbeatTimer = setInterval(() => {
            try {
                res.write(`data: ${JSON.stringify({ kind: 'heartbeat', timestamp: Date.now() })}\n\n`);
            } catch { cleanup(); }
        }, 5000);

        const silenceTimer = setTimeout(() => cleanup(), 60000);
        const peer: SsePeer = { studioId, res, connectedAt: Date.now(), heartbeatTimer, silenceTimer };
        ssePeers.set(studioId, peer);

        sendEvent(peer, 'status', { mcpConnected, studioCount: studioEventQueues.size, serverVersion: '2.1.5' });

        function cleanup() {
            clearInterval(heartbeatTimer);
            clearTimeout(silenceTimer);
            ssePeers.delete(studioId);
            try { res.end(); } catch { /* ignore */ }
        }

        req.on('close', cleanup);
        req.on('error', cleanup);
    });

    // ── /api/response/:taskId (Studio POSTs hasil eksekusi) ───────────────────
    app.post('/api/response/:taskId', (req, res) => {
        const { taskId } = req.params;
        const { status, result, error } = req.body;

        if (status === 'success') {
            successCount++;
            addLog(io, 'response', `Perintah selesai: ${String(result ?? '').substring(0, 120)}`);
        } else {
            errorCount++;
            addLog(io, 'error', `Gagal: ${error}`);
        }

        resolvePendingTask(taskId, status, result, error);
        res.json({ ok: true });
    });

    // ── /api/response (legacy — lama, tetap didukung) ────────────────────────
    app.post('/api/response', (req, res) => {
        const { id, status, result, error } = req.body;
        if (status === 'success') {
            successCount++;
            addLog(io, 'response', `Perintah selesai: ${String(result ?? '').substring(0, 120)}`);
        } else {
            errorCount++;
            addLog(io, 'error', `Gagal: ${error}`);
        }
        resolvePendingTask(id, status, result, error);
        res.json({ ok: true });
    });

    // ── Notifikasi task baru ke Dashboard ────────────────────────────────────
    // Pengiriman task ke Studio dilakukan via /api/stream (snapshot polling).
    // Di sini kita hanya log ke dashboard browser.
    taskEmitter.on('new_task', () => {
        if (taskQueue.length === 0) return;
        const task = taskQueue[0]; // preview saja, tidak shift
        addLog(io, 'task', `Task baru antri: '${task.command}'${task.target ? ` → ${task.target}` : ''}. Menunggu Studio polling...`);
    });

    // ── /api/tasks/enqueue (dari proses MCP eksternal / bridge forwarding) ────
    app.post('/api/tasks/enqueue', async (req, res) => {
        const { command, target, data } = req.body;
        try {
            const result = await addTaskToQueue(command, target, data);
            res.json({ status: 'success', result });
        } catch (err: any) {
            res.json({ status: 'error', error: err.message });
        }
    });

    // ── /api/tasks (legacy long-poll — dipertahankan untuk backward-compat) ───
    // Studio lama yang belum update plugin masih bisa bekerja via polling.
    const waitingPollers: express.Response[] = [];
    taskEmitter.on('new_task_legacy', () => {
        if (taskQueue.length > 0 && waitingPollers.length > 0) {
            const pollRes = waitingPollers.shift();
            const task = taskQueue.shift();
            totalTasks++;
            addLog(io, 'task', `[Legacy] Mengirim perintah '${task?.command}' ke Studio.`);
            pollRes?.json(task);
        }
    });

    app.get('/api/tasks', (req, res) => {
        if (taskQueue.length > 0) {
            const task = taskQueue.shift();
            totalTasks++;
            addLog(io, 'task', `[Legacy] Mengirim perintah '${task?.command}' ke Studio.`);
            return res.json(task);
        }
        const timeoutId = setTimeout(() => {
            const index = waitingPollers.indexOf(res);
            if (index !== -1) {
                waitingPollers.splice(index, 1);
                res.json({ id: null });
            }
        }, 20000);
        waitingPollers.push(res);
        req.on('close', () => {
            clearTimeout(timeoutId);
            const index = waitingPollers.indexOf(res);
            if (index !== -1) waitingPollers.splice(index, 1);
        });
    });

    // ── Port-sharing & anti-zombie ────────────────────────────────────────────
    function tryListen(retriesLeft: number = 2) {
        const server = httpServer.listen(port, () => {
            isBridgeHosting = true;
            console.error(`[Bridge] SSE Bridge Server aktif di http://localhost:${port}`);
        });

        server.on('error', async (err: NodeJS.ErrnoException) => {
            if (err.code === 'EADDRINUSE') {
                try {
                    const controller = new AbortController();
                    const timeoutId = setTimeout(() => controller.abort(), 1000);
                    const pingRes = await fetch(`http://localhost:${port}/api/ping`, { signal: controller.signal });
                    clearTimeout(timeoutId);
                    if (pingRes.ok) {
                        isBridgeHosting = false;
                        console.error(`[Bridge] Port ${port} sudah digunakan oleh NVStudio Bridge aktif. Menggunakan instance yang sudah berjalan.`);
                        return;
                    }
                } catch { /* bukan NVStudio bridge */ }

                if (retriesLeft > 0) {
                    console.error(`[Bridge] Port ${port} zombie. Mencoba membunuh...`);
                    killZombieOnPort(port);
                    setTimeout(() => tryListen(retriesLeft - 1), 1500);
                } else {
                    console.error(`[Bridge] FATAL: Port ${port} tidak dapat dibuka.`);
                }
            } else {
                console.error(`[Bridge] FATAL: Gagal mendengarkan port ${port}:`, err.message);
                process.exit(1);
            }
        });
    }

    tryListen();
}
