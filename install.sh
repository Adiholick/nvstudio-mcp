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

# 4. Pemasangan Plugin Studio (.rbxmx / .rbxm)
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
    if [ -f "studio-plugin/nvstudio_mcp.rbxmx" ]; then
        cp studio-plugin/nvstudio_mcp.rbxmx "$PLUGIN_DIR/"
        echo "✅ Plugin nvstudio_mcp.rbxmx berhasil dipasang ke: $PLUGIN_DIR"
    elif [ -f "studio-plugin/nvstudio_mcp.rbxm" ]; then
        cp studio-plugin/nvstudio_mcp.rbxm "$PLUGIN_DIR/"
        echo "✅ Plugin nvstudio_mcp.rbxm berhasil dipasang ke: $PLUGIN_DIR"
    else
        echo "⚠️  File nvstudio_mcp.rbxmx belum dicompile (Tidak ditemukan di folder). Harap compile secara manual sesuai instruksi!"
    fi
else
    echo "⚠️ OS tidak terdeteksi secara spesifik. Silakan pasang file plugin secara manual."
fi

# 5. Hybrid AI Installer
echo "🤖 Menyiapkan AI Agent Plugin (Hybrid Method)..."
ANTIGRAVITY_PLUGIN_DIR="$HOME/.gemini/config/plugins/nvstudio-mcp"

# A. Instalasi Bundle ke Antigravity
if [ -d "$HOME/.gemini/config/plugins" ]; then
    echo "   -> Terdeteksi Antigravity IDE. Memasang AI Agent Plugin Bundle..."
    mkdir -p "$ANTIGRAVITY_PLUGIN_DIR"
    cp -R agent-plugin/* "$ANTIGRAVITY_PLUGIN_DIR/"
    echo "✅ Bundle terpasang di $ANTIGRAVITY_PLUGIN_DIR"
else
    echo "   -> Antigravity IDE tidak terdeteksi. Melewati instalasi bundle."
fi

# B. Auto-Configurator untuk editor lain (Misal Cursor) via node script sederhana
echo "   -> Mengeksekusi injeksi MCP JSON (Cursor Auto-Configurator jika direktori .cursor ditemukan)..."
node --input-type=commonjs -e '
const fs = require("fs");
const path = require("path");
const configPath = path.join(process.cwd(), ".cursor", "mcp.json");
if (fs.existsSync(path.dirname(configPath))) {
    let config = {};
    try { config = JSON.parse(fs.readFileSync(configPath, "utf8")); } catch(e) {}
    if (!config.mcpServers) config.mcpServers = {};
    config.mcpServers["nvstudio-mcp"] = {
        command: "node",
        args: [process.cwd() + "/dist/index.js"]
    };
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
    console.log("✅ Berhasil menginjeksi konfigurasi ke .cursor/mcp.json");
}
' || true

# 6. Output Konfigurasi Selesai
echo ""
echo "🎉 Instalasi nvstudio-mcp Selesai!"
echo "================================================================="
echo "Untuk menghubungkan AI yang tidak terdeteksi secara otomatis:"
echo "1. Buka pengaturan MCP klien AI Anda."
echo "2. Tambahkan server baru dengan konfigurasi berikut:"
echo "   - Name    : nvstudio-mcp"
echo "   - Command : node"
echo "   - Args    : [\"$INSTALL_DIR/dist/index.js\"]"
echo "================================================================="
echo "Jangan lupa izinkan 'HTTP Requests' di Game Settings Roblox Studio!"
