D4 = D4 or {}
--[[ Basics ]]
local BuildNr = select(4, GetBuildInfo())
local Build = "CLASSIC"
if BuildNr >= 100000 then
    Build = "RETAIL"
elseif BuildNr > 29999 then
    Build = "WRATH"
elseif BuildNr > 19999 then
    Build = "TBC"
end

function D4:GetWoWBuildNr()
    return BuildNr
end

function D4:GetWoWBuild()
    return Build
end

function D4:msg(msg)
    print("[D4] " .. msg)
end

function D4:MSG(name, icon, msg)
    print(format("[|cFFA0A0FF%s|r |T%s:0:0:0:0|t] %s", name, icon, msg))
end

--[[ DATABASE ]]
function D4:GV(db, key, value)
    if db == nil then
        D4:msg("[D4:SV] db is nil")

        return value
    end

    if type(db) ~= "table" then
        D4:msg("[D4:SV] db is not table")

        return value
    end

    if db[key] ~= nil then return db[key] end

    return value
end

function D4:SV(db, key, value)
    if db == nil then
        D4:msg("[D4:SV] db is nil")

        return false
    end

    if key == nil then
        D4:msg("[D4:SV] key is nil")

        return false
    end

    db[key] = value
end

--[[ MINIMAP BUTTONS ]]
local icon = LibStub("LibDBIcon-1.0", true)
function D4:GetLibDBIcon()
    return icon
end

function D4:CreateMinimapButton(tab)
    local mmbtn = LibStub("LibDataBroker-1.1"):NewDataObject(
        tab.name,
        {
            type = "data source",
            text = tab.name,
            icon = tab.icon,
            OnClick = function(sel, btnName)
                if btnName == "LeftButton" and IsShiftKeyDown() and tab.funcSL then
                    tab:funcSL()
                elseif btnName == "RightButton" and IsShiftKeyDown() and tab.funcSR then
                    tab:funcSR()
                elseif btnName == "LeftButton" and tab.funcL then
                    tab:funcL()
                elseif btnName == "RightButton" and tab.funcR then
                    tab:funcR()
                end
            end,
            OnTooltipShow = function(tooltip)
                if not tooltip or not tooltip.AddLine then return end
                for i, v in pairs(tab.vTT) do
                    tooltip:AddLine(v)
                end
            end,
        }
    )

    if mmbtn and D4:GetLibDBIcon() then
        D4:GetLibDBIcon():Register(tab.name, mmbtn, tab.dbtab)
    end
end

function D4:ShowMMBtn(name)
    D4:GetLibDBIcon():Show(name)
end

function D4:HideMMBtn(name)
    D4:GetLibDBIcon():Hide(name)
end

--[[ SLASH COMMANDS ]]
local cmds = {}
function D4:AddSlash(name, func)
    if name == nil then
        D4:msg("failed to add slash command, missing name")

        return false
    end

    cmds["/" .. string.upper(name)] = func
end

function D4:InitSlash()
    local lastMessage = ""
    if ChatEdit_ParseText and type(ChatEdit_ParseText) == "function" then
        hooksecurefunc(
            "ChatEdit_ParseText",
            function(editBox, send, parseIfNoSpace)
                if send == 0 and editBox:GetText() ~= "" then
                    lastMessage = editBox:GetText()
                end
            end
        )
    else
        D4:msg("FAILED TO ADD SLASH COMMAND #1")
    end

    if ChatEdit_SendText and type(ChatEdit_SendText) == "function" then
        hooksecurefunc(
            "ChatEdit_SendText",
            function(frame)
                if lastMessage and lastMessage ~= "" then
                    local cmd = string.upper(lastMessage)
                    if cmds[cmd] ~= nil then
                        cmds[cmd]()
                    end
                end
            end
        )
    else
        D4:msg("FAILED TO ADD SLASH COMMAND #2")
    end
end

