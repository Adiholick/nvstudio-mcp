return function(targetInstance, data, ctx, targetPath)
    -- Guardrail: Cegah penghapusan Service utama
    local protectedServices = {
        "Workspace", "Players", "Lighting", "MaterialService", "NetworkClient", 
        "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage", 
        "StarterGui", "StarterPack", "StarterPlayer", "Teams", "SoundService", "Chat", 
        "TextChatService", "VoiceChatService"
    }
    
    if targetInstance.Parent == game or targetInstance.Parent == nil then
        for _, serviceName in ipairs(protectedServices) do
            if targetInstance.Name == serviceName or targetInstance.ClassName == serviceName then
                return { status = "error", error = "GUARDRAIL BLOCKED: Anda tidak diizinkan untuk menghapus layanan tingkat atas (" .. targetInstance.Name .. ")." }
            end
        end
    end
    
    local name = targetInstance.Name
    local className = targetInstance.ClassName
    local parentName = targetInstance.Parent and targetInstance.Parent.Name or "nil"
    
    local success, err = pcall(function()
        targetInstance:Destroy()
    end)
    
    if success then
        return { status = "success", result = "Instance '" .. name .. "' (" .. className .. ") berhasil dihapus dari " .. parentName .. "." }
    else
        return { status = "error", error = "Gagal menghapus instance: " .. tostring(err) }
    end
end
