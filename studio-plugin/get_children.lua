return function(targetInstance, data, ctx, targetPath)
    local children = {}
    local allChildren = targetInstance:GetChildren()
    local MAX_LIMIT = 200
    for i, child in ipairs(allChildren) do
        if i > MAX_LIMIT then
            table.insert(children, "... (Terpotong, " .. tostring(#allChildren - MAX_LIMIT) .. " children lainnya tidak ditampilkan)")
            break
        end
        table.insert(children, child.Name .. " (" .. child.ClassName .. ")")
    end
    return { status = "success", result = children }
end
