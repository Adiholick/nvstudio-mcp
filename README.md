# nvstudio-mcp 🚀

**nvstudio-mcp** adalah jembatan pintar (*Model Context Protocol Bridge*) yang menghubungkan Asisten AI Anda (seperti Antigravity IDE, Cursor, Claude Desktop, atau Windsurf) secara langsung ke dalam **Roblox Studio**. Dengan plugin ini, AI Anda dapat membaca dan mengedit skrip, membangun hierarki GUI massal, memindai keamanan model 3D, mencari dokumentasi engine resmi, men-generate terrain, dan berinteraksi dengan API Roblox Studio layaknya seorang asisten *Co-Pilot* sejati.

Sistem ini didesain menggunakan **Hybrid Architecture** yang memisahkan logika Engine (*Studio Plugin*) dan aturan anti-halusinasi (*Agent Plugin*).

---

## 🌟 Fitur Unggulan v2.4 (Animation, VFX & Rigging Suite)

- 🏗️ **NV-Rig Engine & Joint Kinematics (`inspect_rig`, `auto_rig`, `edit_rig_joint`, `weld_assembly`, `mirror_rig`)**:
  - **Pure Headless Dispatcher**: Operasi rigging deterministik instan ($O(1)$) tanpa overhead render visual.
  - **Hukum Non-Dislokasi Poros (*Non-Dislocation Law*)**: Menggeser/memutar titik engsel sendi di dunia nyata dengan kompensasi otomatis $C_1 = C_{1\text{old}} \times \text{diff}$ tanpa pernah mendislokasi part anak.
  - **1-Click Auto-Rigging**: Membangun rig lengkap R6 (6 part), R15 (15 part), maupun penautan senjata (`WeaponGrip`) secara instan dengan auto-unanchor.
  - **Bilateral X-Axis Mirroring & Assembly Welder**: Refleksi simetris sendi kiri $\leftrightarrow$ kanan dan pengelasan seluruh komponen armor/prop ke part jangkar utama.
- 🏃 **NV-Animation Engine & Kinematics (`animate_character`, `solve_limb_ik`, `scrub_timeline`)**:
  - **Human-like Motion Synthesis**: Menghasilkan animasi karakter berkualitas tinggi (Walk, Slash, Punch, Idle Breath) berbasis prinsip animasi alami (Anticipation, Follow-Through).
  - **Interpolasi Kurva Halus**: Menggunakan kurva Cubic Bezier (`PoseEasingStyle.Cubic`) dan Quaternion SLERP 4D rotation interpolation bebas *Gimbal Lock*.
  - **Analytical 2-Link LimbIK O(1)**: Penyelesaian sudut tekukan siku dan lutut menggunakan Hukum Cosinus sudut tertutup instan dan ekstensi SoftIK anti-snapping.
  - **Official KeyframeSequence**: Animasi disimpan langsung ke instance resmi di `AnimSaves` karakter, bukan script loop runtime.
- ✨ **NV-VFX Subsystem & Cross-Project Database (`scan_vfx`, `apply_vfx`, `list_vfx_database`, `delete_vfx`)**:
  - **1:1 Pure Table Serializer**: Mengonversi `ParticleEmitter`, `Beam`, `Trail`, `Light`, dan `Attachment` menjadi tabel data murni JSON dengan relasi pointer yang aman.
  - **Database Lintas-Proyek**: Pindai VFX di Project A dan pasang kembali di Project B dengan faktor skala ukuran opsional (`scale`). Dilengkapi 5 preset bawaan (*Cyan Slash*, *Solar Burst*, *Dragon Aura*, *Arcane Rune*, *Emerald Beam*).
  - **Web Category Browser**: Tab antarmuka web modern dengan filter kategori, pencarian real-time, preview JSON, dan aksi 1-klik.
- ⚡ **Batch Instance Builder (`batch_create_instances`, `batch_set_properties`)**:
  - Membangun hierarki objek/UI bersarang puluhan tingkat secara instan dalam 1 putaran request (mengeliminasi 10–20 latency roundtrips).
  - Pembaruan properti massal secara atomik dengan dukungan penuh tipe data Roblox (`UDim`, `UDim2`, `Vector2`, `Vector3`, `NumberRange`, `Rect`, dll).
- 🛡️ **Asset Security Scanner (`preview_asset`, `scan_security`, safe `insert_asset`)**:
  - Audit 10 jenis ancaman berbahaya (backdoor `require`, bytecode/hex obfuscation, `loadstring`, Discord webhook loggers, IP stealer, fake gamepass prompt, off-screen hidden padding).
  - Pratinjau aset terisolasi sebelum dimasukkan ke game dan auto-sanitasi skrip (`strip_scripts = true` secara default).