--[[ QOL ]]
if D4:GetWoWBuild() ~= "RETAIL" and ShouldKnowUnitHealth and ShouldKnowUnitHealth("target") == false then
    function ShouldKnowUnitHealth(unit)
        return true
    end
end

--[[ INPUTS ]]
function D4:CreateCheckbox(tab)
    tab.sw = tab.sw or 25
    tab.sh = tab.sh or 25
    tab.parent = tab.parent or UIParent
    tab.pTab = tab.pTab or "CENTER"
    tab.value = tab.value or nil
    local cb = CreateFrame("CheckButton", tab.name, tab.parent, "UICheckButtonTemplate")
    cb:SetSize(tab.sw, tab.sh)
    cb:SetPoint(unpack(tab.pTab))
    cb:SetChecked(tab.value)
    cb:SetScript(
        "OnClick",
        function(sel)
            tab:funcV(sel:GetChecked())
        end
    )

    cb.f = cb:CreateFontString(nil, nil, "GameFontNormal")
    cb.f:SetPoint("LEFT", cb, "RIGHT", 0, 0)
    cb.f:SetText(tab.name)

    return cb
end

function D4:CreateCheckboxForCVAR(tab)
    tab.sw = tab.sw or 25
    tab.sh = tab.sh or 25
    tab.parent = tab.parent or UIParent
    tab.pTab = tab.pTab or "CENTER"
    tab.value = tab.value or nil
    local cb = D4:CreateCheckbox(tab)
    local cb2 = CreateFrame("CheckButton", tab.name, tab.parent, "UICheckButtonTemplate")
    cb2:SetSize(tab.sw, tab.sh)
    local p1, p2, p3 = unpack(tab.pTab)
    cb2:SetPoint(p1, p2 + 25, p3)
    cb2:SetChecked(tab.value2)
    cb2:SetScript(
        "OnClick",
        function(sel)
            tab:funcV2(sel:GetChecked())
        end
    )

    cb.f:SetPoint("LEFT", cb, "RIGHT", 25, 0)

    return cb
end

--[[ FRAMES ]]
function D4:CreateFrame(tab)
    tab.sw = tab.sw or 100
    tab.sh = tab.sh or 100
    tab.parent = tab.parent or UIParent
    tab.pTab = tab.pTab or "CENTER"
    tab.title = tab.title or ""
    tab.templates = tab.templates or "BasicFrameTemplateWithInset"
    local fra = CreateFrame("FRAME", tab.name, tab.parent, tab.templates)
    fra:SetSize(tab.sw, tab.sh)
    fra:SetPoint(unpack(tab.pTab))
    fra:SetClampedToScreen(true)
    fra:SetMovable(true)
    fra:EnableMouse(true)
    fra:RegisterForDrag("LeftButton")
    fra:SetScript("OnDragStart", fra.StartMoving)
    fra:SetScript("OnDragStop", fra.StopMovingOrSizing)
    fra:Hide()
    fra.TitleText:SetText(tab.title)

    return fra
end

--[[ GRID ]]
function D4:Grid(n, snap)
    n = n or 0
    snap = snap or 10
    local mod = n % snap

    return (mod > (snap / 2)) and (n - mod + snap) or (n - mod)
end

function D4:SetGridSize(size)
    return size
end

function D4:GetGridSize()
    return 10
end

