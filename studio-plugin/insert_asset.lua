return function(targetInstance, data, ctx, targetPath)
    local InsertService = game:GetService("InsertService")
    local assetId = tonumber(data)
    if not assetId then
        return { status = "error", error = "Asset ID harus berupa angka yang valid." }
    end
    
    local success, model = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)
    
    if success and model then
        model.Parent = game.Workspace
        return { status = "success", result = "Aset berhasil dimasukkan ke Workspace." }
    else
        return { status = "error", error = "Gagal memuat aset. Pastikan Asset ID benar dan akun/plugin Anda memiliki izin (Ownership/Public)." }
    end
end
