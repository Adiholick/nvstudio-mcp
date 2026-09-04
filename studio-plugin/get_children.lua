return function(targetInstance, data, ctx, targetPath)
    local children = {}
    for _, child in ipairs(targetInstance:GetChildren()) do
        table.insert(children, child.Name .. " (" .. child.ClassName .. ")")
    end
    return { status = "success", result = children }
end
