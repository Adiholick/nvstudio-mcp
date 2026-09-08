return function(targetInstance, data, ctx, targetPath)
    local maxDepth = 2
    if data and data ~= "" then
        pcall(function() maxDepth = tonumber(data) or 2 end)
    end
    
    local totalNodes = 0
    local HARD_LIMIT = 2000 -- safeguard
    
    local hardLimitReached = false
    
    local function traverse(inst, currentDepth)
        if hardLimitReached then return nil end
        totalNodes = totalNodes + 1
        local node = { name = inst.Name, className = inst.ClassName }
        
        if totalNodes >= HARD_LIMIT then
            hardLimitReached = true
            return { name = "... (terpotong, melebihi limit " .. HARD_LIMIT .. " nodes)", className = "Warning" }
        end
        
        if currentDepth >= maxDepth then
            local childCount = #inst:GetChildren()
            if childCount > 0 then
                node.children = "... (" .. childCount .. " children tersembunyi)"
            end
            return node
        end
        
        local children = inst:GetChildren()
        if #children > 0 then
            node.children = {}
            for _, child in ipairs(children) do
                local childNode = traverse(child, currentDepth + 1)
                if childNode then
                    table.insert(node.children, childNode)
                end
            end
        end
        
        return node
    end
    
    local tree = traverse(targetInstance, 0)
    return { status = "success", result = tree }
end
