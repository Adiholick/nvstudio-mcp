--!strict
-- ============================================================================
-- Module: security_scanner
-- Deskripsi: Engine Heuristik Pemindaian Keamanan & Backdoor Detection
-- Standar: Business-Grade, Zero-Execution Isolation, Comprehensive Threat Rules
-- ============================================================================

local SecurityScanner = {}

-- Daftar nama skrip yang sering digunakan oleh virus/backdoor klasik Roblox
local SUSPICIOUS_SCRIPT_NAMES = {
    "[Vv]accine",
    "[Aa]nti[Ll]ag",
    "[Ff]ix[Ll]ag",
    "[Ii]nfection",
    "[Ff]ire",
    "[Cc]lean",
    "[Vv]irus",
    "4[Dd]",
    "4[Dd]_[Pp]lugin",
    "[Ss]pread",
    "[Ll]ag[Ff]ixer",
    "[Dd]up",
}

-- Aturan Pola Heuristik Kode Berbahaya
local THREAT_PATTERNS = {
    {
        id = "BACKDOOR_REQUIRE",
        pattern = "require%s*%(%s*%d+%s*%)",
        severity = "HIGH",
        name = "Backdoor Numeric Require",
        description = "Memanggil modul eksternal pihak ketiga via Asset ID numerik (indikasi backdoor/remote loader).",
    },
    {
        id = "LOADSTRING_EXEC",
        pattern = "loadstring%s*%(",
        severity = "HIGH",
        name = "Dynamic Code Execution (loadstring)",
        description = "Mengeksekusi string kode dinamis yang tidak dapat diaudit.",
    },
    {
        id = "GETFENV_SETFENV",
        pattern = "[gs]etfenv%s*%(",
        severity = "HIGH",
        name = "Environment Manipulation (getfenv/setfenv)",
        description = "Memanipulasi environment global Luau untuk mengelabui analisis statis.",
    },
    {
        id = "DISCORD_WEBHOOK",
        pattern = "discord[a-z]*%.com/api/webhooks",
        severity = "HIGH",
        name = "Discord Webhook Exfiltration",
        description = "Mencoba mengirimkan data game atau informasi pemain ke webhook eksternal Discord.",
    },
    {
        id = "IP_LOGGER",
        pattern = "webhook%.site|grabify%.link|iplogger|blasze",
        severity = "HIGH",
        name = "External IP/Data Logger",
        description = "Menghubungi domain pencatat IP atau data capture pihak ketiga.",
    },
    {
        id = "FORCED_PURCHASE",
        pattern = "MarketplaceService%s*:%s*Prompt[A-Za-z]*Purchase",
        severity = "MEDIUM",
        name = "Forced Robux/Product Purchase",
        description = "Memicu dialog pembelian paksa Gamepass atau Developer Product.",
    },
    {
        id = "FORCED_TELEPORT",
        pattern = "TeleportService%s*:%s*Teleport",
        severity = "MEDIUM",
        name = "Forced Game Teleportation",
        description = "Memindahkan pemain secara paksa ke game/place lain.",
    },
    {
        id = "CHAR_TABLE_OBFUSCATION",
        pattern = "string%.char%s*%(%s*%d+%s*,%s*%d+%s*,%s*%d+",
        severity = "HIGH",
        name = "Obfuscated string.char Array",
        description = "Menyusun kode rahasia tersembunyi menggunakan deretan kode karakter ASCII.",
    },
}

-- Helper: Pengecekan nama script mencurigakan
local function checkSuspiciousName(name: string): boolean
    for _, pattern in ipairs(SUSPICIOUS_SCRIPT_NAMES) do
        if string.find(name, pattern) then
            return true
        end
    end
    return false
end

