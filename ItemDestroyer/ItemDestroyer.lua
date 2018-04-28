local itemDestroyerFrame = CreateFrame("frame", "ItemDestroyerFrame", UIParent)

----------------------------------------------------------------------------------------------------
-- overriding confirmation popup functions
----------------------------------------------------------------------------------------------------
-- return true if the item on the cursor is a protected one, else return nil
local function IsCursorItemProtected()
	local cursor_type, _, link = GetCursorInfo()
	if cursor_type == "item" then
		return ItemDestroyerSave.protectedItems[link:match("%[(.+)]"):lower()] ~= nil or nil
	end
end

-- return true if the item on the cursor is a gray/poor quality, else return nil
local function IsCursorItemGray()
	local cursor_type, _, link = GetCursorInfo()
	if cursor_type == "item" then
		return link:find("^|cff9d9d9d") and true or nil
	end
end

-- return true if the item on the cursor is a legendary weapon in the Kael'thas fight
local legendaryWeaponIds = {[30311]=1, [30312]=1, [30313]=1, [30314]=1, [30316]=1, [30317]=1, [30318]=1, [30319]=1}
local function IsCursorItemKaelWeapon()
	local cursor_type, _, link = GetCursorInfo()
	if cursor_type == "item" then
		return legendaryWeaponIds[tonumber(link:match("item:(%d+)"))] ~= nil or nil
	end
end

-- show a message about the item on the cursor being protected
local function ShowProtectedWarning()
	DEFAULT_CHAT_FRAME:AddMessage(select(3, GetCursorInfo()) .. " was protected by ItemDestroyer!", 1, 0, 0)
end

-- make DeleteCursorItem() check for protected items
local originalDeleteCursorItem = DeleteCursorItem
DeleteCursorItem = function()
	if IsCursorItemProtected() then
		ShowProtectedWarning()
		ClearCursor()
	else
		originalDeleteCursorItem()
	end
end

-- the normal confirmation window opens
local originalDeleteItem_OnShow = StaticPopupDialogs["DELETE_ITEM"].OnShow -- nil if another addon doesn't add it
StaticPopupDialogs["DELETE_ITEM"].OnShow = function()
	if originalDeleteItem_OnShow then
		originalDeleteItem_OnShow(this)
	end
	if IsCursorItemProtected() then
		ShowProtectedWarning()
		ClearCursor()
	elseif (ItemDestroyerSave.autoConfirmShift and IsShiftKeyDown()) or (ItemDestroyerSave.autoConfirmGray and IsCursorItemGray()) then
		DeleteCursorItem()
	end
end

-- the "good item" confirmation window opens
local originalDeleteGoodItem_OnShow = StaticPopupDialogs["DELETE_GOOD_ITEM"].OnShow
StaticPopupDialogs["DELETE_GOOD_ITEM"].OnShow = function()
	originalDeleteGoodItem_OnShow(this)
	if IsCursorItemProtected() then
		ShowProtectedWarning()
		ClearCursor()
	elseif (ItemDestroyerSave.autoConfirmShift and IsShiftKeyDown()) or (ItemDestroyerSave.autoConfirmKael and IsCursorItemKaelWeapon()) then
		DeleteCursorItem()
	elseif ItemDestroyerSave.autoTypeDelete then
		_G[this:GetName().."EditBox"]:SetText(DELETE_ITEM_CONFIRM_STRING)
	end
end

