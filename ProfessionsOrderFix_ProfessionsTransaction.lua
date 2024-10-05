local AllocationMixin = {};

function AllocationMixin:Init(reagent, quantity)
	self:SetReagent(reagent);
	self:SetQuantity(quantity);
end

function AllocationMixin:GetReagent()
	return self.reagent;
end

function AllocationMixin:SetReagent(reagent)
	self.reagent = reagent;
end

function AllocationMixin:GetQuantity()
	return self.quantity;
end

function AllocationMixin:SetQuantity(quantity)
	self.quantity = quantity;
end

function AllocationMixin:MatchesReagent(reagent)
	return Professions.CraftingReagentMatches(self.reagent, reagent);
end

function CreateAllocation(reagent, quantity)
	return CreateAndInitFromMixin(AllocationMixin, reagent, quantity);
end

local AllocationsMixin = {};

function AllocationsMixin:Init()
	self:Clear();
end

function AllocationsMixin:SetOnChangedHandler(onChangedFunc)
	self.onChangedFunc = onChangedFunc;
end

function AllocationsMixin:Clear()
	self.allocs = {};
	self:OnChanged();
end


function AllocationsMixin:SelectFirst()
	return self.allocs[1];
end

function AllocationsMixin:Enumerate(indexBegin, indexEnd)
	return CreateTableEnumerator(self.allocs, indexBegin, indexEnd);
end

function AllocationsMixin:FindAllocationByPredicate(predicate)
	local key, allocation = FindInTableIf(self.allocs, predicate);
	return allocation;
end

function AllocationsMixin:FindAllocationByReagent(reagent)
	local function MatchesReagent(allocation)
		return allocation:MatchesReagent(reagent);
	end
	return self:FindAllocationByPredicate(MatchesReagent);
end

function AllocationsMixin:GetQuantityAllocated(reagent)
	local allocation = self:FindAllocationByReagent(reagent);
	return allocation and allocation:GetQuantity() or 0;
end

function AllocationsMixin:Accumulate()
	return AccumulateOp(self.allocs, function(allocation)
		return allocation:GetQuantity();
	end);
end

function AllocationsMixin:HasAnyAllocations()
	return self:Accumulate() > 0;
end

function AllocationsMixin:HasAllAllocations(quantityRequired)
	return self:Accumulate() >= quantityRequired;
end

function AllocationsMixin:Allocate(reagent, quantity)
	assert(reagent.itemID or reagent.currencyID);
	local allocation = self:FindAllocationByReagent(reagent);
	if quantity <= 0 then
		if allocation then
			tDeleteItem(self.allocs, allocation);
		end
	else
		if allocation then
			allocation:SetQuantity(quantity);
		else
			table.insert(self.allocs, CreateAllocation(reagent, quantity));
		end
	end

	self:OnChanged();
end

function AllocationsMixin:Overwrite(allocations)
	self.allocs = CopyTable(allocations.allocs);
	self:OnChanged();
end

function AllocationsMixin:OnChanged()
	if self.onChangedFunc ~= nil then
		self.onChangedFunc();
	end
	EventRegistry:TriggerEvent("Professions.AllocationUpdated", self);
end

