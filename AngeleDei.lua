-- Bootstrapping code
AngeleDei = CreateFrame("Frame");
AngeleDei:SetScript('OnEvent', function(self, ...)
	self:Enable(...);
end);
AngeleDei:RegisterEvent("PLAYER_ENTERING_WORLD");

-- Local state
local queue = { };
local lastList = nil;
local hopo = 0;

-- Various visual effects
local currentShiftStart = nil;
local currentShiftEnd = nil;
local nextShiftStart = nil;
local nextShiftEnd = nil;
local otherShiftStart = nil;
local otherShiftEnd = nil;
local idleShift = nil;
local fadeInStart = nil;
local fadeInEnd = nil;
local fadeOutStart = nil;
local fadeOutEnd = nil;
local unlockEnd = nil;
local messageStart = nil;
local messageShown = nil;
local messageFadeOutStart = nil;
local messageEnd = nil;

-- Various display parameters
local QUEUE_SIZE = 4;			-- The last is always invisible
local NEXT_ICON_OFFSET = 96;
local ICON_SPACING = 36;
local FONT = "Interface\\AddOns\\AngeleDei\\fonts\\russel square lt.ttf";
local MESSAGE_FONT = "Fonts\\FRIZQT__.TTF";		-- "Fonts\\SKURRI.TTF";
local ALPHA_STEP = 1.0/(QUEUE_SIZE-1);

local Spellinfo = nil;
local State = nil;
local Rotation = nil;
local Config = { };
local Keystrokes = { };

-- A list of all rotation that we support
local Rotations = { };

-- Vengeance stoplight style colors
local vengeanceStoplight = { "red", "orange", "yellow", "lime", "green" };