----------------------------------------------------------------------------------------------------
-- set up default settings when loading if needed
----------------------------------------------------------------------------------------------------
itemDestroyerFrame:SetScript("OnEvent", function(self, event, addon_name)
	if event == "ADDON_LOADED" and addon_name == "ItemDestroyer" then
		itemDestroyerFrame:UnregisterEvent(event)
		itemDestroyerFrame:SetScript("OnEvent", nil)
		if ItemDestroyerSave                  == nil then ItemDestroyerSave                  = {}   end
		if ItemDestroyerSave.protectedItems   == nil then ItemDestroyerSave.protectedItems   = {}   end
		if ItemDestroyerSave.autoTypeDelete   == nil then ItemDestroyerSave.autoTypeDelete   = true end
		if ItemDestroyerSave.autoConfirmShift == nil then ItemDestroyerSave.autoConfirmShift = true end
		if ItemDestroyerSave.autoConfirmGray  == nil then ItemDestroyerSave.autoConfirmGray  = true end
		if ItemDestroyerSave.autoConfirmKael  == nil then ItemDestroyerSave.autoConfirmKael  = true end
	end
end)
itemDestroyerFrame:RegisterEvent("ADDON_LOADED")

----------------------------------------------------------------------------------------------------
-- GUI
----------------------------------------------------------------------------------------------------
--------------------------------------------------
-- main window
--------------------------------------------------
table.insert(UISpecialFrames, itemDestroyerFrame:GetName()) -- make it closable with escape key
itemDestroyerFrame:SetFrameStrata("HIGH")
itemDestroyerFrame:SetBackdrop({
	bgFile="Interface/Tooltips/UI-Tooltip-Background",
	edgeFile="Interface/DialogFrame/UI-DialogBox-Border",
	tile=1, tileSize=32, edgeSize=32,
	insets={left=11, right=12, top=12, bottom=11}
})
itemDestroyerFrame:SetBackdropColor(0,0,0,1)
itemDestroyerFrame:SetPoint("CENTER")
itemDestroyerFrame:SetWidth(350)
itemDestroyerFrame:SetHeight(500)
itemDestroyerFrame:SetMovable(true)
itemDestroyerFrame:EnableMouse(true)
itemDestroyerFrame:RegisterForDrag("LeftButton")
itemDestroyerFrame:SetScript("OnDragStart", itemDestroyerFrame.StartMoving)
itemDestroyerFrame:SetScript("OnDragStop", itemDestroyerFrame.StopMovingOrSizing)
itemDestroyerFrame:SetScript("OnMouseDown", function(self, button)
	if button == "LeftButton" and not self.isMoving then
		self:StartMoving()
		self.isMoving = true
	end
end)
itemDestroyerFrame:SetScript("OnMouseUp", function(self, button)
	if button == "LeftButton" and self.isMoving then
		self:StopMovingOrSizing()
		self.isMoving = false
	end
end)
itemDestroyerFrame:SetScript("OnHide", function(self)
	if self.isMoving then
		self:StopMovingOrSizing()
		self.isMoving = false
	end
end)
itemDestroyerFrame:Hide()

--------------------------------------------------
-- header title
--------------------------------------------------
local textureHeader = itemDestroyerFrame:CreateTexture(nil, "ARTWORK")
textureHeader:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
textureHeader:SetWidth(315)
textureHeader:SetHeight(64)
textureHeader:SetPoint("TOP", 0, 12)
local textHeader = itemDestroyerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
textHeader:SetPoint("TOP", textureHeader, "TOP", 0, -14)
textHeader:SetText("ItemDestroyer 1.0")

--------------------------------------------------
-- checkbox options
--------------------------------------------------
local checkboxAutoType = CreateFrame("CheckButton", "ItemDestroyer_checkboxAutoType", itemDestroyerFrame, "UICheckButtonTemplate")
checkboxAutoType:SetPoint("TOPLEFT", itemDestroyerFrame, "TOPLEFT", 16, -28)
_G[checkboxAutoType:GetName().."Text"]:SetText('Auto-type "DELETE" on confirmations.')
checkboxAutoType:SetScript("OnClick", function()
	ItemDestroyerSave.autoTypeDelete = this:GetChecked() or false
end)

