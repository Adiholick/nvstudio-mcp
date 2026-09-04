return function(targetInstance, data, ctx, targetPath)
    local success, config = pcall(function() return ctx.HttpService:JSONDecode(data) end)
    if not success or not config.Size or not config.Position or not config.Material then
        return { status = "error", error = "Format JSON tidak valid. Membutuhkan Size, Position, dan Material." }
    end
    
    local fillSuccess, err = pcall(function()
        local terrain = game.Workspace.Terrain
        local materialEnum = Enum.Material[config.Material] or Enum.Material.Grass
        
        local size = Vector3.new(config.Size[1], config.Size[2], config.Size[3])
        local position = Vector3.new(config.Position[1], config.Position[2], config.Position[3])
        
        local region = Region3.new(position - (size/2), position + (size/2))
        terrain:FillRegion(region:ExpandToGrid(4), 4, materialEnum)
    end)
    
    if fillSuccess then
        return { status = "success", result = "Terrain (" .. config.Material .. ") berhasil di-generate." }
    else
        return { status = "error", error = "Gagal men-generate Terrain. Pastikan tipe data array angka valid: " .. tostring(err) }
    end
end
