return function(targetInstance, data, ctx, targetPath)
    local success, config = pcall(function() return ctx.HttpService:JSONDecode(data) end)
    if not success or not config.ClassName then
        return { status = "error", error = "Format data JSON tidak valid atau ClassName hilang." }
    end
    
    local newSuccess, newInst = pcall(function()
        local inst = Instance.new(config.ClassName)
        inst.Parent = targetInstance
        
        if config.Properties then
            for prop, val in pairs(config.Properties) do
                pcall(function() inst[prop] = val end)
            end
        end
        return inst
    end)
    
    if newSuccess then
        return { status = "success", result = "Instance '"..config.ClassName.."' berhasil dibuat di " .. targetPath }
    else
        return { status = "error", error = "Gagal membuat Instance. Pastikan ClassName valid." }
    end
end
