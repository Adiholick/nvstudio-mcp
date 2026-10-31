import { WebSocket, WebSocketServer } from 'ws';
import { IncomingMessage, Server as HttpServer } from 'http';
import { Task, canRetryTask } from './task-queue';

export interface WsStudioPeer {
    studioId: string;
    socket: WebSocket;
    placeId?: number;
    pluginsVersion?: number;
    connectedAt: number;
    lastSeen: number;            // Math.max(lastSeenPong, lastSeenActivity)
    lastSeenPong: number;        // Waktu terakhir menerima pong
    lastSeenActivity: number;    // Waktu terakhir aktivitas koneksi / task
    isAlive: boolean;
    unresponsive?: boolean;      // Ditandai true saat deadline task expired
    unresponsiveUntil?: number;  // Timestamp masa cooldown unresponsive (Bug B)
    busyTaskIds: Set<string>;    // Set task ID yang sedang diproses peer ini
}

export interface WsGatewayCallbacks {
    onTaskResponse: (taskId: string, status: 'success' | 'error', result?: any, error?: string) => void;
    onLog: (type: 'task' | 'response' | 'error' | 'system', message: string) => void;
    onStudioStatusChange: () => void;
    getServerVersion: () => string;
    isMcpConnected: () => boolean;
    onRedispatchTask?: (task: Task, failedStudioId: string) => boolean;
}

interface ActiveWsTask {
    task: Task;
    peer: WsStudioPeer;
    timer: NodeJS.Timeout;
    remainingMs: number;
    dispatchedAt: number;
    attempt: number;             // Nomor attempt untuk task ini (Bug A)
}

const wsPeers = new Map<string, WsStudioPeer>();
const activeWsTasks = new Map<string, ActiveWsTask>();
let wssInstance: WebSocketServer | null = null;
let heartbeatInterval: NodeJS.Timeout | null = null;
let callbacks: WsGatewayCallbacks | null = null;

/**
 * Batalkan deadline timer server-side untuk taskId tertentu (misal saat response sudah diterima).
 * Validasi attempt dan sender peer untuk mencegah late/zombie response dari attempt lama (Bug A).
 * TIDAK mereset unresponsive secara serampangan (Bug B).
 */
export function cancelTaskDeadline(taskId: string, attempt?: number, studioId?: string): boolean {
    const active = activeWsTasks.get(taskId);
    if (!active) return false;

    // Bug A: Abaikan pembatalan jika berasal dari attempt lama atau peer lama yang berbeda
    if (attempt !== undefined && active.attempt !== attempt) {
        return false;
    }
    if (studioId && active.peer.studioId !== studioId) {
        return false;
    }

    clearTimeout(active.timer);
    activeWsTasks.delete(taskId);
    active.peer.busyTaskIds.delete(taskId);
    // Bug B: Jangan reset active.peer.unresponsive di sini! Unresponsive direset saat fresh pong/reconnect.
    active.peer.lastSeenActivity = Date.now();
    active.peer.lastSeen = Math.max(active.peer.lastSeenPong, active.peer.lastSeenActivity);
    return true;
}

/**
 * Tangani expiry deadline task di sisi server (Bug #1).
 */
function handleTaskDeadlineExpired(taskId: string): void {
    const active = activeWsTasks.get(taskId);
    if (!active) return;

    activeWsTasks.delete(taskId);
    const { task, peer, remainingMs } = active;
    peer.busyTaskIds.delete(taskId);

    // 1. Tandai peer tidak responsif dengan masa cooldown 30 detik (Bug B)
    peer.isAlive = false;
    peer.unresponsive = true;
    peer.unresponsiveUntil = Date.now() + 30000;

    if (callbacks) {
        callbacks.onLog(
            'error',
            `Studio WS peer ${peer.studioId.substring(0, 8)}… deadline (${remainingMs}ms) expired untuk task '${task.command}'! Peer ditandai tidak responsif.`
        );
    }

    // 2. Coba re-dispatch ke long-poll atau peer lain jika kuota retry masih ada (Bug K)
    let redispatched = false;
    if (canRetryTask(task) && callbacks?.onRedispatchTask) {
        task.retryCount = (task.retryCount || 0) + 1;
        redispatched = callbacks.onRedispatchTask(task, peer.studioId);
    }

    if (!redispatched) {
        // Jika tidak bisa di-redispatch, reject task langsung untuk menutup hang 30 detik (Bug F)
        if (callbacks) {
            callbacks.onTaskResponse(
                task.id,
                'error',
                undefined,
                `Timeout: Studio tidak merespons dalam deadline server (${remainingMs}ms). Peer tidak responsif dan tidak ada alternatif peer/poller lain.`
            );
        }
    }
}

