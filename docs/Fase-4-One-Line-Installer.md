# BLUEPRINT: nvstudio-mcp (Fase 4 - One-Line Installer)

**Tujuan:** Instruksi ini dirancang untuk dieksekusi oleh AI Agent. Eksekusi instruksi ini untuk membuat skrip `install.sh` (Bash) yang akan mengotomatiskan pengunduhan, kompilasi Node.js, dan pemasangan Plugin Roblox Studio hanya dengan satu baris perintah.

### Langkah 1: Buat File Skrip Instalasi
1. Di dalam *root* direktori proyek `nvstudio-mcp`, buat sebuah file baru bernama `install.sh`.
2. Tuliskan (salin) seluruh *source code* Bash di bawah ini ke dalam file `install.sh`.

```bash
#!/bin/bash
set -e

echo "🚀 Memulai instalasi nvstudio-mcp..."

# 1. Pengecekan Prasyarat
if ! command -v node &> /dev/null; then
    echo "❌ Node.js tidak ditemukan! Silakan instal Node.js terlebih dahulu."
    exit 1
fi
if ! command -v git &> /dev/null; then
    echo "❌ Git tidak ditemukan! Silakan instal Git terlebih dahulu."
    exit 1
fi

# 2. Penentuan Direktori Instalasi Lokal
INSTALL_DIR="$HOME/.nvstudio-mcp"

if [ -d "$INSTALL_DIR" ]; then
    echo "🔄 Memperbarui nvstudio-mcp yang sudah ada di $INSTALL_DIR..."
    cd "$INSTALL_DIR"
    git pull origin main
else
    echo "📥 Mengunduh nvstudio-mcp..."
    # CATATAN UNTUK USER: Ubah 'USERNAME' dengan username GitHub Anda setelah proyek di-push
    git clone https://github.com/USERNAME/nvstudio-mcp.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# 3. Instalasi & Kompilasi Node.js
echo "📦 Menginstal dependensi Node.js..."
npm install

echo "🛠️ Mengkompilasi TypeScript..."
npm run build

# 4. Deteksi OS & Pemasangan Plugin Otomatis
echo "🧩 Memasang Plugin Roblox Studio..."
PLUGIN_DIR=""

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Git Bash / Windows
    PLUGIN_DIR="$LOCALAPPDATA/Roblox/Plugins"
elif grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    # WSL di Windows
    WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
    PLUGIN_DIR="/mnt/c/Users/$WIN_USER/AppData/Local/Roblox/Plugins"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    PLUGIN_DIR="$HOME/Documents/ROBLOX/Plugins"
fi

if [ -n "$PLUGIN_DIR" ]; then
    mkdir -p "$PLUGIN_DIR"
    cp plugin/nvstudio_mcp.server.lua "$PLUGIN_DIR/"
    echo "✅ Plugin berhasil disalin secara otomatis ke: $PLUGIN_DIR"
else
    echo "⚠️ OS tidak terdeteksi secara spesifik. Silakan salin file plugin/nvstudio_mcp.server.lua ke folder Plugins Roblox Studio Anda secara manual."
fi

# 5. Output Konfigurasi Selesai
echo ""
echo "🎉 Instalasi nvstudio-mcp Selesai!"
echo "================================================================="
echo "Untuk menghubungkan AI Anda (Cursor / Claude Desktop / Windsurf):"
echo "1. Buka pengaturan MCP klien AI Anda."
echo "2. Tambahkan server baru dengan konfigurasi berikut:"
echo "   - Name    : nvstudio-mcp"
echo "   - Command : node"
echo "   - Args    : [\"$INSTALL_DIR/dist/index.js\"]"
echo "================================================================="
echo "Jangan lupa izinkan 'HTTP Requests' di Game Settings Roblox Studio!"
```

### Langkah 2: Instruksi Distribusi Publik untuk User
Setelah file `install.sh` ini dibuat, informasikan kepada *User* langkah-langkah berikut untuk mengaktifkan fitur instalasi satu baris (`curl | bash`):
1. *User* harus melakukan *push* seluruh folder proyek `nvstudio-mcp` (termasuk `install.sh`) ke *repository* GitHub publik milik mereka.
2. *User* harus mengubah teks `USERNAME` di dalam `install.sh` (baris ke-26) menjadi *username* GitHub mereka.
3. Setelah diunggah ke GitHub, *user* lain dapat menginstalnya semudah Weppy dengan mengetikkan perintah ini di Git Bash / WSL / Terminal Mac:
   `curl -fsSL [https://raw.githubusercontent.com/USERNAME/nvstudio-mcp/main/install.sh](https://raw.githubusercontent.com/USERNAME/nvstudio-mcp/main/install.sh) | bash`

### Langkah 3: Eksekusi
Eksekusi penulisan file `install.sh` dan sampaikan instruksi publikasi ini kepada *User* sekarang.