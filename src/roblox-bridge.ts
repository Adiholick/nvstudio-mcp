import express from 'express';
import { createServer } from 'http';
import { Server as HttpServer } from 'http';
import { Server } from 'socket.io';
import path from 'path';
import { exec, execSync } from 'child_process';
import { taskQueue, resolvePendingTask, taskEmitter, addTaskToQueue, Task, rejectAllPendingTasks, hasPendingTasks, claimTask } from './task-queue';
import {
    attachWsGateway,
    hasActiveWsPeer,
    getWsPeerCount,
    getWsStudioIds,
    sendTaskViaWs,
    broadcastWsEvent,
    selectWsPeer,
    cancelTaskDeadline,
    getWsPeersDetails,
} from './ws-gateway';
import { getRobloxDocs } from './roblox-docs';

const { version: SERVER_VERSION } = require('../package.json');

interface ActivityLog {
    id: string;
    time: string;
    type: 'task' | 'response' | 'error' | 'system';
    message: string;
}

export let isBridgeHosting = false;
let resolveBridgeReady: (val: boolean) => void;
export const bridgeReadyPromise = new Promise<boolean>((resolve) => {
    resolveBridgeReady = resolve;
});

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
const studioLastSeen = new Map<string, number>();
const studioPlaces = new Map<string, number>();

interface StudioPoller {
    res: express.Response;
    timer: NodeJS.Timeout;
}
const activeStudioPollers = new Map<string, StudioPoller>();

// Antrean global untuk task request yang menunggu poller long-polling (/api/stream)
const pendingStreamTasks: Array<Record<string, unknown>> = [];

export function removePendingStreamTask(taskId: string): void {
    const idx = pendingStreamTasks.findIndex(t => (t as any).requestId === taskId || (t as any).taskId === taskId);
    if (idx !== -1) {
        pendingStreamTasks.splice(idx, 1);
    }
}

let disconnectCheckTimer: NodeJS.Timeout | null = null;
export function checkPendingTasksOnStudioDisconnect(): void {
    if (disconnectCheckTimer) clearTimeout(disconnectCheckTimer);
    disconnectCheckTimer = setTimeout(() => {
        disconnectCheckTimer = null;
        if (!isStudioConnected() && hasPendingTasks()) {
            pendingStreamTasks.length = 0;
            rejectAllPendingTasks('Roblox Studio terputus sebelum merespons tugas.');
        }
    }, 2000);
}

setInterval(() => {
    const now = Date.now();
    let changed = false;
    for (const [sid, lastSeen] of studioLastSeen.entries()) {
        const isPollerActive = activeStudioPollers.has(sid);
        if (!isPollerActive && now - lastSeen > 10000) {
            studioEventQueues.delete(sid);
            studioLastSeen.delete(sid);
            studioPlaces.delete(sid);
            changed = true;
        } else if (now - lastSeen > 25000) {
            studioEventQueues.delete(sid);
            studioLastSeen.delete(sid);
            studioPlaces.delete(sid);
            const poller = activeStudioPollers.get(sid);
            if (poller) {
                clearTimeout(poller.timer);
                try { poller.res.end(); } catch {}
                activeStudioPollers.delete(sid);
            }
            changed = true;
        }
    }
    if (changed) {
        broadcastStatus();
        if (!isStudioConnected() && hasPendingTasks()) {
            checkPendingTasksOnStudioDisconnect();
        }
    }
}, 2000);

export function isStudioConnected(filter?: { placeId?: number; studioId?: string }): boolean {
    if (filter?.studioId) {
        if (hasActiveWsPeer({ studioId: filter.studioId })) return true;
        if (activeStudioPollers.has(filter.studioId)) return true;
        const seen = studioLastSeen.get(filter.studioId);
        if (seen && Date.now() - seen <= 5000) return true;
        return false;
    }
    if (filter?.placeId !== undefined && filter?.placeId !== null) {
        if (hasActiveWsPeer({ placeId: filter.placeId })) return true;
        for (const [sid, pid] of studioPlaces.entries()) {
            if (pid === filter.placeId) {
                if (activeStudioPollers.has(sid)) return true;
                const seen = studioLastSeen.get(sid);
                if (seen && Date.now() - seen <= 5000) return true;
            }
        }
        return false;
    }
    if (hasActiveWsPeer()) return true;
    if (activeStudioPollers.size > 0) return true;
    const now = Date.now();
    for (const lastSeen of studioLastSeen.values()) {
        if (now - lastSeen <= 3000) return true;
    }
    return false;
}

