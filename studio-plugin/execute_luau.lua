return function(targetInstance, data, ctx, targetPath)
    local code = data
    if not code or code == "" then
        return { status = "error", error = "Kode yang dieksekusi tidak boleh kosong." }
    end
    
    local HttpService = game:GetService("HttpService")
    
    -- Bungkus code ke dalam fungsi return
    local wrappedCode = "return function()\n" .. code .. "\nend"
    
    local moduleScript = Instance.new("ModuleScript")
    moduleScript.Name = "AI_Execute_Temp"
    moduleScript.Source = wrappedCode
    
    -- Taruh di ReplicatedStorage sementara agar bisa di-require
    moduleScript.Parent = game:GetService("ReplicatedStorage")
    
    local resultData = nil
    local execError = nil
    local isFinished = false
    
    -- Eksekusi asinkron dengan batas waktu (timeout) 5 detik
    task.spawn(function()
        local reqSuccess, func = pcall(function() return require(moduleScript) end)
        if reqSuccess and type(func) == "function" then
            local execSuccess, res = pcall(func)
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
    
    -- Pembersihan (Wajib dihancurkan)
    pcall(function() moduleScript:Destroy() end)
    
    if not isFinished then
        return { status = "error", error = "Timeout 5 detik terlampaui. Kemungkinan ada infinite loop tanpa task.wait()." }
    end
    
    if execError then
        return { status = "error", error = execError }
    end
    
    -- Cegah return nil error
    if resultData == nil then
        return { status = "success", result = "Eksekusi berhasil (Tidak ada nilai kembalian)." }
    end
    
    -- JSON Encode untuk mencegah raw Instance return crash
    local serializeSuccess, jsonRes = pcall(function()
        return HttpService:JSONEncode(resultData)
    end)
    
    if serializeSuccess then
        return { status = "success", result = HttpService:JSONDecode(jsonRes) } -- decode kembali agar format aslinya diteruskan oleh router
    else
        return { status = "error", error = "Gagal menserialisasi hasil (Dilarang mengembalikan raw Roblox Instance): " .. tostring(jsonRes) }
    end
end
