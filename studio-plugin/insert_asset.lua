--!strict
-- ============================================================================
-- Skill Module: insert_asset (Upgraded with Asset Security Scanner & Script Stripper)
-- ============================================================================

local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")

local SecurityScanner = require(script.Parent:WaitForChild("security_scanner"))

return function(targetInstance: Instance?, data: any, ctx: any, targetPath: string?)
    local assetIdStr = ""
    local stripScripts = true  -- Default TRUE demi keamanan mutlak
    local scanSecurity = true

    if typeof(data) == "string" then
        local success, parsed = pcall(function()
            return HttpService:JSONDecode(data)
        end)
        if success and typeof(parsed) == "table" then
            assetIdStr = tostring(parsed.asset_id or parsed.assetId or "")
            if parsed.strip_scripts ~= nil then stripScripts = parsed.strip_scripts end
            if parsed.scan_security ~= nil then scanSecurity = parsed.scan_security end
        else
            assetIdStr = data
        end
    elseif typeof(data) == "table" then
        assetIdStr = tostring(data.asset_id or data.assetId or "")
        if data.strip_scripts ~= nil then stripScripts = data.strip_scripts end
        if data.scan_security ~= nil then scanSecurity = data.scan_security end
    end

    local rawId = string.gsub(assetIdStr, "rbxassetid://", "")
    rawId = string.gsub(rawId, "%s+", "")
    local assetId = tonumber(rawId)

    if not assetId or assetId <= 0 then
        return { status = "error", error = "Asset ID harus berupa angka yang valid." }
    end

    local success, model = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)

    if not success or not model then
        return {
            status = "error",
            error = "Gagal memuat aset. Pastikan Asset ID benar dan model berstatus publik di Creator Store."
        }
    end

    local securityNotes = {}
    local removedScripts = {}

    -- 1. Scan keamanan jika diaktifkan
    if scanSecurity then
        local scanResult = SecurityScanner.scanInstance(model, true)
        if scanResult.riskLevel == "DANGEROUS" then
            table.insert(securityNotes, string.format("⚠️ PERINGATAN: Aset ini memiliki %d ancaman BERBAHAYA (Backdoor/Obfuscation/Webhook)!", scanResult.highThreats))
        end
    end

    -- 2. Sanitasi: Hapus skrip jika strip_scripts = true
    if stripScripts then
        removedScripts = SecurityScanner.stripScripts(model)
        if #removedScripts > 0 then
            table.insert(securityNotes, string.format("🛡️ Keamanan: %d skrip bawaan telah dihapus secara otomatis demi keamanan game Anda.", #removedScripts))
        else
            table.insert(securityNotes, "🛡️ Keamanan: Aset bersih, tidak ditemukan skrip berbahaya.")
        end
    else
        table.insert(securityNotes, "ℹ️ Catatan: strip_scripts = false, skrip bawaan model dipertahankan.")
    end

    -- 3. Masukkan model ke target
    local parentTarget = targetInstance
    if not parentTarget or parentTarget == game or parentTarget.ClassName == "DataModel" then
        parentTarget = game.Workspace
    end

    model.Parent = parentTarget

    return {
        status = "success",
        result = {
            message = string.format("Aset '%s' (ID: %d) berhasil dimasukkan ke %s.", model.Name, assetId, parentTarget.Name),
            assetName = model.Name,
            assetId = assetId,
            parent = parentTarget:GetFullName(),
            stripScriptsApplied = stripScripts,
            removedScriptsCount = #removedScripts,
            removedScripts = removedScripts,
            securityNotes = table.concat(securityNotes, "\n"),
        }
    }
end
