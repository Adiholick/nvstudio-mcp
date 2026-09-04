import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import path from 'path';
import { exec } from 'child_process';
import { taskQueue, pendingTasks, resolvePendingTask } from './task-queue';

export function startBridgeServer(port: number = 3055) {
    const app = express();
    const httpServer = createServer(app);
    const io = new Server(httpServer, { cors: { origin: "*" } });

    // FIX: Menaikkan limit ke 50mb agar file .Source (Lua) yang besar tidak melempar error 413 Payload Too Large
    app.use(express.json({ limit: '50mb' }));
    app.use(express.static(path.join(__dirname, '../public')));

    let dashboardOpened = false;

    // Endpoint Studio Polling
    app.get('/api/tasks', (req, res) => {
        if (!dashboardOpened) {
            dashboardOpened = true;
            const startCmd = process.platform === 'win32' ? 'start' : process.platform === 'darwin' ? 'open' : 'xdg-open';
            exec(`${startCmd} http://localhost:${port}`);
            console.error(`[Bridge] Pertama kali terhubung dengan Studio! Membuka Dashboard...`);
        }

        if (taskQueue.length > 0) {
            const task = taskQueue.shift();
            io.emit('log', `[AI Task] Mengirim perintah '${task?.command}' ke Studio.`);
            res.json(task);
        } else {
            res.json({ id: null });
        }
    });

    // Endpoint Studio Response
    app.post('/api/response', (req, res) => {
        const { id, status, result, error } = req.body;
        
        io.emit('log', `[Studio Response] Status: ${status}`);
        if (error) io.emit('log', `[Error] ${error}`);

        // Memanggil fungsi resolve secara sinkron (menghindari promise import circular palsu)
        resolvePendingTask(id, status, result, error);
        
        res.json({ message: "Response diterima" });
    });

    httpServer.listen(port, () => {
        console.error(`[Bridge] Dashboard visual & server aktif di http://localhost:${port}`);
    });
}
