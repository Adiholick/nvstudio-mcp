# BLUEPRINT: nvstudio-mcp (Fase 6 - File Sync & AST Validator)

**Tujuan:** Instruksi ini dirancang untuk AI Agent. Anda harus menambahkan sistem "Jaring Pengaman" dengan membuat folder *history* lokal di Node.js, dan menambahkan "Luau AST Validator" di Plugin Roblox Studio.

### Langkah 1: Modifikasi Node.js untuk Sistem Sinkronisasi Temporary
Buka file `src/index.ts` pada server Node.js Anda. Tambahkan modul `fs` (File System) untuk merekam riwayat (backup) setiap kali ada instruksi mengubah script. 

Tambahkan blok fungsi ini di bagian atas sebelum inisialisasi server MCP:
```typescript
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
```

Kemudian, di dalam blok `server.setRequestHandler` (saat `command === "update_script_source"`), panggil fungsi backup tersebut sebelum memasukkan tugas ke antrean:
```typescript
        if (command === "update_script_source" && request.params.arguments?.data) {
            backupScript(target, String(request.params.arguments.data));
        }
```

### Langkah 2: Tambahkan Perintah Rollback di `docs/API_CONTRACT.md`
Tambahkan perintah ke-6 pada API Contract:
6. `rollback_script`:
   - **Fungsi:** Mengembalikan properti `Source` pada target ke versi sebelumnya jika AI berhalusinasi atau AST Validation gagal.
   - **Parameter target:** Path absolut instance.
   - **Parameter data:** Kosongkan.

### Langkah 3: Modifikasi Plugin Luau untuk AST Validator
Buka `plugin/nvstudio_mcp.server.lua`. Modifikasi bagian `elseif command == "update_script_source" then` untuk menggunakan fungsi `loadstring` sebagai validator *syntax* murni (AST Checker) sebelum kode diterapkan:

```lua
    elseif command == "update_script_source" then
        if targetInstance:IsA("LuaSourceContainer") then
            local newCode = data or ""
            
            -- Luau AST Validator (Mengecek syntax tanpa mengeksekusi)
            local success, syntaxError = loadstring(newCode)
            if not success then
                return { 
                    status = "error", 
                    error = "SYNTAX ERROR (AST Validation Gagal): " .. tostring(syntaxError) .. ". Script dibatalkan. Silakan periksa kembali kodemu." 
                }
            end
            
            targetInstance.Source = newCode
            return { status = "success", result = "Script '" .. targetInstance.Name .. "' divalidasi dan berhasil diperbarui." }
        else
            return { status = "error", error = "Target BUKAN Script." }
        end
```

### Langkah 4: Eksekusi
Terapkan perubahan ini. Sekarang jika Anda (AI) menulis kode dengan *syntax* yang rusak atau teks kosong yang tidak valid, Plugin Studio akan menolaknya dan *backup* tetap tersimpan di folder `.history` komputer pengguna.