local checkboxConfirmShift = CreateFrame("CheckButton", "ItemDestroyer_checkboxConfirmShift", itemDestroyerFrame, "UICheckButtonTemplate")
checkboxConfirmShift:SetPoint("TOPLEFT", checkboxAutoType, "BOTTOMLEFT", 0, 7)
_G[checkboxConfirmShift:GetName().."Text"]:SetText("Auto-confirm deletion if holding shift.")
checkboxConfirmShift:SetScript("OnClick", function()
	ItemDestroyerSave.autoConfirmShift = this:GetChecked() or false
end)

local checkboxConfirmGray = CreateFrame("CheckButton", "ItemDestroyer_checkboxConfirmGray", itemDestroyerFrame, "UICheckButtonTemplate")
checkboxConfirmGray:SetPoint("TOPLEFT", checkboxConfirmShift, "BOTTOMLEFT", 0, 7)
_G[checkboxConfirmGray:GetName().."Text"]:SetText("Auto-confirm deletion for gray quality items.")
checkboxConfirmGray:SetScript("OnClick", function()
	ItemDestroyerSave.autoConfirmGray = this:GetChecked() or false
end)

local checkboxConfirmKael = CreateFrame("CheckButton", "ItemDestroyer_checkboxConfirmKael", itemDestroyerFrame, "UICheckButtonTemplate")
checkboxConfirmKael:SetPoint("TOPLEFT", checkboxConfirmGray, "BOTTOMLEFT", 0, 7)
_G[checkboxConfirmKael:GetName().."Text"]:SetText("Auto-confirm deletion for Kael legendary weapons.")
checkboxConfirmKael:SetScript("OnClick", function()
	ItemDestroyerSave.autoConfirmKael = this:GetChecked() or false
end)

--------------------------------------------------
-- edit box
--------------------------------------------------
local editbox = CreateFrame("Frame", "ItemDestroyer_editBox", itemDestroyerFrame)
local editboxInput = CreateFrame("EditBox", "ItemDestroyer_editboxInput", editbox)
local editboxScroll = CreateFrame("ScrollFrame", "ItemDestroyer_editboxScroll", editbox, "UIPanelScrollFrameTemplate")

-- description
local textDescription = itemDestroyerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
textDescription:SetJustifyH("LEFT")
textDescription:SetPoint("TOPLEFT", checkboxConfirmKael, "BOTTOMLEFT", 0, -6)
textDescription:SetText("Protect these items from being destroyed:\n(you can drag items to the editbox)")

-- editbox - main container
editbox:SetPoint("TOPLEFT", textDescription, "BOTTOMLEFT", 0, -6)
editbox:SetPoint("BOTTOM", itemDestroyerFrame, "BOTTOM", 0, 12)
editbox:SetWidth(itemDestroyerFrame:GetRight() - itemDestroyerFrame:GetLeft() - 45)
editbox:SetBackdrop({
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
	tile=1, tileSize=32, edgeSize=16,
	insets={left=5, right=5, top=5, bottom=5}})
editbox:SetBackdropColor(0,0,0,1)

-- editboxInput
editboxInput:SetMultiLine(true)
editboxInput:SetAutoFocus(false)
editboxInput:EnableMouse(true)
editboxInput:SetFont("Fonts/ARIALN.ttf", 14)
editboxInput:SetWidth(editbox:GetWidth()-20)
editboxInput:SetHeight(editbox:GetHeight()-8)
editboxInput:SetScript("OnEscapePressed", function() editboxInput:ClearFocus() end)
editboxInput:SetScript("OnEditFocusLost", function()
	-- save each line
	ItemDestroyerSave.protectedItems = {}
	for line in string.gmatch(editboxInput:GetText(), "[^\r\n]+") do
		if line:find("%w") then -- make sure it's not just spaces
			ItemDestroyerSave.protectedItems[line:lower()] = true
		end
	end
end)

