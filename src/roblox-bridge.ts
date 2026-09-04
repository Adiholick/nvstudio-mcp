import express, { Request, Response } from "express";
import { taskQueue, resolvePendingTask } from "./task-queue";

export const app = express();
app.use(express.json());

// 2. Endpoint GET /api/tasks: Ambil task pertama dari antrean atau kembalikan { id: null }
app.get("/api/tasks", (_req: Request, res: Response) => {
  if (taskQueue.length > 0) {
    const task = taskQueue.shift();
    res.json(task);
  } else {
    res.json({ id: null });
  }
});

// 3. Endpoint POST /api/response: Terima hasil eksekusi dari Roblox Studio
app.post("/api/response", (req: Request, res: Response) => {
  const { id, status, result, error } = req.body;

  if (!id) {
    res.status(400).json({ error: "Property 'id' wajib disertakan" });
    return;
  }

  const resolved = resolvePendingTask(id, status, result, error);
  if (resolved) {
    res.json({ ok: true });
  } else {
    res.status(404).json({ error: `Task dengan ID '${id}' tidak ditemukan atau sudah kedaluwarsa (timeout).` });
  }
});

// 4. Fungsi untuk menjalankan server HTTP Bridge di port 3000
export function startBridgeServer(port: number = 3000) {
  return app.listen(port, () => {
    console.error(`[nvstudio-mcp] HTTP Bridge Server berhasil berjalan di http://localhost:${port}`);
  });
}