/**
 * Inisialisasi WebSocket Gateway pada HTTP server yang ada (port sharing via upgrade /ws).
 */
export function attachWsGateway(httpServer: HttpServer, cb: WsGatewayCallbacks): WebSocketServer {
    callbacks = cb;

    const wss = new WebSocketServer({ noServer: true });
    wssInstance = wss;

    // Handle HTTP Upgrade event secara selektif hanya untuk path '/ws'
    httpServer.on('upgrade', (req: IncomingMessage, socket, head) => {
        try {
            const urlObj = new URL(req.url ?? '/', 'http://localhost');
            if (urlObj.pathname === '/ws') {
                wss.handleUpgrade(req, socket, head, (ws) => {
                    wss.emit('connection', ws, req);
                });
            }
        } catch {
            // Abaikan request URL yang malformed
        }
    });

    wss.on('connection', (socket: WebSocket, req: IncomingMessage) => {
        let boundStudioId: string | null = null;

        socket.on('message', (raw) => {
            let messageStr: string;
            if (typeof raw === 'string') {
                messageStr = raw;
            } else if (Buffer.isBuffer(raw)) {
                messageStr = raw.toString('utf8');
            } else if (raw instanceof ArrayBuffer) {
                messageStr = Buffer.from(raw).toString('utf8');
            } else if (Array.isArray(raw)) {
                messageStr = Buffer.concat(raw).toString('utf8');
            } else {
                return;
            }

            try {
                const msg = JSON.parse(messageStr);
                if (!msg || typeof msg !== 'object') return;

                const kind = msg.kind;
                const now = Date.now();

                // ── Register Envelope ──────────────────────────────────────────
                if (kind === 'register') {
                    const studioId = typeof msg.studioId === 'string' && msg.studioId ? msg.studioId : `ws-anon-${Date.now()}`;
                    boundStudioId = studioId;

                    // Bersihkan koneksi lama untuk studioId yang sama jika ada (Bug I)
                    const existing = wsPeers.get(studioId);
                    if (existing && existing.socket !== socket) {
                        // Invalidate in-flight tasks of old peer before closing it! (Bug I)
                        for (const [taskId, active] of Array.from(activeWsTasks.entries())) {
                            if (active.peer === existing || active.peer.studioId === studioId) {
                                clearTimeout(active.timer);
                                activeWsTasks.delete(taskId);
                                existing.busyTaskIds.delete(taskId);

                                let redispatched = false;
                                if (callbacks?.onRedispatchTask && canRetryTask(active.task)) {
                                    active.task.retryCount = (active.task.retryCount || 0) + 1;
                                    redispatched = callbacks.onRedispatchTask(active.task, studioId);
                                }

                                if (!redispatched && callbacks) {
                                    callbacks.onTaskResponse(
                                        taskId,
                                        'error',
                                        undefined,
                                        `Roblox Studio terkoneksi ulang saat mengeksekusi tugas '${active.task.command}'.`
                                    );
                                }
                            }
                        }
                        existing.busyTaskIds.clear();
                        try {
                            existing.socket.close(1000, 'Replaced by new connection');
                        } catch {}
                    }

                    const peer: WsStudioPeer = {
                        studioId,
                        socket,
                        placeId: msg.placeId !== undefined && msg.placeId !== null ? Number(msg.placeId) : undefined,
                        pluginsVersion: msg.pluginsVersion ?? 1,
                        connectedAt: now,
                        lastSeen: now,
                        lastSeenPong: now,
                        lastSeenActivity: now,
                        isAlive: true,
                        unresponsive: false,
                        busyTaskIds: new Set<string>(),
                    };

                    wsPeers.set(studioId, peer);

                    // Kirim initial status ke Studio
                    const statusPayload = {
                        kind: 'status',
                        mcpConnected: callbacks ? callbacks.isMcpConnected() : false,
                        studioCount: wsPeers.size,
                        serverVersion: callbacks ? callbacks.getServerVersion() : '2.2.2',
                    };
                    try {
                        socket.send(JSON.stringify(statusPayload));
                    } catch {}

                    if (callbacks) {
                        callbacks.onLog('system', `Studio terhubung via WebSocket ⚡ (ID: ${studioId.substring(0, 8)}…, Place: ${msg.placeId ?? 'Local'})`);
                        callbacks.onStudioStatusChange();
                    }
                    return;
                }

                // ── Pong Envelope (Bug #2: Update lastSeenPong) ────────────────
                if (kind === 'pong') {
                    if (boundStudioId && wsPeers.has(boundStudioId)) {
                        const peer = wsPeers.get(boundStudioId)!;
                        peer.isAlive = true;
                        peer.lastSeenPong = now;
                        peer.lastSeen = Math.max(peer.lastSeenPong, peer.lastSeenActivity);
                        // Pulihkan unresponsive jika cooldown sudah berakhir (Bug B)
                        if (peer.unresponsive && (!peer.unresponsiveUntil || now >= peer.unresponsiveUntil)) {
                            peer.unresponsive = false;
                            delete peer.unresponsiveUntil;
                        }
                    }
                    return;
                }

                // ── Response Envelope (Bug #2: Update lastSeenActivity) ────────
                if (kind === 'response') {
                    const taskId = msg.taskId || msg.id;
                    const attempt = typeof msg.attempt === 'number' ? msg.attempt : undefined;
                    const status = msg.status === 'success' ? 'success' : 'error';
                    const result = msg.result;
                    const error = msg.error;

                    if (taskId) {
                        // Bug A: Verifikasi attempt dan studioId untuk mencegah zombie response
                        const active = activeWsTasks.get(taskId);
                        if (active) {
                            if (attempt !== undefined && active.attempt !== attempt) {
                                // Response untuk attempt lama, abaikan!
                                return;
                            }
                            if (boundStudioId && active.peer.studioId !== boundStudioId) {
                                // Response dari peer lama yang berbeda, abaikan!
                                return;
                            }
                        }

                        if (boundStudioId && wsPeers.has(boundStudioId)) {
                            const peer = wsPeers.get(boundStudioId)!;
                            peer.isAlive = true;
                            peer.lastSeenActivity = now;
                            peer.lastSeen = Math.max(peer.lastSeenPong, peer.lastSeenActivity);
                            peer.busyTaskIds.delete(taskId);
                        }

                        const cancelled = cancelTaskDeadline(taskId, attempt, boundStudioId ?? undefined);
                        if (cancelled || !active) {
                            if (callbacks) {
                                callbacks.onTaskResponse(taskId, status, result, error);
                            }
                        }
                    }
                    return;
                }
            } catch (err) {
                console.error('[WsGateway] Gagal memproses pesan WebSocket:', err);
            }
        });

        socket.on('pong', () => {
            if (boundStudioId && wsPeers.has(boundStudioId)) {
                const peer = wsPeers.get(boundStudioId)!;
                const now = Date.now();
                peer.isAlive = true;
                peer.lastSeenPong = now;
                peer.lastSeen = Math.max(peer.lastSeenPong, peer.lastSeenActivity);
                if (peer.unresponsive && (!peer.unresponsiveUntil || now >= peer.unresponsiveUntil)) {
                    peer.unresponsive = false;
                    delete peer.unresponsiveUntil;
                }
            }
        });

        const cleanup = () => {
            if (boundStudioId && wsPeers.has(boundStudioId)) {
                const existing = wsPeers.get(boundStudioId);
                if (existing && (existing.socket === socket || existing.socket.readyState !== WebSocket.OPEN)) {
                    wsPeers.delete(boundStudioId);
                    existing.busyTaskIds.clear();

                    if (callbacks) {
                        callbacks.onLog('system', `Studio WebSocket terputus (ID: ${boundStudioId.substring(0, 8)}…)`);
                        callbacks.onStudioStatusChange();
                    }
                }
            }

            // Tangani task aktif pada peer/socket yang putus (Bug I, K, N)
            for (const [taskId, active] of Array.from(activeWsTasks.entries())) {
                if (active.peer.socket === socket || (boundStudioId && active.peer.studioId === boundStudioId)) {
                    clearTimeout(active.timer);
                    activeWsTasks.delete(taskId);
                    active.peer.busyTaskIds.delete(taskId);

                    let redispatched = false;
                    if (callbacks?.onRedispatchTask && canRetryTask(active.task)) {
                        active.task.retryCount = (active.task.retryCount || 0) + 1;
                        redispatched = callbacks.onRedispatchTask(active.task, boundStudioId || active.peer.studioId);
                    }

                    if (!redispatched && callbacks) {
                        callbacks.onTaskResponse(
                            taskId,
                            'error',
                            undefined,
                            `Roblox Studio terputus saat mengeksekusi tugas '${active.task.command}'.`
                        );
                    }
                }
            }
        };

        socket.on('close', cleanup);
        socket.on('error', cleanup);
    });

    // ── Heartbeat Interval (5 detik) (Bug C Fix) ───────────────────────────────
    if (heartbeatInterval) clearInterval(heartbeatInterval);
    heartbeatInterval = setInterval(() => {
        const now = Date.now();
        for (const [studioId, peer] of Array.from(wsPeers.entries())) {
            if (peer.socket.readyState !== WebSocket.OPEN) {
                try { peer.socket.terminate(); } catch {}
                peer.busyTaskIds.clear();
                wsPeers.delete(studioId);
                if (callbacks) callbacks.onStudioStatusChange();
                continue;
            }

            const isBusy = peer.busyTaskIds.size > 0;

            // BUG C: Jika peer sedang sibuk mengeksekusi task, periksa apakah hang total (>35s tanpa respons/pong)
            if (isBusy) {
                const timeSinceActivity = now - Math.max(peer.lastSeenPong, peer.lastSeenActivity);
                if (timeSinceActivity > 35000) {
                    try { peer.socket.terminate(); } catch {}
                    peer.busyTaskIds.clear();
                    wsPeers.delete(studioId);

                    for (const [taskId, active] of Array.from(activeWsTasks.entries())) {
                        if (active.peer === peer) {
                            clearTimeout(active.timer);
                            activeWsTasks.delete(taskId);
                            let redispatched = false;
                            if (callbacks?.onRedispatchTask && canRetryTask(active.task)) {
                                active.task.retryCount = (active.task.retryCount || 0) + 1;
                                redispatched = callbacks.onRedispatchTask(active.task, studioId);
                            }
                            if (!redispatched && callbacks) {
                                callbacks.onTaskResponse(
                                    taskId,
                                    'error',
                                    undefined,
                                    `Studio WebSocket hung (>35s tanpa respons) saat menjalankan task '${active.task.command}'.`
                                );
                            }
                        }
                    }

                    if (callbacks) {
                        callbacks.onLog('error', `Studio WebSocket ${studioId.substring(0, 8)}… hung (>35s), koneksi diputus.`);
                        callbacks.onStudioStatusChange();
                    }
                    continue;
                }

                peer.isAlive = true;
                try {
                    peer.socket.ping();
                } catch {
                    try { peer.socket.terminate(); } catch {}
                    peer.busyTaskIds.clear();
                    wsPeers.delete(studioId);
                    if (callbacks) callbacks.onStudioStatusChange();
                }
                continue;
            }

            // Peer sedang IDLE: periksa keterlambatan pong secara terpisah
            const pongDelay = now - peer.lastSeenPong;
            if (!peer.isAlive && pongDelay > 15000) {
                // Tidak menjawab ping dalam toleransi waktu saat idle
                try { peer.socket.terminate(); } catch {}
                peer.busyTaskIds.clear();
                wsPeers.delete(studioId);
                if (callbacks) {
                    callbacks.onLog('system', `Studio WebSocket timeout (ID: ${studioId.substring(0, 8)}…)`);
                    callbacks.onStudioStatusChange();
                }
                continue;
            }

            // Tandai isAlive = false dan kirim ping
            peer.isAlive = false;
            try {
                peer.socket.ping();
                peer.socket.send(JSON.stringify({ kind: 'ping', ts: now }));
            } catch {
                try { peer.socket.terminate(); } catch {}
                peer.busyTaskIds.clear();
                wsPeers.delete(studioId);
                if (callbacks) callbacks.onStudioStatusChange();
            }
        }
    }, 5000);

    return wss;
}