ProfessionsOrderFix_ProfessionsRecipeTransactionMixin = {};

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:Init(recipeSchematic)
	self.reagentTbls = {};
	self.allocationTbls = {};
	self.reagentSlotSchematicTbls = {};

	self.recipeID = recipeSchematic.recipeID;
	self.recipeSchematic = recipeSchematic;

	for slotIndex, reagentSlotSchematic in ipairs(recipeSchematic.reagentSlotSchematics) do
		local allocations = CreateAndInitFromMixin(AllocationsMixin);
		table.insert(self.allocationTbls, allocations);
		table.insert(self.reagentSlotSchematicTbls, reagentSlotSchematic);
		self.reagentTbls[slotIndex] = {reagentSlotSchematic = reagentSlotSchematic, allocations = allocations};
	end

	self.applyConcentration = false;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:HasReagentSlots()
	return #self.reagentSlotSchematicTbls > 0;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SetAllocationsChangedHandler(onChangedFunc)
	-- onChangedFunc intended to be invoked when any synthesized slots (enchant, recraft, salvage) are changed.
	self.onChangedFunc = onChangedFunc;

	for index, allocations in self:EnumerateAllAllocations() do
		allocations:SetOnChangedHandler(onChangedFunc);
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:CallOnChangedHandler()
	if self.onChangedFunc then
		self.onChangedFunc();
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SetManuallyAllocated(manuallyAllocated)
	self.manuallyAllocated = manuallyAllocated;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:IsManuallyAllocated()
	return self.manuallyAllocated;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetRecipeID()
	return self.recipeID;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetRecipeSchematic()
	return self.recipeSchematic;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:IsRecraft()
	local recipeSchematic = self:GetRecipeSchematic();
	return recipeSchematic.isRecraft;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetAllocations(slotIndex)
	return self.allocationTbls[slotIndex];
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetReagentSlotSchematic(slotIndex)
	return self.reagentSlotSchematicTbls[slotIndex];
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:IsRecipeType(recipeType)
	local recipeSchematic = self:GetRecipeSchematic();
	return recipeSchematic.recipeType == recipeType;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetQuantityRequiredInSlot(slotIndex)
	local reagentSlotSchematic = self:GetReagentSlotSchematic(slotIndex);
	return reagentSlotSchematic.quantityRequired;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:IsSlotRequired(slotIndex)
	local reagentSlotSchematic = self:GetReagentSlotSchematic(slotIndex);
	return reagentSlotSchematic.required;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:IsSlotBasicReagentType(slotIndex)
	local reagentSlotSchematic = self:GetReagentSlotSchematic(slotIndex);
	return reagentSlotSchematic.reagentType == Enum.CraftingReagentType.Basic;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:IsSlotModifyingRequired(slotIndex)
	local reagentSlotSchematic = self:GetReagentSlotSchematic(slotIndex);
	return ProfessionsUtil.IsReagentSlotModifyingRequired(reagentSlotSchematic);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:AccumulateAllocations(slotIndex)
	local allocations = self:GetAllocations(slotIndex);
	return allocations:Accumulate();
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:IsReagentAllocated(slotIndex, reagent)
	local allocations = self:GetAllocations(slotIndex);
	return allocations and (allocations:FindAllocationByReagent(reagent) ~= nil);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetAllocationsCopy(slotIndex)
	return CopyTable(self:GetAllocations(slotIndex));
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:EnumerateAllocations(slotIndex)
	local allocations = self:GetAllocations(slotIndex);
	return allocations:Enumerate();
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:Enumerate(indexBegin, indexEnd)
	return CreateTableEnumerator(self.reagentTbls, indexBegin, indexEnd);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:EnumerateAllAllocations()
	return CreateTableEnumerator(self.allocationTbls);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:CollateSlotReagents()
	local tbl = {};
	for slotIndex, reagentSlotSchematic in ipairs(self.reagentSlotSchematicTbls) do
		table.insert(tbl, reagentSlotSchematic.reagents);
	end
	return tbl;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:EnumerateAllSlotReagents()
	return CreateTableEnumerator(self:CollateSlotReagents());
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:OnChanged()
	EventRegistry:TriggerEvent("Professions.TransactionUpdated", self);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:IsModificationAllocated(reagent, slotIndex)
	local modification = self:GetModificationAtSlotIndex(slotIndex);
	return modification and (modification.itemID == reagent.itemID);
end

