import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import path from 'path';
import { taskQueue, pendingTasks } from './task-queue';

export function startBridgeServer(port: number = 3055) {
    const app = express();
    const httpServer = createServer(app);
    const io = new Server(httpServer, { cors: { origin: "*" } });

    app.use(express.json());
    app.use(express.static(path.join(process.cwd(), 'public')));

    // Endpoint Studio Polling
    app.get('/api/tasks', (req, res) => {
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

        import('./task-queue').then(({ resolvePendingTask }) => {
            resolvePendingTask(id, status, result, error);
        });
        
        res.json({ message: "Response diterima" });
    });

    httpServer.listen(port, () => {
        console.error(`[Bridge] Dashboard visual & server aktif di http://localhost:${port}`);
    });
}
