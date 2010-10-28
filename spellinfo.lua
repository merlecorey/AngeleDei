local abilitiesWithCooldowns = { CS, HOR, J, AS, HW, CO }; --, HOW };

-- Add a spell cooldown
local AddSpell = function(this, spellID, cooldown, icon)
	--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFFD000Angeli Dei / spellinfo|r] " .. (spellID or "?") .. ": " .. cooldown);

	local name, rank, ii = GetSpellInfo(spellID);

	if(icon == nil) then
		icon = ii;
	end
	
	if(icon == nil) then
		if(spellID == IDLE) then
			icon = "Interface\\Icons\\Spell_Nature_Polymorph_Cow";
		elseif(spellID == INQ) then
			icon = "Interface\\Icons\\Ability_Paladin_SheathofLight";		-- TBI
		end		
	end
		
	local info = { };
	info.id = spellID;
	info.name = name;
	info.icon = icon;
	info.cooldown = cooldown;
	
	this.cooldowns[spellID] = info;
end

-- Add an effect
local AddEffect = function(this, spellID, expiration)
	--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFFD000Angeli Dei / spellinfo|r] " .. (name or "?") .. "*: " .. expiration;

	local name = GetSpellInfo(spellID);

	local info = { };
	info.id = spellID;
	info.name = name;
	info.icon = nil;
	info.expiration = expiration;

	this.effects[spellID] = info;
end

-- Get the ability cooldown time
local GetCooldown = function(this, spellID)
	return this.cooldowns[spellID].cooldown;
end

-- Get the name of the ability
local GetName = function(this, spellID)
	return this.cooldowns[spellID].name;
end

-- Get the ability icon
local GetIcon = function(this, spellID)
	return this.cooldowns[spellID].icon;
end

-- Get the effect expiration time
local GetExpiration = function(this, spellID)
	return this.effects[spellID].expiration;
end

-- Find out whether this spell is known to us
local IsKnownSpell = function(this, spellID)
	return this.cooldowns[spellID] ~= nil;
end

-- Check if we have the glyph with the given spellID (glyph types: 1=major, 2=minor, 3=prime)
local function hasGlyph(targetSpellID, targetType)
	for i = 1, GetNumGlyphSockets() do
		local enabled, glyphType, glyphLocation, glyphSpellID, icon = GetGlyphSocketInfo(i);
		if(enabled) and (glyphSpellID) then
			if(glyphSpellID == targetSpellID) and (glyphType == targetType) then
				return true;
			end
		end
	end
	return false;
end

-- Get the number of talent points in the given talent
local talentRank = function(spellID)
	-- Translate spell ID into spell name to avoid localization
	local name = GetSpellInfo(spellID);
	if(name == nil) then
		return 0;
	end
	
	local tabs = GetNumTalentTabs();
	for t=1,tabs do
	    local talents = GetNumTalents(t);
	    for i=1,talents do
	        local n, _, _, _, rank = GetTalentInfo(t, i);
	        if(n == name) then
				--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFFD000Angeli Dei / spellinfo|r] " .. name .. " = " .. rank);
	        	return rank;
	        end
	    end
	end

	--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFFD000Angeli Dei / spellinfo|r] " .. name .. " = 0");
	return 0;
end

-- Get a list of abilities with cooldowns
local GetAbilitiesWithCooldowns = function(this)
	return abilitiesWithCooldowns;
end

local IsProtection = function(this)
	return this.protection;
end

-- Constructor
function CreateSpellinfo()
	local t = { };
	
	t.cooldowns = { };
	t.effects = { };
	t.protection = (talentRank(20925) > 0);		-- Holy Shield
	
	t.AddSpell = AddSpell;
	t.AddEffect = AddEffect;
	t.GetIcon = GetIcon;
	t.GetName = GetName;
	t.GetCooldown = GetCooldown;
	t.GetExpiration = GetExpiration;
	t.IsKnownSpell = IsKnownSpell;
	t.GetAbilitiesWithCooldowns = GetAbilitiesWithCooldowns;
	t.IsProtection = IsProtection;

	t:AddSpell(CS, 3);
	t:AddSpell(HOR, 3, "Interface\\Icons\\Ability_Paladin_HammeroftheRighteous");
	t:AddSpell(SHOR, 0, "Interface\\Icons\\Ability_Paladin_ShieldofVengeance");
	t:AddSpell(INQ, 0);
	t:AddSpell(J, 8)
	t:AddSpell(AS, 24 - talentRank(84854)*3, "Interface\\Icons\\Spell_Holy_AvengersShield");	-- Shield of the Templar
	t:AddSpell(HW, 15);
	t:AddSpell(CO, 30 + (hasGlyph(54928, 1) and 6 or 0));		-- Glyph of Consecration
	t:AddSpell(HOW, 6);
	t:AddSpell(WOG, 0);
	t:AddSpell(HOJ, 60 - talentRank(20488)*10);		-- Improved Hammer of Justice
	
	t:AddEffect(HS, 20);
	t:AddEffect(SD, 15);
	t:AddEffect(JOTW, 10);
	t:AddEffect(GC, 0);

	t:AddSpell(IDLE, 0, "Interface\\Icons\\Spell_Nature_Polymorph_Cow");	-- An empty GCD is not a real ability, but...

	return t;
end
