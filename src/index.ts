#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import {
  startBridgeServer,
  isBridgeHosting,
  setMcpConnected,
  isStudioConnected,
  bridgeReadyPromise,
  getConnectedStudios,
} from "./roblox-bridge";
import { addTaskToQueue } from "./task-queue";
import fs from 'fs';
import path from 'path';
import { validateLuauSyntax } from './luau-validator';
import { getRobloxDocs } from './roblox-docs';

const HISTORY_DIR = path.join(__dirname, '..', '.history');
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
startBridgeServer(3055, isDaemon);

// 2. Inisialisasi server MCP
const pkg = require('../package.json');
const server = new Server(
  {
    name: "nvstudio-mcp",
    version: pkg.version,
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// 3. Definisi Semantic Tools MCP untuk Roblox Studio
const TOOLS: Tool[] = [
  {
    name: "execute_luau",
    description: "Eksekusi kode Luau sembarang secara langsung di Roblox Studio dan kembalikan output/hasilnya (mendukung return table, primitif, dan console log).",
    inputSchema: {
      type: "object",
      properties: {
        code: {
          type: "string",
          description: "Kode Luau yang akan dieksekusi di Roblox Studio.",
        },
        target: {
          type: "string",
          description: "Path opsional objek target (contoh: 'Workspace.Map').",
        },
        placeId: {
          type: "number",
          description: "Place ID Roblox tujuan jika membuka beberapa Studio (multi-Studio routing).",
        },
        studioId: {
          type: "string",
          description: "Session ID Studio spesifik jika diketahui.",
        },
      },
      required: ["code"],
    },
  },
  {
    name: "get_children",
    description: "Ambil daftar child langsung (nama dan ClassName) dari suatu Instance di Roblox Studio.",
    inputSchema: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Path absolut dari objek target di Roblox (contoh: 'Workspace', 'ReplicatedStorage.Modules').",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["target"],
    },
  },
  {
    name: "get_full_tree",
    description: "Ambil struktur hierarki pohon instance secara rekursif hingga kedalaman (depth) tertentu.",
    inputSchema: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Path root objek untuk hierarki (contoh: 'Workspace', 'StarterGui').",
        },
        max_depth: {
          type: "number",
          description: "Kedalaman maksimal penelusuran hierarki (default: 2).",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["target"],
    },
  },
  {
    name: "get_script_source",
    description: "Baca seluruh isi source code Luau dari sebuah Script, LocalScript, atau ModuleScript.",
    inputSchema: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Path absolut ke Script target (contoh: 'ServerScriptService.GameManager').",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["target"],
    },
  },
  {
    name: "update_script_source",
    description: "Ganti seluruh isi source code script dengan kode baru. Dilengkapi validasi sintaks otomatis (AST check) dan riwayat rollback.",
    inputSchema: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Path absolut ke Script target (contoh: 'ServerScriptService.MainHandler').",
        },
        code: {
          type: "string",
          description: "Source code Luau baru yang akan ditulis.",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["target", "code"],
    },
  },
  {
    name: "patch_script_source",
    description: "Ganti bagian tertentu dari source code script (search and replace chunk) tanpa menimpa seluruh file.",
    inputSchema: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Path absolut ke Script target.",
        },
        target_content: {
          type: "string",
          description: "Potongan kode lama yang ingin diganti (persis karakter per karakter).",
        },
        replacement_content: {
          type: "string",
          description: "Potongan kode baru sebagai pengganti.",
        },
        allow_multiple: {
          type: "boolean",
          description: "Jika true, ganti semua kemunculan alih-alih hanya kemunculan pertama (default: false).",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["target", "target_content", "replacement_content"],
    },
  },
  {
    name: "rollback_script",
    description: "Kembalikan source code script ke versi sebelumnya dari riwayat backup sesi saat ini.",
    inputSchema: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Path absolut ke Script yang ingin di-rollback.",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["target"],
    },
  },
  {
    name: "get_properties",
    description: "Ambil properti umum, attributes, dan tags dari suatu Instance di Roblox Studio.",
    inputSchema: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Path absolut ke Instance (contoh: 'Workspace.Baseplate', 'Lighting').",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["target"],
    },
  },
  {
    name: "set_properties",
    description: "Ubah properti dari suatu Instance di Roblox Studio menggunakan key-value JSON.",
    inputSchema: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Path absolut ke Instance target (contoh: 'Workspace.Part').",
        },
        properties: {
          type: "object",
          description: "Objek key-value properti (contoh: { \"Anchored\": true, \"Size\": [10, 2, 10], \"Color\": [255, 0, 0] }).",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["target", "properties"],
    },
  },
  {
    name: "create_instance",
    description: "Buat Instance baru di Roblox Studio di bawah parent target dengan ClassName dan properti awal opsional.",
    inputSchema: {
      type: "object",
      properties: {
        class_name: {
          type: "string",
          description: "ClassName Roblox (contoh: 'Part', 'Folder', 'RemoteEvent', 'Script').",
        },
        target: {
          type: "string",
          description: "Path parent tempat Instance akan dibuat (contoh: 'Workspace', 'ReplicatedStorage').",
        },
        properties: {
          type: "object",
          description: "Properti awal opsional yang disetel saat instance dibuat.",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["class_name", "target"],
    },
  },
  {
    name: "delete_instance",
    description: "Hapus (Destroy) Instance dari game. Service utama dilindungi guardrail dan objek dengan >10 descendant memerlukan force: true.",
    inputSchema: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Path absolut ke Instance yang ingin dihapus.",
        },
        force: {
          type: "boolean",
          description: "Wajib disetel ke true jika instance memiliki lebih dari 10 descendants.",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["target"],
    },
  },
  {
    name: "search_instance",
    description: "Cari Instance berdasarkan nama atau substring di dalam hierarki Roblox Studio.",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "Nama atau substring instance yang dicari.",
        },
        target: {
          type: "string",
          description: "Scope root opsional tempat mencari (default: seluruh service utama).",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "generate_terrain",
    description: "Generate blok voxel terrain di Workspace.Terrain dengan material, posisi, dan ukuran tertentu.",
    inputSchema: {
      type: "object",
      properties: {
        material: {
          type: "string",
          description: "Nama material terrain (contoh: 'Grass', 'Water', 'Sand', 'Rock', 'Snow').",
        },
        position: {
          type: "array",
          items: { type: "number" },
          description: "Posisi voxel region [X, Y, Z].",
        },
        size: {
          type: "array",
          items: { type: "number" },
          description: "Ukuran dimensi voxel region [X, Y, Z].",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["material", "position", "size"],
    },
  },
  {
    name: "preview_asset",
    description: "Pratinjau hierarki dan pemindaian keamanan aset Creator Store secara terisolasi sebelum dimasukkan ke dalam game. Mendeteksi skrip backdoor, require eksternal numerik, obfuscation, webhook discord, dan virus script tanpa risiko mengeksekusi kode berbahaya.",
    inputSchema: {
      type: "object",
      properties: {
        asset_id: {
          type: "string",
          description: "Roblox Asset ID angka (atau rbxassetid://) dari Creator Store.",
        },
        deep_scan: {
          type: "boolean",
          description: "Jika true (default), memindai dan menganalisis source code seluruh skrip di dalam model.",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["asset_id"],
    },
  },
  {
    name: "scan_security",
    description: "Audit keamanan instance atau model yang sudah ada di dalam game (Workspace, ServerScriptService, dll.) untuk mendeteksi skrip backdoor, virus, webhook discord, dan kode berbahaya.",
    inputSchema: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Path instance atau folder yang ingin diaudit (default: 'Workspace').",
        },
        deep_scan: {
          type: "boolean",
          description: "Jika true (default), memindai isi source code skrip.",
        },
        clean_threats: {
          type: "boolean",
          description: "Jika true, secara otomatis menghapus skrip berbahaya yang terdeteksi (default: false).",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
    },
  },
  {
    name: "insert_asset",
    description: "Muat dan masukkan aset Roblox (Model/Package) berdasarkan Asset ID ke dalam Workspace atau target tertentu dengan proteksi sanitasi skrip otomatis.",
    inputSchema: {
      type: "object",
      properties: {
        asset_id: {
          type: "string",
          description: "Roblox Asset ID angka (atau rbxassetid://).",
        },
        target: {
          type: "string",
          description: "Parent tujuan tempat menempatkan model (default: 'Workspace').",
        },
        strip_scripts: {
          type: "boolean",
          description: "Jika true (default: true), secara otomatis menghapus semua skrip dari model sebelum dimasukkan ke game demi keamanan mutlak dari backdoor.",
        },
        scan_security: {
          type: "boolean",
          description: "Jika true (default: true), memindai potensi ancaman keamanan sebelum insert.",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["asset_id"],
    },
  },
  {
    name: "search_asset",
    description: "Cari aset publik di Roblox Creator Store / Marketplace (Model, Audio, Decal, Image).",
    inputSchema: {
      type: "object",
      properties: {
        keyword: {
          type: "string",
          description: "Kata kunci pencarian aset.",
        },
        category: {
          type: "string",
          enum: ["Model", "Audio", "Decal", "Image"],
          description: "Kategori aset yang dicari (default: 'Model').",
        },
      },
      required: ["keyword"],
    },
  },
  {
    name: "script_grep",
    description: "Cari teks atau pola (pattern) di dalam seluruh script di dalam game (Workspace, ServerScriptService, dll.).",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "String atau pola teks yang ingin dicari di baris kode.",
        },
        target: {
          type: "string",
          description: "Scope root opsional tempat mencari script.",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "get_logs",
    description: "Ambil log konsol / output terbaru Roblox Studio yang ditangkap oleh plugin.",
    inputSchema: {
      type: "object",
      properties: {
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
    },
  },
  {
    name: "list_connected_studios",
    description: "Lihat daftar seluruh sesi Roblox Studio yang sedang terhubung ke Bridge Server, Place ID masing-masing, status koneksi, dan transport (WebSocket/Long-Polling).",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "call_mcp_tool",
    description: "Legacy tool dispatcher untuk kompatibilitas mundur. Mendukung semua command: execute_luau, get_children, get_full_tree, get_script_source, update_script_source, patch_script_source, rollback_script, get_properties, set_properties, create_instance, delete_instance, search_instance, generate_terrain, insert_asset, preview_asset, scan_security, batch_create_instances, batch_set_properties, search_asset, script_grep, get_roblox_docs, get_logs.",
    inputSchema: {
      type: "object",
      properties: {
        command: {
          type: "string",
          description: "Nama perintah yang dieksekusi.",
        },
        target: {
          type: "string",
          description: "Path objek target di Roblox Studio.",
        },
        data: {
          type: "string",
          description: "Data tambahan sesuai command.",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["command"],
    },
  },
  {
    name: "get_roblox_docs",
    description: "Ambil dokumentasi resmi Roblox Engine API langsung dari Creator Docs (Classes, Services, Data types, Enums, dan Libraries). Mengembalikan format Markdown lengkap beserta signature fungsi, deskripsi parameter, properti, event, dan contoh kode untuk mencegah halusinasi kode Luau.",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "Nama Class, Service, Data type, Enum, atau Library Roblox (contoh: 'TweenService', 'CanvasGroup', 'Vector3', 'EasingStyle', 'task').",
        },
        member: {
          type: "string",
          description: "Opsional: Nama method, property, event, atau enum item spesifik untuk menghemat token (contoh: 'Create', 'GroupTransparency', 'Completed').",
        },
        category: {
          type: "string",
          enum: ["class", "datatype", "enum", "library", "auto"],
          description: "Opsional: Kategori dokumentasi (default: 'auto').",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "batch_create_instances",
    description: "Pembangun instance massal dan deklaratif dalam satu kali pemanggilan. Mendukung mode hierarki bersarang (tree) atau daftar array datar (instances) lengkap dengan penyetelan properti langsung (UDim, Vector2, UDim2, Color3, Enum, dll.) untuk menghemat token dan latensi jaringan.",
    inputSchema: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Path root tujuan tempat menaruh instance (contoh: 'StarterGui.MyScreen', 'Workspace.Map').",
        },
        tree: {
          type: "object",
          description: "Objek hierarki bersarang { className, name, properties, children: [...] } untuk membangun struktur pohon secara rekursif.",
        },
        instances: {
          type: "array",
          description: "Daftar array datar [{ className, name, parent, properties }] jika tidak menggunakan mode tree.",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
    },
  },
  {
    name: "batch_set_properties",
    description: "Ubah properti pada banyak instance sekaligus dalam satu kali request atomik.",
    inputSchema: {
      type: "object",
      properties: {
        updates: {
          type: "array",
          description: "Array objek pembaruan: [{ target: 'Path.To.Instance', properties: { PropName: value, ... } }].",
        },
        placeId: {
          type: "number",
          description: "Target Place ID untuk multi-Studio routing.",
        },
        studioId: {
          type: "string",
          description: "Target Studio session ID.",
        },
      },
      required: ["updates"],
    },
  },
];

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: TOOLS };
});

/**
 * Dispatcher pusat untuk meneruskan task ke Roblox Studio (Bridge Hosting lokal atau eksternal).
 */
async function dispatchTaskToStudio(
  command: string,
  target: string,
  data?: string,
  options?: { placeId?: number; studioId?: string }
): Promise<any> {
  const placeId = options?.placeId;
  const studioId = options?.studioId;

  if (isBridgeHosting) {
    if (!isStudioConnected({ placeId, studioId })) {
      for (let i = 0; i < 10; i++) {
        await new Promise(r => setTimeout(r, 50));
        if (isStudioConnected({ placeId, studioId })) break;
      }
      if (!isStudioConnected({ placeId, studioId })) {
        const errorMsg = placeId !== undefined
          ? `Roblox Studio dengan Place ID ${placeId} tidak terdeteksi aktif. Studio yang saat ini terhubung: ${JSON.stringify(getConnectedStudios())}`
          : "Roblox Studio tidak terdeteksi aktif. Pastikan Roblox Studio dibuka, place telah dimuat, dan plugin nvstudio-mcp dalam status terhubung.";
        throw new Error(errorMsg);
      }
    }
    return await addTaskToQueue(command, target, data, { placeId, studioId });
  } else {
    let forwardedToBridge = false;
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 35000);
      const bridgeRes = await fetch("http://localhost:3055/api/tasks/enqueue", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ command, target, data, placeId, studioId }),
        signal: controller.signal,
      });
      clearTimeout(timeoutId);

      if (bridgeRes.ok) {
        forwardedToBridge = true;
        const bridgeJson = (await bridgeRes.json()) as any;
        if (bridgeJson.status === "error") {
          throw new Error(bridgeJson.error);
        }
        return bridgeJson.result;
      } else {
        throw new Error(`Bridge server returned HTTP ${bridgeRes.status}`);
      }
    } catch (err: any) {
      if (forwardedToBridge) throw err;
      throw new Error("Gagal menghubungi server Bridge. Pastikan server daemon berjalan di port 3055.");
    }
  }
}

