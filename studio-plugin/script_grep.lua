return function(targetInstance, data, ctx, targetPath)
    local query = tostring(data)
    if not query or query == "" then
        return { status = "error", error = "Query pencarian tidak boleh kosong." }
    end

    local matches = {}
    local matchCount = 0
    local MAX_MATCHES = 50

    local searchableServices = {
        game:GetService("Workspace"),
        game:GetService("ServerScriptService"),
        game:GetService("ReplicatedStorage"),
        game:GetService("StarterPlayer"),
        game:GetService("StarterGui")
    }

    local function searchInScript(scriptObj)
        local success, source = pcall(function() return scriptObj.Source end)
        if not success or not source then return end

        local lines = string.split(source, "\n")
        for i, line in ipairs(lines) do
            -- Coba cari dengan plain text dulu, jika gagal coba pattern
            local found = string.find(line, query, 1, true)
            if not found then
                pcall(function() found = string.find(line, query) end)
            end

            if found then
                table.insert(matches, {
                    script = scriptObj:GetFullName(),
                    line = i,
                    content = string.match(line, "^%s*(.-)%s*$") or line
                })
                matchCount = matchCount + 1
                if matchCount >= MAX_MATCHES then
                    return true
                end
            end
        end
        return false
    end

    for _, service in ipairs(searchableServices) do
        pcall(function()
            local descendants = service:GetDescendants()
            for _, desc in ipairs(descendants) do
                if desc:IsA("LuaSourceContainer") then
                    if searchInScript(desc) then
                        break
                    end
                end
            end
        end)
        if matchCount >= MAX_MATCHES then
            break
        end
    end

    return { status = "success", matches = matches, count = matchCount, limitReached = (matchCount >= MAX_MATCHES) }
end
