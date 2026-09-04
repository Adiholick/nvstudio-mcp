return function(targetInstance, data, ctx, targetPath)
    if targetInstance:IsA("LuaSourceContainer") then
        return { status = "success", result = targetInstance.Source }
    else
        return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInstance.ClassName .. "). Kamu WAJIB menggunakan get_children terlebih dahulu sebelum menarik source." }
    end
end
