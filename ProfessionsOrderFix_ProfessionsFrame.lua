
local ProfessionsFrameEvents =
{
	"TRADE_SKILL_NAME_UPDATE",
	"TRADE_SKILL_LIST_UPDATE",
	"TRADE_SKILL_CLOSE",
	"GARRISON_TRADESKILL_NPC_CLOSED",
	"IGNORELIST_UPDATE",
};

local helptipSystemName = "Professions";

ProfessionsOrderFix_ProfessionsMixin = {};

function ProfessionsOrderFix_ProfessionsMixin:OnLoad()
	FrameUtil.RegisterFrameForEvents(self, ProfessionsFrameEvents);

	self:RegisterEvent("OPEN_RECIPE_RESPONSE");

	EventRegistry:RegisterCallback("Professions.SelectSkillLine", function(_, info)
		local useLastSkillLine = false;
		self:SetProfessionInfo(info, useLastSkillLine);
	end, self);
end

function ProfessionsOrderFix_ProfessionsMixin:ApplyDesiredWidth()
	local pageWidth = self.OrdersPage:GetDesiredPageWidth();

	self.currentPageWidth = pageWidth;
	UpdateUIPanelPositions(self);
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
	elseif event == "TRADE_SKILL_LIST_UPDATE" then
		-- Filter changes can cause trade skill list updates while we're in the process
		-- of rebuilding our list. Always yield to a subsequent update if the data source
		-- hasn't been rebuilt yet.'
		if C_TradeSkillUI.IsDataSourceChanging() then
			return;
		end

		local professionInfo;

		local openRecipeResponse = self.openRecipeResponse;
		if openRecipeResponse then
			self.openRecipeResponse = nil;
			professionInfo = ProcessOpenRecipeResponse(openRecipeResponse);

			ShowUIPanel(self);
			local forcedOpen = true;
			self:SetTab(forcedOpen);
		else
			professionInfo = Professions.GetProfessionInfo();
		end

		local useLastSkillLine = true;
		self:SetProfessionInfo(professionInfo, useLastSkillLine);
	elseif event == "TRADE_SKILL_CLOSE" or event == "GARRISON_TRADESKILL_NPC_CLOSED" then
		HideUIPanel(self);
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
	self:SetTab(false)
end


local unlockableSpecHelpTipInfo =
{
	text = PROFESSIONS_SPECS_CAN_UNLOCK_SPEC,
	buttonStyle = HelpTip.ButtonStyle.Close,
	targetPoint = HelpTip.Point.BottomEdgeCenter,
	system = helptipSystemName,
	autoHorizontalSlide = true,
	onAcknowledgeCallback = function() ProfessionsOrderFix_ProfessionsFrame.unlockSpecHelptipAcknowledged = true; end,
};

local pendingPointsHelpTipInfo =
{
	text = PROFESSIONS_SPECS_PENDING_POINTS,
	buttonStyle = HelpTip.ButtonStyle.Close,
	targetPoint = HelpTip.Point.BottomEdgeCenter,
	system = helptipSystemName,
	autoHorizontalSlide = true,
	onAcknowledgeCallback = function() ProfessionsOrderFix_ProfessionsFrame.pendingPointsHelptipAcknowledged = true; end,
};

local unspentPointsHelpTipInfo =
{
	text = PROFESSIONS_UNSPENT_SPEC_POINTS_REMINDER,
	buttonStyle = HelpTip.ButtonStyle.Close,
	targetPoint = HelpTip.Point.BottomEdgeCenter,
	system = helptipSystemName,
	autoHorizontalSlide = true,
	onAcknowledgeCallback = function() ProfessionsOrderFix_ProfessionsFrame.unspentPointsHelptipAcknowledged = true; end,
};

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

function ProfessionsOrderFix_ProfessionsMixin:SetTab(forcedOpen)
	if self.changingTabs then
		return;
	end
	self.changingTabs = true;

	local isSpecTab = false;
	local isCraftingOrderTab = true;
	local isRecipesTab = false;

	local specTabInfo = C_ProfSpecs.GetSpecTabInfo();
	local specTabEnabled = specTabInfo.enabled;

	StaticPopup_Hide("PROFESSIONS_SPECIALIZATION_CONFIRM_CLOSE");

	local specHelpTipShown = false;

	HelpTip:HideAllSystem(helptipSystemName);
	SetCVarBitfield("closedInfoFramesAccountWide", LE_FRAME_TUTORIAL_ACCOUNT_NPC_CRAFTING_ORDERS, true);

	Professions.ApplyfilterSet(self.craftingOrdersFilters);

	local professionInfo = Professions.GetProfessionInfo();
	self:SetProfessionInfo(professionInfo, useLastSkillLine);

	UpdateUIPanelPositions(self);
	self.changingTabs = false;
end

function ProfessionsOrderFix_ProfessionsMixin:OnShow()
	EventRegistry:TriggerEvent("ItemButton.UpdateCraftedProfessionQualityShown");
	PlaySound(SOUNDKIT.UI_PROFESSIONS_WINDOW_OPEN);

	MicroButtonPulseStop(ProfessionMicroButton);
	MainMenuMicroButton_HideAlert(ProfessionMicroButton);
	ProfessionMicroButton.showProfessionSpellHighlights = nil;
end

function ProfessionsOrderFix_ProfessionsMixin:OnHide()
	EventRegistry:TriggerEvent("ItemButton.UpdateCraftedProfessionQualityShown");
	C_PlayerInteractionManager.ClearInteraction(Enum.PlayerInteractionType.Professions);

	C_Garrison.CloseGarrisonTradeskillNPC();
	PlaySound(SOUNDKIT.UI_PROFESSIONS_WINDOW_CLOSE);

	C_TradeSkillUI.CloseTradeSkill();
	C_CraftingOrders.CloseCrafterCraftingOrders();
end

-- Set dynamically
function ProfessionsOrderFix_ProfessionsMixin:Update()
	if self.professionInfo and self.professionInfo.profession then
		local shouldOrdersTabBeEnabled = C_TradeSkillUI.IsNearProfessionSpellFocus(self.professionInfo.profession);
		if shouldOrdersTabBeEnabled ~= self.isCraftingOrdersTabEnabled then
			self:SetTab(false)
		end
	end
end