-- Initialize the addon
function AngeleDei:Enable(event)
	-- We needed these events for initialization only
	AngeleDei:UnregisterEvent("PLAYER_ENTERING_WORLD");
	AngeleDei:SetScript("OnEvent", nil);

	-- Disable this addon if the player is not a paladin
	local _, c = UnitClass("player");
	if(c ~= "PALADIN") then
		DEFAULT_CHAT_FRAME:AddMessage(MESSAGE_WRONG_CLASS, 1, 1, 1);
		return
	end
	
	-- We'll use this frame for timer and combat log events
	AngeleDei:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	AngeleDei:RegisterEvent("PLAYER_TARGET_CHANGED");
	AngeleDei:RegisterEvent("ACTIONBAR_PAGE_CHANGED");
	AngeleDei:RegisterEvent("UNIT_AURA");
	AngeleDei:RegisterEvent("PLAYER_ALIVE");
	AngeleDei:RegisterEvent("PLAYER_DEAD");
	AngeleDei:RegisterEvent("PLAYER_REGEN_ENABLED");
	AngeleDei:RegisterEvent("PLAYER_REGEN_DISABLED");
	AngeleDei:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
	
	AngeleDei:SetScript("OnUpdate", AngeleDei.OnUpdate);
	AngeleDei:SetScript("OnEvent", AngeleDei.OnEvent);
	
	DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD000Angele Dei|r: Protection Paladin rotation made easy."
		--.. " |TInterface\\Icons\\Ability_Paladin_DivineStorm:20:20:0:0|t"
		--.. " |TInterface\\Icons\\Ability_Paladin_ProtectoroftheInnocent:20:20:0:0|t"	
		--.. " |TInterface\\Icons\\Ability_Paladin_SwiftRetribution:20:20:0:0|t"	
		--.. " |TInterface\\Icons\\Ability_SteelMelee:20:20:0:0|t"	
		--.. " |TInterface\\Icons\\Ability_ThunderBolt:20:20:0:0|t"	
		, 1, 1, 1);
	
	-- Create a Vengeance tooltip scanner
	AngeleDei:CreateTooltipScanner();
	
	-- This one will not work on the first login but it WILL work after subsequent UI reloads
	Spellinfo = CreateSpellinfo();				
	AngeleDei.Spellinfo = Spellinfo;
	
	State = CreateState();
	
	-- Add some rotations
	Rotations[#Rotations+1] = CreateRotationTheck939();
	Rotations[#Rotations+1] = CreateRotationAOE939();
	Rotation = Rotations[1];
	
	-- Retrieve configuration settings; make sure we have default values available
	Config = Options:SetDefaults();				
	Keystrokes = (Config.rotations or { })[Rotation.name] or { };
	
	-- Try setting the current rotation based on the action bar page (if this is not successful,
	-- the rotation will be set to the default single-target)
	AngeleDei:RotationByActionBarPage(true);
	
	-- Visual stuff
	AngeleDei:CreateIcons();
	
	-- Display the frame (if enabled). This will also do the initial simulation run
	AngeleDei_RotationFrame:SetScale(Config.scale);
	AngeleDei_RotationFrame:EnableMouse(not Config.locked);
	if(Config.enabled) then
		AngeleDei:EnableAddon(true);
	else
		AngeleDei:DisableAddon(true);
	end
	
	-- Update the holy power indicator according to the settings
	AngeleDei:UpdateHolyPowerIndicatorStyle();
	AngeleDei:UpdateVengeanceIndicatorStyle();

	-- Set up command line interface
	SLASH_AD1 = "/AD";
	SLASH_AD2 = "/ANGELEDEI";
	SlashCmdList["AD"] = AngeleDei_SlashCommand;
end

-- Process /ad commands
function AngeleDei_SlashCommand(msg)
	if(msg == "cfg") then
		-- Open configuration window
		InterfaceOptionsFrame_Show();			-- This line is a hack. Other mods don't seem to need it, but I can't make the window show without it...
		InterfaceOptionsFrame_OpenToCategory('Angele Dei');
	elseif(msg == "show") or (msg == "on") then
		-- Enable the AD addon
		AngeleDei:EnableAddon();
	elseif(msg == "hide") or (msg == "off") then
		-- Disable the AD addon
		AngeleDei:DisableAddon();
	elseif(msg == "reset") then
		-- Re-center the frame
		AngeleDei_RotationFrame:ClearAllPoints();
		AngeleDei_RotationFrame:SetPoint("CENTER", UIParent, "CENTER");
	elseif(msg == "move") then
		-- Make the window movable for 10 seconds
		if(Config.locked) then
			AngeleDei_RotationFrame:EnableMouse(true);
			for i=1,#queue do
				queue[i]:SetVertexColor(0, 1, 0.75);
			end
			unlockEnd = GetTime() + 10;
		end
	else
		-- Print command line help
		for i=1,#CMDLINE_HELP do
			DEFAULT_CHAT_FRAME:AddMessage(CMDLINE_HELP[i], 1, 1, 1);
		end
	end
end

-- Enable the addon (NOOP if already enabled)
function AngeleDei:EnableAddon(force)
	if(Config.enabled) and (not force) then
		return;
	end
	
	Config.enabled = true;
	AngeleDei:RunSimulation(GetTime(), "On enable", true);
	AngeleDei_RotationFrame:SetAlpha(0);
	AngeleDei_RotationFrame:Show();
	fadeInStart = GetTime();
	fadeInEnd = fadeInStart + 0.2;
end

-- Disable the addon (NOOP if already disabled)
function AngeleDei:DisableAddon(force)
	if(not Config.enabled) and (not force) then
		return;
	end
	
	Config.enabled = false;
	fadeOutStart = GetTime();
	fadeOutEnd = fadeOutStart + 0.2;
end

-- Get the settings map
function AngeleDei:GetSettings()
	if(AngeleDeiPreferencesMkIII == nil) then
		AngeleDeiPreferencesMkIII = { };		
	end
	return AngeleDeiPreferencesMkIII;
end

-- Get the list of rotation names
function AngeleDei:GetRotations()
	return Rotations;
end

-- Create Vengeance tooltip scanner
function AngeleDei:CreateTooltipScanner()
	AngeleDei_RotationFrame.scanner = CreateFrame("GameTooltip", "VengeanceStatusScanTip", nil, "GameTooltipTemplate")
	AngeleDei_RotationFrame.scanner:SetOwner(UIParent, "ANCHOR_NONE")
end

-- Create frame icons
function AngeleDei:CreateIcons()
	queue[1] = AngeleDei:createEmptyTexture(36, 1, IDLE, Keystrokes[IDLE]);
	queue[1]:SetWidth(48);
	queue[1]:SetHeight(48);

	for i=0,QUEUE_SIZE-2 do
		queue[i+2] = AngeleDei:createEmptyTexture(NEXT_ICON_OFFSET + (i*ICON_SPACING), 1-(i+1)*ALPHA_STEP, IDLE, Keystrokes[IDLE]);	-- i<3 and 0.3 or 0.15
	end

	-- Set textures of all icons	
	for i=1,#queue do
		queue[i]:SetTexture(Spellinfo:GetIcon(IDLE));
		queue[i].time = 1000000000;
	end

	local y0 = (AngeleDei_RotationFrame_HP_1:GetTop() + AngeleDei_RotationFrame_HP_1:GetBottom()) / 2;
	local y1 = (AngeleDei_RotationFrame_HP_3:GetTop() + AngeleDei_RotationFrame_HP_3:GetBottom()) / 2;
	
	--local names = { "red-s", "orange-s", "yellow-s", "lime-s", "green-s" };
	local names = { "orange-s", "orange-s", "orange-s", "orange-s", "orange-s" };
	
	AngeleDei_RotationFrame.vengeanceDark = { };
	AngeleDei_RotationFrame.vengeanceLight = { };
	
	for i=0,4 do	
		local t = AngeleDei_RotationFrame:CreateTexture(nil, "BACKGROUND");
		t:SetPoint("CENTER", AngeleDei_RotationFrame_HP_1, "CENTER", -20, i/4*(y1-y0));
		t:SetTexture("Interface\\AddOns\\AngeleDei\\images\\dark-s.tga");
		t:SetWidth(16);
		t:SetHeight(16);
		t:SetAlpha(1);
		
		local tt = AngeleDei_RotationFrame:CreateTexture(nil, "ARTWORK");
		tt:SetPoint("CENTER", t, "CENTER");
		
		local color = (Config.vengeanceStyle == "stoplight") and vengeanceStoplight[i+1] or Config.vengeanceStyle;		
		tt:SetTexture("Interface\\AddOns\\AngeleDei\\images\\" .. color .. "-s.tga");
		
		tt:SetWidth(16);
		tt:SetHeight(16);
		tt:SetBlendMode("BLEND");
		tt:SetAlpha(0);
		
		AngeleDei_RotationFrame.vengeanceDark[i] = t;
		AngeleDei_RotationFrame.vengeanceLight[i] = tt;

		if(Config.vengeanceEnabled) then
			t:Show();
			tt:Show();
		end
	end

	if(Config.vengeanceEnabled) then
		AngeleDei:UpdateVengeanceIndicator();
	end
end

-- Update the appearance of the frame based on the settings. This is called
-- after the settings are saved.
function AngeleDei:UpdateAppearance()
	for i=1,#queue do
		local icon = queue[i];
		icon.label:SetText(Keystrokes[icon.ability]);
	end
	AngeleDei:UpdateHolyPowerIndicatorStyle();
	AngeleDei:UpdateVengeanceIndicatorStyle();
	AngeleDei_RotationFrame:SetScale(Config.scale);
	AngeleDei_RotationFrame:EnableMouse(not Config.locked);
	
	AngeleDei:RunSimulation(GetTime(), "On config change", true);
end

-- Start the icon shift animation
function AngeleDei:Shift(t)
	idleShift = nil;
	currentShiftStart = t;
	currentShiftEnd = currentShiftStart + 0.3;
	nextShiftStart = t + 0.25;
	nextShiftEnd = nextShiftStart + 0.35;
	otherShiftStart = t + 0.5;
	otherShiftEnd = otherShiftStart + 0.35;

	local recycled = table.remove(queue, 1);
	queue[#queue+1] = recycled;
end

-- Update the holy power indicator based on the current UI settings
function AngeleDei:UpdateHolyPowerIndicatorStyle()
	local a1, a2, a3 = 1, 1, 1;
	
	-- Set alpha
	if(Config.fadeOut) then
		if(Config.style == "stoplight") then
			a1, a2, a3 = 1, 0.5, 0.5;
		else
			a1, a2, a3 = 0.5, 0.5, 1;
		end
	end
	
	AngeleDei_RotationFrame_HP_1:SetAlpha(a1);
	AngeleDei_RotationFrame_HP_2:SetAlpha(a2);
	AngeleDei_RotationFrame_HP_3:SetAlpha(a3);
	
	AngeleDei:UpdateHolyPower(getHolyPower());
end

-- Update the vengeance indicator based on the current UI settings
function AngeleDei:UpdateVengeanceIndicatorStyle()
	for i=0,4 do
		local dark = AngeleDei_RotationFrame.vengeanceDark[i];
		local light = AngeleDei_RotationFrame.vengeanceLight[i];
		
		local color = (Config.vengeanceStyle == "stoplight") and vengeanceStoplight[i+1] or Config.vengeanceStyle;
		light:SetTexture("Interface\\AddOns\\AngeleDei\\images\\" .. color .. "-s.tga");
		
		if(Config.vengeanceEnabled) then
			dark:Show();
			light:Show();
		else
			dark:Hide();
			light:Hide();
		end
	end
	
	-- Just in case we do it while we have Vengeance...
	AngeleDei:UpdateVengeanceIndicator();
end

-- Update the holy power indicator based on the current level of HoPo
function AngeleDei:UpdateHolyPower(h)	
	local t1, t2, t3;
	local style = Config.style;
	if(style == "stoplight") then
		t3 = (h == 1) and "red" or "dark";
		t2 = (h == 2) and "yellow" or "dark";
		t1 = (h == 3) and "green" or "dark";
	else
		t3 = (h >= 3) and style or "dark";
		t2 = (h >= 2) and style or "dark";
		t1 = (h >= 1) and style or "dark";
	end

	local a1, a2, a3 = 1, 1, 1;

	AngeleDei_RotationFrame_HP_1:SetTexture("Interface\\AddOns\\AngeleDei\\images\\" .. t1);
	AngeleDei_RotationFrame_HP_2:SetTexture("Interface\\AddOns\\AngeleDei\\images\\" .. t2);
	AngeleDei_RotationFrame_HP_3:SetTexture("Interface\\AddOns\\AngeleDei\\images\\" .. t3);
	
	-- Schedule a blink if the corresponding option is set
	if(h == 3) and (Config.blink) then
		hopo3BlinkStart = GetTime();
		hopo3BlinkEnd = hopo3BlinkStart + 0.45;
	end
end

-- Handle heartbeat
function AngeleDei:OnUpdate()
	local t = GetTime();
	
	-- Animate the rotation switch message
	if(messageStart) then
		local mess = AngeleDei_RotationFrame.message;
		if(t >= messageEnd) then
			mess:Hide();
			mess:SetAlpha(1);
			messageStart = nil;
			messageShown = nil;
			messageFadeOutStart = nil;
			messageEnd = nil;
		elseif(t >= messageFadeOutStart) then
			mess:SetAlpha((t - messageEnd) / (messageFadeOutStart - messageEnd));		
		elseif(t >= messageShown) then
			mess:SetAlphaGradient(100, 0);		
			mess:SetAlpha(1);
		elseif(t >= messageStart) then
			local len = string.len(mess:GetText()) + 1;
			local g = len * (t - messageStart) / (messageShown - messageStart);
			mess:SetAlphaGradient(g, 4);		
		end			
	end	
	
	-- Keep the window movable until 'unlockEnd'
	if(unlockEnd) then
		if(t >= unlockEnd) then
			for i=1,#queue do
				queue[i]:SetVertexColor(1, 1, 1);
			end
			AngeleDei_RotationFrame:EnableMouse(not Config.locked);
			unlockEnd = nil;
		end
	end
	
	-- Fade entire frame in or out
	if(fadeInStart) then
		if(t >= fadeInEnd) then
			AngeleDei_RotationFrame:SetAlpha(1);
			fadeInStart = nil;
			fadeInEnd = nil;
		elseif(t >= fadeInStart) then
			AngeleDei_RotationFrame:SetAlpha((t - fadeInStart) / (fadeInEnd - fadeInStart));		
		end
	elseif(fadeOutStart) then
		if(t >= fadeOutEnd) then
			AngeleDei_RotationFrame:Hide();
			AngeleDei_RotationFrame:SetAlpha(1);
			fadeOutStart = nil;
			fadeOutEnd = nil;
		elseif(t >= fadeOutStart) then
			AngeleDei_RotationFrame:SetAlpha((t - fadeOutEnd) / (fadeOutStart - fadeOutEnd));		
		end
	end
	
	-- Update holy power indicator
	local h = getHolyPower();
	if(h ~= hopo) then
		AngeleDei:UpdateHolyPower(h);
		hopo = h;
	end

	-- Handle HoPo indicator blinking
	if(hopo3BlinkStart) then
		local hp3icon = (Config.style == "stoplight") 
			and AngeleDei_RotationFrame_HP_1 
			or AngeleDei_RotationFrame_HP_3;
		local hp3texture = (Config.style == "stoplight") 
			and "Interface\\AddOns\\AngeleDei\\images\\green" 
			or "Interface\\AddOns\\AngeleDei\\images\\" .. Config.style;
		if(t >= hopo3BlinkEnd) then
			hopo3BlinkStart = nil;
			hopo3BlinkEnd = nil;
			hp3icon:SetTexture(hp3texture);
		else
			local a = mod(floor((t - hopo3BlinkStart)/0.075 + 0.5), 2);
			if(a == 0) then
				hp3icon:SetTexture(hp3texture);
			else
				hp3icon:SetTexture("Interface\\AddOns\\AngeleDei\\images\\dark");
			end			
		end			
	end	

	-- Handle icon blinking
	for i=1,QUEUE_SIZE-1 do
		local x = queue[i];
		if(x.blinkStart) then
			if(t >= x.blinkEnd) then
				x.blinkStart = nil;
				x.blinkEnd = nil;
				x.previous = nil;
				
				x:SetTexture(Spellinfo:GetIcon(x.ability));
				x:SetVertexColor(1, 1, 1);
			elseif(t >= x.blinkStart) then
				local a = mod(floor((t - x.blinkStart)/0.075 + 0.5), 2);
				if(a == 0) then
					x:SetTexture(Spellinfo:GetIcon(x.previous));
					x:SetVertexColor(1, 0, 0);
				else
					x:SetTexture(Spellinfo:GetIcon(x.ability));
					x:SetVertexColor(1, 1, 1);
				end
			end
		end
	end

	-- A forced shift due to an idle rotation slot?
	if(idleShift) then
		if(queue[1].ability ~= IDLE) then
			--DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Angele Dei|r: Idle shift cancelled", 1, 1, 1);
			idleShift = nil;				-- It's no longer an idle slot		
		elseif(t >= idleShift) then
			idleShift = nil;
			--DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFAngele Dei|r: Shift (IDLE)", 1, 1, 1);
			State:SetLastUsed(IDLE);
			AngeleDei:Shift(t);
			--DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF80Angele Dei|r: Simulation (IDLE completed)", 1, 1, 1);
			AngeleDei:RunSimulation(t, "Idle shift");		-- Just like we would if we used an ability
		end
	end

	-- The current icon slides down and fades out
	if(currentShiftStart) then
		local last = queue[#queue];
		if(t >= currentShiftEnd) then
			currentShiftStart = nil;
			currentShiftEnd = nil;
			last:SetAlpha(0);
			last:Hide();
			last:SetWidth(32);
			last:SetHeight(32);
		elseif(t >= currentShiftStart) then
			local a = (currentShiftEnd - t)/(currentShiftEnd - currentShiftStart);
			last:SetAlpha(a);
			last.label:SetAlpha(a);
			last:SetPoint("CENTER", AngeleDei_RotationFrame, "LEFT", 36, -96*(1-a));
		end
	end
	
	-- The next icon slides left into the frame and fades in to 100%
	if(nextShiftStart) then
		if(t >= nextShiftEnd) then
			nextShiftStart = nil;
			nextShiftEnd = nil;
			queue[1]:SetAlpha(1);
			queue[1]:SetPoint("CENTER", AngeleDei_RotationFrame, "LEFT", 36, 0);
			queue[1]:SetWidth(48);
			queue[1]:SetHeight(48);
		elseif(t >= nextShiftStart) then
			local a = (t - nextShiftStart)/(nextShiftEnd - nextShiftStart);
			queue[1]:SetAlpha(1 + (a-1)*ALPHA_STEP);
			queue[1]:SetPoint("CENTER", AngeleDei_RotationFrame, "LEFT", NEXT_ICON_OFFSET - a*(NEXT_ICON_OFFSET - ICON_SPACING), 0);
			queue[1]:SetWidth(32+16*a);
			queue[1]:SetHeight(32+16*a);
		end
	end
	
	-- All other icons slide left
	if(otherShiftStart) then
		if(t >= otherShiftEnd) then
			-- This is the end of the animation. Set the final positions and alpha values.
			otherShiftStart = nil;
			otherShiftEnd = nil;

			for i=0,#queue-2 do
				queue[i+2]:SetAlpha(1-(i+1)*ALPHA_STEP); -- 0.75-i*0.25);
				queue[i+2]:SetPoint("CENTER", AngeleDei_RotationFrame, "LEFT", NEXT_ICON_OFFSET + (i*ICON_SPACING), 0);
				queue[i+2]:Show();
			end
			--DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Angele Dei|r: Shift completed", 1, 1, 1);

			-- If the new current ability is idle, schedule another shift 0.65 = (1.5 - 'otherShiftEnd' delay) seconds later
			if(queue[1].ability == IDLE) then
				idleShift = t + queue[1].idle - 0.85;
			end
		elseif(t >= otherShiftStart) then
			local a = (t - otherShiftStart)/(otherShiftEnd - otherShiftStart);
			for i=1,#queue-2 do
				queue[i+1]:SetAlpha(1-(i-a+1)*ALPHA_STEP); -- 0.75-(i-a)*0.25);
				queue[i+1]:SetPoint("CENTER", AngeleDei_RotationFrame, "LEFT", NEXT_ICON_OFFSET + ((i-a)*ICON_SPACING), 0);
			end
		end
	end
end

-- Get the current holy power
function getHolyPower()
	return UnitPower("player", 9);
end

-- Event handler
function AngeleDei:OnEvent(event, timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, p1, p2, p3, s1, s2, s3, s4, s5, s6, s7)
	-- Handle the very first instance of either PLAYER_ALIVE or PLAYER_DEAD. These events indicate that
	-- all talent information is available to the UI. We'll use it to reload the Spellinfo object
	if(event == "PLAYER_ALIVE") or (event == "PLAYER_DEAD") then
		AngeleDei:UnregisterEvent("PLAYER_ALIVE");	-- Do it only once!
		AngeleDei:UnregisterEvent("PLAYER_DEAD");
		Spellinfo = CreateSpellinfo();				-- Talents are guaranteed to be available by now
		AngeleDei.Spellinfo = Spellinfo;
		return;
	end
	
	-- Process action bar page changes (duh)
	if(event == "ACTIONBAR_PAGE_CHANGED") then
		AngeleDei:RotationByActionBarPage();
		return
	end
	
	-- Update spell info on dual-spec switching
	if(event == "ACTIVE_TALENT_GROUP_CHANGED") then
		local wasProt = Spellinfo:IsProtection();	
		Spellinfo = CreateSpellinfo();
		AngeleDei.Spellinfo = Spellinfo;
		local isProt = Spellinfo:IsProtection();
		
		if(wasProt) and (not isProt) then
			-- Switched away from prot. Remember the enable/disable state at this time
			Config.stateBeforeTalentSwitch = Config.enabled;
			if(Config.protOnly) then
				AngeleDei:DisableAddon();
			end
		elseif(not wasProt) and (isProt) then
			-- Switched to prot. Enable or disable the addon depending on what it was before
			-- the last switch away from prot
			if(Config.stateBeforeTalentSwitch) then
				AngeleDei:EnableAddon();
			else
				AngeleDei:DisableAddon();
			end
		end

		return		
	end
	
	-- If the "combat toggle" option is set, enable the addon when we enter combat
	-- and disable it when combat ends.
	if(event == "PLAYER_REGEN_ENABLED") then
		if(Config.combatToggle) and (Spellinfo:IsProtection() or (not Config.protOnly)) then
			AngeleDei:DisableAddon();
		end
		return;
	elseif(event == "PLAYER_REGEN_DISABLED") and (Config.combatToggle) and (Spellinfo:IsProtection() or (not Config.protOnly)) then
		if(Config.combatToggle) and (Spellinfo:IsProtection() or (not Config.protOnly)) then
			AngeleDei:EnableAddon();
		end
		return;
	end
	
	local myself = UnitName("player");
		
	-- Process aura changes (used for vengeance)
	if(event == "UNIT_AURA" and Config.vengeanceEnabled) then
		if(timestamp == "player") then
			AngeleDei:UpdateVengeanceIndicator();
		end
		return;
	end
	
	-- Re-run the simulation if the player changed the current target to
	-- or from a low-health target
	if(event == "PLAYER_TARGET_CHANGED") then
		updateSimulation(event, nil, nil, nil);
		return;
	end
	
	-- Debug output for all combat events
	if(srcName == myself) or (dstName == myself) then 
		--ChatFrame1:AddMessage(myself .. ": " .. stringify(eventType) .. "/" .. stringify(p2) .. " (" .. stringify(srcName) .. ":" .. stringify(dstName) .. ") #1:" .. stringify(s1) .. " #2:" .. stringify(s2));
	end
	
	-- Ignore spellcasts and energy restore procs generated by other people
	if((eventType == "SPELL_CAST_SUCCESS") or (eventType == "SPELL_ENERGIZE")) and (srcName ~= myself) then
		return;
	end
	
	-- Ignore all other events that are not related to me
	if(srcName ~= myself) and (dstName ~= myself) then
		return;
	end
	
	-- Update the simulation based on combat log events
	updateSimulation(eventType, p1, p2, s2);	
end

-- Process an event that could make us re-run the simulation
function updateSimulation(eventType, p1, p2, s2)
	-- 'p1' is spellID, 'p2' is name
	local needUpdate = State:ApplyEvent(eventType, p1, s2, Spellinfo);
	
	-- If the addon is disabled, we will not update the frame (but we will still
	-- maintain our state!)
	if(not Config.enabled) then
		return;
	end
	
	-- If the rotation is not target-sensitive, do not re-run the sim when the target changes.
	-- This should reduce jitter for AOE rotations when target die quickly
	if(eventType == "PLAYER_TARGET_CHANGED") and (not Rotation:IsTargetSensitive()) then
		return;
	end

	local t = GetTime();

	if(needUpdate == 2) then
		--DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFAngele Dei|r: Shift (" .. eventType .. " / " .. p2 .. ")", 1, 1, 1);
		AngeleDei:Shift(t);
	end
	
	if(needUpdate ~= 0) then
		--DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF80Angele Dei|r: Simulation (" .. eventType .. " / " .. p2 .. ")", 1, 1, 1);
		AngeleDei:RunSimulation(t, p2 or "(" .. eventType .. ")");
		--local list = Rotation:GetNext(5, GetTime(), Spellinfo, State);
		--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFFC000Angeli Dei|r] Next " .. #list .. ":");			
		--for i=1,#list do
		--	if(lastList == nil) or (lastList[i+1] == nil) or (lastList[i+1] == list[i]) then		
		--		DEFAULT_CHAT_FRAME:AddMessage("    " .. list[i]);
		--	else
		--		DEFAULT_CHAT_FRAME:AddMessage("    " .. list[i] .. " (was: " .. lastList[i+1] .. ")");
		--	end
		--end
		--lastList = list;
	end
end

-- Re-run a simulation and modify the queue accordingly
function AngeleDei:RunSimulation(t, reason, suppressSound)
	--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFFD000Angeli Dei|r] Next " .. (#queue-1) .. " -- |cFFFFD000" .. reason .. "|r @ " .. format("%4.3f", t));
	local list = Rotation:GetNext(#queue-1, t, Spellinfo, State, Config);
	local changed = nil;
	for i=1,#list do
		--DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF    " .. list[i].ability .. " @ " .. format("%4.3f", list[i].time - t) .. " / " .. (list[i].idle or "?"));

		local x = queue[i];
		local a = list[i];
		x.previous = x.ability;
		x.ability = a.ability;
		x.time = a.time;
		x.idle = a.idle;
		x:SetTexture(Spellinfo:GetIcon(x.ability));
		x.label:SetText(Keystrokes[x.ability]);

		if(onEnable) then
			x.previous = x.ability;
			x.blinkStart = nil;
			x.blinkEnd = nil;
		else
			-- Blink it if it has changed
			if(x.previous ~= x.ability) then
				-- We'll use it to choose the sound
				if(changed == nil) then
					changed = i;
				end
				x.blinkStart = t;
				x.blinkEnd = t+0.45;			
			end
		end
		
	end

	if(changed) and (changed == 1) and (not suppressSound) then
		PlaySoundFile("Interface\\AddOns\\AngeleDei\\sounds\\lutnia1_1.ogg");
	end
end

-- Create a new, empty texture. We'll need five of them
function AngeleDei:createEmptyTexture(x, alpha, ability, text)
	local t = AngeleDei_RotationFrame:CreateTexture();
	t.ability = ability;
	
	local label = AngeleDei_RotationFrame:CreateFontString();
	label:SetPoint("TOPRIGHT", t, "TOPRIGHT", 0, -2);
	label:SetFont(FONT, 12, "OUTLINE");
	label:SetTextColor(1, 1, 1, 1);
	label:SetShadowColor(0, 0, 0, 0.5);
	label:SetShadowOffset(1.5, -1.5);
	label:SetText(text or "A");	
	t.label = label;
	
	-- These are related to blink notifications when the icon changes
	t.previous = nil;
	t.blinkStart = nil;
	t.blinkEnd = nil;

	t.SetAlpha_Old = t.SetAlpha;
	t.SetAlpha = function(obj, x)		-- Hmm. This is kinda neat...
		obj:SetAlpha_Old(x);
		obj.label:SetAlpha(x);
	end
	
	t.SetWidth_Old = t.SetWidth;
	t.SetWidth = function(obj, x)
		obj:SetWidth_Old(x);
		obj.label:SetFont(FONT, 12*x/32, "OUTLINE");
	end	

	t:SetPoint("CENTER", AngeleDei_RotationFrame, "LEFT", x, 0);
	--t:SetTexture("Interface\\Icons\\Spell_Holy_CrusaderStrike");
	t:SetWidth(32);
	t:SetHeight(32);
	t:SetAlpha(alpha or 1.0);
	t:Show();

	return t;
end

-- Switch to the given rotation
local function switchToRotation(r, suppressVisuals)
	Rotation = r;
	State:SetHolyPower(UnitPower("player", 9));
	Keystrokes = (Config.rotations or { })[Rotation.name] or { };
	
	if(not suppressVisuals) then
		AngeleDei:RunSimulation(GetTime(), "Rotation switch: " .. r.name, true);
		
		local mess = AngeleDei_RotationFrame.message;
		if(mess == nil) then
			mess = AngeleDei_RotationFrame:CreateFontString(nil, "ARTWORK");
			mess:SetFont(MESSAGE_FONT, 36, "THICKOUTLINE");
			mess:SetTextColor(1, 0.9, 0.9, 1);
			--mess:SetShadowColor(1, 0, 0, 0.5);
			--mess:SetShadowOffset(5, -5);
			AngeleDei_RotationFrame.message = mess;
		end
		
		mess:SetText(r.name);
		mess:SetPoint("CENTER", UIParent, "CENTER");
		mess:SetAlphaGradient(0, 4);
		mess:Show();
		messageStart = GetTime();
		messageShown = messageStart + 0.15;
		messageFadeOutStart = messageShown + 1.5;
		messageEnd = messageFadeOutStart + 0.15;
	end
end

-- Switch to a single target or AOE rotation depending on the argument
function AngeleDei:SwitchToRotation(singleTarget)
	local r = nil;
	for i=1,#Rotations do
		if(Rotations[i].singleTarget == singleTarget) then
			r = Rotations[i];
		end
	end
	
	-- Don't do anything if we are already using that rotation
	if(r == Rotation) then
		return;
	end
	
	switchToRotation(r);
end

-- Switch between single-target and AOE rotations
function AngeleDei:ToggleRotation()
	AngeleDei:SwitchToRotation(not Rotation.singleTarget);
end

-- Switch to the rotation that matches the given action bar
function AngeleDei:RotationByActionBarPage(suppressVisuals)
	local page = GetActionBarPage();
	
	for i=1,#Rotations do
		local r = Rotations[i];
		local targetPage = Config.rotations[r.name].page;
		if(page == targetPage) then
			switchToRotation(r, suppressVisuals);
			return;
		end
	end
end

-- Extract tooltip text from a list of tooltip regions
local function getTooltipText(...)
	local text = "";
	for i=1,select("#", ...) do
		local rgn = select(i, ...);
		if(rgn) and (rgn:GetObjectType() == "FontString") then
			text = text .. (rgn:GetText() or "");
		end
	end
	return text == "" and "0" or text;
end

-- Get the current Vengeance (0.0 .. 1.0)
function AngeleDei:GetVengeance()
	local name = GetSpellInfo(VENG);
	local n = UnitAura("player", name);
	if(n == nil) then
		return 0;
	end
	
	local s = AngeleDei_RotationFrame.scanner;
	s:ClearLines();
	s:SetUnitBuff("player", name);
	local text = getTooltipText(s:GetRegions());
	local vengeance = tonumber(string.match(text, "%d+"));
	local maxVengeance = floor(0.1*UnitHealthMax("player"));
	local result = vengeance / maxVengeance;
	return result;
end

-- Update the vengeance indicator
function AngeleDei:UpdateVengeanceIndicator()
	local v = AngeleDei:GetVengeance();
	--print("Vengeance: " .. v);
	
	for i=0,4 do
		local t = AngeleDei_RotationFrame.vengeanceLight[i];
		local v0 = i*0.2;
		local v1 = (i+1)*0.2;
		if(v <= v0) then
			t:SetAlpha(0);
		elseif(v > v1) then
			t:SetAlpha(1);
		else
			t:SetAlpha((v-v0)/0.2);
		end			
	end
end