function D4:UpdateGrid()
    local id = 0
    grid.lines = grid.lines or {}
    for i, v in pairs(grid.lines) do
        v:Hide()
    end

    for x = 0, GetScreenWidth() / 2, D4:GetGridSize() do
        grid.lines[id] = grid.lines[id] or grid:CreateTexture()
        grid.lines[id]:SetPoint("CENTER", 0.5 + x, 0)
        grid.lines[id]:SetSize(1.09, GetScreenHeight())
        if x % 50 == 0 then
            grid.lines[id]:SetColorTexture(1, 1, 0.5, 0.25)
        else
            grid.lines[id]:SetColorTexture(0.5, 0.5, 0.5, 0.25)
        end

        grid.lines[id]:Show()
        id = id + 1
    end

    for x = 0, -GetScreenWidth() / 2, -D4:GetGridSize() do
        grid.lines[id] = grid.lines[id] or grid:CreateTexture()
        grid.lines[id]:SetPoint("CENTER", 0.5 + x, 0)
        grid.lines[id]:SetSize(1.09, GetScreenHeight())
        if x % 50 == 0 then
            grid.lines[id]:SetColorTexture(1, 1, 0.5, 0.25)
        else
            grid.lines[id]:SetColorTexture(0.5, 0.5, 0.5, 0.25)
        end

        grid.lines[id]:Show()
        id = id + 1
    end

    for y = 0, GetScreenHeight() / 2, D4:GetGridSize() do
        grid.lines[id] = grid.lines[id] or grid:CreateTexture()
        grid.lines[id]:SetPoint("CENTER", 0, 0.5 + y)
        grid.lines[id]:SetSize(GetScreenWidth(), 1.09, GetScreenHeight())
        if y % 50 == 0 then
            grid.lines[id]:SetColorTexture(1, 1, 0.5, 0.25)
        else
            grid.lines[id]:SetColorTexture(0.5, 0.5, 0.5, 0.25)
        end

        grid.lines[id]:Show()
        id = id + 1
    end

    for y = 0, -GetScreenHeight() / 2, -D4:GetGridSize() do
        grid.lines[id] = grid.lines[id] or grid:CreateTexture()
        grid.lines[id]:SetPoint("CENTER", 0, 0.5 + y)
        grid.lines[id]:SetSize(GetScreenWidth(), 1.09)
        if y % 50 == 0 then
            grid.lines[id]:SetColorTexture(1, 1, 0.5, 0.25)
        else
            grid.lines[id]:SetColorTexture(0.5, 0.5, 0.5, 0.25)
        end

        grid.lines[id]:Show()
        id = id + 1
    end
end

function D4:CreateGrid()
    if grid == nil then
        grid = CreateFrame("Frame", "grid", UIParent)
        grid:EnableMouse(false)
        grid:SetSize(GetScreenWidth(), GetScreenHeight())
        grid:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        grid:SetFrameStrata("LOW")
        grid:SetFrameLevel(1)
        grid.bg = grid:CreateTexture("grid.bg", "BACKGROUND", nil, 0)
        grid.bg:SetAllPoints(grid)
        grid.bg:SetColorTexture(0.03, 0.03, 0.03, 0)
        grid.hor = grid:CreateTexture()
        grid.hor:SetPoint("CENTER", 0, -0.5)
        grid.hor:SetSize(GetScreenWidth(), 1)
        grid.hor:SetColorTexture(1, 1, 1, 1)
        grid.ver = grid:CreateTexture()
        grid.ver:SetPoint("CENTER", 0.5, 0)
        grid.ver:SetSize(1, GetScreenHeight())
        grid.ver:SetColorTexture(1, 1, 1, 1)
    end

    D4:UpdateGrid()
end

function D4:AddHelper(frame, hide)
    if frame.hh == nil then
        frame.hh = frame:CreateTexture(nil, "HIGHLIGHT")
        frame.hh:SetSize(1.1, frame:GetHeight())
        frame.hh:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.hh:SetColorTexture(1, 1, 1)
    end

    if frame.vh == nil then
        frame.vh = frame:CreateTexture(nil, "HIGHLIGHT")
        frame.vh:SetSize(frame:GetWidth(), 1.1)
        frame.vh:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.vh:SetColorTexture(1, 1, 1)
    end

    if hide then
        frame.hh:Hide()
        frame.vh:Hide()
    else
        frame.hh:Show()
        frame.vh:Show()
    end
end

function D4:HideGrid(frame)
    D4:AddHelper(frame, true)
    D4:CreateGrid()
    grid:Hide()
end

function D4:ShowGrid(frame)
    D4:AddHelper(frame, false)
    D4:CreateGrid()
    grid:Show()
end

--[[ Init ]]
D4:InitSlash()