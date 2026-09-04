# BLUEPRINT: nvstudio-mcp (Fase 7 - Live Debugging & Console)

**Tujuan:** Instruksi ini dirancang untuk AI Agent. Anda harus memodifikasi Plugin Roblox Studio untuk menangkap rekaman error dari `LogService` dan membuat perintah baru agar agen AI bisa memantau kondisi *game*.

### Langkah 1: Perbarui `docs/API_CONTRACT.md`
Tambahkan perintah ke-7 pada API Contract:
7. `get_logs`:
   - **Fungsi:** Mengambil 50 baris terakhir dari *Output Console* Roblox Studio. Sangat penting digunakan setelah memodifikasi script untuk memastikan tidak ada *runtime error*.
   - **Parameter target:** `"game"`
   - **Parameter data:** Kosongkan.
   - **Response:** Array string berisi pesan *log* dan *error*.

### Langkah 2: Modifikasi Plugin Luau (`plugin/nvstudio_mcp.server.lua`)
Di bagian atas file plugin (di bawah deklarasi variabel URL), tambahkan sistem penangkap log (*Log Catcher*):

```lua
local LogService = game:GetService("LogService")
local recentLogs = {}
local MAX_LOGS = 50

-- Menangkap setiap pesan yang muncul di Output Studio
LogService.MessageOut:Connect(function(message, messageType)
    local prefix = "[INFO] "
    if messageType == Enum.MessageType.MessageError then
        prefix = "[ERROR] "
    elseif messageType == Enum.MessageType.MessageWarning then
        prefix = "[WARNING] "
    end
    
    table.insert(recentLogs, prefix .. message)
    
    -- Jaga agar memori tidak penuh (maksimal 50 log terbaru)
    if #recentLogs > MAX_LOGS then
        table.remove(recentLogs, 1)
    end
end)
```

Kemudian, di dalam blok `processTask`, tambahkan *handler* untuk perintah `get_logs`:

```lua
    elseif command == "get_logs" then
        if #recentLogs == 0 then
            return { status = "success", result = {"Console kosong. Tidak ada error atau log terbaru."} }
        else
            return { status = "success", result = recentLogs }
        end
```

### Langkah 3: Eksekusi & Kepatuhan Guardrail
Terapkan penambahan kode log ini. 
**Peringatan Operasional untuk AI:** Dengan adanya fitur `get_logs` ini, setiap kali Anda selesai menggunakan `call_mcp_tool` untuk melakukan `update_script_source`, sangat disarankan untuk memanggil `get_logs` beberapa detik kemudian guna memverifikasi bahwa perubahan Anda tidak memicu *error* di sisi server/klien Roblox. Tetap patuhi aturan untuk selalu memanggil `get_children` saat mencari objek. Dilarang menggunakan metode *bypass* eksternal.