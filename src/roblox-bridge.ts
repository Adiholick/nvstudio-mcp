import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import path from 'path';
import { exec } from 'child_process';
import { taskQueue, resolvePendingTask } from './task-queue';

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
    activityLogs.unshift(log); // newest first
    if (activityLogs.length > 200) activityLogs.pop();

    io.emit('log', log);
    io.emit('stats', { totalTasks, successCount, errorCount, sessionStart });
}

export function startBridgeServer(port: number = 3055) {
    const app = express();
    const httpServer = createServer(app);
    const io = new Server(httpServer, { cors: { origin: "*" } });

    // FIX: Menaikkan limit ke 50mb agar file .Source (Lua) yang besar tidak melempar error 413 Payload Too Large
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
            res.json({ id: null });
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

    httpServer.listen(port, () => {
        console.error(`[Bridge] Dashboard visual & server aktif di http://localhost:${port}`);
    });
}
