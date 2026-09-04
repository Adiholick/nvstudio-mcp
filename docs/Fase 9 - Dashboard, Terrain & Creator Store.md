# BLUEPRINT: nvstudio-mcp (Fase 9 - Dashboard, Terrain & Creator Store)

**Tujuan:** Instruksi ini dirancang untuk AI Agent. Anda wajib mengeksekusi instruksi ini untuk mengekspansi `nvstudio-mcp` dengan antarmuka visual (Dashboard), fitur pembuatan daratan (Terrain), penyisipan aset dari *Creator Store*, dan memodifikasi *port* komunikasi lokal untuk mencegah tabrakan *port*.

### Langkah 1: Perubahan Port & Instalasi Dependensi (Node.js)
Secara *default*, port 3000 sering digunakan oleh React/Vite/Express. Kita akan memindahkannya ke port khusus **3055**.
1. Buka terminal di dalam direktori `nvstudio-mcp` dan instal pustaka WebSocket:
   `npm install socket.io`
   `npm install -D @types/socket.io`
2. Buka `src/index.ts` dan `src/roblox-bridge.ts`. Ubah semua referensi port dari `3000` menjadi `3055`.
3. Buka `plugin/nvstudio_mcp.server.lua`, perbarui variabel URL di bagian paling atas:
   ```lua
   local TASK_URL = "http://localhost:3055/api/tasks"
   local RESPONSE_URL = "http://localhost:3055/api/response"
   ```

### Langkah 2: Pembaruan Kontrak API (`docs/API_CONTRACT.md`)
Tambahkan dua perintah baru ke dalam daftar *commands* di file kontrak API:
8. `insert_asset`:
   - **Fungsi:** Memasukkan model 3D/aset dari Roblox Creator Store langsung ke Workspace.
   - **Parameter target:** `"game"`
   - **Parameter data:** String/Number berisi ID Aset (contoh: `12345678`).
9. `generate_terrain`:
   - **Fungsi:** Membuat blok daratan (*voxel terrain*) secara instan.
   - **Parameter target:** `"Workspace.Terrain"`
   - **Parameter data:** String JSON berisi konfigurasi Terrain. Contoh: `{"Size": [50, 10, 50], "Position": [0, -5, 0], "Material": "Grass"}`

### Langkah 3: Integrasi Web Dashboard & WebSocket (`src/roblox-bridge.ts`)
Ganti seluruh isi `src/roblox-bridge.ts` dengan kode berikut agar server Express dapat menyajikan halaman HTML (Dashboard) dan memancarkan log secara *real-time* via `socket.io`:

```typescript
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

        if (pendingTasks.has(id)) {
            const resolveTask = pendingTasks.get(id)!;
            pendingTasks.delete(id);
            if (status === 'success') resolveTask({ success: true, data: result });
            else resolveTask({ success: false, error: error });
        }
        res.json({ message: "Response diterima" });
    });

    httpServer.listen(port, () => {
        console.error(`[Bridge] Dashboard visual & server aktif di http://localhost:${port}`);
    });
}
```

### Langkah 4: Pembuatan Antarmuka Web Dashboard
1. Buat direktori baru bernama `public` di dalam *root* proyek.
2. Buat file `public/index.html` dan isi dengan kode UI berikut:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>nvstudio-mcp | Live Dashboard</title>
    <style>
        body { font-family: 'Consolas', monospace; background-color: #0f172a; color: #38bdf8; margin: 0; padding: 20px; }
        h1 { color: #f8fafc; font-size: 1.5rem; border-bottom: 1px solid #334155; padding-bottom: 10px; }
        #log-container { background-color: #1e293b; padding: 15px; border-radius: 8px; height: 75vh; overflow-y: auto; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
        .log-entry { margin-bottom: 8px; border-bottom: 1px solid #334155; padding-bottom: 4px; }
        .log-time { color: #94a3b8; font-size: 0.85em; margin-right: 10px; }
    </style>
</head>
<body>
    <h1>nvstudio-mcp : Activity Dashboard (Port 3055)</h1>
    <div id="log-container"></div>

    <script src="/socket.io/socket.io.js"></script>
    <script>
        const socket = io();
        const container = document.getElementById('log-container');

        socket.on('log', (msg) => {
            const el = document.createElement('div');
            el.className = 'log-entry';
            const time = new Date().toLocaleTimeString();
            el.innerHTML = `<span class="log-time">[${time}]</span>${msg}`;
            container.appendChild(el);
            container.scrollTop = container.scrollHeight; // Auto-scroll
        });
    </script>
</body>
</html>
```

### Langkah 5: Penambahan Fitur Terrain & Creator Store (Plugin Luau)
Buka `plugin/nvstudio_mcp.server.lua`. Di dalam fungsi `processTask`, tambahkan *handler* baru (sebagai blok `elseif`) untuk mengeksekusi kedua fitur ini:

```lua
    elseif command == "insert_asset" then
        local InsertService = game:GetService("InsertService")
        local assetId = tonumber(data)
        if not assetId then
            return { status = "error", error = "Asset ID harus berupa angka yang valid." }
        end
        
        local success, model = pcall(function()
            return InsertService:LoadAsset(assetId)
        end)
        
        if success and model then
            model.Parent = game.Workspace
            return { status = "success", result = "Aset berhasil dimasukkan ke Workspace." }
        else
            return { status = "error", error = "Gagal memuat aset. Pastikan Asset ID benar dan akun/plugin Anda memiliki izin (Ownership/Public)." }
        end

    elseif command == "generate_terrain" then
        local success, config = pcall(function() return HttpService:JSONDecode(data) end)
        if not success or not config.Size or not config.Position or not config.Material then
            return { status = "error", error = "Format JSON tidak valid. Membutuhkan Size, Position, dan Material." }
        end
        
        local terrain = game.Workspace.Terrain
        local materialEnum = Enum.Material[config.Material] or Enum.Material.Grass
        
        local size = Vector3.new(config.Size[1], config.Size[2], config.Size[3])
        local position = Vector3.new(config.Position[1], config.Position[2], config.Position[3])
        
        local region = Region3.new(position - (size/2), position + (size/2))
        
        local fillSuccess, err = pcall(function()
            terrain:FillRegion(region:ExpandToGrid(4), 4, materialEnum)
        end)
        
        if fillSuccess then
            return { status = "success", result = "Terrain (" .. config.Material .. ") berhasil di-generate." }
        else
            return { status = "error", error = "Gagal men-generate Terrain: " .. tostring(err) }
        end
```

### Langkah 6: Eksekusi Pembangunan
1. Instal dependensi WebSocket.
2. Buat folder `public` dan file `index.html`.
3. Terapkan pembaruan pada `roblox-bridge.ts` dan `nvstudio_mcp.server.lua`.
4. Jalankan `npm run build` ulang. Mulai saat ini, *user* dapat membuka `http://localhost:3055` di browser untuk melihat *Web Dashboard Visual* saat AI sedang beroperasi!