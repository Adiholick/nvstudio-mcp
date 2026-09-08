return function(targetInstance, data, ctx, targetPath)
    local InsertService = game:GetService("InsertService")
    local rawId = tostring(data or ""):gsub("rbxassetid://", ""):gsub("%s+", "")
    local assetId = tonumber(rawId)
    if not assetId then
        return { status = "error", error = "Asset ID harus berupa angka yang valid." }
    end
    
    local success, model = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)
    
    if success and model then
        if targetInstance == game or targetInstance.ClassName == "DataModel" then
            model.Parent = game.Workspace
        else
            model.Parent = targetInstance
        end
        return { status = "success", result = "Aset berhasil dimasukkan ke " .. model.Parent.Name .. "." }
    else
        return { status = "error", error = "Gagal memuat aset. Pastikan Asset ID benar dan akun/plugin Anda memiliki izin (Ownership/Public)." }
    end
end
