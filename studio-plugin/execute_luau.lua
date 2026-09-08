return function(targetInstance, data, ctx, targetPath)
    local code = data
    if not code or code == "" then
        return { status = "error", error = "Kode yang dieksekusi tidak boleh kosong." }
    end
    
    local HttpService = game:GetService("HttpService")
    
    -- Bungkus code ke dalam fungsi return
    local wrappedCode = "return function()\n" .. code .. "\nend"
    
    local moduleScript = Instance.new("ModuleScript")
    moduleScript.Name = "AI_Execute_" .. HttpService:GenerateGUID(false):gsub("-", "")
    moduleScript.Source = wrappedCode
    
    -- Taruh di ReplicatedStorage sementara agar bisa di-require
    moduleScript.Parent = game:GetService("ReplicatedStorage")
    
    local resultData = nil
    local execError = nil
    local isFinished = false
    
    -- Eksekusi asinkron dengan batas waktu (timeout) 5 detik
    local logs = {}
    
    local execThread = task.spawn(function()
        local reqSuccess, func = pcall(function() return require(moduleScript) end)
        if reqSuccess and type(func) == "function" then
            local LogService = game:GetService("LogService")
            local connection = LogService.MessageOut:Connect(function(msg, msgType)
                table.insert(logs, msg)
            end)
            local execSuccess, res = pcall(func)
            pcall(function() connection:Disconnect() end)
            if execSuccess then
                resultData = res
            else
                execError = "Runtime Error: " .. tostring(res)
            end
        else
            execError = "Syntax/Require Error: " .. tostring(func)
        end
        isFinished = true
    end)
    
    -- Tunggu hingga 5 detik
    local timeWaited = 0
    while not isFinished and timeWaited < 5 do
        timeWaited = timeWaited + task.wait()
    end
    

    if not isFinished then
        pcall(function() task.cancel(execThread) end)
    end
    
    -- Pembersihan (Wajib dihancurkan)
    pcall(function() moduleScript:Destroy() end)
    
    if not isFinished then
        return { status = "error", error = "Timeout 5 detik terlampaui. Thread mungkin tetap berjalan di background jika terjebak dalam infinite loop tanpa task.wait(). PASTIKAN menambahkan task.wait() di dalam loop komputasi berat." }
    end
    
    if execError then
        return { status = "error", error = execError, logs = #logs > 0 and logs or nil }
    end
    
    local returnPayload = { status = "success" }
    if #logs > 0 then
        returnPayload.logs = logs
    end

    -- Cegah return nil error
    if resultData == nil then
        returnPayload.result = "Eksekusi berhasil (Tidak ada nilai kembalian)."
        return returnPayload
    end
    
    -- JSON Encode untuk mencegah raw Instance return crash
    local serializeSuccess, jsonRes = pcall(function()
        return HttpService:JSONEncode(resultData)
    end)
    
    if serializeSuccess then
        returnPayload.result = HttpService:JSONDecode(jsonRes) -- decode kembali agar format aslinya diteruskan oleh router
        return returnPayload
    else
        return { status = "error", error = "Gagal menserialisasi hasil (Dilarang mengembalikan raw Roblox Instance): " .. tostring(jsonRes) }
    end
end
