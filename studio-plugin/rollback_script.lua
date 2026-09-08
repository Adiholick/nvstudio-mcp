return function(targetInstance, data, ctx, targetPath)
    if targetInstance:IsA("LuaSourceContainer") then
        local historyStack = ctx.scriptHistory[targetPath]
        if historyStack and type(historyStack) == "table" and #historyStack > 0 then
            local prevSource = table.remove(historyStack)
            targetInstance.Source = prevSource
            return { status = "success", result = "Script '" .. targetInstance.Name .. "' berhasil di-rollback ke versi sebelumnya. Sisa backup: " .. #historyStack }
        elseif type(historyStack) == "string" then
            -- Kompatibilitas mundur dengan data lama (sebelum FEAT-04)
            targetInstance.Source = historyStack
            ctx.scriptHistory[targetPath] = nil
            return { status = "success", result = "Script '" .. targetInstance.Name .. "' berhasil di-rollback (versi tunggal/legacy)." }
        else
            return { status = "error", error = "Tidak ada riwayat backup sebelumnya di sesi Studio ini untuk: " .. targetPath }
        end
    else
        return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInstance.ClassName .. ")." }
    end
end
