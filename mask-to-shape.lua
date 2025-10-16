local comp = fu:GetCurrentComp()

local function collectPolylineMasksFromTool(tool, masks)
    if not tool then return end
    if tool.ID == "PolylineMask" then
        table.insert(masks, tool)
    end
    local children = tool:GetChildrenList()
    if not children then return end
    for _, child in pairs(children) do
        collectPolylineMasksFromTool(child, masks)
    end
end

local function getPolylineMasks()
    local tools = comp and comp:GetToolList(false)
    local masks = {}
    if not tools then return masks end

    if comp.ActiveTool ~= nil then
        collectPolylineMasksFromTool(comp.ActiveTool, masks)
    else
        for _, tool in pairs(tools) do
            if tool.ID == "PolylineMask" then
                table.insert(masks, tool)
            end
        end
    end

    return masks
end

local function connectShapes(polygons,width, height, baseX, baseY)
    if not polygons or #polygons == 0 then return end

    local flow = comp.CurrentFrame.FlowView
    local offsetX = 0

    flow:Select()

    -- Merge
    offsetX = offsetX + 1
    local merge = comp:AddTool("sMerge", baseX + offsetX, baseY)
    flow:Select(merge, true)

    local verticalSpacing = 1.0
    local columnIndex = 0
    for index, polygon in ipairs(polygons) do
        columnIndex       = columnIndex + 1
        local offsetY     = (columnIndex - 1) * verticalSpacing
        local inputName   = string.format("Input%d", index)
        local inputSocket = merge[inputName]
        if inputSocket then
            inputSocket.ConnectTo(inputSocket, polygon.Output)
            flow:QueueSetPos(inputSocket, baseX, baseY + offsetY)
        end
        flow:Select(polygon, true)
    end
    flow:QueueSetPos(merge, baseX + offsetX, baseY)

    -- Transform
    offsetX = offsetX + 1
    local transform = comp:AddTool("sTransform", baseX + offsetX, baseY)
    flow:QueueSetPos(transform, baseX + offsetX, baseY)
    transform.Input.ConnectTo(transform.Input, merge.Output)
    local scale = comp:GetPrefs("Comp.FrameFormat.Height") / comp:GetPrefs("Comp.FrameFormat.Width")
    transform.XSize = scale
    transform.YSize = scale * (height / width)
    flow:Select(transform, true)

    -- Render
    offsetX = offsetX + 1
    local render = comp:AddTool("sRender", baseX + offsetX, baseY)
    flow:QueueSetPos(render, baseX + offsetX, baseY)
    render.Input.ConnectTo(render.Input, transform.Output)
    flow:Select(render, true)
end

local function clonePolylineMasksBody(masks)
    if not masks or #masks == 0 then return end

    local flow = comp.CurrentFrame.FlowView

    local baseX, baseY = nil, nil
    local verticalSpacing = 1.0
    local polygons = {}

    local posOffsetX = 1
    local parent = masks[1].ParentTool
    local outputWidth = masks[1]:GetAttrs("TOOLI_ImageWidth")
    local outputHeight = masks[1]:GetAttrs("TOOLI_ImageHeight")

    if parent then
        local px, py = flow:GetPos(parent)
        if px and py then
            baseX, baseY = px + posOffsetX, py
        end
        local outputWidth = parent:GetAttrs("TOOLI_ImageWidth")
        local outputHeight = parent:GetAttrs("TOOLI_ImageHeight")
    else
        local px, py = flow:GetPos(masks[1])
        if px and py then
            baseX, baseY = px + posOffsetX, py
        end
    end


    local columnIndex = 0
    for _, src in ipairs(masks) do
        columnIndex   = columnIndex + 1
        local offsetY = (columnIndex - 1) * verticalSpacing
        local newTool = comp:AddTool("sPolygon", baseX, baseY + offsetY)
        flow:SetPos(newTool, baseX, baseY + offsetY)

        local settings = src:SaveSettings()
        newTool:LoadSettings(settings)
        if newTool.Center then
            newTool.Center = { 0, 0 }
        end

        newTool:SetAttrs({ TOOLS_Name = "s" .. src.Name })

        table.insert(polygons, newTool)
    end

    connectShapes(polygons,outputWidth, outputHeight, baseX, baseY)
end


local function main()
    local masks = getPolylineMasks()
    if #masks == 0 then return end

    comp:Lock()
    comp:StartUndo("Clone PolylineMask via Settings")

    local ok, err = pcall(function()
        clonePolylineMasksBody(masks)
    end)

    comp.CurrentFrame.FlowView:FlushSetPosQueue()
    comp:EndUndo(true)
    comp:Unlock()
    if comp.Refresh then comp:Refresh() end

    if not ok then
        error(debug.traceback(err, 2))
    end
end

main()
