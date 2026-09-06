import { v4 as uuidv4 } from "uuid";

export interface Task {
  id: string;
  command: string;
  target: string;
  data?: string;
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
 * Menambahkan task baru ke antrean dan mengembalikan Promise
 * yang tertahan sampai ada response atau timeout 30 detik.
 */
export function addTaskToQueue(
  command: string,
  target: string,
  data?: string
): Promise<any> {
  const id = uuidv4();
  const task: Task = { id, command, target, data };

  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      if (pendingTasks.has(id)) {
        pendingTasks.delete(id);
        reject(new Error("Timeout: Roblox Studio tidak merespons"));
      }
    }, 30000);

    pendingTasks.set(id, { resolve, reject, timer });
    taskQueue.push(task);
    taskEmitter.emit('new_task');
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

  if (status === "success") {
    pending.resolve(result);
  } else {
    pending.reject(new Error(error || "Terjadi kesalahan pada Roblox Studio"));
  }

  return true;
}
