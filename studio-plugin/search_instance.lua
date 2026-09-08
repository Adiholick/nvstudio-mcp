return function(targetInstance, data, ctx, targetPath)
    if not data or data == "" or data == "nil" then
        return { status = "error", error = "Query pencarian tidak boleh kosong." }
    end
    local searchName = tostring(data)
    local results = {}
    
    local searchableServices = {game:GetService("Workspace"), game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService"), game:GetService("StarterGui")}
    local lowerSearch = string.lower(searchName)
    
    local nodesChecked = 0
    local function search(inst)
        nodesChecked = nodesChecked + 1
        if nodesChecked % 1000 == 0 then task.wait() end
        if string.find(inst.Name:lower(), searchName:lower(), 1, true) then
            table.insert(results, inst:GetFullName() .. " (" .. inst.ClassName .. ")")
        end
        if #results >= 50 then return end
        for _, child in ipairs(inst:GetChildren()) do
            search(child)
            if #results >= 50 then break end
        end
    end

    if targetInstance and targetInstance ~= game then
        search(targetInstance)
    else
        for _, service in ipairs(searchableServices) do
            search(service)
            if #results >= 50 then break end
        end
    end
    
    if #results > 0 then
        return { status = "success", result = results }
    else
        return { status = "success", result = "Tidak ditemukan instance dengan nama: " .. searchName }
    end
end
