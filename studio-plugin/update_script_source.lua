return function(targetInstance, data, ctx, targetPath)
    if targetInstance:IsA("LuaSourceContainer") then
        local newCode = data or ""
        
        -- Catatan: Validasi AST menggunakan loadstring() sengaja DIHAPUS.
        -- Karena secara default Roblox Studio mematikan LoadStringEnabled, menggunakannya 
        -- hanya akan membuat AI gagal terus menerus untuk menulis script. 
        -- Error syntax akan ditangkap secara native oleh Roblox Output.
        
        ctx.scriptHistory[targetPath] = targetInstance.Source
        targetInstance.Source = newCode
        return { status = "success", result = "Script '" .. targetInstance.Name .. "' berhasil diperbarui." }
    else
        return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInstance.ClassName .. ")." }
    end
end
