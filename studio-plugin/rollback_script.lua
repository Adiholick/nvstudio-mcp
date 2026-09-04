return function(targetInstance, data, ctx, targetPath)
    if targetInstance:IsA("LuaSourceContainer") then
        local prevSource = ctx.scriptHistory[targetPath]
        if prevSource then
            targetInstance.Source = prevSource
            return { status = "success", result = "Script '" .. targetInstance.Name .. "' berhasil di-rollback ke versi sebelumnya." }
        else
            return { status = "error", error = "Tidak ada riwayat backup sebelumnya di sesi Studio ini untuk: " .. targetPath }
        end
    else
        return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInstance.ClassName .. ")." }
    end
end
