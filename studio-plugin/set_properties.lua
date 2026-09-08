return function(targetInstance, data, ctx, targetPath)
    local success, config = pcall(function() return ctx.HttpService:JSONDecode(data) end)
    if not success or type(config) ~= "table" then
        return { status = "error", error = "Format data JSON tidak valid untuk set_properties." }
    end
    
    local applied = {}
    local errors = {}
    
    for prop, val in pairs(config) do
        local ok, err = pcall(function()
            local currentVal = targetInstance[prop]
            if typeof(currentVal) == "Vector3" and type(val) == "table" and #val == 3 then
                targetInstance[prop] = Vector3.new(val[1], val[2], val[3])
            elseif typeof(currentVal) == "Color3" and type(val) == "table" and #val == 3 then
                local r, g, b = val[1], val[2], val[3]
                if r > 1 or g > 1 or b > 1 then
                    targetInstance[prop] = Color3.fromRGB(r, g, b)
                else
                    targetInstance[prop] = Color3.new(r, g, b)
                end
            elseif typeof(currentVal) == "UDim2" and type(val) == "table" and #val == 4 then
                targetInstance[prop] = UDim2.new(val[1], val[2], val[3], val[4])
            elseif typeof(currentVal) == "CFrame" and type(val) == "table" then
                targetInstance[prop] = CFrame.new(unpack(val))
            elseif typeof(currentVal) == "EnumItem" and type(val) == "string" then
                local enumType = tostring(currentVal.EnumType)
                local successEnum, enumValue = pcall(function() return Enum[enumType][val] end)
                if successEnum and enumValue then
                    targetInstance[prop] = enumValue
                else
                    error("Nilai Enum '" .. val .. "' tidak valid untuk EnumType '" .. enumType .. "'")
                end
            else
                targetInstance[prop] = val
            end
        end)
        
        if ok then
            table.insert(applied, prop)
        else
            table.insert(errors, prop .. ": " .. tostring(err))
        end
    end
    
    if #errors > 0 then
        local successMsg = ""
        if #applied > 0 then
            successMsg = "Berhasil mengubah: " .. table.concat(applied, ", ") .. ".\n"
        end
        return { 
            status = #applied > 0 and "success" or "error", 
            result = successMsg .. "Namun beberapa properti gagal diubah:\n" .. table.concat(errors, "\n") 
        }
    end
    return { status = "success", result = "Berhasil mengubah properti: " .. table.concat(applied, ", ") }
end
