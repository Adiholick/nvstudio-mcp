# BLUEPRINT: nvstudio-mcp (Fase 8 - Sistem Anti-Halusinasi Mutlak)

**Tujuan:** Instruksi ini dirancang untuk AI Agent. Anda wajib mengeksekusi instruksi ini untuk membangun sistem pengunci perilaku (Guardrails) permanen agar AI tidak kembali mencoba menggunakan skrip *bypass* eksternal atau menargetkan *Folder* secara buta.

### Langkah 1: Buat File Aturan Klien (IDE System Rules)
File ini akan secara otomatis dibaca oleh IDE (seperti Cursor, Windsurf, atau Cline) sebagai instruksi dasar (*system prompt*) di setiap sesi obrolan baru.
1. Di dalam *root* direktori proyek `nvstudio-mcp`, buat sebuah file bernama `.cursorrules`. (Jika Anda menggunakan editor lain, Anda juga bisa menyimpannya sebagai `AI_RULES.md`).
2. Tuliskan teks peringatan keras berikut ke dalamnya:

```text
# ROBLOX STUDIO MCP RULES - MUTLAK DAN TIDAK BISA DIGANGGU GUGAT

1. SINGLE POINT OF INTERACTION:
Anda HANYA DIIZINKAN berinteraksi dengan Roblox menggunakan alat `call_mcp_tool`. 

2. STRICT BYPASS BAN:
DILARANG KERAS merancang, menulis, atau mengeksekusi script eksternal seperti `fetch_mcp_source.js`, `PowerShell`, atau `Node.js runner` lainnya untuk berinteraksi dengan Roblox. Jalur komunikasi sudah diatur sepenuhnya melalui MCP lokal.

3. MANDATORY HIERARCHY CHECK:
DILARANG memanggil `get_script_source` secara menebak-nebak (buta). Anda WAJIB memanggil `get_children` pada direktori parent terlebih dahulu. Jika Anda mendapat pesan error bahwa "teks kosong", itu karena Anda mencoba membaca Folder, bukan Script. Selalu verifikasi ClassName dari hasil `get_children` sebelum mengekstrak kode.
```

### Langkah 2: Hardcode Guardrail pada Deskripsi Tool MCP
Modifikasi file `src/index.ts` agar deskripsi *tool* bertindak sebagai peringatan *self-correcting* yang dibaca AI setiap kali ia akan memanggil protokol.

Buka `src/index.ts` dan ganti bagian `description` pada `ListToolsRequestSchema` menjadi:

```typescript
server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [{
        name: "call_mcp_tool",
        description: "ALAT MUTLAK UNTUK ROBLOX. DILARANG KERAS menggunakan PowerShell atau skrip bypass (fetch_mcp_source.js). WAJIB memanggil 'get_children' terlebih dahulu sebelum 'get_script_source' untuk memverifikasi tipe instance agar tidak terjadi error teks kosong.",
        inputSchema: {
            type: "object",
            properties: {
                command: { type: "string", description: "Contoh: 'get_children', 'get_script_source', 'create_instance'" },
                target: { type: "string", description: "Path absolut. Contoh: 'Workspace.Map'" },
                data: { type: "string", description: "Data/kode opsional" }
            },
            required: ["command", "target"]
        }
    }]
}));
```

### Langkah 3: Interceptor Logika di Node.js (Lapisan Penolakan Mutlak)
Langkah ini memastikan bahwa meskipun AI mengabaikan instruksi dan mencoba mengekstrak kode dari target yang salah, server Node.js akan mencegat dan menolaknya bahkan sebelum perintah tersebut sampai ke Roblox Studio.

Masih di dalam `src/index.ts`, pada bagian `CallToolRequestSchema`, tambahkan logika *interceptor* ini tepat sebelum perintah dimasukkan ke dalam antrean (`addTaskToQueue`):

```typescript
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    if (request.params.name === "call_mcp_tool") {
        const command = String(request.params.arguments?.command);
        const target = String(request.params.arguments?.target);
        
        // 🔴 GUARDRAIL MUTLAK: Cegah tebakan path buta
        if (command === "get_script_source") {
            const genericTargets = ["Workspace", "ServerScriptService", "ReplicatedStorage", "StarterGui", "StarterPack", "game"];
            
            if (genericTargets.includes(target) || !target.includes(".")) {
                return { 
                    content: [{ 
                        type: "text", 
                        text: "🔴 SERVER GUARDRAIL BLOCKED: DILARANG mengekstrak kode secara buta dari direktori utama atau target yang tidak spesifik. Anda WAJIB memanggil perintah 'get_children' pada '" + target + "' terlebih dahulu untuk memverifikasi nama dan ClassName (Pastikan target adalah LuaSourceContainer)." 
                    }] 
                };
            }
        }

        // Lanjutkan ke antrean jika lolos guardrail
        const result = await addTaskToQueue(command, target, request.params.arguments?.data);
        return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
    throw new Error("Tool tidak ditemukan");
});
```

### Langkah 4: Eksekusi dan Kompilasi
1. Tulis file `.cursorrules`.
2. Terapkan pembaruan pada `src/index.ts`.
3. Jalankan perintah kompilasi `npm run build` untuk menerapkan aturan keamanan baru ini ke dalam biner eksekusi.