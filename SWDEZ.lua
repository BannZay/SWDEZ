local Debug = BannZay.Logger;
local Array = BannZay.Array;
local KVP = BannZay.KVP;

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
	treatSkillIds:Add(60192); -- Freezing Arrow
	treatSkillIds:Add(14311); -- Freezing Trap
	
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

local function AddUnit(triggeredUnit, lifeTimeSeconds)
	local triggeredUnitGuid = UnitGUID(triggeredUnit);
	
	if triggeredUnitNames:TranformAndFind(triggeredUnitGuid, function(x) return x:Item2() end) ~= nil then
		return false;
	end
	
	local kvp = KVP:New(GetTime() + lifeTimeSeconds, triggeredUnitGuid);
	triggeredUnitNames:Add(kvp);
	dbg:Log(1, "Unit added:" .. triggeredUnitGuid);
	return true;
end

local function RemoveUnit(triggeredUnit)
	local triggeredUnitName = UnitGUID(triggeredUnit);
	
	local item, index = triggeredUnitNames:Find(function(kvp) return kvp:Item2() == triggeredUnitName end);

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
	events:ZONE_CHANGED_NEW_AREA();

	dbg:Log(2, "Loaded");
	triggeredUnitNames = Array:New();
	treatSkillNames = CreateTreatSkillNames();
	FlashFrame = CreateFlashFrame();

	UIFrameFlash(FlashFrame, 0.1, 0.1, -1, false)
end

function OnUpdate()
	local now = GetTime();
	
	if triggeredUnitNames:Count() ~= nil then
		for i=1, triggeredUnitNames:Count(), 1 do
			local kvp = triggeredUnitNames:All()[i];
			if kvp ~= nil then
				local endTime = kvp:Item1();
				local id = kvp:Item2();
						
				if (now > endTime) then
					triggeredUnitNames:RemoveAt(i);
					dbg:Log(1, "Id '" .. id .. "' was automatically removed");
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

local function OnCastDetected(unit, spellName, lifeTimeSeconds)
	if UnitIsFriend("player", unit) then return end
	if treatSkillNames:IndexOf(spellName) == nil then return end
	if (string.match(unit, "pet") and UnitName("player") ~= UnitName(unit.."target")) then return end
	
	if AddUnit(unit, lifeTimeSeconds) == true then
		PlaySoundFile("Interface\\AddOns\\SWDEZ\\Sounds\\thing.ogg")
	end
end


function events:ZONE_CHANGED_NEW_AREA()
	local type = select(2, IsInInstance())
	
	-- Check if we are entering or leaving an arena and call the functions	
	if (type == "arena") then
		ControlFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
		ControlFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	else
		ControlFrame:UnregisterEvent("PLAYER_FOCUS_CHANGED")
		ControlFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
	end
end

function events:PLAYER_TARGET_CHANGED()
	local name = UnitCastingInfo("target")
	print(name)
	if name ~= nil then
		events:UNIT_SPELLCAST_START("target", name);
	end
end

function events:UNIT_SPELLCAST_START(unit, spellName)
	OnCastDetected(unit, spellName, 3);
end

function events:UNIT_SPELLCAST_SUCCEEDED(unit, spellName)
	OnCastDetected(unit, spellName, 1);
end

function events:UNIT_SPELLCAST_STOP(unit, spellName, rankName, sourceFlags)
	RemoveUnit(unit);
end

function events:ZONE_CHANGED_NEW_AREA()
	RemoveAllUnits();
end

ControlFrame = CreateFrame("Frame");
OnLoad();