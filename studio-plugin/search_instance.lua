return function(targetInstance, data, ctx, targetPath)
    local searchName = tostring(data)
    local results = {}
    
    local searchableServices = {game:GetService("Workspace"), game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService"), game:GetService("StarterGui")}
    
    for _, service in ipairs(searchableServices) do
        for _, desc in ipairs(service:GetDescendants()) do
            if desc.Name == searchName then
                table.insert(results, desc:GetFullName())
            end
        end
    end
    
    if #results > 0 then
        return { status = "success", result = results }
    else
        return { status = "success", result = "Tidak ditemukan instance dengan nama: " .. searchName }
    end
end