-- Helper: Deteksi obfuscation byte escape (\108\111\97\100) atau hex (\x6c\x6f)
local function checkByteObfuscation(source: string): (boolean, string?)
    local byteCount = 0
    for _ in string.gmatch(source, "\\[0-9][0-9][0-9]") do
        byteCount = byteCount + 1
        if byteCount >= 4 then
            return true, "Terdeteksi deretan escape byte ASCII (\\ddd) berulang."
        end
    end

    local hexCount = 0
    for _ in string.gmatch(source, "\\x[0-9a-fA-F][0-9a-fA-F]") do
        hexCount = hexCount + 1
        if hexCount >= 4 then
            return true, "Terdeteksi deretan escape hex (\\xHH) berulang."
        end
    end

    return false, nil
end

-- Helper: Deteksi kode yang sengaja disembunyikan dengan spasi/baris kosong berlebih
local function checkOffscreenHiding(source: string): (boolean, string?)
    -- Cek spasi horizontal masif (> 80 spasi berturut-turut)
    if string.find(source, "   " .. string.rep(" ", 80)) then
        return true, "Kode sengaja didorong ke kanan dengan lebih dari 80 spasi agar tersembunyi dari layar Studio."
    end

    -- Cek baris kosong masif di awal skrip (> 15 baris kosong)
    local leadingNewlines = 0
    for line in string.gmatch(source, "([^\r\n]*)\r?\n") do
        if string.gsub(line, "%s+", "") == "" then
            leadingNewlines = leadingNewlines + 1
            if leadingNewlines >= 15 then
                return true, "Terdapat lebih dari 15 baris kosong di awal skrip untuk menyembunyikan payload di baris bawah."
            end
        else
            break
        end
    end

    return false, nil
end