/**
 * Cek apakah ada setidaknya satu peer Studio aktif terhubung via WebSocket.
 */
export function hasActiveWsPeer(filter?: { studioId?: string; placeId?: number }): boolean {
    for (const peer of wsPeers.values()) {
        if (peer.socket.readyState === WebSocket.OPEN && !peer.unresponsive) {
            if (filter?.studioId && peer.studioId !== filter.studioId) continue;
            if (filter?.placeId !== undefined && filter?.placeId !== null && peer.placeId !== filter.placeId) continue;
            return true;
        }
    }
    return false;
}

/**
 * Jumlah studio aktif terhubung via WebSocket.
 */
export function getWsPeerCount(): number {
    let count = 0;
    for (const peer of wsPeers.values()) {
        if (peer.socket.readyState === WebSocket.OPEN) {
            count++;
        }
    }
    return count;
}

/**
 * Dapatkan daftar studioId aktif terhubung via WebSocket.
 */
export function getWsStudioIds(): string[] {
    const list: string[] = [];
    for (const [sid, peer] of wsPeers.entries()) {
        if (peer.socket.readyState === WebSocket.OPEN) {
            list.push(sid);
        }
    }
    return list;
}

/**
 * Dapatkan detail seluruh WS peer untuk reporting/discovery.
 */
