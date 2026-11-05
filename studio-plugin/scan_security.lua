--!strict
-- ============================================================================
-- Skill Module: scan_security
-- Deskripsi: Audit Keamanan Instance/Model yang Sudah Ada di Tempat Kerja Studio
-- ============================================================================

local HttpService = game:GetService("HttpService")
local SecurityScanner = require(script.Parent:WaitForChild("security_scanner"))

return function(targetInstance: Instance?, data: any, ctx: any, targetPath: string?)
    local target = targetInstance or game.Workspace
    local deepScan = true
    local cleanThreats = false

    if typeof(data) == "string" and #data > 0 then
        local success, parsed = pcall(function()
            return HttpService:JSONDecode(data)
        end)
        if success and typeof(parsed) == "table" then
            if parsed.deep_scan ~= nil then deepScan = parsed.deep_scan end
            if parsed.clean_threats ~= nil then cleanThreats = parsed.clean_threats end
        end
    elseif typeof(data) == "table" then
        if data.deep_scan ~= nil then deepScan = data.deep_scan end
        if data.clean_threats ~= nil then cleanThreats = data.clean_threats end
    end

    local scanResult
    local ok, err = pcall(function()
        scanResult = SecurityScanner.scanInstance(target, deepScan)
    end)

    if not ok or not scanResult then
        return {
            status = "error",
            error = "Gagal memindai target: " .. tostring(err)
        }
    end

    local cleanedScripts = {}
    if cleanThreats and #scanResult.threats > 0 then
        -- Hapus skrip yang terdeteksi bahaya (HIGH severity)
        local scriptsToDestroy = {}
        for _, threat in ipairs(scanResult.threats) do
            if threat.severity == "HIGH" and threat.scriptPath then
                scriptsToDestroy[threat.scriptPath] = true
            end
        end

        local function purge(instance: Instance)
            for _, desc in ipairs(instance:GetDescendants()) do
                if desc:IsA("LuaSourceContainer") and scriptsToDestroy[desc:GetFullName()] then
                    table.insert(cleanedScripts, {
                        name = desc.Name,
                        className = desc.ClassName,
                        path = desc:GetFullName(),
                    })
                    pcall(function() desc:Destroy() end)
                end
            end
        end

        purge(target)
    end

    return {
        status = "success",
        result = {
            target = target:GetFullName(),
            riskLevel = scanResult.riskLevel,
            stats = scanResult.stats,
            highThreatsCount = scanResult.highThreats,
            mediumThreatsCount = scanResult.mediumThreats,
            threats = scanResult.threats,
            cleanedThreatsCount = #cleanedScripts,
            cleanedScripts = cleanedScripts,
            isCleaned = cleanThreats,
        }
    }
end

