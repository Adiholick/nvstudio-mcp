# nvstudio-mcp 🚀

**nvstudio-mcp** adalah jembatan pintar (*Model Context Protocol Bridge*) yang menghubungkan Asisten AI Anda (seperti Antigravity IDE, Cursor, Claude Desktop, atau Windsurf) secara langsung ke dalam **Roblox Studio**. Dengan plugin ini, AI Anda dapat membaca, mengedit script, men-generate terrain, dan berinteraksi dengan API Roblox Studio layaknya seorang asisten *Co-Pilot* sejati.

Sistem ini didesain menggunakan **Hybrid Architecture** yang memisahkan logika Engine (*Studio Plugin*) dan aturan anti-halusinasi (*Agent Plugin*).

---

## 📥 Instalasi

Langkah instalasinya **sangat gampang!**

### 1. Jalankan Installer (Otomatis)

Pilih perintah sesuai terminal yang Anda gunakan:

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/Adiholick/nvstudio-mcp/main/install.ps1 | iex
```

**macOS / Linux / Git Bash:**
```bash
curl -fsSL https://raw.githubusercontent.com/Adiholick/nvstudio-mcp/main/install.sh | bash
```


**Installer ini akan secara otomatis melakukan hal berikut:**
- Memasang dependensi Node.js dan melakukan kompilasi TypeScript (*Bridge Server*).
- Menyalin file plugin `nvstudio_mcp.rbxmx` ke dalam sistem Plugin Roblox Studio di OS Anda (Windows/macOS/WSL) secara otomatis.
- Mengintegrasikan *AI Agent Skills* langsung ke **Antigravity IDE** (`~/.gemini/config/plugins/nvstudio-mcp`).
- Melakukan auto-konfigurasi JSON jika Anda menggunakan **Cursor Editor**.

### 2. Mengaktifkan Izin di Roblox Studio
1. Buka proyek game Anda di Roblox Studio.
2. Di pojok kiri atas, buka **Home** -> **Game Settings** -> **Security**.
3. Centang (aktifkan) opsi **`Allow HTTP Requests`** agar plugin dapat berkomunikasi dengan AI.

---

## 🔌 Cara Menggunakan (Untuk AI Lain)

Jika Anda menggunakan AI Client lain (misalnya: **Claude Desktop** atau klien yang tidak dikonfigurasi otomatis), Anda dapat menambahkan `nvstudio-mcp` secara manual ke konfigurasi `mcp.json` Anda.

Salin konfigurasi ini:
```json
{
  "mcpServers": {
    "nvstudio-mcp": {
      "command": "node",
      "args": [
        "C:/Path/Ke/Folder/nvstudio-mcp/dist/index.js"
      ]
    }
  }
}
```
*(Ingat untuk mengganti path `args` di atas dengan direktori instalasi aktual Anda, biasanya berada di `~/.nvstudio-mcp/dist/index.js`).*

---

## 🗑️ Cara Uninstall (Mencopot Pemasangan)

Jika Anda ingin berhenti menggunakan `nvstudio-mcp`, Anda dapat membersihkannya dari sistem Anda secara menyeluruh dengan 4 langkah berikut:

### 1. Hapus Plugin dari Roblox Studio
Hapus file plugin dari folder lokal Roblox Anda.
- **Windows:** Buka folder `%LOCALAPPDATA%\Roblox\Plugins` (atau `AppData\Local\Roblox\Plugins`) dan hapus file `nvstudio_mcp.rbxmx` (atau `nvstudio_mcp.rbxm`).
- **macOS:** Buka folder `~/Documents/ROBLOX/Plugins` dan hapus file `nvstudio_mcp.rbxmx` (atau `nvstudio_mcp.rbxm`).

### 2. Hapus Agen dari Antigravity (Jika Menggunakan AGY)
Hapus *bundle* keterampilan *anti-halusinasi* dari memori AI Anda:
```bash
rm -rf ~/.gemini/config/plugins/nvstudio-mcp
```
*(Untuk pengguna Windows PowerShell, Anda bisa menghapus folder `C:\Users\NamaAnda\.gemini\config\plugins\nvstudio-mcp` secara manual).*

### 3. Hapus File Instalasi Node.js
Installer `install.sh` sebelumnya mengkloning repositori dan menginstal Node.js di dalam direktori *Home* Anda (secara bawaan di `~/.nvstudio-mcp`). Hapus direktori tersebut:
```bash
rm -rf ~/.nvstudio-mcp
```

### 4. Hapus Konfigurasi dari Editor AI Anda
Jika Anda memasukkan konfigurasi MCP secara otomatis ke Cursor atau secara manual ke Claude Desktop, buka file pengaturan `mcp.json` tersebut dan **hapus blok `"nvstudio-mcp"`** dari dalam objek `mcpServers`.

---

**Selamat Menciptakan Game Impian Anda dengan AI! 🎮🤖**