-- editboxScroll
editboxScroll:SetPoint("TOPLEFT", editbox, "TOPLEFT", 8, -8)
editboxScroll:SetPoint("BOTTOMRIGHT", editbox, "BOTTOMRIGHT", -6, 8)
editboxScroll:EnableMouse(true)
editboxScroll:SetScript("OnMouseDown", function() editboxInput:SetFocus() end)
editboxScroll:SetScrollChild(editboxInput)

-- taken from Blizzard's macro UI XML to handle scrolling
editboxInput:SetScript("OnTextChanged", function()
	local scrollbar = _G[editboxScroll:GetName() .. "ScrollBar"]
	local min, max = scrollbar:GetMinMaxValues()
	if max > 0 and this.max ~= max then
	this.max = max
	scrollbar:SetValue(max)
	end
end)
editboxInput:SetScript("OnUpdate", function(this)
	ScrollingEdit_OnUpdate(editboxScroll)
end)
editboxInput:SetScript("OnCursorChanged", function()
	ScrollingEdit_OnCursorChanged(arg1, arg2, arg3, arg4)
end)

-- dragging an item onto the editbox - has to affect the scroll box and input
local function InputReceiveItem()
	local cursor_type, _, link = GetCursorInfo()
	if cursor_type == "item" then
		local text = link:match("%[(.+)]"):lower()
		local original = editboxInput:GetText()
		if original == "" or original:sub(-1) == "\n" then
			editboxInput:SetText(original .. text .. "\n")
		else
			editboxInput:SetText(original .. "\n" .. text .. "\n")
		end
		editboxInput:SetFocus()
		ClearCursor()
		CloseDropDownMenus()
	end
end

editboxScroll:SetScript("OnReceiveDrag", InputReceiveItem)
local editboxScroll_OnMouseDown = editboxScroll:GetScript("OnMouseDown")
editboxScroll:SetScript("OnMouseDown", function(self, button)
	if button == "LeftButton" then InputReceiveItem() end
	editboxScroll_OnMouseDown(self, button)
end)

editboxInput:SetScript("OnReceiveDrag", InputReceiveItem)
editboxInput:SetScript("OnMouseDown", function(self, button)
	if button == "LeftButton" then InputReceiveItem() end
end)

--------------------------------------------------
-- close button
--------------------------------------------------
local buttonClose = CreateFrame("Button", "ItemDestroyer_ButtonClose", itemDestroyerFrame, "UIPanelCloseButton")
buttonClose:SetPoint("TOPRIGHT", itemDestroyerFrame, "TOPRIGHT", -8, -8)
buttonClose:SetScript("OnClick", function()
	editboxInput:ClearFocus()
	itemDestroyerFrame:Hide()
end)

--------------------------------------------------
-- showing
--------------------------------------------------
itemDestroyerFrame:SetScript("OnShow", function(self)
	checkboxAutoType:SetChecked(ItemDestroyerSave.autoTypeDelete)
	checkboxConfirmShift:SetChecked(ItemDestroyerSave.autoConfirmShift)
	checkboxConfirmGray:SetChecked(ItemDestroyerSave.autoConfirmGray)
	checkboxConfirmKael:SetChecked(ItemDestroyerSave.autoConfirmKael)

	-- put list in alphabetical order
	local alphabetical = {}
	local inserted
	for name in pairs(ItemDestroyerSave.protectedItems) do
		inserted = false
		for i=1,#alphabetical do
			if name < alphabetical[i] then
				table.insert(alphabetical, i, name)
				inserted = true
				break
			end
		end
		if not inserted then
			table.insert(alphabetical, name)
		end
	end
	if next(alphabetical) ~= nil then
		editboxInput:SetText(table.concat(alphabetical, "\n"))
	end
end)

----------------------------------------------------------------------------------------------------
-- slash command
----------------------------------------------------------------------------------------------------
_G.SLASH_ITEMDESTROYER1 = "/itemdestroyer"
function SlashCmdList.ITEMDESTROYER()
	itemDestroyerFrame:Show()
end
