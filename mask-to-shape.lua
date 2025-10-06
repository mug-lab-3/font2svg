-- ===============================
-- Fusion Script: clone-polyline-masks.lua
-- ===============================

local comp = fu:GetCurrentComp()

-- FlowView を安全に取る（Fusionページ以外だと nil のことがある）
local function getFlowView()
    if comp and comp.CurrentFrame and comp.CurrentFrame.FlowView then
        return comp.CurrentFrame.FlowView
    end
    return nil
end

-- 本体処理（設定読み込みで複製、ちょい右へオフセット）
local function collectPolylineMasks()
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

local function connectPolygonsToMerge(polygons, flow)
    if not polygons or #polygons == 0 then return end

    local merge = comp:AddTool("sMerge", 1, 1)
    local mergePosX, mergePosY = nil, nil

    if flow then
        local reference = polygons[1]
        local x, y = flow:GetPos(reference)
        if x and y then
            mergePosX, mergePosY = x + 2, y
            flow:SetPos(merge, mergePosX, mergePosY)
        end
    end

    for index, polygon in ipairs(polygons) do
        local polygonOutput = polygon.Output or getPrimaryOutput(polygon)
        local inputName = string.format("Input%d", index)
        local inputSocket = merge[inputName]

        if polygonOutput and inputSocket then
            inputSocket.ConnectTo(inputSocket, polygonOutput)
        end
    end

    local mergeOutput = merge.Output or getPrimaryOutput(merge)
    local transform = comp:AddTool("sTransform", 1, 1)

    if flow and mergePosX and mergePosY then
        flow:SetPos(transform, mergePosX + 2, mergePosY)
    end

    local transformInput = transform.Input or transform["Input"]
    if transformInput and mergeOutput then
        transformInput.ConnectTo(transformInput, mergeOutput)
    end

    local transformOutput = transform.Output or getPrimaryOutput(transform)
    local render = comp:AddTool("sRender", 1, 1)

    if flow and mergePosX and mergePosY then
        flow:SetPos(render, mergePosX + 4, mergePosY)
    end

    local renderInput = render.Input or render["Input"]
    if renderInput and transformOutput then
        renderInput.ConnectTo(renderInput, transformOutput)
    end
end

local function clonePolylineMasksBody(masks)
    if not masks or #masks == 0 then return end

    local flow = comp.CurrentFrame.FlowView
    local columnIndex = 0
    local baseX, baseY = nil, nil
    local verticalSpacing = 1.5
    local polygons = {}

    local posOffsetX = 1.1
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

    for _, src in ipairs(masks) do
        local settings = src:SaveSettings()
        local newTool  = comp:AddTool("sPolygon", 1, 1)
        newTool:LoadSettings(settings)

        if newTool.Center then
            newTool.Center = { 0, 0 }
        end

        table.insert(polygons, newTool)

        if flow then
            if baseX and baseY then
                columnIndex = columnIndex + 1
                local offsetY = (columnIndex - 1) * verticalSpacing
                flow:SetPos(newTool, baseX, baseY + offsetY)
            end
        end

        -- 任意：色など軽いメタ継承
        local a = src:GetAttrs()
        if a.TOOLNC_Color then
            newTool:SetAttrs({ TOOLNC_Color = a.TOOLNC_Color })
        end
    end

    connectPolygonsToMerge(polygons, flow)
end

-- 実行エントリ（pcallで挟み、Lock/Unlockで囲む）
local function run()
    local masks = collectPolylineMasks()
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
        -- トレースを付けて再throw
        error(debug.traceback(err, 2))
    end
end

run()