export function getWsPeersDetails() {
    return Array.from(wsPeers.values()).map(p => ({
        studioId: p.studioId,
        placeId: p.placeId,
        connectedAt: p.connectedAt,
        lastSeen: p.lastSeen,
        lastSeenPong: p.lastSeenPong,
        lastSeenActivity: p.lastSeenActivity,
        isAlive: p.isAlive,
        isBusy: p.busyTaskIds.size > 0,
        unresponsive: !!p.unresponsive,
    }));
}

/**
 * Pilih peer WebSocket berdasarkan kriteria studioId / placeId (Bug #3 Routing & Bug L Load Balancing).
 */
export function selectWsPeer(criteria?: { studioId?: string | null; placeId?: number | null }): WsStudioPeer | null {
    if (wsPeers.size === 0) return null;
    const now = Date.now();

    const isPeerEligible = (p: WsStudioPeer): boolean => {
        if (p.socket.readyState !== WebSocket.OPEN) return false;
        if (p.unresponsive) {
            // Bug B: Pulihkan jika masa cooldown sudah berakhir
            if (p.unresponsiveUntil && now >= p.unresponsiveUntil) {
                p.unresponsive = false;
                delete p.unresponsiveUntil;
                return true;
            }
            return false;
        }
        return true;
    };

    // 1. Jika studioId spesifik diminta
    if (criteria?.studioId) {
        const peer = wsPeers.get(criteria.studioId);
        if (peer && isPeerEligible(peer)) {
            return peer;
        }
        return null;
    }

    // 2. Jika placeId spesifik diminta
    let candidates: WsStudioPeer[] = [];
    if (criteria?.placeId !== undefined && criteria?.placeId !== null) {
        candidates = Array.from(wsPeers.values()).filter(
            p => isPeerEligible(p) && p.placeId === criteria.placeId
        );
    } else {
        candidates = Array.from(wsPeers.values()).filter(isPeerEligible);
    }

    if (candidates.length === 0) return null;

    // Bug L: Prioritaskan peer yang idle (busyTaskIds.size === 0) dan least busy
    candidates.sort((a, b) => {
        if (a.busyTaskIds.size !== b.busyTaskIds.size) {
            return a.busyTaskIds.size - b.busyTaskIds.size;
        }
        return b.lastSeen - a.lastSeen;
    });

    return candidates[0];
}