- 📚 **Live Roblox Engine API & Docs Lookup (`get_roblox_docs`)**:
  - Mengambil dokumentasi resmi terverifikasi langsung dari Roblox Creator Docs (Class, Datatype, Enum, Library, dan Service).
  - Dilengkapi filter nama member spesifik dan caching disk lokal super cepat (~2 ms) untuk mencegah halusinasi kode Luau.
- 🎨 **Standarisasi Desain GUI & Smart Responsive Scaling**:
  - Panduan baku UI modern (*Dark Modern Theme* #1C1C1E, #191919, aksen Cyan #00AAFF).
  - Deteksi perangkat responsif pintar (`GetDeviceType` memisahkan PC, Phone, Tablet, dan Console secara terisolasi).
- 🔄 **Real-Time Polling Stream & Visual Dashboard**:
  - Komunikasi sub-detik yang sangat stabil dan bebas latensi. Buka [http://localhost:3055](http://localhost:3055) di browser Anda untuk memantau antrean perintah, status koneksi Studio, dan log eksekusi.
- 🧹 **Anti-Zombie Port & Auto-Connect**:
  - Port `3055` dibersihkan secara otomatis jika terjadi force-close, dan plugin Studio otomatis terhubung tanpa perlu menekan tombol manual.

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
3. 🧠 **Universal AI Skill Installer**: Menginjeksi skill pemandu (*nvstudio-mcp-guide*, *nvstudio-gui-standards*, *nvstudio-animation-vfx*, *nvstudio-rig-engine*, *nvstudio-assets-terrain-guide*, *nvstudio-roblox-sync-guide*) dan aturan anti-halusinasi langsung ke struktur editor AI Anda (**Antigravity IDE**, **Cursor**, **Claude Code**, **Codex**, **OpenCode**, dan **Windsurf**).
4. ⚙️ Melakukan auto-konfigurasi registrasi MCP server pada editor yang terdeteksi.

---

### Langkah 2: Mengaktifkan Izin di Roblox Studio (Wajib)

Karena pembatasan keamanan bawaan Roblox Studio, akses HTTP harus diizinkan sekali per place/game:
1. Buka game/place Anda di **Roblox Studio**.
2. Di toolbar atas, buka tab **Home** ➔ **Game Settings** ➔ pilih menu **Security**.
3. Centang (aktifkan) **`Allow HTTP Requests`**, lalu klik **Save**.
4. **Auto-Detect Aktif!** Plugin Roblox Studio akan otomatis terhubung (*Connected*) segera setelah server bridge aktif.

---

### 📂 Alternatif: Instalasi Plugin Secara Manual (Opsional)

Jika Anda **tidak** menggunakan skrip installer otomatis di atas (misalnya hanya menambahkan server via `npx` di klien AI), pasang file plugin Roblox Studio secara manual:
1. Ambil file `nvstudio_mcp.rbxmx` dari folder `studio-plugin/nvstudio_mcp.rbxmx`.
2. Pindahkan/salin file tersebut ke direktori plugin Roblox di komputer Anda:
   - **Windows:** `%LOCALAPPDATA%\Roblox\Plugins`
   - **macOS:** `~/Documents/ROBLOX/Plugins`
3. Buka atau buka kembali Roblox Studio. Plugin akan muncul di tab **Plugins**.

---

## 🔌 Cara Menggunakan (Konfigurasi MCP Klien AI)

### Klien Berbasis NPM (Cursor, Claude Desktop, Windsurf)
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

### Klien Berbasis Instalasi Lokal (Antigravity IDE)
Jika Anda menggunakan instalasi lokal via installer di `%USERPROFILE%\.nvstudio-mcp`, tambahkan ke `~/.gemini/config/mcp_config.json`:
```json
{
  "mcpServers": {
    "nvstudio-mcp": {
      "command": "node",
      "args": [
        "C:/Users/<Username>/.nvstudio-mcp/dist/index.js"
      ]
    }
  }
}
```

---

## 🗑️ Cara Uninstall (Mencopot Pemasangan)

Jika Anda ingin membersihkan `nvstudio-mcp` dari sistem Anda secara menyeluruh:

1. **Hapus Plugin dari Roblox Studio:**
   - Hapus file `nvstudio_mcp.rbxmx` dari `%LOCALAPPDATA%\Roblox\Plugins` (Windows) atau `~/Documents/ROBLOX/Plugins` (macOS).
2. **Hapus AI Plugin Antigravity:**
   ```bash
   rm -rf ~/.gemini/config/plugins/nvstudio-mcp
   ```
3. **Hapus Direktori Instalasi Node.js:**
   ```bash
   rm -rf ~/.nvstudio-mcp
   ```
4. **Hapus Konfigurasi MCP:**
   Hapus blok `"nvstudio-mcp"` dari file konfigurasi `mcp.json` editor AI Anda.

---

**Selamat Menciptakan Game Impian Anda dengan AI! 🎮🤖**
