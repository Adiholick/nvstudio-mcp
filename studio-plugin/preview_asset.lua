--!strict
-- ============================================================================
-- Skill Module: preview_asset
-- Deskripsi: Pratinjau & Pemindaian Keamanan Aset Creator Store Secara Terisolasi
-- ============================================================================

local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")

local SecurityScanner = require(script.Parent:WaitForChild("security_scanner"))

return function(targetInstance: Instance?, data: any, ctx: any, targetPath: string?)
    local assetIdStr = ""
    local deepScan = true

    if typeof(data) == "string" then
        local success, parsed = pcall(function()
            return HttpService:JSONDecode(data)
        end)
        if success and typeof(parsed) == "table" then
            assetIdStr = tostring(parsed.asset_id or parsed.assetId or "")
            if parsed.deep_scan ~= nil then deepScan = parsed.deep_scan end
        else
            assetIdStr = data
        end
    elseif typeof(data) == "table" then
        assetIdStr = tostring(data.asset_id or data.assetId or "")
        if data.deep_scan ~= nil then deepScan = data.deep_scan end
    end

    local cleanIdStr = string.gsub(assetIdStr, "rbxassetid://", "")
    cleanIdStr = string.gsub(cleanIdStr, "%s+", "")
    local assetId = tonumber(cleanIdStr)

    if not assetId or assetId <= 0 then
        return { status = "error", error = "Asset ID tidak valid. Berikan Asset ID angka (contoh: 123456789)." }
    end

    -- Muat Aset secara terisolasi (unparented / memory only)
    local ok, model = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)

    if not ok or not model then
        return {
            status = "error",
            error = string.format("Gagal memuat aset ID %d. Pastikan Asset ID publik dan terdaftar di Creator Store.", assetId)
        }
    end

    local scanResult
    local scanOk, err = pcall(function()
        scanResult = SecurityScanner.scanInstance(model, deepScan)
    end)

    local rootName = model.Name
    local childrenOverview = {}
    for _, child in ipairs(model:GetChildren()) do
        table.insert(childrenOverview, {
            name = child.Name,
            className = child.ClassName,
        })
    end

    -- Hancurkan model sementara dari memori (Cleanup Mutlak)
    pcall(function()
        model:Destroy()
    end)

    if not scanOk or not scanResult then
        return {
            status = "error",
            error = "Gagal memindai aset: " .. tostring(err)
        }
    end

    local recommendation = "Aman untuk dimasukkan langsung menggunakan insert_asset."
    if scanResult.riskLevel == "DANGEROUS" then
        recommendation = "PERINGATAN: Aset ini memiliki ancaman BERBAHAYA! Wajib gunakan 'insert_asset' dengan strip_scripts = true, atau hindari aset ini."
    elseif scanResult.riskLevel == "WARNING" then
        recommendation = "Perhatian: Aset mengandung skrip atau peringatan moderat. Periksa kembali atau gunakan strip_scripts = true jika skrip tidak diperlukan."
    end

    return {
        status = "success",
        result = {
            assetId = assetId,
            assetName = rootName,
            riskLevel = scanResult.riskLevel,
            recommendation = recommendation,
            stats = scanResult.stats,
            highThreatsCount = scanResult.highThreats,
            mediumThreatsCount = scanResult.mediumThreats,
            threats = scanResult.threats,
            topLevelChildren = childrenOverview,
        }
    }
end