export interface ConnectedStudioSummary {
    studioId: string;
    placeId?: number;
    transport: 'websocket' | 'long-polling';
    lastSeen: number;
    isAlive: boolean;
    isBusy: boolean;
}

export function getConnectedStudios(): ConnectedStudioSummary[] {
    const list: ConnectedStudioSummary[] = [];
    const wsDetails = getWsPeersDetails();
    const wsStudioIds = new Set<string>();

    for (const p of wsDetails) {
        wsStudioIds.add(p.studioId);
        list.push({
            studioId: p.studioId,
            placeId: p.placeId,
            transport: 'websocket',
            lastSeen: p.lastSeen,
            isAlive: p.isAlive && !p.unresponsive,
            isBusy: p.isBusy,
        });
    }

    const now = Date.now();
    for (const [sid, lastSeen] of studioLastSeen.entries()) {
        if (!wsStudioIds.has(sid) && (activeStudioPollers.has(sid) || now - lastSeen <= 5000)) {
            list.push({
                studioId: sid,
                placeId: studioPlaces.get(sid),
                transport: 'long-polling',
                lastSeen,
                isAlive: true,
                isBusy: false,
            });
        }
    }

    return list;
}

export function getConnectedStudioCount(): number {
    const ids = new Set<string>();
    for (const sid of studioEventQueues.keys()) ids.add(sid);
    for (const sid of getWsStudioIds()) ids.add(sid);
    return Math.max(ids.size, isStudioConnected() ? 1 : 0);
}

function flushEventsToStudio(sid: string): boolean {
    const poller = activeStudioPollers.get(sid);
    if (!poller) return false;

    const queue = studioEventQueues.get(sid) ?? [];
    if (queue.length === 0) return false;

    studioEventQueues.set(sid, []); // kosongkan antrian
    clearTimeout(poller.timer);
    activeStudioPollers.delete(sid);

    const nonStatusEvents = queue.filter(ev => ev.kind !== 'status');
    const events: Array<Record<string, unknown>> = [
        { kind: 'status', mcpConnected, studioCount: Math.max(studioEventQueues.size, 1), serverVersion: SERVER_VERSION },
        ...nonStatusEvents
    ];

    try {
        poller.res.setHeader('Content-Type', 'text/plain');
        poller.res.setHeader('Cache-Control', 'no-cache, no-store');
        const body = events.map(ev => `data: ${JSON.stringify(ev)}`).join('\n');
        poller.res.send(body);
        return true;
    } catch {
        return false;
    }
}

