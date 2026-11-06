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
            elseif typeof(currentVal) == "Vector2" and type(val) == "table" and #val >= 2 then
                targetInstance[prop] = Vector2.new(val[1], val[2])
            elseif typeof(currentVal) == "UDim" and type(val) == "table" and #val >= 2 then
                targetInstance[prop] = UDim.new(val[1], val[2])
            elseif typeof(currentVal) == "Color3" and type(val) == "table" and #val == 3 then
                local r, g, b = val[1], val[2], val[3]
                if r > 1 or g > 1 or b > 1 then
                    targetInstance[prop] = Color3.fromRGB(r, g, b)
                else
                    targetInstance[prop] = Color3.new(r, g, b)
                end
            elseif typeof(currentVal) == "UDim2" and type(val) == "table" and #val == 4 then
                targetInstance[prop] = UDim2.new(val[1], val[2], val[3], val[4])
            elseif typeof(currentVal) == "NumberRange" and type(val) == "table" then
                targetInstance[prop] = NumberRange.new(val[1], val[2] or val[1])
            elseif typeof(currentVal) == "Rect" and type(val) == "table" and #val >= 4 then
                targetInstance[prop] = Rect.new(val[1], val[2], val[3], val[4])
            elseif typeof(currentVal) == "BrickColor" and type(val) == "string" then
                targetInstance[prop] = BrickColor.new(val)
            elseif typeof(currentVal) == "CFrame" and type(val) == "table" then
                targetInstance[prop] = CFrame.new(unpack(val))
            elseif typeof(currentVal) == "ColorSequence" or (type(val) == "table" and val.t == "ColorSequence") then
                local kps = {}
                local rawList = (type(val) == "table" and val.t == "ColorSequence") and val.v or val
                if type(rawList) == "table" then
                    for _, kp in ipairs(rawList) do
                        local t = kp[1] or 0
                        local col = kp[2]
                        local c3
                        if typeof(col) == "Color3" then
                            c3 = col
                        elseif type(col) == "table" and col.t == "Color3" then
                            c3 = Color3.new(col.v[1], col.v[2], col.v[3])
                        elseif type(col) == "table" and #col >= 3 then
                            c3 = (col[1] > 1 or col[2] > 1 or col[3] > 1) and Color3.fromRGB(col[1], col[2], col[3]) or Color3.new(col[1], col[2], col[3])
                        else
                            c3 = Color3.new(1, 1, 1)
                        end
                        table.insert(kps, ColorSequenceKeypoint.new(math.clamp(t, 0, 1), c3))
                    end
                end
                if #kps >= 2 then
                    table.sort(kps, function(a, b) return a.Time < b.Time end)
                    -- Pastikan keypoint pertama t=0 dan terakhir t=1
                    if kps[1].Time ~= 0 then
                        kps[1] = ColorSequenceKeypoint.new(0, kps[1].Value)
                    end
                    if kps[#kps].Time ~= 1 then
                        kps[#kps] = ColorSequenceKeypoint.new(1, kps[#kps].Value)
                    end
                    -- Pastikan waktu meningkat secara monoton murni
                    for i = 2, #kps do
                        if kps[i].Time <= kps[i - 1].Time then
                            local newT = math.min(1.0, kps[i - 1].Time + 0.001)
                            kps[i] = ColorSequenceKeypoint.new(newT, kps[i].Value)
                        end
                    end
                    targetInstance[prop] = ColorSequence.new(kps)
                elseif #kps == 1 then
                    targetInstance[prop] = ColorSequence.new(kps[1].Value)
                end
            elseif typeof(currentVal) == "NumberSequence" or (type(val) == "table" and val.t == "NumberSequence") then
                local kps = {}
                local rawList = (type(val) == "table" and val.t == "NumberSequence") and val.v or val
                if type(rawList) == "table" then
                    for _, kp in ipairs(rawList) do
                        if type(kp) == "table" then
                            local t = kp[1] or 0
                            local v = kp[2] or 0
                            local env = kp[3] or 0
                            table.insert(kps, NumberSequenceKeypoint.new(math.clamp(t, 0, 1), v, env))
                        end
                    end
                end
                if #kps >= 2 then
                    table.sort(kps, function(a, b) return a.Time < b.Time end)
                    -- Pastikan keypoint pertama t=0 dan terakhir t=1
                    if kps[1].Time ~= 0 then
                        kps[1] = NumberSequenceKeypoint.new(0, kps[1].Value, kps[1].Envelope)
                    end
                    if kps[#kps].Time ~= 1 then
                        kps[#kps] = NumberSequenceKeypoint.new(1, kps[#kps].Value, kps[#kps].Envelope)
                    end
                    -- Pastikan waktu meningkat secara monoton murni
                    for i = 2, #kps do
                        if kps[i].Time <= kps[i - 1].Time then
                            local newT = math.min(1.0, kps[i - 1].Time + 0.001)
                            kps[i] = NumberSequenceKeypoint.new(newT, kps[i].Value, kps[i].Envelope)
                        end
                    end
                    targetInstance[prop] = NumberSequence.new(kps)
                elseif #kps == 1 then
                    targetInstance[prop] = NumberSequence.new(kps[1].Value)
                end
            elseif typeof(currentVal) == "EnumItem" and type(val) == "string" then
                local enumType = tostring(currentVal.EnumType)
                local successEnum, enumValue = pcall(function() return Enum[enumType][val] end)
                if successEnum and enumValue then
                    targetInstance[prop] = enumValue
                else
                    error("Nilai Enum '" .. val .. "' tidak valid untuk EnumType '" .. enumType .. "'")
                end
            elseif prop == "Parent" or prop == "PrimaryPart" or string.match(prop, ".*Value$") then
                -- Evaluasi properti relasional
                if typeof(currentVal) == "Instance" or typeof(targetInstance[prop]) == "Instance" or val == nil then
                    if type(val) == "string" and ctx.getInstanceFromPath then
                        local resolved = ctx.getInstanceFromPath(val)
                        if resolved then
                            targetInstance[prop] = resolved
                        else
                            error("Instance target tidak ditemukan pada path: " .. val)
                        end
                    else
                        targetInstance[prop] = val
                    end
                else
                    targetInstance[prop] = val
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
