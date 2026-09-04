local HttpService = game:GetService("HttpService")
local TASK_URL = "http://localhost:3000/api/tasks"
local RESPONSE_URL = "http://localhost:3000/api/response"

local scriptHistory = {} -- Menyimpan riwayat rollback untuk target

local LogService = game:GetService("LogService")
local recentLogs = {}
local MAX_LOGS = 50

-- Menangkap setiap pesan yang muncul di Output Studio
LogService.MessageOut:Connect(function(message, messageType)
    local prefix = "[INFO] "
    if messageType == Enum.MessageType.MessageError then
        prefix = "[ERROR] "
    elseif messageType == Enum.MessageType.MessageWarning then
        prefix = "[WARNING] "
    end
    
    table.insert(recentLogs, prefix .. message)
    
    -- Jaga agar memori tidak penuh (maksimal 50 log terbaru)
    if #recentLogs > MAX_LOGS then
        table.remove(recentLogs, 1)
    end
end)

-- Fungsi untuk mengurai path string (contoh: "Workspace.Map.Part") menjadi Instance
local function getInstanceFromPath(path)
    local parts = string.split(path, ".")
    local current = game
    
    for i, part in ipairs(parts) do
        if part == "game" and i == 1 then
            continue
        end
        local success, nextInstance = pcall(function()
            return current[part]
        end)
        
        if not success or not nextInstance then
            return nil, "Gagal menemukan instance '" .. part .. "' pada path: " .. path
        end
        current = nextInstance
    end
    
    return current, nil
end

-- Fungsi pemrosesan command sesuai API_CONTRACT.md
local function processTask(taskData)
    local command = taskData.command
    local target = taskData.target
    local data = taskData.data

    local targetInstance, err = getInstanceFromPath(target)
    if not targetInstance then
        return { status = "error", error = err }
    end

    if command == "get_children" then
        local children = {}
        for _, child in ipairs(targetInstance:GetChildren()) do
            table.insert(children, child.Name .. " (" .. child.ClassName .. ")")
        end
        return { status = "success", result = children }
        
    elseif command == "get_script_source" then
        if targetInstance:IsA("LuaSourceContainer") then
            return { status = "success", result = targetInstance.Source }
        else
            return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInstance.ClassName .. "). Kamu WAJIB menggunakan get_children terlebih dahulu sebelum menarik source." }
        end
        
    elseif command == "update_script_source" then
        if targetInstance:IsA("LuaSourceContainer") then
            local newCode = data or ""
            
            -- Luau AST Validator (Mengecek syntax tanpa mengeksekusi)
            local success, syntaxError = loadstring(newCode)
            if not success then
                return { 
                    status = "error", 
                    error = "SYNTAX ERROR (AST Validation Gagal): " .. tostring(syntaxError) .. ". Script dibatalkan. Silakan periksa kembali kodemu." 
                }
            end
            
            scriptHistory[target] = targetInstance.Source
            targetInstance.Source = newCode
            return { status = "success", result = "Script '" .. targetInstance.Name .. "' divalidasi dan berhasil diperbarui." }
        else
            return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInstance.ClassName .. ")." }
        end
        
    elseif command == "rollback_script" then
        if targetInstance:IsA("LuaSourceContainer") then
            local prevSource = scriptHistory[target]
            if prevSource then
                targetInstance.Source = prevSource
                return { status = "success", result = "Script '" .. targetInstance.Name .. "' berhasil di-rollback ke versi sebelumnya." }
            else
                return { status = "error", error = "Tidak ada riwayat backup sebelumnya di sesi Studio ini untuk: " .. target }
            end
        else
            return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInstance.ClassName .. ")." }
        end
        
    elseif command == "get_logs" then
        if #recentLogs == 0 then
            return { status = "success", result = {"Console kosong. Tidak ada error atau log terbaru."} }
        else
            return { status = "success", result = recentLogs }
        end
        
    elseif command == "search_instance" then
        -- Fitur Semantic Search (Mencari berdasar nama)
        local searchName = tostring(data)
        local results = {}
        
        -- Membatasi pencarian hanya pada direktori penting untuk menghindari lag
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

    elseif command == "create_instance" then
        -- Fitur Native Builder (Membuat instance dari JSON)
        local success, config = pcall(function() return HttpService:JSONDecode(data) end)
        if not success or not config.ClassName then
            return { status = "error", error = "Format data JSON tidak valid atau ClassName hilang." }
        end
        
        local newSuccess, newInst = pcall(function()
            local inst = Instance.new(config.ClassName)
            inst.Parent = targetInstance
            
            -- Set properti tambahan jika ada
            if config.Properties then
                for prop, val in pairs(config.Properties) do
                    pcall(function() inst[prop] = val end)
                end
            end
            return inst
        end)
        
        if newSuccess then
            return { status = "success", result = "Instance '"..config.ClassName.."' berhasil dibuat di " .. target }
        else
            return { status = "error", error = "Gagal membuat Instance. Pastikan ClassName valid." }
        end

    else
        return { status = "error", error = "Perintah tidak dikenali oleh Plugin: " .. tostring(command) }
    end
end

-- Polling Loop (Berjalan di background)
task.spawn(function()
    print("[nvstudio-mcp] Plugin aktif, memulai polling ke Local Bridge Server...")
    while true do
        task.wait(1) -- Polling setiap 1 detik
        
        -- Coba GET Request
        local getSuccess, getResponse = pcall(function()
            return HttpService:GetAsync(TASK_URL)
        end)
        
        if getSuccess and getResponse then
            local decodeSuccess, taskData = pcall(function()
                return HttpService:JSONDecode(getResponse)
            end)
            
            -- Jika ada task baru
            if decodeSuccess and type(taskData) == "table" and taskData.id ~= nil then
                local execResult = processTask(taskData)
                execResult.id = taskData.id
                
                -- Kirim POST Request balasan ke server
                pcall(function()
                    local payload = HttpService:JSONEncode(execResult)
                    HttpService:PostAsync(RESPONSE_URL, payload, Enum.HttpContentType.ApplicationJson)
                end)
            end
        end
    end
end)
