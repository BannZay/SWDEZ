local Debug = BannZay.Logger;
local Array = BannZay.Array;

local debugLevel = 0;
local debugTitle = "SWDEZ";
local dbg = Debug:New(debugTitle, debugLevel);
local ControlFrame = nil;
local FlashFrame = nil;
local treatSkillNames = nil;
local triggeredUnitNames = Array:New();

local events = {}

local function CreateTreatSkillNames()
	local treatSkillIds = Array:New();
	treatSkillIds:Add(12826); -- Polymorph
	treatSkillIds:Add(6358);  -- Seduction
	treatSkillIds:Add(19503); -- Scatter Shot
	treatSkillIds:Add(19386); -- Wyvern Sting
	
	local names = Array:New();
	
	for i,v in pairs(treatSkillIds:All()) do
		local spellName = GetSpellInfo(v);
		names:Add(spellName);
	end
	
	return names;
end
	
local function CreateFlashFrame()

	local flashFrame = CreateFrame("Frame")
	flashFrame:ClearAllPoints()
	flashFrame:SetPoint("TOP", "UIParent", "TOP", 0, 0);
	flashFrame:SetPoint("BOTTOM", "UIParent", "BOTTOM", 0, 0);
	flashFrame:SetPoint("LEFT", "UIParent", "LEFT", 0, 0);
	flashFrame:SetPoint("RIGHT", "UIParent", "RIGHT", 0, 0);
	flashFrame:Hide()
	
	local texture = flashFrame:CreateTexture(nil,BORDER);
	texture:SetAllPoints();
	texture:SetBlendMode("ADD");
	texture:SetTexture("Interface\\FullScreenTextures\\LowHealth", 0.5, 0.3, 0.2);
	texture:SetAlpha(1);
	
	return flashFrame;
end

local function AddUnit(triggeredUnit)
	local triggeredUnitName = UnitName(triggeredUnit);
	local kvp = KVP:New(GetTime(), triggeredUnitName);
	local item2 = kvp:Item2();
	dbg:Log(1, "Unit added:" .. triggeredUnitName);
	triggeredUnitNames:Add(kvp);
end

local function RemoveUnit(triggeredUnit)
	local triggeredUnitName = UnitName(triggeredUnit);
	
	local index = triggeredUnitNames:Find(function(kvp) return kvp:Item2() == triggeredUnitName end);
	
	if index ~= nil then
		triggeredUnitNames:RemoveAt(index);
		dbg:Log(1, "Unit removed:" .. triggeredUnitName);
	end
end

local function RemoveAllUnits()
	triggeredUnitNames:Clear();
	dbg:Log(2, "All units removed");
end

function OnLoad()
	ControlFrame:SetScript("OnUpdate", OnUpdate);
	ControlFrame:SetScript("OnEvent", function(self, event, ...) events[event](self, ...); end);
	for k, v in pairs(events) do
		ControlFrame:RegisterEvent(k);
	end

	dbg:Log(2, "Loaded");
	triggeredUnitNames = Array:New();
	treatSkillNames = CreateTreatSkillNames();
	FlashFrame = CreateFlashFrame();

	UIFrameFlash(FlashFrame, 0.1, 0.1, -1, false)
end

function OnUpdate()
	local now = GetTime();
	local lifeTimeSeconds = 3; -- in case of unknown bug, it will stop falshes after 3 seconds
	
	if triggeredUnitNames:Count() ~= nil then
		for i=1, triggeredUnitNames:Count(), 1 do
			local kvp = triggeredUnitNames:All()[i];
			if kvp ~= nil then
				local addedTime = kvp:Item1();
				local playerName = kvp:Item2();
						
				if (now - addedTime > lifeTimeSeconds) then
					triggeredUnitNames:RemoveAt(i);
					dbg.Log(0, "Alert was not removed in time, most likely there is a bug");
					i = i - 1;
				end
			end
		end
	end

	if triggeredUnitNames:Count() > 0 then
		FlashFrame:Show();
	else
		FlashFrame:Hide();
	end
end

function events:UNIT_SPELLCAST_START(unit, spellName)	
	if UnitIsFriend("player", unit) then return end
	if treatSkillNames:IndexOf(spellName) == nil then return end
	if (string.match(unit, "pet") and UnitName("player") ~= UnitName(unit.."target")) then return end
	AddUnit(unit)
end

function events:UNIT_SPELLCAST_STOP(unit, spellName, rankName, sourceFlags)
	RemoveUnit(unit);
end

function events:ZONE_CHANGED_NEW_AREA()
	RemoveAllUnits();
end

ControlFrame = CreateFrame("Frame");
OnLoad();