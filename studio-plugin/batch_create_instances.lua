--!strict
-- ============================================================================
-- Skill Module: batch_create_instances
-- Deskripsi: Pembangun Hierarki Instance Massal & Deklaratif (Tree / Batch List)
-- ============================================================================

local HttpService = game:GetService("HttpService")

return function(targetInstance: Instance?, data: any, ctx: any, targetPath: string?)
    local success, config = pcall(function()
        if type(data) == "table" then return data end
        return HttpService:JSONDecode(tostring(data))
    end)

    if not success or type(config) ~= "table" then
        return { status = "error", error = "Format data JSON tidak valid untuk batch_create_instances." }
    end

    local setPropsFunc = require(script.Parent:WaitForChild("set_properties"))
    local defaultParent = targetInstance or game.Workspace

    if config.target and ctx and ctx.getInstanceFromPath then
        local resolved = ctx.getInstanceFromPath(config.target)
        if resolved then defaultParent = resolved end
    end

    local createdList = {}
    local errors = {}
    local createdCount = 0

    local function applyProps(inst: Instance, props: any)
        if not props or type(props) ~= "table" or not next(props) then return end
        local propJson = HttpService:JSONEncode(props)
        local res = setPropsFunc(inst, propJson, ctx, inst:GetFullName())
        if res and res.status == "error" then
            table.insert(errors, string.format("[%s] Error properti: %s", inst.Name, tostring(res.result or res.error)))
        end
    end

    -- 1. MODE HIERARCHICAL TREE (Pohon Bersarang)
    local function buildTreeNode(parentInst: Instance, node: any): Instance?
        local className = node.className or node.ClassName
        if not className or type(className) ~= "string" then
            table.insert(errors, "Node pohon tidak memiliki ClassName yang valid.")
            return nil
        end

        local ok, inst = pcall(function()
            local newObj = Instance.new(className)
            if node.name or node.Name then
                newObj.Name = tostring(node.name or node.Name)
            end
            newObj.Parent = parentInst
            return newObj
        end)

        if not ok or not inst then
            table.insert(errors, string.format("Gagal membuat instance '%s': %s", className, tostring(inst)))
            return nil
        end

        createdCount = createdCount + 1
        table.insert(createdList, inst:GetFullName())

        -- Terapkan properti
        applyProps(inst, node.properties or node.Properties)

        -- Rekursif untuk seluruh child
        local children = node.children or node.Children
        if children and type(children) == "table" then
            for _, childNode in ipairs(children) do
                buildTreeNode(inst, childNode)
            end
        end

        return inst
    end

    -- Eksekusi Mode Tree jika disediakan
    if config.tree and type(config.tree) == "table" then
        buildTreeNode(defaultParent, config.tree)
    end

    -- 2. MODE FLAT ARRAY (Daftar Instance Terpisah)
    local instancesArray = config.instances or config.items
    if instancesArray and type(instancesArray) == "table" then
        for idx, item in ipairs(instancesArray) do
            local parentInst = defaultParent
            if item.parent and ctx and ctx.getInstanceFromPath then
                local resParent = ctx.getInstanceFromPath(item.parent)
                if resParent then parentInst = resParent end
            end

            local className = item.className or item.ClassName
            if className then
                local ok, inst = pcall(function()
                    local newObj = Instance.new(className)
                    if item.name or item.Name then
                        newObj.Name = tostring(item.name or item.Name)
                    end
                    newObj.Parent = parentInst
                    return newObj
                end)

                if ok and inst then
                    createdCount = createdCount + 1
                    table.insert(createdList, inst:GetFullName())
                    applyProps(inst, item.properties or item.Properties)
                else
                    table.insert(errors, string.format("Item #%d (%s) gagal dibuat: %s", idx, tostring(className), tostring(inst)))
                end
            end
        end
    end

    local status = (createdCount > 0 or #errors == 0) and "success" or "error"
    return {
        status = status,
        result = {
            totalCreated = createdCount,
            created = createdList,
            hasErrors = (#errors > 0),
            errors = errors,
            message = string.format("Berhasil membuat %d instance secara batch.", createdCount)
        }
    }
end

