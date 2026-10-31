import { v4 as uuidv4 } from "uuid";

export interface Task {
  id: string;
  command: string;
  target: string;
  data?: string;
  studioId?: string;
  placeId?: number;
  remainingMs?: number;
  retryCount?: number;
  deliveredVia?: 'ws' | 'stream' | 'legacy';
  dispatchedAt?: number;
  createdAt?: number;
  attempt?: number;
}

export const DEFAULT_TASK_TIMEOUT = 30000;
export const MAX_TASK_RETRIES = 1;

export function canRetryTask(task: Task): boolean {
  return (task.retryCount || 0) < MAX_TASK_RETRIES;
}

export interface TaskOptions {
  studioId?: string;
  placeId?: number;
  remainingMs?: number;
}

export interface PendingTask {
  resolve: (value: any) => void;
  reject: (reason?: any) => void;
  timer: NodeJS.Timeout;
}

import { EventEmitter } from "events";

// 1. Array untuk menampung antrean tugas (task queue)
export const taskQueue: Task[] = [];
export const taskEmitter = new EventEmitter();

// 2. Map untuk menyimpan Promise dari tugas yang sedang menunggu (pending tasks)
export const pendingTasks = new Map<string, PendingTask>();

/**
 * Klaim task secara atomik oleh salah satu channel transport ('ws' | 'stream' | 'legacy').
 * Mengembalikan Task jika berhasil, atau null jika task sudah diklaim sebelumnya.
 */
export function claimTask(taskId: string, channel: 'ws' | 'stream' | 'legacy'): Task | null {
  const task = taskQueue.find(t => t.id === taskId);
  if (!task) return null;
  if (task.deliveredVia) return null;
  task.deliveredVia = channel;
  return task;
}

/**
 * Menambahkan task baru ke antrean dan mengembalikan Promise
 * yang tertahan sampai ada response atau timeout.
 */
export function addTaskToQueue(
  command: string,
  target: string,
  data?: string,
  options?: TaskOptions
): Promise<any> {
  const id = uuidv4();
  const timeoutMs = options?.remainingMs ?? DEFAULT_TASK_TIMEOUT;
  const task: Task = {
    id,
    command,
    target,
    data,
    studioId: options?.studioId,
    placeId: options?.placeId,
    remainingMs: timeoutMs,
    createdAt: Date.now(),
  };

  return new Promise((resolve, reject) => {
    // Beri buffer 2 detik di atas deadline task agar server-side transport timeout
    // atau redispatch dapat menangani error secara terstruktur terlebih dahulu.
    const timer = setTimeout(() => {
      if (pendingTasks.has(id)) {
        pendingTasks.delete(id);
        reject(new Error(`Timeout: Roblox Studio tidak merespons dalam batas waktu ${Math.round(timeoutMs / 1000)} detik.`));
      }
    }, timeoutMs + 2000);

    pendingTasks.set(id, { resolve, reject, timer });
    taskQueue.push(task);
    if (taskQueue.length > 50) {
      const droppedTask = taskQueue.shift();
      if (droppedTask) {
        const pending = pendingTasks.get(droppedTask.id);
        if (pending) {
          clearTimeout(pending.timer);
          pending.reject(new Error("Timeout: Antrean Studio penuh, task dibuang."));
          pendingTasks.delete(droppedTask.id);
        }
      }
    }
    taskEmitter.emit('new_task', task);
  });
}

/**
 * Menyelesaikan pending task berdasarkan id dan status respons dari Roblox Studio.
 */
export function resolvePendingTask(
  id: string,
  status: "success" | "error",
  result?: any,
  error?: string
): boolean {
  const pending = pendingTasks.get(id);
  if (!pending) {
    return false;
  }

  clearTimeout(pending.timer);
  pendingTasks.delete(id);
  
  const index = taskQueue.findIndex(t => t.id === id);
  if (index !== -1) taskQueue.splice(index, 1);

  if (status === "success") {
    pending.resolve(result);
  } else {
    pending.reject(new Error(error || "Terjadi kesalahan pada Roblox Studio"));
  }

  return true;
}

/**
 * Menolak semua pending tasks dengan pesan error tertentu (misal ketika Studio terputus).
 */
export function rejectAllPendingTasks(errorMsg: string): void {
  for (const [id, pending] of pendingTasks.entries()) {
    clearTimeout(pending.timer);
    pending.reject(new Error(errorMsg));
  }
  pendingTasks.clear();
  taskQueue.length = 0;
}

/**
 * Cek apakah ada task yang masih menunggu respons dari Studio.
 */
export function hasPendingTasks(): boolean {
  return pendingTasks.size > 0;
}
