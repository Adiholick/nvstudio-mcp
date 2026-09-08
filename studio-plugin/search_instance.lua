return function(targetInstance, data, ctx, targetPath)
    local searchName = tostring(data)
    local results = {}
    
    local searchableServices = {game:GetService("Workspace"), game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService"), game:GetService("StarterGui")}
    local lowerSearch = string.lower(searchName)
    
    for _, service in ipairs(searchableServices) do
        for _, desc in ipairs(service:GetDescendants()) do
            if string.find(string.lower(desc.Name), lowerSearch, 1, true) then
                table.insert(results, desc:GetFullName())
                if #results >= 50 then break end
            end
        end
        if #results >= 50 then break end
    end
    
    if #results > 0 then
        return { status = "success", result = results }
    else
        return { status = "success", result = "Tidak ditemukan instance dengan nama: " .. searchName }
    end
end
