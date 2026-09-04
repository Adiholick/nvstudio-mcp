#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { startBridgeServer } from "./roblox-bridge";
import { addTaskToQueue } from "./task-queue";
import fs from 'fs';
import path from 'path';

const HISTORY_DIR = path.join(process.cwd(), '.history');
if (!fs.existsSync(HISTORY_DIR)) {
    fs.mkdirSync(HISTORY_DIR, { recursive: true });
}

function backupScript(target: string, code: string) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const safeTargetName = target.replace(/[^a-zA-Z0-9]/g, '_');
    const fileName = `${safeTargetName}_${timestamp}.luau`;
    fs.writeFileSync(path.join(HISTORY_DIR, fileName), code);
}

// 1. Impor dan jalankan server Express lokal di port 3055
startBridgeServer(3055);

// 2. Inisialisasi server MCP
const server = new Server(
  {
    name: "nvstudio-mcp",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// 3 & 4. Daftarkan tool call_mcp_tool dan definisikan schema parameternya
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "call_mcp_tool",
        description: "ALAT MUTLAK UNTUK ROBLOX. DILARANG KERAS menggunakan PowerShell atau skrip bypass (fetch_mcp_source.js). WAJIB memanggil 'get_children' terlebih dahulu sebelum 'get_script_source' untuk memverifikasi tipe instance agar tidak terjadi error teks kosong.",
        inputSchema: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description: "Perintah yang akan dieksekusi (contoh: 'get_children', 'get_script_source', 'update_script_source', 'rollback_script', 'get_logs').",
            },
            target: {
              type: "string",
              description: "Path absolut dari objek target di Roblox Studio (contoh: 'Workspace.Map.Script' atau 'ServerScriptService.MainModule').",
            },
            data: {
              type: "string",
              description: "Data tambahan opsional, misalnya isi source code baru saat menjalankan perintah 'update_script_source'.",
            },
          },
          required: ["command", "target"],
        },
      },
    ],
  };
});



// 5. Handler untuk menangani pemanggilan call_mcp_tool
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name !== "call_mcp_tool") {
    throw new Error(`Tool tidak dikenali: ${request.params.name}`);
  }

  const args = request.params.arguments as {
    command: string;
    target: string;
    data?: string;
  };

  const { command, target, data } = args;

  if (!command || !target) {
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            status: "error",
            error: "Parameter 'command' dan 'target' wajib diisi.",
          }),
        },
      ],
      isError: true,
    };
  }

  // 6. 🔴 GUARDRAIL MUTLAK: Cegah tebakan path buta
  if (command === "get_script_source") {
    const genericTargets = ["Workspace", "ServerScriptService", "ReplicatedStorage", "StarterGui", "StarterPack", "game"];
    
    if (genericTargets.includes(target) || !target.includes(".")) {
      return { 
        content: [{ 
          type: "text", 
          text: "🔴 SERVER GUARDRAIL BLOCKED: DILARANG mengekstrak kode secara buta dari direktori utama atau target yang tidak spesifik. Anda WAJIB memanggil perintah 'get_children' pada '" + target + "' terlebih dahulu untuk memverifikasi nama dan ClassName (Pastikan target adalah LuaSourceContainer)." 
        }],
        isError: true
      };
    }
  }

  // 7. Teruskan ke antrean dan kembalikan hasilnya sebagai string JSON
  try {
    if (command === "update_script_source" && data) {
      backupScript(target, String(data));
    }

    const result = await addTaskToQueue(command, target, data);
    return {
      content: [
        {
          type: "text",
          text: typeof result === "string" ? result : JSON.stringify(result, null, 2),
        },
      ],
    };
  } catch (err: any) {
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            status: "error",
            error: err?.message || String(err),
          }),
        },
      ],
      isError: true,
    };
  }
});

// 8. Jalankan koneksi MCP menggunakan StdioServerTransport
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("[nvstudio-mcp] MCP Server aktif melalui StdioServerTransport.");

  const shutdown = () => {
    console.error("[nvstudio-mcp] Koneksi ditutup oleh IDE. Mematikan server...");
    process.exit(0);
  };

  // Tangani penutupan koneksi
  process.stdin.on('close', shutdown);
  process.stdin.on('end', shutdown);

  // Fallback: Cek apakah parent process (IDE) masih hidup secara berkala
  setInterval(() => {
    try {
      // process.kill dengan signal 0 hanya mengecek keberadaan proses tanpa membunuhnya
      process.kill(process.ppid, 0);
    } catch (e) {
      console.error("[nvstudio-mcp] Parent process (IDE) sudah mati. Mematikan server untuk menghindari zombie connection...");
      process.exit(0);
    }
  }, 3000);
}

main().catch((err) => {
  console.error("[nvstudio-mcp] Gagal menjalankan MCP server:", err);
  process.exit(1);
});
