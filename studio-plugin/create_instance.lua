return function(targetInstance, data, ctx, targetPath)
    local success, config = pcall(function() return ctx.HttpService:JSONDecode(data) end)
    if not success or not config.ClassName then
        return { status = "error", error = "Format data JSON tidak valid atau ClassName hilang." }
    end
    
    local newSuccess, newInst = pcall(function()
        local inst = Instance.new(config.ClassName)
        inst.Parent = targetInstance
        return inst
    end)
    
    if not newSuccess then
        return { status = "error", error = "Gagal membuat Instance: " .. tostring(newInst) }
    end

    local propResultMsg = ""
    if config.Properties and next(config.Properties) then
        local setPropsFunc = require(script.Parent:FindFirstChild("set_properties"))
        if setPropsFunc then
            local propData = ctx.HttpService:JSONEncode(config.Properties)
            local propRes = setPropsFunc(newInst, propData, ctx, "")
            if propRes.status == "error" then
                propResultMsg = " (Namun ada error properti: " .. propRes.result .. ")"
            elseif propRes.result then
                propResultMsg = " (" .. propRes.result .. ")"
            end
        else
            propResultMsg = " (Gagal meload set_properties)"
        end
    end
    
    return { status = "success", result = "Instance '"..config.ClassName.."' berhasil dibuat di " .. targetPath .. propResultMsg }
end
