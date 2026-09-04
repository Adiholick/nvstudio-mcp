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
    git clone https://github.com/Adiholick/nvstudio-mcp.git "$INSTALL_DIR"
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
