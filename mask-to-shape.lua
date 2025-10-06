-- ===============================
-- Fusion Script: clone-polyline-masks.lua
-- ===============================

local comp = fu:GetCurrentComp()

local function getPolylineMasks()
    local tools = comp and comp:GetToolList(false)
    local masks = {}

    if not tools then return masks end

    for _, tool in pairs(tools) do
        if tool and tool.ID == "PolylineMask" then
            table.insert(masks, tool)
        end
    end

    return masks
end

local function getPrimaryOutput(tool)
    if not tool then return nil end

    local outputs = tool:GetOutputList()
    if not outputs then return nil end

    if outputs.Output then return outputs.Output end
    if outputs.ShapeOut then return outputs.ShapeOut end

    for _, out in pairs(outputs) do
        return out
    end

    return nil
end

local function connectShapes(polygons)
    if not polygons or #polygons == 0 then return end

    local flow = comp.CurrentFrame.FlowView
    local merge = comp:AddTool("sMerge", 1, 1)
    local mergePosX, mergePosY = nil, nil

    local reference = polygons[1]
    local x, y = flow:GetPos(reference)
    if x and y then
        mergePosX, mergePosY = x + 1, y
        flow:SetPos(merge, mergePosX, mergePosY)
    end

    for index, polygon in ipairs(polygons) do
        local polygonOutput = polygon.Output or getPrimaryOutput(polygon)
        local inputName = string.format("Input%d", index)
        local inputSocket = merge[inputName]

        if polygonOutput and inputSocket then
            inputSocket.ConnectTo(inputSocket, polygonOutput)
        end
    end

    local transform = comp:AddTool("sTransform", 1, 1)

    if flow and mergePosX and mergePosY then
        flow:SetPos(transform, mergePosX + 1, mergePosY)
    end

    local mergeOutput = merge.Output or getPrimaryOutput(merge)
    local transformInput = transform.Input or transform["Input"]
    transform.Input.ConnectTo(transform.Input, merge.Output)

    local transformOutput = transform.Output or getPrimaryOutput(transform)
    local render = comp:AddTool("sRender", 1, 1)

    if flow and mergePosX and mergePosY then
        flow:SetPos(render, mergePosX + 2, mergePosY)
    end

    local renderInput = render.Input or render["Input"]
    if renderInput and transformOutput then
        renderInput.ConnectTo(renderInput, transformOutput)
    end
end

local function clonePolylineMasksBody(masks)
    if not masks or #masks == 0 then return end

    local flow = comp.CurrentFrame.FlowView

    local baseX, baseY = nil, nil
    local verticalSpacing = 1.0
    local polygons = {}

    local posOffsetX = 1
    local parent = masks[1].ParentTool
    if parent then
        local px, py = flow:GetPos(parent)
        if px and py then
            baseX, baseY = px + posOffsetX, py
        end
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
        local newTool = comp:AddTool("sPolygon", 1, 1)
        flow:SetPos(newTool, baseX, baseY + offsetY)

        local settings = src:SaveSettings()
        newTool:LoadSettings(settings)
        if newTool.Center then
            newTool.Center = { 0, 0 }
        end

        newTool:SetAttrs({ TOOLS_Name = "s" .. src.Name })

        table.insert(polygons, newTool)
    end

    connectShapes(polygons)
end


local function main()
    local masks = getPolylineMasks()
    if #masks == 0 then return end

    comp:Lock()
    comp:StartUndo("Clone PolylineMask via Settings")

    local ok, err = pcall(function()
        clonePolylineMasksBody(masks)
    end)

    comp:EndUndo(true)
    comp:Unlock()
    if comp.Refresh then comp:Refresh() end

    if not ok then
        error(debug.traceback(err, 2))
    end
end

main()
