local ProfessionsFrameEvents =
{
	"TRADE_SKILL_NAME_UPDATE",
	-- "TRADE_SKILL_LIST_UPDATE",
	"TRADE_SKILL_CLOSE",
	"GARRISON_TRADESKILL_NPC_CLOSED",
	"IGNORELIST_UPDATE",
};

local helptipSystemName = "Professions";

ProfessionsOrderFix_ProfessionsMixin = {};

function ProfessionsOrderFix_ProfessionsMixin:OnLoad()
	FrameUtil.RegisterFrameForEvents(self, ProfessionsFrameEvents);

	TabSystemOwnerMixin.OnLoad(self);
	self:SetTabSystem(self.TabSystem);

	self.craftingOrdersTabID = self:AddNamedTab(PROFESSIONS_CRAFTING_ORDERS_TAB_NAME, self.OrdersPage);
	self.TabSystem:SetTabShown(self.craftingOrdersTabID, false);

	self:RegisterEvent("OPEN_RECIPE_RESPONSE");

	EventRegistry:RegisterCallback("Professions.SelectSkillLine", function(_, info)
		local useLastSkillLine = false;
		self:SetProfessionInfo(info, useLastSkillLine);
	end, self);
	self:SetMovable(true);
	self:RegisterForDrag("LeftButton");
	self:SetClampedToScreen(true);
	self:SetScript("OnDragStart", self.StartMoving);
	self:SetScript("OnDragStop", self.StopMovingOrSizing);
end

function ProfessionsOrderFix_ProfessionsMixin:OnEvent(event, ...)
	local function ProcessOpenRecipeResponse(openRecipeResponse)
		C_TradeSkillUI.SetProfessionChildSkillLineID(openRecipeResponse.skillLineID);
		local professionInfo = Professions.GetProfessionInfo();
		professionInfo.openRecipeID = openRecipeResponse.recipeID;
		professionInfo.openSpecTab = openRecipeResponse.openSpecTab;
		local useLastSkillLine = false;
		self:SetProfessionInfo(professionInfo, useLastSkillLine);
		return professionInfo;
	end

	if event == "TRADE_SKILL_NAME_UPDATE" then
		-- Intended to refresh title.
		self:Refresh();
	-- TODO: do I really need this?
	-- elseif event == "TRADE_SKILL_LIST_UPDATE" then
	-- 	-- Filter changes can cause trade skill list updates while we're in the process
	-- 	-- of rebuilding our list. Always yield to a subsequent update if the data source
	-- 	-- hasn't been rebuilt yet.'
	-- 	if C_TradeSkillUI.IsDataSourceChanging() then
	-- 		return;
	-- 	end

	-- 	local professionInfo;

	-- 	local openRecipeResponse = self.openRecipeResponse;
	-- 	if openRecipeResponse then
	-- 		self.openRecipeResponse = nil;
	-- 		professionInfo = ProcessOpenRecipeResponse(openRecipeResponse);

	-- 		ShowUIPanel(self);
	-- 		self:SetupFrame();
	-- 	else
	-- 		professionInfo = Professions.GetProfessionInfo();
	-- 	end

	-- 	local useLastSkillLine = true;
	-- 	self:SetProfessionInfo(professionInfo, useLastSkillLine);
	elseif event == "TRADE_SKILL_CLOSE" or event == "GARRISON_TRADESKILL_NPC_CLOSED" then
		self:Hide();
	elseif event == "OPEN_RECIPE_RESPONSE" then
		local recipeID, professionSkillLineID, expansionSkillLineID = ...;
		local openRecipeResponse = {skillLineID = expansionSkillLineID, recipeID = recipeID};

		if C_TradeSkillUI.IsDataSourceChanging() then
			-- Defer handling the response until the next TRADE_SKILL_LIST_UPDATE otherwise
			-- it will likely just be overwritten by a default recipe selection.
			self.openRecipeResponse = openRecipeResponse;
			return;
		end

		local professionInfo = Professions.GetProfessionInfo();
		if expansionSkillLineID == professionInfo.professionID then
			-- We're in the same expansion profession so the recipe should exist in the list.
			professionInfo.openRecipeID = openRecipeResponse.recipeID;
		elseif professionSkillLineID == professionInfo.parentProfessionID then
			-- We're in a different expansion in the same profession. We need to regenerate
			-- the recipe list, so treat this as if the profession info is changing (consistent
			-- with a change when the dropdown is changed).
			local newProfessionInfo = ProcessOpenRecipeResponse(openRecipeResponse);
			local useLastSkillLine = false;
			self:SetProfessionInfo(newProfessionInfo, useLastSkillLine);
		else
			-- We're in a different profession entirely. Defer handling the response until the
			-- next TRADE_SKILL_LIST_UPDATE.
			self.openRecipeResponse = openRecipeResponse;
		end
	elseif event == "IGNORELIST_UPDATE" then
		C_CraftingOrders.UpdateIgnoreList();
	end