/**
 * Mengirim task ke Studio via WebSocket dengan server-side deadline enforcement (Bug #1),
 * routing berbasis target/place (Bug #3), attempt stamping (Bug A), dan load checking (Bug L & M).
 */
export function sendTaskViaWs(task: Task, targetStudioId?: string | null): boolean {
    if (wsPeers.size === 0) return false;

    const targetPeer = selectWsPeer({
        studioId: targetStudioId || task.studioId,
        placeId: task.placeId,
    });

    if (!targetPeer || targetPeer.socket.readyState !== WebSocket.OPEN) return false;

    // Bug J: Hitung sisa waktu aktual (remainingMs) dari budget total dikurangi waktu tunggu
    const totalBudget = task.remainingMs ?? 30000;
    const elapsed = task.createdAt ? (Date.now() - task.createdAt) : 0;
    const remainingMs = Math.max(1000, totalBudget - elapsed);

    // Bug A & E: Stamp attempt counter dan tandai channel pengiriman
    const attempt = (task.attempt || 0) + 1;
    task.attempt = attempt;
    task.dispatchedAt = Date.now();
    task.deliveredVia = 'ws';

    const envelope = {
        kind: 'request',
        requestId: task.id,
        taskId: task.id,
        attempt,
        command: task.command,
        target: task.target,
        data: task.data ?? null,
        remainingMs,
    };

    // Bug M: Pastikan socket masih OPEN dan tangani error saat pengiriman
    try {
        if (targetPeer.socket.readyState !== WebSocket.OPEN) return false;
        targetPeer.socket.send(JSON.stringify(envelope));
    } catch {
        return false;
    }

    // Enforce deadline server-side (Bug #1)
    targetPeer.busyTaskIds.add(task.id);
    targetPeer.lastSeenActivity = Date.now();
    targetPeer.lastSeen = Math.max(targetPeer.lastSeenPong, targetPeer.lastSeenActivity);

    const taskTimer = setTimeout(() => {
        handleTaskDeadlineExpired(task.id);
    }, remainingMs);

    activeWsTasks.set(task.id, {
        task,
        peer: targetPeer,
        timer: taskTimer,
        remainingMs,
        dispatchedAt: task.dispatchedAt,
        attempt,
    });

    return true;
}

/**
 * Broadcast event ke semua Studio yang terhubung via WebSocket.
 */
export function broadcastWsEvent(kind: string, payload: Record<string, unknown>): void {
    if (wsPeers.size === 0) return;
    const body = JSON.stringify({ kind, ...payload });
    for (const peer of wsPeers.values()) {
        if (peer.socket.readyState === WebSocket.OPEN) {
            try {
                peer.socket.send(body);
            } catch {}
        }
    }
}

/**
 * Menutup semua koneksi WebSocket dan membersihkan state (Bug N).
 */
export function closeAllWsPeers(): void {
    if (heartbeatInterval) {
        clearInterval(heartbeatInterval);
        heartbeatInterval = null;
    }
    for (const active of activeWsTasks.values()) {
        clearTimeout(active.timer);
    }
    activeWsTasks.clear();

    for (const peer of wsPeers.values()) {
        peer.busyTaskIds.clear();
        peer.isAlive = false;
        try {
            peer.socket.close(1000, 'Server stopping');
        } catch {}
    }
    wsPeers.clear();
}
