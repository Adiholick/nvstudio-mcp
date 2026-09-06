#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { startBridgeServer, isBridgeHosting, setMcpConnected } from "./roblox-bridge";
import { addTaskToQueue } from "./task-queue";
import fs from 'fs';
import path from 'path';
import { validateLuauSyntax } from './luau-validator';

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

const isDaemon = process.argv.includes('--daemon') || process.argv.includes('-d');

// 1. Impor dan jalankan server Express lokal di port 3055
startBridgeServer(3055);

// 2. Inisialisasi server MCP
const server = new Server(
  {
    name: "nvstudio-mcp",
    version: "2.1.0",
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
        description: "ALAT MUTLAK UNTUK ROBLOX. Command: patch_script_source, get_children, get_script_source, update_script_source, rollback_script, get_logs, create_instance, search_instance, generate_terrain, insert_asset, delete_instance, get_properties, script_grep, execute_luau, search_asset.",
        inputSchema: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description: "Perintah yang dieksekusi (contoh: 'patch_script_source', 'get_script_source', 'update_script_source').",
            },
            target: {
              type: "string",
              description: "Path absolut dari objek target di Roblox Studio (contoh: 'Workspace.Map.Script').",
            },
            data: {
              type: "string",
              description: "Data tambahan (misal payload JSON untuk patch_script_source, atau source code penuh untuk update_script_source).",
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

  // Pre-commit validation for full source replacement
  if (command === "update_script_source" && data) {
      const validation = validateLuauSyntax(String(data));
      if (!validation.valid) {
          return {
              content: [{
                  type: "text",
                  text: JSON.stringify({
                      status: "error",
                      error: `Syntax error terdeteksi (Pre-commit check Node.js): ${validation.error} pada baris ${validation.line || 'unknown'}`
                  })
              }],
              isError: true
          };
      }
      backupScript(target, String(data));
  }

  // Intercept command yang dieksekusi di server lokal (Node.js) alih-alih di Studio
  if (command === "search_asset" && data) {
    try {
      const queryParams = typeof data === "string" ? JSON.parse(data) : data;
      const keyword = encodeURIComponent(queryParams.keyword || "");
      let assetType = "10"; // Default: Model
      
      if (queryParams.category === "Audio") {
          assetType = "9"; // Audio
      } else if (queryParams.category === "Decal" || queryParams.category === "Image") {
          assetType = "13"; // Decal
      }
      
      const url = `https://catalog.roblox.com/v1/search/items?category=All&keyword=${keyword}&limit=10&itemTypes=Asset&assetTypes=${assetType}`;
      const res = await fetch(url);
      const jsonRes = await res.json();
      
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              status: "success",
              result: jsonRes.data || jsonRes
            }, null, 2)
          }
        ]
      };
    } catch (err: any) {
      return {
        content: [{ type: "text", text: JSON.stringify({ status: "error", error: "Gagal mencari aset: " + err.message }) }],
        isError: true
      };
    }
  }

  // 8. Teruskan ke antrean tugas
  try {
    if (command === "update_script_source" && data) {
      backupScript(target, String(data));
    }

    let result: any;
    if (isBridgeHosting) {
      // Instance ini sendiri yang meng-host bridge server
      result = await addTaskToQueue(command, target, data);
    } else {
      // Bridge server aktif di proses background lain (port 3055)
      let forwardedToBridge = false;
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 35000);
        const bridgeRes = await fetch("http://localhost:3055/api/tasks/enqueue", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ command, target, data }),
          signal: controller.signal
        });
        clearTimeout(timeoutId);

        if (bridgeRes.ok) {
          forwardedToBridge = true;
          const bridgeJson = await bridgeRes.json() as any;
          if (bridgeJson.status === "error") {
            throw new Error(bridgeJson.error);
          }
          result = bridgeJson.result;
        }
      } catch (err: any) {
        if (forwardedToBridge) {
          throw err;
        }
        // Fallback in-process jika HTTP gagal dihubungi
        result = await addTaskToQueue(command, target, data);
      }
    }

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

// 8. Jalankan koneksi MCP menggunakan StdioServerTransport (hanya jika bukan mode Daemon)
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("[nvstudio-mcp] MCP Server aktif melalui StdioServerTransport.");

  // Beritahu SSE plugin bahwa MCP agent sekarang aktif
  setMcpConnected(true);

  let isShuttingDown = false;
  const shutdown = () => {
    if (isShuttingDown) return;
    isShuttingDown = true;
    setMcpConnected(false); // Beritahu SSE plugin bahwa MCP agent sudah menutup koneksi
    console.error("[nvstudio-mcp] Koneksi ditutup oleh IDE. Mematikan server...");
    process.exit(0);
  };

  // Tangani penutupan koneksi stdin (ketika IDE menutup pipe)
  process.stdin.on('close', shutdown);
  process.stdin.on('end', shutdown);
  process.stdin.on('error', shutdown);

  // Fallback khusus Windows: cek apakah stdin masih readable secara berkala
  setInterval(() => {
    if (!process.stdin.readable) {
      console.error("[nvstudio-mcp] stdin tidak readable lagi. IDE kemungkinan sudah ditutup.");
      shutdown();
    }
  }, 3000);
}

if (isDaemon) {
  console.error("[nvstudio-mcp] Berjalan dalam mode DAEMON (Background Bridge Server di port 3055).");
  process.on('SIGINT', () => process.exit(0));
  process.on('SIGTERM', () => process.exit(0));
} else {
  main().catch((err) => {
    console.error("[nvstudio-mcp] Gagal menjalankan MCP server:", err);
    process.exit(1);
  });
}