end

function ProfessionsOrderFix_ProfessionsMixin:SetOpenRecipeResponse(skillLineID, recipeID, openSpecTab)
	self.openRecipeResponse = {skillLineID = skillLineID, recipeID = recipeID, openSpecTab = openSpecTab};
end

function ProfessionsOrderFix_ProfessionsMixin:SetProfessionInfo(professionInfo, useLastSkillLine)
	local professionIDChanged = (not self.professionInfo) or (self.professionInfo.professionID ~= professionInfo.professionID);
	if professionIDChanged then
		local sourceChanged = (not self.professionInfo) or self.professionInfo.sourceCounter ~= professionInfo.sourceCounter;
		local professionChanged = (not self.professionInfo) or (self.professionInfo.profession ~= professionInfo.profession);
		local forceSkillLineChange = sourceChanged or professionChanged;
		local useNewSkillLine = forceSkillLineChange or not useLastSkillLine;
		if not useNewSkillLine then
			return;
		end
		if professionChanged then
			SearchBoxTemplate_ClearText(self.OrdersPage.BrowseFrame.RecipeList.SearchBox);
			Professions.SetAllSourcesFiltered(false);
		end
		C_TradeSkillUI.SetProfessionChildSkillLineID(useNewSkillLine and professionInfo.professionID or self.professionInfo.professionID);
	end

	-- Always updating the profession info so we're not displaying any stale information in the refresh.
	self.professionInfo = Professions.GetProfessionInfo();
	self.professionInfo.openRecipeID = professionInfo.openRecipeID;
	self.professionInfo.openSpecTab = professionInfo.openSpecTab;

	if professionIDChanged then
		EventRegistry:TriggerEvent("Professions.ProfessionSelected", self.professionInfo);
	end

	self:Refresh();
end

function ProfessionsOrderFix_ProfessionsMixin:SetTitle(skillLineName)
	if C_TradeSkillUI.IsTradeSkillGuild() then
		self:SetTitleFormatted("ProfessionsOrderFix: " .. GUILD_TRADE_SKILL_TITLE, skillLineName);
	else
		local linked, linkedName = C_TradeSkillUI.IsTradeSkillLinked();
		if linked and linkedName then
			self:SetTitleFormatted("%s %s[%s]|r", "ProfessionsOrderFix: " .. TRADE_SKILL_TITLE:format(skillLineName), HIGHLIGHT_FONT_COLOR_CODE, linkedName);
		else
			self:SetTitleFormatted("ProfessionsOrderFix: " ..  TRADE_SKILL_TITLE, skillLineName);
		end
	end
end

function ProfessionsOrderFix_ProfessionsMixin:GetProfessionInfo()
	return Professions.GetProfessionInfo();
end

function ProfessionsOrderFix_ProfessionsMixin:SetProfessionType(professionType)
	self.professionType = professionType;
end

function ProfessionsOrderFix_ProfessionsMixin:Refresh()
	local professionInfo = self:GetProfessionInfo();
	if professionInfo.professionID == 0 then
		return;
	end

	self:SetTitle(self.professionInfo.professionName or self.professionInfo.parentProfessionName);
	self:SetPortraitToAsset(C_TradeSkillUI.GetTradeSkillTexture(self.professionInfo.professionID));
	self:SetProfessionType(Professions.GetProfessionType(self.professionInfo));

	for _, page in ipairs(self.Pages) do
		page:Refresh(self.professionInfo);
	end

	self:UpdateTabs();
end

