# BLUEPRINT: nvstudio-mcp (Fase 5 - Direct Action & Semantic Search)

**Tujuan:** Instruksi ini dirancang untuk AI Agent. Anda harus melakukan *upgrade* pada dokumen `API_CONTRACT.md` dan `plugin/nvstudio_mcp.server.lua` untuk menambahkan fitur "Semantic Instance Search" dan "Native Instance Builder".

### Langkah 1: Perbarui `docs/API_CONTRACT.md`
Buka file `docs/API_CONTRACT.md` dan tambahkan dua perintah (*commands*) baru ke dalam daftar yang sudah ada:

4. `search_instance`: 
   - **Fungsi:** Mencari *path* absolut dari sebuah objek berdasarkan namanya di dalam *DataModel*. Sangat berguna jika agen AI kehilangan orientasi letak objek.
   - **Parameter `target`:** Diisi dengan `game` (pencarian global).
   - **Parameter `data`:** Diisi dengan *string* nama instance yang dicari (contoh: `"Sword"`).
   - **Response:** Array *string* berisi *path* absolut (contoh: `["Workspace.Map.Weapons.Sword"]`).
5. `create_instance`:
   - **Fungsi:** Membuat *Instance* baru secara instan tanpa perlu menulis kode Luau.
   - **Parameter `target`:** Path absolut tempat instance ini akan dijadikan *child* (contoh: `"Workspace"`).
   - **Parameter `data`:** *String* berformat JSON yang berisi `ClassName` dan properti. Contoh: `{"ClassName": "Part", "Properties": {"Name": "MyPart", "Color": [255, 0, 0]}}`

### Langkah 2: Perbarui Plugin `plugin/nvstudio_mcp.server.lua`
Buka file plugin Anda, lalu tambahkan logika untuk menangani `search_instance` dan `create_instance` di dalam fungsi `processTask`. Ganti blok `if command == ...` dengan logika yang diperbarui berikut:

```lua
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
            return { status = "error", error = "Target BUKAN Script." }
        end
        
    elseif command == "update_script_source" then
        if targetInstance:IsA("LuaSourceContainer") then
            targetInstance.Source = data or ""
            return { status = "success", result = "Script diperbarui." }
        else
            return { status = "error", error = "Target BUKAN Script." }
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
        return { status = "error", error = "Perintah tidak dikenali." }
    end
```

### Langkah 3: Eksekusi
Terapkan modifikasi ini pada kedua file tersebut secara lokal, lalu berikan laporan jika sudah selesai untuk melanjutkan ke Fase 6 (Validasi AST & Sinkronisasi File).