function enqueueForStudio(studioId: string | null, event: Record<string, unknown>) {
    if (studioId) {
        // Event untuk studio tertentu
        if (!studioEventQueues.has(studioId)) studioEventQueues.set(studioId, []);
        const q = studioEventQueues.get(studioId)!;
        q.push(event);
        if (q.length > 100) q.shift();
        flushEventsToStudio(studioId);
    } else {
        // Broadcast non-task (status, heartbeat) ke semua studio yang terdaftar
        for (const [sid, q] of studioEventQueues.entries()) {
            q.push(event);
            if (q.length > 100) q.shift();
            flushEventsToStudio(sid);
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
    const studioCount = getConnectedStudioCount();
    const statusEvent = {
        mcpConnected,
        studioCount,
        serverVersion: SERVER_VERSION,
    };
    broadcastEvent('status', statusEvent);
    broadcastWsEvent('status', statusEvent);
}

/**
 * Push task ke Studio peer (dengan routing studioId/placeId).
 * Mengembalikan true jika berhasil dikirim langsung ke poller aktif, false jika diantrekan (Bug F).
 */
function broadcastTask(task: Task): boolean {
    const totalBudget = task.remainingMs ?? 30000;
    const elapsed = task.createdAt ? (Date.now() - task.createdAt) : 0;
    const remainingMs = Math.max(1000, totalBudget - elapsed);

    // Bug A & E: Stamp attempt counter dan channel pengiriman
    const attempt = (task.attempt || 0) + 1;
    task.attempt = attempt;
    task.dispatchedAt = Date.now();
    task.deliveredVia = 'stream';

    const taskEvent = {
        kind: 'request',
        requestId: task.id,
        taskId: task.id,
        attempt,
        command: task.command,
        target: task.target,
        data: task.data ?? null,
        studioId: task.studioId,
        placeId: task.placeId,
        remainingMs,
    };

    // 1. Coba kirim langsung ke poller aktif yang cocok (hanging GET)
    let matchingSid: string | null | undefined = null;
    if (task.studioId && activeStudioPollers.has(task.studioId)) {
        matchingSid = task.studioId;
    } else if (task.placeId !== undefined && task.placeId !== null) {
        for (const sid of activeStudioPollers.keys()) {
            if (studioPlaces.get(sid) === task.placeId) {
                matchingSid = sid;
                break;
            }
        }
    } else if (!task.studioId && task.placeId === undefined && activeStudioPollers.size > 0) {
        let bestSid: string | null = null;
        let latestTime = -1;
        for (const sid of activeStudioPollers.keys()) {
            const seen = studioLastSeen.get(sid) ?? 0;
            if (seen > latestTime) {
                latestTime = seen;
                bestSid = sid;
            }
        }
        matchingSid = bestSid || activeStudioPollers.keys().next().value;
    }

    if (matchingSid && activeStudioPollers.has(matchingSid)) {
        const poller = activeStudioPollers.get(matchingSid)!;
        clearTimeout(poller.timer);
        activeStudioPollers.delete(matchingSid);
        studioLastSeen.set(matchingSid, Date.now());

        const events: Array<Record<string, unknown>> = [
            { kind: 'status', mcpConnected, studioCount: Math.max(studioEventQueues.size, 1), serverVersion: SERVER_VERSION },
            taskEvent
        ];

        try {
            poller.res.setHeader('Content-Type', 'text/plain');
            poller.res.setHeader('Cache-Control', 'no-cache, no-store');
            const body = events.map(ev => `data: ${JSON.stringify(ev)}`).join('\n');
            poller.res.send(body);
            return true;
        } catch {
            // Jika pengiriman langsung gagal, masukkan ke antrean pending
        }
    }

    // 2. Jika tidak ada poller yang sedang hanging (jeda antar-request), masukkan ke antrean
    pendingStreamTasks.push(taskEvent);
    if (pendingStreamTasks.length > 50) {
        pendingStreamTasks.shift();
    }
    return false;
}

// ── Logging ───────────────────────────────────────────────────────────────────
let logCounter = 0;
function addLog(io: Server, type: ActivityLog['type'], message: string) {
    const log: ActivityLog = {
        id: `${Date.now()}-${++logCounter}`,
        time: new Date().toLocaleTimeString('id-ID'),
        type,
        message,
    };
    activityLogs.unshift(log);
    if (activityLogs.length > 200) activityLogs.pop();
    if (io.engine && io.engine.clientsCount > 0) {
        io.emit('log', log);
        io.emit('stats', { 
            totalTasks, 
            successCount, 
            errorCount, 
            sessionStart,
            studioConnected: isStudioConnected(),
            studioCount: getConnectedStudioCount(),
            wsStudios: getWsPeerCount(),
            connectedStudios: getConnectedStudios(),
            version: SERVER_VERSION
        });
    }
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
                const localAddress = parts[1];
                if (!localAddress || !localAddress.endsWith(`:${port}`)) continue;
                
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

export function startBridgeServer(port: number, isDaemon: boolean = false) {
    const app = express();
    const httpServer = createServer(app);
    const io = new Server(httpServer, { cors: { origin: '*' } });

    function handleTaskResponse(taskId: string, status: 'success' | 'error', result?: any, error?: string) {
        if (status === 'success') {
            successCount++;
            addLog(io, 'response', `Perintah selesai: ${String(result ?? '').substring(0, 120)}`);
        } else {
            errorCount++;
            addLog(io, 'error', `Gagal: ${error}`);
        }
        removePendingStreamTask(taskId);
        cancelTaskDeadline(taskId);
        resolvePendingTask(taskId, status, result, error);
    }

    // Pasang WebSocket Gateway untuk duplex communication instan (/ws)
    attachWsGateway(httpServer, {
        onTaskResponse: (taskId, status, result, error) => {
            handleTaskResponse(taskId, status, result, error);
        },
        onLog: (type, message) => {
            addLog(io, type, message);
        },
        onStudioStatusChange: () => {
            const connected = isStudioConnected();
            const studioCount = getConnectedStudioCount();
            io.emit('studio-status', { 
                connected, 
                studioCount, 
                connectedStudios: getConnectedStudios(),
                version: SERVER_VERSION 
            });
            broadcastStatus();
            if (!connected && hasPendingTasks()) {
                checkPendingTasksOnStudioDisconnect();
            }
        },
        getServerVersion: () => SERVER_VERSION,
        isMcpConnected: () => mcpConnected,
        onRedispatchTask: (task, failedStudioId) => {
            // Coba re-dispatch ke peer WS lain jika ada yang cocok
            const nextPeer = selectWsPeer({
                placeId: task.placeId,
            });
            if (nextPeer && nextPeer.studioId !== failedStudioId) {
                const ok = sendTaskViaWs(task, nextPeer.studioId);
                if (ok) return true;
            }
            // Fallback: hanya ke long-polling jika ada poller yang sedang hanging aktif (Bug F)
            if (activeStudioPollers.size > 0) {
                const delivered = broadcastTask(task);
                if (delivered) return true;
            }
            return false;
        },
    });

    app.use(express.json({ limit: '50mb' }));
    app.use(express.static(path.join(__dirname, '../public')));

    let dashboardOpened = false;

    // Sediakan initial state ke dashboard browser baru
    io.on('connection', (socket) => {
        socket.emit('init', {
            logs: activityLogs,
            stats: { 
                totalTasks, 
                successCount, 
                errorCount, 
                sessionStart, 
                studioConnected: isStudioConnected(), 
                studioCount: getConnectedStudioCount(),
                wsStudios: getWsPeerCount(),
                port,
                version: SERVER_VERSION,
                connectedStudios: getConnectedStudios(),
            },
        });
    });

    // ── /api/docs (Endpoint pencarian dokumentasi engine untuk web dashboard) ──
    app.get('/api/docs', async (req, res) => {
        try {
            const query = String(req.query.query || '').trim();
            const member = req.query.member ? String(req.query.member).trim() : undefined;
            const category = req.query.category ? String(req.query.category).trim() : 'auto';
            if (!query) {
                return res.status(400).json({ error: "Parameter 'query' wajib diisi." });
            }
            const result = await getRobloxDocs(query, member, category);
            res.json({ success: true, result });
        } catch (err: any) {
            res.status(500).json({ error: err.message });
        }
    });

    // ── /api/stats ─────────────────────────────────────────────────────────────
    app.get('/api/stats', (req, res) => {
        const activeStudios = getConnectedStudioCount();
        const wsStudios = getWsPeerCount();
        res.json({
            totalTasks, successCount, errorCount, sessionStart,
            studioConnected: isStudioConnected(),
            studioCount: activeStudios,
            wsConnectedCount: wsStudios,
            transport: wsStudios > 0 ? 'websocket' : (activeStudioPollers.size > 0 ? 'long-polling' : 'none'),
            mcpConnected,
            port,
            connectedStudios: getConnectedStudios(),
        });
    });

    // ── /api/ping ─────────────────────────────────────────────────────────────
    app.get('/api/ping', (req, res) => {
        const uptime = Math.floor((Date.now() - new Date(sessionStart).getTime()) / 1000);
        const activeStudios = getConnectedStudioCount();
        const wsStudios = getWsPeerCount();
        res.json({ 
            status: 'ok', 
            version: SERVER_VERSION,
            uptimeSeconds: uptime,
            totalTasksProcessed: totalTasks,
            activeStudios: activeStudios,
            wsStudios: wsStudios,
            dualMode: true,
        });
    });

    // ── /api/stream (True Long-Polling endpoint untuk Roblox GetAsync) ─────
    // Roblox HttpService:GetAsync() menahan koneksi sampai server merespons.
    // Jika ada task yang menunggu: kirim seketika (<1ms).
    // Jika tidak ada task: tahan koneksi (hanging GET) hingga task baru tiba
    // atau timeout 15 detik (heartbeat) untuk menjaga koneksi tetap segar.
    app.get('/api/stream', (req, res) => {
        const studioId = (req.query.studioId as string) || `anon-${Date.now()}`;
        const placeIdStr = req.query.placeId as string | undefined;
        const placeId = placeIdStr !== undefined && placeIdStr !== '' ? parseInt(placeIdStr, 10) : undefined;
        if (placeId !== undefined && !isNaN(placeId)) {
            studioPlaces.set(studioId, placeId);
        }
        studioLastSeen.set(studioId, Date.now());

        // Daftarkan studio jika belum ada
        if (!studioEventQueues.has(studioId)) {
            studioEventQueues.set(studioId, []);
            io.emit('studio-status', { 
                connected: true, 
                studioCount: Math.max(studioEventQueues.size, 1), 
                studioId,
                connectedStudios: getConnectedStudios(),
                version: SERVER_VERSION
            });
            addLog(io, 'system', `Studio terdaftar. (ID: ${studioId.substring(0, 8)}…, Place: ${placeId ?? 'Local'}, Total: ${studioEventQueues.size})`);

            if (!isDaemon && !dashboardOpened) {
                dashboardOpened = true;
                const url = `http://localhost:${port}`;
                const startCmd = process.platform === 'win32' ? `start "" "${url}"` : process.platform === 'darwin' ? `open "${url}"` : `xdg-open "${url}"`;
                exec(startCmd, (error) => {
                    if (error) console.error(`[Bridge] Gagal membuka browser:`, error);
                });
            }
        }

        // Jika poller lama untuk studio ini masih aktif, selesaikan dulu
        const oldPoller = activeStudioPollers.get(studioId);
        if (oldPoller) {
            clearTimeout(oldPoller.timer);
            try { oldPoller.res.end(); } catch {}
            activeStudioPollers.delete(studioId);
        }

        // 1. Prioritas Utama: Cek apakah ada task AI yang cocok sedang menunggu poller Studio ini (Bug #3 Routing)
        const matchIdx = pendingStreamTasks.findIndex((t: any) => {
            if (t.studioId && t.studioId !== studioId) return false;
            if (t.placeId !== undefined && t.placeId !== null && placeId !== undefined && t.placeId !== placeId) return false;
            return true;
        });

        if (matchIdx !== -1) {
            const taskEvent = pendingStreamTasks.splice(matchIdx, 1)[0];
            const events: Array<Record<string, unknown>> = [
                { kind: 'status', mcpConnected, studioCount: Math.max(studioEventQueues.size, 1), serverVersion: SERVER_VERSION },
                taskEvent
            ];
            res.setHeader('Content-Type', 'text/plain');
            res.setHeader('Cache-Control', 'no-cache, no-store');
            const body = events.map(ev => `data: ${JSON.stringify(ev)}`).join('\n');
            return res.send(body);
        }

        // 2. Kumpulkan semua events non-task yang belum dikirim ke studio ini
        const queue = studioEventQueues.get(studioId) ?? [];
        if (queue.length > 0) {
            studioEventQueues.set(studioId, []); // kosongkan antrian
            const events: Array<Record<string, unknown>> = [
                { kind: 'status', mcpConnected, studioCount: Math.max(studioEventQueues.size, 1), serverVersion: SERVER_VERSION },
                ...queue.filter(ev => ev.kind !== 'status')
            ];
            res.setHeader('Content-Type', 'text/plain');
            res.setHeader('Cache-Control', 'no-cache, no-store');
            const body = events.map(ev => `data: ${JSON.stringify(ev)}`).join('\n');
            return res.send(body);
        }

        // 3. Jika antrean kosong, TAHAN koneksi (Long-Polling) maksimal 15 detik
        const timer = setTimeout(() => {
            activeStudioPollers.delete(studioId);
            try {
                const events = [
                    { kind: 'heartbeat', timestamp: Date.now() },
                    { kind: 'status', mcpConnected, studioCount: Math.max(studioEventQueues.size, 1), serverVersion: SERVER_VERSION }
                ];
                res.setHeader('Content-Type', 'text/plain');
                res.setHeader('Cache-Control', 'no-cache, no-store');
                const body = events.map(ev => `data: ${JSON.stringify(ev)}`).join('\n');
                res.send(body);
            } catch {}
        }, 15000);

        activeStudioPollers.set(studioId, { res, timer });

        res.on('close', () => {
            const current = activeStudioPollers.get(studioId);
            if (current && current.res === res) {
                clearTimeout(current.timer);
                activeStudioPollers.delete(studioId);
            }
            if (!res.writableEnded) {
                // Client menutup koneksi HTTP sebelum respons dikirim (Studio ditutup/crash)
                studioLastSeen.delete(studioId);
                studioEventQueues.delete(studioId);
                broadcastStatus();
                if (hasPendingTasks()) {
                    checkPendingTasksOnStudioDisconnect();
                }
            }
        });
    });

    // ── /api/events (SSE persisten untuk browser/klien modern) ───────────────
    app.get('/api/events', (req, res) => {
        const studioId = (req.query.studioId as string) || `browser-${Date.now()}`;

        res.setHeader('Content-Type', 'text/event-stream');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('Connection', 'keep-alive');
        res.setHeader('X-Accel-Buffering', 'no');
        res.flushHeaders();

        let silenceTimer: NodeJS.Timeout;
        const heartbeatTimer = setInterval(() => {
            try {
                const payload = JSON.stringify({
                    kind: 'heartbeat',
                    timestamp: Date.now(),
                    mcpConnected,
                    serverVersion: SERVER_VERSION,
                });
                res.write(`data: ${payload}\n\n`);
                silenceTimer.refresh();
            } catch { cleanup(); }
        }, 5000);

        silenceTimer = setTimeout(() => cleanup(), 60000);
        const peer: SsePeer = { studioId, res, connectedAt: Date.now(), heartbeatTimer, silenceTimer };
        ssePeers.set(studioId, peer);

        sendEvent(peer, 'status', { mcpConnected, studioCount: studioEventQueues.size, serverVersion: SERVER_VERSION });

        function cleanup() {
            clearInterval(heartbeatTimer);
            clearTimeout(silenceTimer);
            ssePeers.delete(studioId);
            try { res.end(); } catch { /* ignore */ }
        }

        res.on('close', cleanup);
        res.on('error', cleanup);
    });

    // ── /api/response/:taskId (Studio POSTs hasil eksekusi) (Bug H) ─────────
    app.post('/api/response/:taskId', (req, res) => {
        const taskId = req.params.taskId || req.body?.taskId || req.body?.id;
        const { status, result, error } = req.body;
        handleTaskResponse(taskId, status, result, error);
        res.json({ ok: true });
    });

    // ── /api/response (legacy & fallback) (Bug H) ───────────────────────────
    app.post('/api/response', (req, res) => {
        const taskId = req.body?.taskId || req.body?.id || (req.query?.taskId as string);
        const { status, result, error } = req.body;
        handleTaskResponse(taskId, status, result, error);
        res.json({ ok: true });
    });

    // ── Notifikasi task baru ke Dashboard & Dispatch ke Studio ────────────────
    taskEmitter.on('new_task', (task: Task) => {
        totalTasks++;
        addLog(io, 'task', `Task dikirim ke Studio: '${task.command}'${task.target ? ` → ${task.target}` : ''}`);

        // Prioritas 1: Push via WebSocket instan duplex jika Studio aktif terhubung via WS
        const sentWs = sendTaskViaWs(task);
        if (sentWs) {
            task.deliveredVia = 'ws';
            return; // Berhasil terkirim instan via WebSocket! Tidak perlu enqueue ke long-polling.
        }

        // Prioritas 2 (Fallback): Enqueue ke Long-Polling /api/stream
        broadcastTask(task);
    });

    // ── /api/tasks/enqueue (dari proses MCP eksternal / bridge forwarding) ────
    app.post('/api/tasks/enqueue', async (req, res) => {
        const { command, target, data, placeId, studioId, remainingMs } = req.body;
        
        // Fast-check: pastikan Studio yang cocok aktif polling / websocket (Bug #3)
        if (!isStudioConnected({ placeId, studioId })) {
            for (let i = 0; i < 10; i++) {
                await new Promise(r => setTimeout(r, 50));
                if (isStudioConnected({ placeId, studioId })) break;
            }
            if (!isStudioConnected({ placeId, studioId })) {
                return res.json({
                    status: 'error',
                    error: placeId !== undefined
                        ? `Roblox Studio dengan Place ID ${placeId} tidak terdeteksi aktif.`
                        : 'Roblox Studio tidak terdeteksi aktif. Pastikan Roblox Studio dibuka, place telah dimuat, dan plugin nvstudio-mcp dalam status terhubung.'
                });
            }
        }

        try {
            const result = await addTaskToQueue(command, target, data, { placeId, studioId, remainingMs });
            res.json({ status: 'success', result });
        } catch (err: any) {
            res.json({ status: 'error', error: err?.message || String(err) });
        }
    });

    // ── /api/tasks (legacy long-poll — dipertahankan untuk backward-compat) ───
    // Studio lama yang belum update plugin masih bisa bekerja via polling.
    // Menggunakan claimTask secara atomik untuk mencegah perebutan task (Bug D & E).
    const waitingPollers: express.Response[] = [];
    taskEmitter.on('new_task', (task: Task) => {
        if (task.deliveredVia) return; // Abaikan jika task sudah terkirim via WS atau Stream
        if (waitingPollers.length > 0) {
            const claimed = claimTask(task.id, 'legacy');
            if (!claimed) return;
            const pollRes = waitingPollers.shift();
            const index = taskQueue.findIndex(t => t.id === task.id);
            if (index !== -1) taskQueue.splice(index, 1);
            
            removePendingStreamTask(task.id);
            
            for (const queue of studioEventQueues.values()) {
                const qIndex = queue.findIndex((e: any) => e.requestId === task.id);
                if (qIndex !== -1) queue.splice(qIndex, 1);
            }
            
            addLog(io, 'task', `[Legacy] Mengirim perintah '${task.command}' ke Studio.`);
            pollRes?.json(claimed);
        }
    });

    app.get('/api/tasks', (req, res) => {
        // Cari task pertama yang belum diklaim oleh transport mana pun
        const unclaimedIdx = taskQueue.findIndex(t => !t.deliveredVia);
        if (unclaimedIdx !== -1) {
            const candidate = taskQueue[unclaimedIdx];
            const claimed = claimTask(candidate.id, 'legacy');
            if (claimed) {
                taskQueue.splice(unclaimedIdx, 1);
                removePendingStreamTask(claimed.id);
                addLog(io, 'task', `[Legacy] Mengirim perintah tertunda '${claimed.command}' ke Studio.`);
                return res.json(claimed);
            }
        }
        waitingPollers.push(res);
        res.on('close', () => {
            const index = waitingPollers.indexOf(res);
            if (index !== -1) waitingPollers.splice(index, 1);
        });
    });

    // ── Port-sharing & anti-zombie ────────────────────────────────────────────
    function tryListen(retriesLeft: number = 2) {
        const server = httpServer.listen(port, () => {
            isBridgeHosting = true;
            console.error(`[Bridge] SSE Bridge Server aktif di http://localhost:${port}`);
            resolveBridgeReady(true);
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
                        resolveBridgeReady(false);
                        return;
                    }
                } catch { /* bukan NVStudio bridge */ }

                if (retriesLeft > 0) {
                    console.error(`[Bridge] Port ${port} zombie. Mencoba membunuh...`);
                    killZombieOnPort(port);
                    setTimeout(() => tryListen(retriesLeft - 1), 500);
                } else {
                    console.error(`[Bridge] FATAL: Port ${port} tidak dapat dibuka.`);
                    resolveBridgeReady(false);
                }
            } else {
                console.error(`[Bridge] FATAL: Gagal mendengarkan port ${port}:`, err.message);
                resolveBridgeReady(false);
                process.exit(1);
            }
        });
    }

    tryListen();
}