function ProfessionsOrderFix_ProfessionsMixin:UpdateTabs()
	if not self.professionInfo or not self:IsVisible() then
		return;
	end

	-- local shouldShowCraftingOrders = self.professionInfo.profession and C_CraftingOrders.ShouldShowCraftingOrderTab();
	-- local forceAwayFromOrders = not shouldShowCraftingOrders;
	local shouldShowCraftingOrders = not self:IfShouldBeClosed();
	if not shouldShowCraftingOrders then
		FrameUtil.UnregisterUpdateFunction(self);
		-- self.isCraftingOrdersTabEnabled = false;
	else
		-- self.isCraftingOrdersTabEnabled = C_TradeSkillUI.IsNearProfessionSpellFocus(self.professionInfo.profession);
		-- forceAwayFromOrders = not self.isCraftingOrdersTabEnabled;
		FrameUtil.RegisterUpdateFunction(self, .75, GenerateClosure(self.Update, self));
	end

	self.TabSystem:Layout();
	-- if forceAwayFromOrders or not ProfessionsFrame.craftingOrdersTabID or ProfessionsFrame:GetTab() ~= ProfessionsFrame.craftingOrdersTabID then
	if not shouldShowCraftingOrders then
		self:Hide();
		return;
	end

	self:SetupFrame();
end

local npcCraftingOrdersHelpTipInfo =
{
	text = PROFESSIONS_CRAFTING_ORDERS_NPC_HELPTIP,
	buttonStyle = HelpTip.ButtonStyle.Close,
	targetPoint = HelpTip.Point.TopEdgeCenter,
	alignment = HelpTip.Alignment.Center,
	offsetX = 0,
	cvarBitfield = "closedInfoFramesAccountWide",
	bitfieldFlag = LE_FRAME_TUTORIAL_ACCOUNT_NPC_CRAFTING_ORDERS,
	checkCVars = true,
	system = helptipSystemName,
};

function ProfessionsOrderFix_ProfessionsMixin:SetupFrame()
	if self.changingTabs then
		return;
	end
	self.changingTabs = true;

	HelpTip:HideAllSystem(helptipSystemName);
	SetCVarBitfield("closedInfoFramesAccountWide", LE_FRAME_TUTORIAL_ACCOUNT_NPC_CRAFTING_ORDERS, true);

	local selectedPage = self:GetElementsForTab(self.craftingOrdersTabID)[1];
	local pageWidth = selectedPage:GetDesiredPageWidth();
	if pageWidth == self.currentPageWidth then
		self.changingTabs = false;
		return;
	end

	local overrideSkillLine = C_CraftingOrders.GetDefaultOrdersSkillLine();
	if overrideSkillLine then
		local professionInfo = Professions.GetProfessionInfo();
		local useLastSkillLine = false;
		self:SetProfessionInfo(professionInfo, useLastSkillLine);
	end

	TabSystemOwnerMixin.SetTab(self, self.craftingOrdersTabID);
	self.currentPageWidth = pageWidth;
	self:SetWidth(pageWidth);
	UpdateUIPanelPositions(self);
	EventRegistry:TriggerEvent("ProfessionsOrderFix_ProfessionsFrame.TabSet", ProfessionsOrderFix_ProfessionsFrame, self.craftingOrdersTabID);
	self.changingTabs = false;
end

function ProfessionsOrderFix_ProfessionsMixin:OnShow()
	if self:IfShouldBeClosed() then
		self:Hide();
		return;
	end
	EventRegistry:TriggerEvent("ProfessionsOrderFix_ProfessionsFrame.Show");
	EventRegistry:TriggerEvent("ItemButton.UpdateCraftedProfessionQualityShown");
	PlaySound(SOUNDKIT.UI_PROFESSIONS_WINDOW_OPEN);
	self:UpdateTabs();
end

function ProfessionsOrderFix_ProfessionsMixin:OnHide()
	EventRegistry:TriggerEvent("ProfessionsOrderFix_ProfessionsFrame.Hide");

	PlaySound(SOUNDKIT.UI_PROFESSIONS_WINDOW_CLOSE);
	C_CraftingOrders.CloseCrafterCraftingOrders();
end

function ProfessionsOrderFix_ProfessionsMixin:IfShouldBeClosed()
	return not self.professionInfo or
	not self.professionInfo.profession or
	not C_CraftingOrders.ShouldShowCraftingOrderTab() or
	not ProfessionsFrame.craftingOrdersTabID or
	ProfessionsFrame:GetTab() ~= ProfessionsFrame.craftingOrdersTabID;
end

-- Set dynamically
function ProfessionsOrderFix_ProfessionsMixin:Update()
	if self:IfShouldBeClosed() then
		self:Hide();
		return;
	end

	if self.professionInfo and self.professionInfo.profession then
		local shouldOrdersTabBeEnabled = C_TradeSkillUI.IsNearProfessionSpellFocus(self.professionInfo.profession);
		if shouldOrdersTabBeEnabled ~= self.isCraftingOrdersTabEnabled then
			self:UpdateTabs();
		end
	end
end
