--!strict
-- ============================================================================
-- Skill Module: batch_set_properties
-- Deskripsi: Modifikasi Properti Massal untuk Beberapa Instance Sekaligus
-- ============================================================================

local HttpService = game:GetService("HttpService")

return function(targetInstance: Instance?, data: any, ctx: any, targetPath: string?)
    local success, config = pcall(function()
        if type(data) == "table" then return data end
        return HttpService:JSONDecode(tostring(data))
    end)

    if not success or type(config) ~= "table" then
        return { status = "error", error = "Format data JSON tidak valid untuk batch_set_properties." }
    end

    local setPropsFunc = require(script.Parent:WaitForChild("set_properties"))
    local updates = config.updates or config
    if type(updates) ~= "table" then
        return { status = "error", error = "Parameter 'updates' harus berupa array pembaruan properti." }
    end

    local updatedCount = 0
    local successfulTargets = {}
    local errors = {}

    for idx, updateItem in ipairs(updates) do
        local inst = targetInstance
        local instPath = updateItem.target or updateItem.path
        if instPath and ctx and ctx.getInstanceFromPath then
            local resolved = ctx.getInstanceFromPath(instPath)
            if resolved then
                inst = resolved
            else
                table.insert(errors, string.format("Item #%d: Target path '%s' tidak ditemukan.", idx, tostring(instPath)))
                continue
            end
        end

        local props = updateItem.properties or updateItem.props
        if inst and props and type(props) == "table" then
            local propJson = HttpService:JSONEncode(props)
            local res = setPropsFunc(inst, propJson, ctx, inst:GetFullName())
            if res and res.status == "error" then
                table.insert(errors, string.format("[%s]: %s", inst.Name, tostring(res.result or res.error)))
            else
                updatedCount = updatedCount + 1
                table.insert(successfulTargets, inst:GetFullName())
            end
        else
            table.insert(errors, string.format("Item #%d: Instance atau properties tidak valid.", idx))
        end
    end

    local status = (updatedCount > 0 or #errors == 0) and "success" or "error"
    return {
        status = status,
        result = {
            totalUpdated = updatedCount,
            updatedInstances = successfulTargets,
            hasErrors = (#errors > 0),
            errors = errors,
            message = string.format("Berhasil memperbarui properti untuk %d instance.", updatedCount)
        }
    }
end

