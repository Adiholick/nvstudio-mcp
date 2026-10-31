return function(targetInstance, data, ctx, targetPath)
    local CollectionService = game:GetService("CollectionService")
    
    local props = {
        Name = targetInstance.Name,
        ClassName = targetInstance.ClassName,
        Parent = targetInstance.Parent and targetInstance.Parent.Name or "nil",
    }
    
    -- Ambil Properties Umum secara aman via pcall
    local function tryProp(propName)
        local success, val = pcall(function() return targetInstance[propName] end)
        if success and val ~= nil then
            if typeof(val) == "Vector3" then
                props[propName] = {math.round(val.X*100)/100, math.round(val.Y*100)/100, math.round(val.Z*100)/100}
            elseif typeof(val) == "Color3" then
                props[propName] = {math.round(val.R * 255), math.round(val.G * 255), math.round(val.B * 255)}
            elseif typeof(val) == "CFrame" then
                props[propName] = tostring(val)
            elseif typeof(val) == "EnumItem" then
                props[propName] = val.Name
            elseif typeof(val) == "UDim2" then
                props[propName] = {val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset}
            elseif typeof(val) == "Instance" then
                props[propName] = val:GetFullName()
            else
                props[propName] = val
            end
        end
    end
    
    local commonProps = {
        "Anchored", "CanCollide", "Transparency", "Reflectance", 
        "Position", "Size", "Color", "Material", "Text", "TextColor3", 
        "BackgroundTransparency", "BackgroundColor3", "Visible", "Enabled",
        "Volume", "Playing", "Looped", "Value"
    }
    
    for _, prop in ipairs(commonProps) do
        tryProp(prop)
    end
    
    -- Attributes & Tags (sanitasi tipe non-JSON agar tidak throw error di JSONEncode)
    pcall(function()
        local rawAttrs = targetInstance:GetAttributes()
        local safeAttrs = {}
        for k, val in pairs(rawAttrs) do
            if typeof(val) == "Vector3" then
                safeAttrs[k] = {math.round(val.X*100)/100, math.round(val.Y*100)/100, math.round(val.Z*100)/100}
            elseif typeof(val) == "Color3" then
                safeAttrs[k] = {math.round(val.R * 255), math.round(val.G * 255), math.round(val.B * 255)}
            elseif typeof(val) == "CFrame" then
                safeAttrs[k] = tostring(val)
            elseif typeof(val) == "EnumItem" then
                safeAttrs[k] = val.Name
            elseif typeof(val) == "UDim2" then
                safeAttrs[k] = {val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset}
            elseif typeof(val) == "Instance" then
                safeAttrs[k] = val:GetFullName()
            elseif typeof(val) == "DateTime" then
                safeAttrs[k] = val:ToIsoDate()
            elseif typeof(val) == "string" or typeof(val) == "number" or typeof(val) == "boolean" then
                safeAttrs[k] = val
            else
                safeAttrs[k] = tostring(val)
            end
        end
        props.Attributes = safeAttrs
    end)
    pcall(function()
        props.Tags = CollectionService:GetTags(targetInstance)
    end)
    
    return { status = "success", result = props }
end
