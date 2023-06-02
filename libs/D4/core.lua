local AddOnName, AddonTable = ...
local COLR = "|cffff0000"
local COLY = "|cffffff00"
local COLG = "|cff00ff00"
local COLADDON = "|cff6060ff"
local mmBtn = nil
local mmBtnName = nil
local dbTab = nil
local grid = nil

--[[PRINT]]
function AddonTable:MSG(...)
	print(format("[%s" .. AddOnName .. "|r] %s", COLADDON, COLG), ...)
end

function AddonTable:DEB(...)
	print(format("[%s" .. AddOnName .. "|r] [%sDEBUG|r] %s", COLADDON, COLY, COLY), ...)
end

function AddonTable:ERR(...)
	print(format("[%s" .. AddOnName .. "|r] %s", COLADDON, COLR), ...)
end

--[[DB]]
function AddonTable:SetDBTable(dbName)
	dbTab = _G[dbName] or {}
end

function AddonTable:CheckDBTable()
	if dbTab ~= nil then return true end

	return false
end

function AddonTable:GetValue(key, val)
	if AddonTable:CheckDBTable() then
		if dbTab[key] ~= nil then
			return dbTab[key]
		else
			AddonTable:SetValue(key, val)

			return val
		end
	end

	return nil
end

function AddonTable:SetValue(key, val)
	if AddonTable:CheckDBTable() then
		dbTab[key] = val
	end

	return val
end

function AddonTable:GetPoint(name)
	if AddonTable:CheckDBTable() then return dbTab[name .. "p1"], dbTab[name .. "p2"], dbTab[name .. "p3"], dbTab[name .. "p4"], dbTab[name .. "p5"] end

	return nil
end

function AddonTable:SetPoint(name, p1, p2, p3, p4, p5)
	if AddonTable:CheckDBTable() then
		dbTab[name .. "p1"] = p1
		dbTab[name .. "p2"] = p2
		dbTab[name .. "p3"] = p3
		dbTab[name .. "p4"] = p4
		dbTab[name .. "p5"] = p5
	end

	return p1, p2, p3, p4, p5
end

--[[FRAMES]]
function AddonTable:CreateFrame(name, parent, x, y, w, h)
	local frame = CreateFrame("FRAME", name, parent)
	frame:SetPoint("CENTER", parent, x, y)
	frame:SetSize(w, h)

	return frame
end

--[[GRID]]
function AddonTable:Grid(n, snap)
	n = n or 0
	snap = snap or 10
	local mod = n % snap

	return (mod > (snap / 2)) and (n - mod + snap) or (n - mod)
end

function AddonTable:SetGridSize(size)
	return size
end

function AddonTable:GetGridSize()
	return 10
end

function AddonTable:UpdateGrid()
	local id = 0
	grid.lines = grid.lines or {}

	for i, v in pairs(grid.lines) do
		v:Hide()
	end

	for x = 0, GetScreenWidth() / 2, AddonTable:GetGridSize() do
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

	for x = 0, -GetScreenWidth() / 2, -AddonTable:GetGridSize() do
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

	for y = 0, GetScreenHeight() / 2, AddonTable:GetGridSize() do
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

	for y = 0, -GetScreenHeight() / 2, -AddonTable:GetGridSize() do
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

function AddonTable:CreateGrid()
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

	AddonTable:UpdateGrid()
end

function AddonTable:AddHelper(frame, hide)
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

function AddonTable:HideGrid(frame)
	AddonTable:AddHelper(frame, true)
	AddonTable:CreateGrid()
	grid:Hide()
end

function AddonTable:ShowGrid(frame)
	AddonTable:AddHelper(frame, false)
	AddonTable:CreateGrid()
	grid:Show()
end

--[[TAINTFREE SLASH COMMANDS]]
local lastMessage = ""
local cmds = {}

hooksecurefunc("ChatEdit_ParseText", function(editBox, send, parseIfNoSpace)
	if send == 0 and editBox:GetText() ~= "" then
		lastMessage = editBox:GetText()
	end
end)

hooksecurefunc("ChatEdit_SendText", function(frame)
	if lastMessage and lastMessage ~= "" then
		local cmd = string.upper(lastMessage)

		--cmd = strsplit(" ", cmd)
		if cmds[cmd] ~= nil then
			cmds[cmd]()
		end
	end
end)

function AddonTable:AddSlash(name, func)
	cmds["/" .. string.upper(name)] = func
end

--[[MINIMAPBUTTON]]
function AddonTable:GetMinimapTable()
	return mmBtn.db
end

function AddonTable:CreateMinimapButton(db, name, ico, ttTab, lBtnFunc, rBtnFunc, lBtnShiftFunc, rBtnShiftFunc)
	mmBtnName = name

	mmBtn = LibStub("LibDataBroker-1.1"):NewDataObject("AddonTableMinimapIcon", {
		type = "data source",
		text = name,
		icon = ico,
		OnClick = function(sel, btn)
			if IsShiftKeyDown() and btn == "LeftButton" and lBtnShiftFunc then
				lBtnShiftFunc()
			elseif btn == "LeftButton" and lBtnFunc then
				lBtnFunc()
			elseif IsShiftKeyDown() and btn == "RightButton" and rBtnShiftFunc then
				rBtnShiftFunc()
			elseif btn == "RightButton" and rBtnFunc then
				rBtnFunc()
			end
		end,
		OnTooltipShow = function(tt)
			if not tt or not tt.AddLine then return end

			for i, v in pairs(ttTab) do
				tt:AddLine(v)
			end
		end,
	})

	if mmBtn then
		mmBtn.db = db
		local dbIcon = LibStub("LibDBIcon-1.0", true)

		if dbIcon then
			dbIcon:Register(name, mmBtn, AddonTable:GetMinimapTable())
		end
	end

	return mmBtn
end

function AddonTable:HideMMBtn()
	local dbIcon = LibStub("LibDBIcon-1.0", true)

	if dbIcon and mmBtnName then
		dbIcon:Hide(mmBtnName)
	end
end

function AddonTable:ShowMMBtn()
	local dbIcon = LibStub("LibDBIcon-1.0", true)

	if dbIcon and mmBtnName then
		dbIcon:Show(mmBtnName)
	end
end