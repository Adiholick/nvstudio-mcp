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

// 1. Impor dan jalankan server Express lokal di port 3000
startBridgeServer(3000);

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
        description: "Eksekusi perintah ke Roblox Studio melalui HTTP Bridge lokal.",
        inputSchema: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description: "Perintah yang akan dieksekusi (contoh: 'get_children', 'get_script_source', 'update_script_source', 'rollback_script').",
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

// Daftar root service umum yang bukan merupakan script spesifik
const TOP_LEVEL_SERVICES = new Set([
  "game",
  "workspace",
  "replicatedstorage",
  "replicatedfirst",
  "serverscriptservice",
  "serverstorage",
  "startergui",
  "starterpack",
  "starterplayer",
  "starterplayerscripts",
  "startercharacterscripts",
  "lighting",
  "soundservice",
  "players",
]);

function isSpecificScriptTarget(target: string): boolean {
  if (!target || typeof target !== "string") {
    return false;
  }

  const cleanTarget = target.trim();
  const parts = cleanTarget.split(".").filter((p) => p.length > 0);

  // Jika hanya berupa satu kata (misal "Workspace") atau dimulai dengan game lalu hanya 1 level service
  if (parts.length <= 1) {
    return false;
  }

  if (parts[0].toLowerCase() === "game" && parts.length <= 2) {
    return false;
  }

  // Jika target persis nama top-level service
  const lastPart = parts[parts.length - 1].toLowerCase();
  if (TOP_LEVEL_SERVICES.has(lastPart) && parts.length <= 2) {
    return false;
  }

  return true;
}

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

  // 6. Validasi target untuk perintah get_script_source
  if (command === "get_script_source" && !isSpecificScriptTarget(target)) {
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            status: "error",
            error: `Target '${target}' tidak spesifik. Anda WAJIB menggunakan perintah 'get_children' terlebih dahulu untuk menelusuri hierarki objek sampai menemukan file script yang spesifik.`,
          }),
        },
      ],
      isError: true,
    };
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
}

main().catch((err) => {
  console.error("[nvstudio-mcp] Gagal menjalankan MCP server:", err);
  process.exit(1);
});