-- Analisis Source Code dari sebuah Script
local function scanScriptSource(scriptInstance: Instance, source: string): { any }
    local threats = {}
    local lines = string.split(source, "\n")

    -- 1. Scan pola heuristik baris per baris
    for lineIdx, line in ipairs(lines) do
        -- Skip baris komentar murni
        local trimmed = string.match(line, "^%s*(.-)%s*$") or ""
        if not string.sub(trimmed, 1, 2) == "--" then
            for _, rule in ipairs(THREAT_PATTERNS) do
                local s, e = string.find(line, rule.pattern)
                if s then
                    local snippet = string.sub(line, math.max(1, s - 30), math.min(#line, e + 30))
                    table.insert(threats, {
                        severity = rule.severity,
                        ruleId = rule.id,
                        name = rule.name,
                        scriptName = scriptInstance.Name,
                        scriptPath = scriptInstance:GetFullName(),
                        scriptClass = scriptInstance.ClassName,
                        line = lineIdx,
                        snippet = string.match(snippet, "^%s*(.-)%s*$") or snippet,
                        description = rule.description,
                    })
                end
            end
        end
    end

    -- 2. Cek Obfuscation
    local isObf, obfReason = checkByteObfuscation(source)
    if isObf then
        table.insert(threats, {
            severity = "HIGH",
            ruleId = "BYTE_OBFUSCATION",
            name = "Byte / Hex Obfuscation Payload",
            scriptName = scriptInstance.Name,
            scriptPath = scriptInstance:GetFullName(),
            scriptClass = scriptInstance.ClassName,
            line = 1,
            snippet = string.sub(source, 1, 60) .. "...",
            description = obfReason or "Payload kode disamarkan menggunakan escape bytes.",
        })
    end

    -- 3. Cek Off-screen Code Hiding
    local isHidden, hideReason = checkOffscreenHiding(source)
    if isHidden then
        table.insert(threats, {
            severity = "HIGH",
            ruleId = "OFFSCREEN_HIDING",
            name = "Off-Screen Hidden Code",
            scriptName = scriptInstance.Name,
            scriptPath = scriptInstance:GetFullName(),
            scriptClass = scriptInstance.ClassName,
            line = 1,
            snippet = "[Whitespace Padding Terdeteksi]",
            description = hideReason or "Kode disembunyikan menggunakan whitespace ekstrem.",
        })
    end

    return threats
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Memindai Instance secara rekursif
function SecurityScanner.scanInstance(rootInstance: Instance, deepScan: boolean?)
    local shouldDeepScan = (deepScan ~= false)
    local allThreats = {}
    local stats = {
        totalInstances = 1,
        models = 0,
        parts = 0,
        meshParts = 0,
        textures = 0,
        scripts = {
            total = 0,
            server = 0,
            localScript = 0,
            module = 0,
        },
    }

    local function inspectItem(item: Instance)
        stats.totalInstances = stats.totalInstances + 1

        if item:IsA("Model") then
            stats.models = stats.models + 1
        elseif item:IsA("MeshPart") then
            stats.meshParts = stats.meshParts + 1
            stats.parts = stats.parts + 1
        elseif item:IsA("BasePart") then
            stats.parts = stats.parts + 1
        elseif item:IsA("Texture") or item:IsA("Decal") or item:IsA("SurfaceAppearance") then
            stats.textures = stats.textures + 1
        end

        if item:IsA("LuaSourceContainer") then
            stats.scripts.total = stats.scripts.total + 1
            if item:IsA("Script") then
                stats.scripts.server = stats.scripts.server + 1
            elseif item:IsA("LocalScript") then
                stats.scripts.localScript = stats.scripts.localScript + 1
            elseif item:IsA("ModuleScript") then
                stats.scripts.module = stats.scripts.module + 1
            end

            -- Cek nama mencurigakan
            if checkSuspiciousName(item.Name) then
                table.insert(allThreats, {
                    severity = "HIGH",
                    ruleId = "SUSPICIOUS_SCRIPT_NAME",
                    name = "Known Malicious Script Name Pattern",
                    scriptName = item.Name,
                    scriptPath = item:GetFullName(),
                    scriptClass = item.ClassName,
                    line = 0,
                    snippet = item.Name,
                    description = string.format("Nama skrip '%s' cocok dengan pola nama virus/backdoor klasik.", item.Name),
                })
            end

            -- Deep scan isi source code
            if shouldDeepScan then
                local success, source = pcall(function()
                    return (item :: any).Source
                end)
                if success and typeof(source) == "string" and #source > 0 then
                    local scriptThreats = scanScriptSource(item, source)
                    for _, t in ipairs(scriptThreats) do
                        table.insert(allThreats, t)
                    end
                end
            end
        end
    end

    inspectItem(rootInstance)
    for _, desc in ipairs(rootInstance:GetDescendants()) do
        inspectItem(desc)
    end

    -- Hitung Level Risiko
    local riskLevel = "SAFE"
    local highCount = 0
    local medCount = 0

    for _, t in ipairs(allThreats) do
        if t.severity == "HIGH" then
            highCount = highCount + 1
        elseif t.severity == "MEDIUM" then
            medCount = medCount + 1
        end
    end

    if highCount > 0 then
        riskLevel = "DANGEROUS"
    elseif medCount > 0 or stats.scripts.total > 0 then
        riskLevel = "WARNING"
    end

    return {
        riskLevel = riskLevel,
        threats = allThreats,
        stats = stats,
        highThreats = highCount,
        mediumThreats = medCount,
    }
end

-- Menghapus seluruh skrip dari sebuah instance (Sanitasi Total)
function SecurityScanner.stripScripts(rootInstance: Instance): { any }
    local removed = {}

    for _, desc in ipairs(rootInstance:GetDescendants()) do
        if desc:IsA("LuaSourceContainer") then
            table.insert(removed, {
                name = desc.Name,
                className = desc.ClassName,
                path = desc:GetFullName(),
            })
            pcall(function()
                desc:Destroy()
            end)
        end
    end

    if rootInstance:IsA("LuaSourceContainer") then
        table.insert(removed, {
            name = rootInstance.Name,
            className = rootInstance.ClassName,
            path = rootInstance:GetFullName(),
        })
        pcall(function()
            rootInstance:Destroy()
        end)
    end

    return removed
end

return SecurityScanner