local function CanReagentSlotBeItemModification(reagentSlotSchematic)
	return (reagentSlotSchematic.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent) and
			(reagentSlotSchematic.reagentType == Enum.CraftingReagentType.Modifying);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GenerateExpectedItemModifications()
	local modsCopy = CopyTable(self.recraftItemMods);
	for index, modification in ipairs(modsCopy) do
		modification.itemID = 0;
	end

	self:ClearExemptedReagents();

	for slotIndex, reagentSlotSchematic in ipairs(self.recipeSchematic.reagentSlotSchematics) do
		if CanReagentSlotBeItemModification(reagentSlotSchematic) then
			local modification = modsCopy[reagentSlotSchematic.dataSlotIndex];

			local allocations = self:GetAllocations(slotIndex);
			local allocs = allocations:SelectFirst();
			if allocs then
				local reagent = allocs:GetReagent();
				modification.itemID = reagent.itemID;
				local dataSlotIndex = reagentSlotSchematic.dataSlotIndex;
				self:SetExemptedReagent(reagent, dataSlotIndex);
			else
				modification.itemID = 0;
			end
		end
	end

	self.recraftExpectedItemMods = modsCopy;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SanitizeAllocationsInternal(index, allocations)
	local valid = true;
	for allocationsIndex, allocs in allocations:Enumerate() do
		if valid then
			local reagent = allocs:GetReagent();
			-- If the allocation is a current or pending item modification in recrafting
			-- then we don't discard it -- it needs to remain in the allocation list
			-- because it currently represents a "no change" operation.

			if not self:IsModificationAllocated(reagent, index) and self:IsReagentSanizationExempt(reagent) then
				local owned = ProfessionsUtil.GetReagentQuantityInPossession(reagent, self.useCharacterInventoryOnly);
				local quantity = allocs:GetQuantity();
				if owned < quantity then
					valid = false;
				end
			end
		end
	end

	if not valid then
		allocations:Clear();
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:IsReagentSanizationExempt(reagent)
	if self.exemptedReagents then
		if self.exemptedReagents[reagent.itemID] then
			return false;
		end
	end
	return true;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SetExemptedReagent(reagent, dataSlotIndex)
	if not self.exemptedReagents then
		self.exemptedReagents = {};
	end

	self.exemptedReagents[reagent.itemID] = dataSlotIndex;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:ClearExemptedReagents()
	self.exemptedReagents = nil;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SanitizeOptionalAllocations()
	for index, allocations in ipairs_reverse(self.allocationTbls) do
		local reagentSlotSchematic = self:GetReagentSlotSchematic(index);
		if not reagentSlotSchematic.required then
			self:SanitizeAllocationsInternal(index, allocations);
		end
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SanitizeAllocations()
	for index, allocations in ipairs_reverse(self.allocationTbls) do
		self:SanitizeAllocationsInternal(index, allocations);
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SanitizeTargetAllocations()
	self:SanitizeRecraftAllocation();
	self:SanitizeEnchantAllocation();
	self:SanitizeSalvageAllocation();
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SanitizeRecraftAllocation(clearExpected)
	local itemGUID = self:GetRecraftAllocation();
	if itemGUID and not C_Item.IsItemGUIDInInventory(itemGUID) then
		self:ClearRecraftAllocation();
	end

	if clearExpected then
		self.recraftExpectedItemMods = nil;
	end
	self:CacheItemModifications();
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SanitizeEnchantAllocation(clearExpected)
	local item = self:GetEnchantAllocation();
	local itemGUID = item and item:GetItemGUID() or nil;
	if itemGUID and not C_Item.IsItemGUIDInInventory(itemGUID) then
		self:ClearEnchantAllocations();
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SanitizeSalvageAllocation(clearExpected)
	local item = self:GetSalvageAllocation();
	local itemGUID = item and item:GetItemGUID() or nil;
	if itemGUID and not C_Item.IsItemGUIDInInventory(itemGUID) then
		self:ClearSalvageAllocations();
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:OverwriteAllocations(slotIndex, allocations)
	local currentAllocations = self:GetAllocations(slotIndex);
	currentAllocations:Overwrite(allocations);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:OverwriteAllocation(slotIndex, reagent, quantity)
	local allocations = self:GetAllocations(slotIndex);
	allocations:Clear();
	allocations:Allocate(reagent, quantity);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:ClearAllocations(slotIndex)
	local allocations = self:GetAllocations(slotIndex);
	allocations:Clear();
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:HasAnyAllocations(slotIndex)
	local allocations = self:GetAllocations(slotIndex);
	return allocations and allocations:HasAnyAllocations();
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:HasAllAllocations(slotIndex, quantityRequired)
	local allocations = self:GetAllocations(slotIndex);
	local reagentSlotSchematic = self:GetReagentSlotSchematic(slotIndex);
	return allocations and allocations:HasAllAllocations(reagentSlotSchematic.quantityRequired);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:HasAllocatedReagent(reagent)
	for index, allocations in self:EnumerateAllAllocations() do
		if allocations:FindAllocationByReagent(reagent) then
			return true;
		end
	end
	return false;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:AreAllRequirementsAllocatedByItemID(itemID)
	local requirements = C_TradeSkillUI.GetReagentRequirementItemIDs(itemID);
	for index, requiredItemID in ipairs(requirements) do
		if not self:HasAllocatedItemID(requiredItemID) then
			return false;
		end
	end
	return true;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:AreAllRequirementsAllocated(item)
	return self:AreAllRequirementsAllocatedByItemID(item:GetItemID());
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:HasAllocatedItemID(itemID)
	local reagent = Professions.CreateCraftingReagentByItemID(itemID);
	return self:HasAllocatedReagent(reagent);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:HasAllocatedCurrencyID(currencyID)
	local reagent = Professions.CreateCraftingReagentByCurrencyID(currencyID);
	return self:HasAllocatedReagent(reagent);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:ClearSalvageAllocations()
	self:SetSalvageAllocation(nil);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SetSalvageAllocation(salvageItem)
	local changed = self.salvageItem ~= salvageItem;
	self.salvageItem = salvageItem;
	if changed then
		self:CallOnChangedHandler();
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetSalvageAllocation()
	return self.salvageItem;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetAllocationItemGUID()
	if self.salvageItem then
		return self.salvageItem:GetItemGUID();
	elseif self.enchantItem then
		return self.enchantItem:GetItemGUID();
	elseif self.recraftItemGUID then
		-- When setting the recraft allocation, we set the GUID directly so we can just return that.
		return self.recraftItemGUID;
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:ClearEnchantAllocations()
	self:SetEnchantAllocation(nil);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SetEnchantAllocation(enchantItem)
	local changed = self.enchantItem ~= enchantItem;
	self.enchantItem = enchantItem;
	if changed then
		self:CallOnChangedHandler();
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetEnchantAllocation()
	return self.enchantItem;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SetRecraft(isRecraft)
	self.isRecraft = isRecraft;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:IsRecraft()
	return self.isRecraft;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:ClearRecraftAllocation()
	self:SetRecraftAllocation(nil);
	self:SetRecraftAllocationOrderID(nil);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SetRecraftAllocation(itemGUID)
	local changed = self.recraftItemGUID ~= itemGUID;
	self.recraftItemGUID = itemGUID;
	self:CacheItemModifications();
	if changed then
		self:CallOnChangedHandler();
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SetRecraftAllocationOrderID(orderID)
	self.recraftOrderID = orderID;
	self:CacheItemModifications();
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:CacheItemModifications()
	if self.recraftItemGUID or self.recraftOrderID then
		self.recraftItemMods = self.recraftItemGUID and C_TradeSkillUI.GetItemSlotModifications(self.recraftItemGUID) or C_TradeSkillUI.GetItemSlotModificationsForOrder(self.recraftOrderID);
		if not self.recraftExpectedItemMods then
			self:ClearExemptedReagents();
			for dataSlotIndex, modification in ipairs(self.recraftItemMods) do
				local reagent = Professions.CreateCraftingReagentByItemID(modification.itemID);
				self:SetExemptedReagent(reagent, dataSlotIndex);
			end
		end
	else
		self.recraftItemMods = nil;
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetRecraftItemMods()
	return self.recraftItemMods;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetRecraftAllocation()
	return self.recraftItemGUID, self.recraftOrderID;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:HasRecraftAllocation()
	return self.recraftItemGUID ~= nil or self.recraftOrderID ~= nil;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:ClearModification(dataSlotIndex)
	local modificationTable = self:GetModificationTable();
	local modification = modificationTable and modificationTable[dataSlotIndex]
	if modification then
		modification.itemID = 0;
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetModificationTable()
	return self.recraftExpectedItemMods or self.recraftItemMods;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetModification(dataSlotIndex)
	-- If expected item mods have been set then we've sent off the transaction to the
	-- server and we're waiting for the item mods to be officially stamped onto the item.
	return self:GetModificationInternal(dataSlotIndex, self:GetModificationTable());
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetModificationAtSlotIndex(slotIndex)
	local reagentSlotSchematic = self:GetReagentSlotSchematic(slotIndex);
	return self:GetModification(reagentSlotSchematic.dataSlotIndex);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:IsModificationUnchangedAtSlotIndex(slotIndex)
	local modification = self:GetModificationAtSlotIndex(slotIndex);
	return modification and self:HasAllocatedItemID(modification.itemID);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetOriginalModification(dataSlotIndex)
	if self.recraftOrderID then
		-- Recrafting an order does not display previous modifications
		return nil;
	end
	return self:GetModificationInternal(dataSlotIndex, self.recraftItemMods);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:GetModificationInternal(dataSlotIndex, modificationTable)
	return modificationTable and modificationTable[dataSlotIndex] or nil;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:HasModification(dataSlotIndex)
	if self.recraftItemMods then
		return self.recraftItemMods[dataSlotIndex].itemID > 0;
	end
	return false;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:HasMetAllRequirements()
	if not self:HasMetSalvageRequirements() then
		return false;
	end

	if not self:HasMetQuantityRequirements() then
		return false;
	end

	if not self:HasMetPrerequisiteRequirements() then
		return false;
	end

	return true;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:HasMetSalvageRequirements()
	if self:IsRecipeType(Enum.TradeskillRecipeType.Salvage) then
		if not self.salvageItem then
			return false;
		end

		local recipeSchematic = self:GetRecipeSchematic();
		local quantity = self.salvageItem:GetStackCount();
		if not quantity then
			return false;
		end

		local quantityRequired = recipeSchematic.quantityMax;
		return quantity >= quantityRequired;
	end

	return true;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:HasMetQuantityRequirements()
	for slotIndex, reagentTbl in self:Enumerate() do
		local reagentSlotSchematic = reagentTbl.reagentSlotSchematic;
		if ProfessionsUtil.IsReagentSlotRequired(reagentSlotSchematic) then
			local quantityRequired = reagentSlotSchematic.quantityRequired;
			local allocations = self:GetAllocations(slotIndex);
			for reagentIndex, reagent in ipairs(reagentSlotSchematic.reagents) do
				local allocation = allocations:FindAllocationByReagent(reagent);
				if allocation then
					quantityRequired = quantityRequired - allocation:GetQuantity();
				end
			end

			if quantityRequired > 0 then
				return false;
			end
		end
	end

	return true;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:HasMetPrerequisiteRequirements()
	for slotIndex, reagentTbl in self:Enumerate() do
		local allocations = self:GetAllocations(slotIndex);
		local reagentSlotSchematic = reagentTbl.reagentSlotSchematic;
		for reagentIndex, reagent in ipairs(reagentSlotSchematic.reagents) do
			local allocation = allocations:FindAllocationByReagent(reagent);
			if allocation then
				if reagent.itemID and not self:AreAllRequirementsAllocatedByItemID(reagent.itemID) then
					return false;
				end
				if reagent.currencyID and not self:HasAllocatedCurrencyID(reagent.currencyID) then
					return false;
				end
			end
		end
	end

	return true;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:CreateCraftingReagentInfoTblIf(predicate)
	local tbl = {};
	for slotIndex, reagentTbl in self:Enumerate() do
		if predicate(reagentTbl, slotIndex) then
			local reagentSlotSchematic = reagentTbl.reagentSlotSchematic;
			local dataSlotIndex = reagentSlotSchematic.dataSlotIndex;
			for index, allocation in reagentTbl.allocations:Enumerate() do
				local quantity = allocation:GetQuantity();
				if quantity > 0 then
					-- CraftingReagentInfo can only ever be initialized with items, so we can disregard currency here.
					local reagent = allocation:GetReagent();
					local craftingReagentInfo = Professions.CreateCraftingReagentInfo(reagent.itemID, dataSlotIndex, quantity);
					table.insert(tbl, craftingReagentInfo);
				end
			end
		end
	end
	return tbl;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:CreateOptionalOrFinishingCraftingReagentInfoTbl()
	local function IsOptionalOrFinishing(reagentTbl)
		local reagentType = reagentTbl.reagentSlotSchematic.reagentType;
		return reagentType == Enum.CraftingReagentType.Modifying or reagentType == Enum.CraftingReagentType.Finishing;
	end
	return self:CreateCraftingReagentInfoTblIf(IsOptionalOrFinishing);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:CreateOptionalCraftingReagentInfoTbl()
	local function IsOptionalReagentType(reagentTbl)
		return reagentTbl.reagentSlotSchematic.reagentType == Enum.CraftingReagentType.Modifying;
	end
	return self:CreateCraftingReagentInfoTblIf(IsOptionalReagentType);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:CreateCraftingReagentInfoTbl()
	local function IsModifiedCraftingReagent(reagentTbl)
		return reagentTbl.reagentSlotSchematic.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent;
	end
	return self:CreateCraftingReagentInfoTblIf(IsModifiedCraftingReagent);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:CreateRegularReagentInfoTbl()
	local function IsRegularCraftingReagent(reagentTbl)
		return reagentTbl.reagentSlotSchematic.dataSlotType == Enum.TradeskillSlotDataType.Reagent;
	end
	return self:CreateCraftingReagentInfoTblIf(IsRegularCraftingReagent);
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:IsApplyingConcentration()
	return self.applyConcentration;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SetApplyConcentration(applyConcentration)
	if self.applyConcentration ~= applyConcentration then
		self.applyConcentration = applyConcentration;

		-- Update stat lines
		self:CallOnChangedHandler();

		-- Update toggle button state
		self:OnChanged();
	end
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:SetUseCharacterInventoryOnly(useCharacterInventoryOnly)
	self.useCharacterInventoryOnly = useCharacterInventoryOnly;
end

function ProfessionsOrderFix_ProfessionsRecipeTransactionMixin:ShouldUseCharacterInventoryOnly()
	return self.useCharacterInventoryOnly;
end

function CreateProfessionsOrderFix_ProfessionsRecipeTransaction(recipeSchematic)
	local transaction = CreateFromMixins(ProfessionsOrderFix_ProfessionsRecipeTransactionMixin);
	transaction:Init(recipeSchematic);
	return transaction;
end
