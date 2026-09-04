# PowerShell Installer untuk nvstudio-mcp
$ErrorActionPreference = "Stop"

Write-Host "🚀 Memulai instalasi nvstudio-mcp..." -ForegroundColor Cyan

# 1. Pengecekan Prasyarat
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Node.js tidak ditemukan! Silakan instal Node.js terlebih dahulu." -ForegroundColor Red
    exit 1
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Git tidak ditemukan! Silakan instal Git terlebih dahulu." -ForegroundColor Red
    exit 1
}

# 2. Penentuan Direktori Instalasi Lokal
$InstallDir = Join-Path $HOME ".nvstudio-mcp"

if (Test-Path $InstallDir) {
    Write-Host "🔄 Memperbarui nvstudio-mcp yang sudah ada di $InstallDir..." -ForegroundColor Yellow
    Set-Location $InstallDir
    git pull origin main
} else {
    Write-Host "📥 Mengunduh nvstudio-mcp..." -ForegroundColor Green
    git clone https://github.com/Adiholick/nvstudio-mcp.git $InstallDir
    Set-Location $InstallDir
}

# 3. Instalasi & Kompilasi Node.js
Write-Host "📦 Menginstal dependensi Node.js..." -ForegroundColor Cyan
npm install

Write-Host "🛠️ Mengkompilasi TypeScript..." -ForegroundColor Cyan
npm run build

# 4. Pemasangan Plugin Studio (.rbxmx / .rbxm)
Write-Host "🧩 Memasang Plugin Roblox Studio..." -ForegroundColor Cyan
$PluginDir = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"

if (-not (Test-Path $PluginDir)) {
    New-Item -ItemType Directory -Force -Path $PluginDir | Out-Null
}

$PluginSourceX = Join-Path $InstallDir "studio-plugin\nvstudio_mcp.rbxmx"
$PluginSourceM = Join-Path $InstallDir "studio-plugin\nvstudio_mcp.rbxm"

if (Test-Path $PluginSourceX) {
    Copy-Item -Force $PluginSourceX $PluginDir
    Write-Host "✅ Plugin nvstudio_mcp.rbxmx berhasil dipasang ke: $PluginDir" -ForegroundColor Green
} elseif (Test-Path $PluginSourceM) {
    Copy-Item -Force $PluginSourceM $PluginDir
    Write-Host "✅ Plugin nvstudio_mcp.rbxm berhasil dipasang ke: $PluginDir" -ForegroundColor Green
} else {
    Write-Host "⚠️  File nvstudio_mcp.rbxmx belum dicompile (Tidak ditemukan di folder). Harap compile secara manual sesuai instruksi!" -ForegroundColor Yellow
}

# 5. Hybrid AI Installer (Antigravity & Cursor)
Write-Host "🤖 Menyiapkan AI Agent Plugin (Hybrid Method)..." -ForegroundColor Cyan
$AntigravityBase = Join-Path $HOME ".gemini\config\plugins"
$AntigravityPluginDir = Join-Path $AntigravityBase "nvstudio-mcp"

if (Test-Path $AntigravityBase) {
    Write-Host "   -> Terdeteksi Antigravity IDE. Memasang AI Agent Plugin Bundle..." -ForegroundColor Green
    if (-not (Test-Path $AntigravityPluginDir)) {
        New-Item -ItemType Directory -Force -Path $AntigravityPluginDir | Out-Null
    }
    Copy-Item -Recurse -Force (Join-Path $InstallDir "agent-plugin\*") $AntigravityPluginDir
    Write-Host "✅ Bundle terpasang di $AntigravityPluginDir" -ForegroundColor Green
} else {
    Write-Host "   -> Antigravity IDE tidak terdeteksi. Melewati instalasi bundle." -ForegroundColor Gray
}

# Injeksi Cursor mcp.json jika direktori .cursor ditemukan
$CursorDir = Join-Path (Get-Location) ".cursor"
$CursorMcp = Join-Path $CursorDir "mcp.json"
if (Test-Path $CursorDir) {
    try {
        $Config = @{}
        if (Test-Path $CursorMcp) {
            $Config = Get-Content $CursorMcp -Raw | ConvertFrom-Json -AsHashtable
        }
        if (-not $Config.ContainsKey("mcpServers")) {
            $Config["mcpServers"] = @{}
        }
        $Config["mcpServers"]["nvstudio-mcp"] = @{
            "command" = "npx";
            "args" = @("-y", "@adiholick/nvstudio-mcp@latest")
        }
        $Config | ConvertTo-Json -Depth 10 | Set-Content $CursorMcp -Encoding UTF8
        Write-Host "✅ Berhasil menginjeksi konfigurasi ke .cursor/mcp.json" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Gagal menginjeksi .cursor/mcp.json: $_" -ForegroundColor Yellow
    }
}

# 6. Output Konfigurasi Selesai
Write-Host ""
Write-Host "🎉 Instalasi nvstudio-mcp Selesai!" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Untuk menghubungkan AI yang tidak terdeteksi secara otomatis:"
Write-Host "1. Buka pengaturan MCP klien AI Anda."
Write-Host "2. Tambahkan server baru dengan konfigurasi berikut:"
Write-Host "   - Name    : nvstudio-mcp"
Write-Host "   - Command : npx"
Write-Host "   - Args    : [`"-y`", `"@adiholick/nvstudio-mcp@latest`"]"
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Jangan lupa izinkan 'HTTP Requests' di Game Settings Roblox Studio!" -ForegroundColor Yellow