/**
 * Helper untuk mengeksekusi pencarian aset di katalog web Roblox.
 */
async function handleSearchAsset(keyword: string, category: string = "Model") {
  const encodedKeyword = encodeURIComponent(keyword || "");
  let assetType = "10"; // Default: Model
  if (category === "Audio") {
    assetType = "9";
  } else if (category === "Decal" || category === "Image") {
    assetType = "13";
  }

  const url = `https://catalog.roblox.com/v1/search/items?category=All&keyword=${encodedKeyword}&limit=10&itemTypes=Asset&assetTypes=${assetType}`;
  const res = await fetch(url);
  const jsonRes = await res.json();
  return jsonRes.data || jsonRes;
}

// 4. Handler untuk memproses panggilan tools
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  await bridgeReadyPromise;
  const toolName = request.params.name;
  const args = (request.params.arguments || {}) as Record<string, any>;

  try {
    let result: any;

    switch (toolName) {
      case "execute_luau": {
        const code = String(args.code ?? "");
        if (!code) throw new Error("Parameter 'code' wajib diisi.");
        result = await dispatchTaskToStudio("execute_luau", args.target || "", code, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "get_children": {
        const target = String(args.target ?? "");
        if (!target) throw new Error("Parameter 'target' wajib diisi.");
        result = await dispatchTaskToStudio("get_children", target, "", {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "get_full_tree": {
        const target = String(args.target ?? "");
        if (!target) throw new Error("Parameter 'target' wajib diisi.");
        const depth = String(args.max_depth ?? 2);
        result = await dispatchTaskToStudio("get_full_tree", target, depth, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "get_script_source": {
        const target = String(args.target ?? "");
        if (!target) throw new Error("Parameter 'target' wajib diisi.");
        result = await dispatchTaskToStudio("get_script_source", target, "", {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "update_script_source": {
        const target = String(args.target ?? "");
        const code = String(args.code ?? "");
        if (!target) throw new Error("Parameter 'target' wajib diisi.");

        // Pre-commit AST syntax check di Node.js
        const validation = validateLuauSyntax(code);
        if (!validation.valid) {
          throw new Error(`Syntax error terdeteksi (Pre-commit check Node.js): ${validation.error} pada baris ${validation.line || 'unknown'}`);
        }

        backupScript(target, code);
        result = await dispatchTaskToStudio("update_script_source", target, code, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "patch_script_source": {
        const target = String(args.target ?? "");
        if (!target) throw new Error("Parameter 'target' wajib diisi.");
        if (!args.target_content) throw new Error("Parameter 'target_content' wajib diisi.");
        if (args.replacement_content === undefined) throw new Error("Parameter 'replacement_content' wajib diisi.");

        const payload = JSON.stringify({
          target_content: args.target_content,
          replacement_content: args.replacement_content,
          allow_multiple: !!args.allow_multiple,
        });

        result = await dispatchTaskToStudio("patch_script_source", target, payload, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "rollback_script": {
        const target = String(args.target ?? "");
        if (!target) throw new Error("Parameter 'target' wajib diisi.");
        result = await dispatchTaskToStudio("rollback_script", target, "", {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "get_properties": {
        const target = String(args.target ?? "");
        if (!target) throw new Error("Parameter 'target' wajib diisi.");
        result = await dispatchTaskToStudio("get_properties", target, "", {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "set_properties": {
        const target = String(args.target ?? "");
        if (!target) throw new Error("Parameter 'target' wajib diisi.");
        if (!args.properties) throw new Error("Parameter 'properties' wajib diisi.");
        const propsData = typeof args.properties === "string" ? args.properties : JSON.stringify(args.properties);
        result = await dispatchTaskToStudio("set_properties", target, propsData, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "create_instance": {
        const className = String(args.class_name ?? "");
        const target = String(args.target ?? "");
        if (!className) throw new Error("Parameter 'class_name' wajib diisi.");
        if (!target) throw new Error("Parameter 'target' wajib diisi.");
        const payload = JSON.stringify({
          ClassName: className,
          Properties: args.properties || {},
        });
        result = await dispatchTaskToStudio("create_instance", target, payload, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "delete_instance": {
        const target = String(args.target ?? "");
        if (!target) throw new Error("Parameter 'target' wajib diisi.");
        const data = args.force ? "force" : "";
        result = await dispatchTaskToStudio("delete_instance", target, data, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "search_instance": {
        const query = String(args.query ?? "");
        if (!query) throw new Error("Parameter 'query' wajib diisi.");
        result = await dispatchTaskToStudio("search_instance", args.target || "", query, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "generate_terrain": {
        const material = String(args.material ?? "");
        if (!material) throw new Error("Parameter 'material' wajib diisi.");
        if (!args.position || !Array.isArray(args.position)) throw new Error("Parameter 'position' [X, Y, Z] wajib diisi.");
        if (!args.size || !Array.isArray(args.size)) throw new Error("Parameter 'size' [X, Y, Z] wajib diisi.");
        const payload = JSON.stringify({
          Material: material,
          Position: args.position,
          Size: args.size,
        });
        result = await dispatchTaskToStudio("generate_terrain", "", payload, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "preview_asset": {
        const assetId = String(args.asset_id ?? "");
        if (!assetId) throw new Error("Parameter 'asset_id' wajib diisi.");
        const payload = JSON.stringify({
          asset_id: assetId,
          deep_scan: args.deep_scan !== false,
        });
        result = await dispatchTaskToStudio("preview_asset", "", payload, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "scan_security": {
        const payload = JSON.stringify({
          deep_scan: args.deep_scan !== false,
          clean_threats: args.clean_threats === true,
        });
        result = await dispatchTaskToStudio("scan_security", args.target || "Workspace", payload, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "insert_asset": {
        const assetId = String(args.asset_id ?? "");
        if (!assetId) throw new Error("Parameter 'asset_id' wajib diisi.");
        const payload = JSON.stringify({
          asset_id: assetId,
          strip_scripts: args.strip_scripts !== false,
          scan_security: args.scan_security !== false,
        });
        result = await dispatchTaskToStudio("insert_asset", args.target || "Workspace", payload, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "search_asset": {
        const keyword = String(args.keyword ?? "");
        if (!keyword) throw new Error("Parameter 'keyword' wajib diisi.");
        result = await handleSearchAsset(keyword, args.category);
        break;
      }

      case "script_grep": {
        const query = String(args.query ?? "");
        if (!query) throw new Error("Parameter 'query' wajib diisi.");
        result = await dispatchTaskToStudio("script_grep", args.target || "", query, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "get_logs": {
        result = await dispatchTaskToStudio("get_logs", "", "", {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "list_connected_studios": {
        if (isBridgeHosting) {
          result = getConnectedStudios();
        } else {
          try {
            const statsRes = await fetch("http://localhost:3055/api/stats");
            const statsJson = (await statsRes.json()) as any;
            result = statsJson.connectedStudios || [];
          } catch {
            result = [];
          }
        }
        break;
      }

      case "get_roblox_docs": {
        const query = String(args.query ?? "").trim();
        if (!query) throw new Error("Parameter 'query' wajib diisi.");
        const member = args.member ? String(args.member).trim() : undefined;
        const category = args.category ? String(args.category).trim() : "auto";
        result = await getRobloxDocs(query, member, category);
        break;
      }

      case "batch_create_instances": {
        const payload = JSON.stringify({
          target: args.target,
          tree: args.tree,
          instances: args.instances,
        });
        result = await dispatchTaskToStudio("batch_create_instances", args.target || "Workspace", payload, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "batch_set_properties": {
        if (!args.updates || !Array.isArray(args.updates)) throw new Error("Parameter 'updates' wajib berupa array.");
        const payload = JSON.stringify({
          updates: args.updates,
        });
        result = await dispatchTaskToStudio("batch_set_properties", "", payload, {
          placeId: args.placeId,
          studioId: args.studioId,
        });
        break;
      }

      case "call_mcp_tool": {
        const { command, target, data, placeId, studioId } = args as {
          command: string;
          target?: string;
          data?: string;
          placeId?: number;
          studioId?: string;
        };

        if (!command) throw new Error("Parameter 'command' wajib diisi.");

        // Pre-commit validation for full source replacement
        if (command === "update_script_source" && data) {
          const validation = validateLuauSyntax(String(data));
          if (!validation.valid) {
            throw new Error(`Syntax error terdeteksi (Pre-commit check Node.js): ${validation.error} pada baris ${validation.line || 'unknown'}`);
          }
          if (target) backupScript(target, String(data));
        }

        // Intercept get_roblox_docs di Node.js
        if (command === "get_roblox_docs") {
          const queryParams = typeof data === "string" ? (function() { try { return JSON.parse(data); } catch { return { query: data }; } })() : (data || {});
          const q = String(queryParams.query || target || "").trim();
          result = await getRobloxDocs(q, queryParams.member, queryParams.category);
          break;
        }

        // Intercept search_asset di Node.js
        if (command === "search_asset" && data) {
          const queryParams = typeof data === "string" ? JSON.parse(data) : data;
          result = await handleSearchAsset(queryParams.keyword || "", queryParams.category);
          break;
        }

        result = await dispatchTaskToStudio(command, target || "", data, { placeId, studioId });
        break;
      }

      default:
        throw new Error(`Tool tidak dikenali: ${toolName}`);
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

// 5. Jalankan koneksi MCP menggunakan StdioServerTransport (hanya jika bukan mode Daemon)
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("[nvstudio-mcp] MCP Server aktif melalui StdioServerTransport.");

  // Beritahu SSE/WS plugin bahwa MCP agent sekarang aktif
  setMcpConnected(true);

  let isShuttingDown = false;
  const shutdown = () => {
    if (isShuttingDown) return;
    isShuttingDown = true;
    setMcpConnected(false);
    console.error("[nvstudio-mcp] Koneksi ditutup oleh IDE. Mematikan server...");
    process.exit(0);
  };

  process.stdin.on('close', shutdown);
  process.stdin.on('end', shutdown);
  process.stdin.on('error', shutdown);
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
