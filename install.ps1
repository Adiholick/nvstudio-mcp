# PowerShell Installer untuk nvstudio-mcp
$ErrorActionPreference = "Stop"

Write-Host "[*] Memulai instalasi nvstudio-mcp..." -ForegroundColor Cyan

# 1. Pengecekan Prasyarat
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Node.js tidak ditemukan! Silakan instal Node.js terlebih dahulu." -ForegroundColor Red
    exit 1
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Git tidak ditemukan! Silakan instal Git terlebih dahulu." -ForegroundColor Red
    exit 1
}

# 2. Penentuan Direktori Instalasi Lokal
$InstallDir = Join-Path $HOME ".nvstudio-mcp"

if (Test-Path $InstallDir) {
    Write-Host "[*] Memperbarui nvstudio-mcp yang sudah ada di $InstallDir..." -ForegroundColor Yellow
    Set-Location $InstallDir
    git reset --hard HEAD
    git clean -fd
    git pull origin main
} else {
    Write-Host "[*] Mengunduh nvstudio-mcp..." -ForegroundColor Green
    git clone https://github.com/Adiholick/nvstudio-mcp.git $InstallDir
    Set-Location $InstallDir
}

# 3. Instalasi & Kompilasi Node.js
Write-Host "[*] Menghentikan instance nvstudio-mcp lama jika sedang berjalan..." -ForegroundColor Cyan
try {
    $existing = Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%nvstudio%'" -ErrorAction SilentlyContinue
    foreach ($p in $existing) {
        if ($p.ProcessId -ne $PID) {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        }
    }
} catch {}

Write-Host "[*] Menginstal dependensi Node.js..." -ForegroundColor Cyan
npm install

Write-Host "[*] Mengkompilasi TypeScript & Plugin..." -ForegroundColor Cyan
npm run build

# 4. Pemasangan Plugin Studio (.rbxmx / .rbxm)
Write-Host "[*] Memasang Plugin Roblox Studio..." -ForegroundColor Cyan
$PluginDir = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"

if (-not (Test-Path $PluginDir)) {
    New-Item -ItemType Directory -Force -Path $PluginDir | Out-Null
}

$PluginSourceX = Join-Path $InstallDir "studio-plugin\nvstudio_mcp.rbxmx"
$PluginSourceM = Join-Path $InstallDir "studio-plugin\nvstudio_mcp.rbxm"

if (Test-Path $PluginSourceX) {
    Copy-Item -Force $PluginSourceX $PluginDir
    Write-Host "[OK] Plugin nvstudio_mcp.rbxmx berhasil dipasang ke: $PluginDir" -ForegroundColor Green
} elseif (Test-Path $PluginSourceM) {
    Copy-Item -Force $PluginSourceM $PluginDir
    Write-Host "[OK] Plugin nvstudio_mcp.rbxm berhasil dipasang ke: $PluginDir" -ForegroundColor Green
} else {
    Write-Host "[WARN] File nvstudio_mcp.rbxmx belum dicompile. Harap compile secara manual!" -ForegroundColor Yellow
}

# 5. Hybrid AI Installer (Antigravity & Cursor)
Write-Host "[*] Menyiapkan AI Agent Plugin (Hybrid Method)..." -ForegroundColor Cyan
$AntigravityConfigDir = Join-Path $HOME ".gemini\config"
$AntigravityGlobalMcpFile = Join-Path $AntigravityConfigDir "mcp_config.json"

if (Test-Path $AntigravityConfigDir) {
    Write-Host "   -> Terdeteksi Antigravity IDE. Mendaftarkan MCP Server secara global..." -ForegroundColor Green
    
    $GlobalConfig = @{ "mcpServers" = @{} }
    if (Test-Path $AntigravityGlobalMcpFile) {
        try {
            $GlobalConfig = Get-Content $AntigravityGlobalMcpFile -Raw | ConvertFrom-Json -AsHashtable
        } catch {
            $GlobalConfig = @{ "mcpServers" = @{} }
        }
    }
    
    if (-not $GlobalConfig.ContainsKey("mcpServers") -or $GlobalConfig["mcpServers"] -eq $null) {
        $GlobalConfig["mcpServers"] = @{}
    }
    
    $NodeExe = "node"
    $DistJs = (Join-Path $InstallDir "dist\index.js").Replace("\", "/")
    
    $GlobalConfig["mcpServers"]["nvstudio-mcp"] = @{
        "command" = $NodeExe;
        "args" = @($DistJs)
    }
    
    $GlobalConfig | ConvertTo-Json -Depth 5 | Set-Content $AntigravityGlobalMcpFile -Encoding UTF8
    Write-Host "[OK] NVStudio MCP terdaftar di konfigurasi global Antigravity ($AntigravityGlobalMcpFile)" -ForegroundColor Green
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
        Write-Host "[OK] Berhasil menginjeksi konfigurasi ke .cursor/mcp.json" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Gagal menginjeksi .cursor/mcp.json: $_" -ForegroundColor Yellow
    }
}

# 6. Selesai
Write-Host ""
Write-Host "[SUCCESS] Instalasi nvstudio-mcp Selesai!" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Status:"
Write-Host " - Roblox Studio Plugin : Terpasang di AppData\Local\Roblox\Plugins"
Write-Host " - MCP IDE Configuration: Terkonfigurasi untuk Antigravity / Cursor"
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Jangan lupa izinkan 'HTTP Requests' di Game Settings Roblox Studio!" -ForegroundColor Yellow
