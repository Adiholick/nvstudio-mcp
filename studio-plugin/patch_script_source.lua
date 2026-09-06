local HttpService = game:GetService("HttpService")

return function(targetInstance, data, ctx, targetPath)
    if not targetInstance:IsA("LuaSourceContainer") then
        return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInstance.ClassName .. ")." }
    end

    local payload = nil
    pcall(function()
        payload = HttpService:JSONDecode(data)
    end)

    if not payload then
        return { status = "error", error = "Payload data harus berupa JSON valid." }
    end

    local currentSource = targetInstance.Source
    local newSource = currentSource
    local affectedLines = 0

    -- Mode 1: Search & Replace Exact Chunk
    if payload.target_content and payload.replacement_content then
        local targetContent = payload.target_content
        local replacementContent = payload.replacement_content
        local allowMultiple = payload.allow_multiple or false

        -- Escape magic characters for string.gsub if needed, or use string.find manually.
        -- string.gsub doesn't do plain text replacement directly without escaping.
        -- We'll write a plain text replace function.
        
        local function plainReplace(str, pattern, repl, max)
            local res = ""
            local startIdx = 1
            local count = 0
            while true do
                if max and count >= max then break end
                local findStart, findEnd = string.find(str, pattern, startIdx, true) -- true for plain match
                if not findStart then break end
                
                res = res .. string.sub(str, startIdx, findStart - 1) .. repl
                startIdx = findEnd + 1
                count = count + 1
            end
            res = res .. string.sub(str, startIdx)
            return res, count
        end

        local _, occurrences = plainReplace(currentSource, targetContent, replacementContent)
        
        if occurrences == 0 then
            return { status = "error", error = "target_content tidak ditemukan di dalam script." }
        elseif occurrences > 1 and not allowMultiple then
            return { status = "error", error = "target_content ditemukan " .. occurrences .. " kali. Tolong sertakan baris konteks lebih banyak agar unik, atau set allow_multiple = true." }
        end

        newSource, affectedLines = plainReplace(currentSource, targetContent, replacementContent)
        affectedLines = affectedLines -- not exact line count, but occurrences count
    
    -- Mode 2: Line Range Replace
    elseif payload.start_line and payload.end_line and payload.replacement_content then
        local lines = string.split(currentSource, "\n")
        local startLine = tonumber(payload.start_line)
        local endLine = tonumber(payload.end_line)
        
        if not startLine or not endLine or startLine < 1 or endLine > #lines or startLine > endLine then
            return { status = "error", error = "Range baris tidak valid. Jumlah baris script: " .. #lines }
        end

        local newLines = {}
        for i = 1, startLine - 1 do
            table.insert(newLines, lines[i])
        end
        
        table.insert(newLines, payload.replacement_content)
        
        for i = endLine + 1, #lines do
            table.insert(newLines, lines[i])
        end
        
        newSource = table.concat(newLines, "\n")
        affectedLines = (endLine - startLine) + 1
    else
        return { status = "error", error = "Payload tidak lengkap. Butuh (target_content & replacement_content) atau (start_line, end_line & replacement_content)." }
    end

    -- Simpan backup snapshot sebelum mengaplikasikan patch
    ctx.scriptHistory[targetPath] = currentSource

    -- Terapkan perubahan
    targetInstance.Source = newSource
    
    return { 
        status = "success", 
        result = "Patch berhasil diterapkan pada '" .. targetInstance.Name .. "'. Perubahan diaplikasikan.",
        affected_lines = affectedLines
    }
end
