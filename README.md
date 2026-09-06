# nvstudio-mcp 🚀

**nvstudio-mcp** adalah jembatan pintar (*Model Context Protocol Bridge*) yang menghubungkan Asisten AI Anda (seperti Antigravity IDE, Cursor, Claude Desktop, atau Windsurf) secara langsung ke dalam **Roblox Studio**. Dengan plugin ini, AI Anda dapat membaca, mengedit script, men-generate terrain, dan berinteraksi dengan API Roblox Studio layaknya seorang asisten *Co-Pilot* sejati.

Sistem ini didesain menggunakan **Hybrid Architecture** yang memisahkan logika Engine (*Studio Plugin*) dan aturan anti-halusinasi (*Agent Plugin*).

---

## 📥 Instalasi

Langkah instalasi dirancang **sangat mudah dan otomatis!**

> 💡 **Apakah perlu install plugin Roblox secara manual?**
> **TIDAK PERLU.** Jika Anda menjalankan skrip installer di bawah (Langkah 1), installer akan **secara otomatis menyalin plugin (`nvstudio_mcp.rbxmx`)** langsung ke folder plugin Roblox Studio di sistem operasi Anda.

---

### Langkah 1: Jalankan Installer (Otomatis & Direkomendasikan)

Pilih perintah sesuai terminal yang Anda gunakan:

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/Adiholick/nvstudio-mcp/main/install.ps1 | iex
```

**macOS / Linux / Git Bash:**
```bash
curl -fsSL https://raw.githubusercontent.com/Adiholick/nvstudio-mcp/main/install.sh | bash
```

**Apa saja yang dilakukan installer ini secara otomatis?**
1. 📦 Mengunduh source code, memasang dependensi Node.js, dan mengkompilasi TypeScript (*Bridge Server*).
2. 🧩 **Memasang Plugin Roblox Studio (`nvstudio_mcp.rbxmx`) otomatis** ke folder sistem Roblox Studio Anda (`%LOCALAPPDATA%\Roblox\Plugins` di Windows atau `~/Documents/ROBLOX/Plugins` di macOS).
3. 🤖 Mengintegrasikan *AI Agent Skills* anti-halusinasi langsung ke **Antigravity IDE** (`~/.gemini/config/plugins/nvstudio-mcp`).
4. ⚙️ Melakukan auto-konfigurasi jika mendeteksi editor **Cursor** (`.cursor/mcp.json`).

---

### Langkah 2: Mengaktifkan Izin di Roblox Studio (Wajib)

Karena pembatasan keamanan bawaan Roblox Studio, akses HTTP harus diizinkan sekali per place/game:
1. Buka game/place Anda di **Roblox Studio**.
2. Di toolbar atas, buka tab **Home** ➔ **Game Settings** ➔ pilih menu **Security**.
3. Centang (aktifkan) **`Allow HTTP Requests`**, lalu klik **Save**.
4. **Auto-Detect Aktif!** Plugin Roblox Studio kini memiliki heartbeat pintar yang akan otomatis terhubung (*Auto-Connect*) segera setelah MCP server aktif — Anda tidak perlu lagi repot menekan tombol connect secara manual.

---

### 📂 Alternatif: Instalasi Plugin Secara Manual (Opsional)

Jika Anda **tidak** menggunakan skrip installer otomatis di atas (misalnya hanya menambahkan server via `npx` di klien AI), pasang file plugin Roblox Studio secara manual:
1. Ambil file `nvstudio_mcp.rbxmx` dari folder [studio-plugin/nvstudio_mcp.rbxmx](file:///studio-plugin/nvstudio_mcp.rbxmx).
2. Pindahkan/salin file tersebut ke direktori plugin Roblox di komputer Anda:
   - **Windows:** `%LOCALAPPDATA%\Roblox\Plugins` (atau `C:\Users\<Username>\AppData\Local\Roblox\Plugins`)
   - **macOS:** `~/Documents/ROBLOX/Plugins`
3. Restart atau buka kembali Roblox Studio. Plugin akan muncul di tab **Plugins**.

---

## 🔌 Cara Menggunakan (Konfigurasi MCP Klien AI)

Jika Anda menggunakan AI Client lain seperti **Claude Desktop**, **Windsurf**, atau ingin menambahkan konfigurasi secara manual:

Tambahkan konfigurasi berikut ke file `mcp.json` Anda:
```json
{
  "mcpServers": {
    "nvstudio-mcp": {
      "command": "npx",
      "args": [
        "-y",
        "@adiholick/nvstudio-mcp@latest"
      ]
    }
  }
}
```
*(AI Anda akan selalu menjalankan versi terbaru dari server Bridge langsung dari NPM!)*

---

## 🖥️ Dashboard Visual & Fitur Pintar v2.0

- **Visual Dashboard Real-time:** Buka [http://localhost:3055](http://localhost:3055) di browser Anda untuk melihat monitor antrean perintah, log aktivitas AI, status koneksi Studio, dan statistik eksekusi secara visual.
- **Auto-Detect & Auto-Connect:** Plugin Roblox Studio otomatis menyambung ke server saat aktif dan kembali menunggu (*Waiting*) saat server mati tanpa interupsi manual.
- **Anti-Zombie Port Handling:** Tidak perlu khawatir error `EADDRINUSE`. Jika port `3055` tertahan oleh proses zombie akibat restart editor/IDE, server akan otomatis membersihkan port tersebut secara aman.

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