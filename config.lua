Options = CreateFrame("Frame", "AngeleDeiOptionsFrame", UIParent)

local styleCodes = { "default", "red", "orange", "golden", "yellow", "lime", "green", "cyan", "blue", "purple", "magenta", "white", "stoplight" };

local abilities = {
	{ CS, SHOR, J, AS, HW, CO },
	{ HOR, INQ, HOW, IDLE }
};

-- Create the top frame
function Options:Load(title, subtitle)
	self.name = title;

	local text = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
	text:SetPoint("TOPLEFT", 16, -16);
	text:SetText(title);

	local subtext = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	subtext:SetHeight(32);
	subtext:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -8);
	subtext:SetPoint("RIGHT", self, -32, 0);
	subtext:SetNonSpaceWrap(true);
	subtext:SetJustifyH("LEFT");
	subtext:SetJustifyV("TOP");
	subtext:SetText(subtitle);

	local miscLabel = self:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall");
	miscLabel:SetPoint("TOPLEFT", subtext, "BOTTOMLEFT", 0, 4);
	miscLabel:SetText(SECTION_MISC);
	
	Options.combatToggle = self:CreateCheckButton(LABEL_COMBAT_TOGGLE, self);
	Options.combatToggle:SetPoint("TOPLEFT", miscLabel, "BOTTOMLEFT", 0, -4);

	Options.protOnly = self:CreateCheckButton(LABEL_PROT_ONLY, self);
	Options.protOnly:SetPoint("TOPLEFT", Options.combatToggle, "BOTTOMLEFT", 0, 4);

	Options.locked = self:CreateCheckButton(LABEL_LOCKED, self);
	Options.locked:SetPoint("TOPLEFT", Options.protOnly, "BOTTOMLEFT", 0, 4);

	Options.sound = self:CreateCheckButton(LABEL_SOUND, self);
	Options.sound:SetPoint("TOPLEFT", Options.locked, "BOTTOMLEFT", 0, 4);

	Options.scale = Options:CreateSlider(LABEL_SCALE, self, 0.3, 1.5, 0.05);
	Options.scale:SetPoint("TOPLEFT", Options.sound, "BOTTOMLEFT", 0, -16);
	local minValue, maxValue = Options.scale:GetMinMaxValues();
	local minLabel = Options.scale:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	minLabel:SetText(format("%2.1f", minValue));
	minLabel:SetPoint("TOPLEFT", Options.scale, "BOTTOMLEFT", 0, 0);
	local maxLabel = Options.scale:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	maxLabel:SetText(format("%2.1f", maxValue));
	maxLabel:SetPoint("TOPRIGHT", Options.scale, "BOTTOMRIGHT", 0, 0);
	Options.scale:SetScript("OnValueChanged", function(self)
		self.value:SetText(format("%3.2f", self:GetValue()));
	end);

	-- Set up UI interaction functions
	Options.okay = function()
		Options:Save();
	end;

	Options.cancel = function()
		-- ...
	end;
	
	Options.refresh = function()
		Options:Populate();
	end

	InterfaceOptions_AddCategory(Options);

	-- Other panels
	Options:CreateBuffPanel();
	Options:CreateGeneralRotationPanel();
	
	local rotationCodes = AngeleDei:GetRotations();
	for i=1,#rotationCodes do
		local code = rotationCodes[i].name;
		local description = rotationCodes[i].description or (code .. " settings");
		local icon = rotationCodes[i].singleTarget 
			and	"|TInterface\\Icons\\Ability_SteelMelee:20:20:0:0|t"	
			or	"|TInterface\\Icons\\Ability_Paladin_DivineStorm:20:20:0:0|t";

		Options[code] = Options:CreateRotationPanel(code, description, icon);
	end
end

-- Set up the buff indicator panel
function Options:CreateBuffPanel()
	local panel = Options:CreatePanel(TITLE_PROCS, SUBTITLE_PROCS);
	Options.buffs = panel;
	Options.buffs.parent = Options.name;
	
	-- Holy Power
	local hopoLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall");
	hopoLabel:SetPoint("TOPLEFT", Options.buffs.subtitle, "BOTTOMLEFT", 0, 4);
	hopoLabel:SetText(SECTION_HOPO);

	Options.fadeOut = Options:CreateCheckButton(LABEL_FADEOUT, panel);
	Options.fadeOut:SetPoint("TOPLEFT", hopoLabel, "BOTTOMLEFT", 0, -4);

	Options.blink = Options:CreateCheckButton(LABEL_BLINK, panel);
	Options.blink:SetPoint("TOPLEFT", Options.fadeOut, "BOTTOMLEFT", 0, 4);

	Options.style = Options:CreateSlider(LABEL_HOPO_STYLE, panel, 1, #STYLES, 1);
	Options.style:SetPoint("TOPLEFT", Options.blink, "BOTTOMLEFT", 0, -16);
	Options.style:SetScript("OnValueChanged", function(self)
		self.value:SetText(STYLES[self:GetValue()]);
	end);

	-- Vengeance
	local vengLabel = Options.buffs:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall");
	vengLabel:SetPoint("TOPLEFT", Options.style, "BOTTOMLEFT", 0, -24);
	vengLabel:SetText(SECTION_VENGEANCE);

	Options.vengeanceEnabled = Options:CreateCheckButton(LABEL_VENGEANCE_ENABLE, panel);
	Options.vengeanceEnabled:SetPoint("TOPLEFT", vengLabel, "BOTTOMLEFT", 0, -4);

	Options.vengeanceStyle = Options:CreateSlider(LABEL_VENGEANCE_STYLE, panel, 1, #STYLES, 1);
	Options.vengeanceStyle:SetPoint("TOPLEFT", Options.vengeanceEnabled, "BOTTOMLEFT", 0, -16);
	Options.vengeanceStyle:SetScript("OnValueChanged", function(self)
		self.value:SetText(STYLES[self:GetValue()]);
	end);
	
	local buffLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall");
	buffLabel:SetPoint("TOPLEFT", Options.vengeanceStyle, "BOTTOMLEFT", 0, -24);
	buffLabel:SetText(SECTION_BUFFS);

	Options.sacredDuty = Options:CreateCheckButton(LABEL_SACRED_DUTY, panel);
	Options.sacredDuty:SetPoint("TOPLEFT", buffLabel, "BOTTOMLEFT", 0, -4);	
	Options.sacredDuty:Disable();
	Options.sacredDuty:SetAlpha(0.6);

	Options.jotw = Options:CreateCheckButton(LABEL_JOTW, panel);
	Options.jotw:SetPoint("TOPLEFT", Options.sacredDuty, "BOTTOMLEFT", 0, 4);
	Options.jotw:Disable();
	Options.jotw:SetAlpha(0.6);
end

-- Set up a rotation panel
function Options:CreateRotationPanel(title, subtitle, icon)
	local panel = Options:CreatePanel(icon .. " " .. title, subtitle);
	Options[title] = panel;
	
	panel.page = Options:CreateSlider(LABEL_BIND, panel, 0, 12, 1);
	panel.page:SetPoint("TOPLEFT", panel.subtitle, "BOTTOMLEFT", 0, -8);
	panel.page:SetScript("OnValueChanged", function(self)
		local v = self:GetValue();
		local page = (v == 0) and LABEL_DISABLED or (LABEL_PAGE .. v);
		self.value:SetText(page);
	end);
	--panel.page:Disable();
	--panel.page:SetAlpha(0.75);	
	
	local section = Options:CreateSection(SECTION_KEYSTROKES, panel, 192);
	section:SetPoint("TOP", panel.page, "BOTTOM", 0, -24);
	
	panel.keystrokes = { };
	
	for j=1,#abilities do
		local row = abilities[j];
		for i=1,#row do
			local name = row[i];
			local texture = AngeleDei.Spellinfo:GetIcon(name);

			local icon = panel:CreateTexture(panel:GetName() .. "." .. name);
			icon:SetWidth(32);
			icon:SetHeight(32);
			icon:SetTexCoord(0, 1, 0, 1);
			icon:SetTexture(texture);
			icon:SetPoint("CENTER", section, "TOP", (i-3.5)*64, -(j-1)*96-36);
			
			local input = CreateFrame("EditBox", "Input_" .. i .. "_" .. j, panel, "InputBoxTemplate");
			input:SetWidth(48);
			input:SetHeight(20);
			input:SetPoint("TOP", icon, "BOTTOM", 0, -8);
			input:SetJustifyH("CENTER");
			input:SetMaxLetters(5);
			input:SetMultiLine(false);
			input:SetAutoFocus(false);
			
			-- For whatever reason, setting the text ahead of time does not work
			input:SetScript("OnShow", function(self)
				-- This line is a hack per http://forums.worldofwarcraft.com/thread.html?topicId=8202610228&sid=1
				-- Without this line, the contents of textboxes will NOT be displayed until the user clicks
				-- the box and moves the cursor. No idea why, but... this works.
				self:SetCursorPosition(0);
			end);
	
			panel.keystrokes[name] = input;
		end
	end
	
	return panel;
end

-- Create a new panel. Bind its top and
function Options:CreateSection(name, parent, height)
	local section = CreateFrame("Frame", self:GetName() .. "|" .. parent:GetName() .. "|" .. name, parent, "OptionsBoxTemplate");
	section:SetBackdropBorderColor(0.75, 0.75, 0.75);
	section:SetBackdropColor(0.15, 0.15, 0.15, 0.5);
	_G[section:GetName() .. "Title"]:SetText(name);
	_G[section:GetName() .. "Title"]:SetFontObject("GameFontNormalSmall");
	
	section:SetPoint("LEFT", parent, "LEFT", 8, 0);
	section:SetPoint("RIGHT", parent, "RIGHT", -8, 0);
	section:SetHeight(height);

	return section;
end

-- Set up the Timing panel
function Options:CreateGeneralRotationPanel()
	Options.timing = Options:CreatePanel(TITLE_ROTATION_GENERAL, SUBTITLE_ROTATION_GENERAL);
	Options.timing.parent = Options.name;

	Options.timing.delay = Options:CreateSlider(LABEL_DELAY, Options.timing, 0, 750, 5);
	Options.timing.delay:SetPoint("TOPLEFT", Options.timing.subtitle, "BOTTOMLEFT", 0, -8);
	Options.timing.delay:SetScript("OnValueChanged", function(self)
		self.value:SetText(self:GetValue() .. LABEL_MSEC);
	end);
	Options.timing.delay:SetValue(250);

	Options.timing.priority = Options:CreateSlider(LABEL_OVERRIDE, Options.timing, 0, 750, 5);
	Options.timing.priority:SetPoint("TOPLEFT", Options.timing.delay, "BOTTOMLEFT", 0, -24);
	Options.timing.priority:SetScript("OnValueChanged", function(self)
		self.value:SetText(self:GetValue() .. LABEL_MSEC);
	end);
	Options.timing.priority:SetValue(500);

	Options.timing.holyShield = Options:CreateCheckButton(LABEL_HOLY_SHIELD, Options.timing);
	Options.timing.holyShield:SetPoint("TOPLEFT", Options.timing.priority, "BOTTOMLEFT", 0, -8);	

	Options.timing.consecration = Options:CreateCheckButton(LABEL_CONSECRATION, Options.timing);
	Options.timing.consecration:SetPoint("TOPLEFT", Options.timing.holyShield, "BOTTOMLEFT", 0, 4);	

	Options.timing.hallowedGround = Options:CreateCheckButton(LABEL_HALLOWED_GROUND, Options.timing);
	Options.timing.hallowedGround:SetPoint("TOPLEFT", Options.timing.consecration, "BOTTOMLEFT", 24, 4);	
	_G[Options.timing.hallowedGround:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall");

	return Options.timing;
end

-- Create an interface options panel
function Options:CreatePanel(title, subtitle)
	local frame = CreateFrame("Frame", "AngeleDeiOptionsFrame." .. title, UIParent);
	
	frame.name = title;
	frame.parent = Options.name;
	InterfaceOptions_AddCategory(frame);

	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
	frame.title:SetPoint("TOPLEFT", 16, -16);
	frame.title:SetText(title);

	frame.subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	frame.subtitle:SetHeight(32);
	frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8);
	frame.subtitle:SetPoint("RIGHT", frame, -32, 0);
	frame.subtitle:SetNonSpaceWrap(true);
	frame.subtitle:SetJustifyH("LEFT");
	frame.subtitle:SetJustifyV("TOP");
	frame.subtitle:SetText(subtitle);

	return frame;
end

-- Create a check button
function Options:CreateCheckButton(name, parent)
	local button = CreateFrame("CheckButton", parent:GetName() .. name, parent, "InterfaceOptionsCheckButtonTemplate")
	_G[button:GetName() .. "Text"]:SetText(name)
	return button
end

-- Create a color picker
function Options:CreateColorPicker(name, parent)
	local frame = CreateFrame("Button", parent:GetName() .. name, parent);
	frame:SetWidth(24);
	frame:SetHeight(24);
	frame:SetNormalTexture("Interface\\AddOns\\AngeleDei\\images\\ComboGlowGrayscale.tga");
	frame:SetFrameStrata("HIGH");
	frame:GetNormalTexture():SetVertexColor(64/255, 165/255, 255/255);

	--[[
	local bg = frame:CreateTexture(nil, "BACKGROUND");
	bg:SetWidth(14);
	bg:SetHeight(14);
	bg:SetTexture(1, 1, 1);
	bg:SetPoint("CENTER");
	frame.bg = bg;
	--]]
	
	frame:SetScript("OnClick", function(self)
		if(not ColorPickerFrame:IsShown()) then
			UIDropDownMenuButton_OpenColorPicker(self)
			ColorPickerFrame.hasOpacity = false;
			ColorPickerFrame:SetColorRGB(frame:GetNormalTexture():GetVertexColor());
			ColorPickerFrame.func = function(self)
				local r, g, b = ColorPickerFrame:GetColorRGB();
				frame:GetNormalTexture():SetVertexColor(r, g, b);
			end
			
			ColorPickerFrame:SetFrameStrata("TOOLTIP");
			ColorPickerFrame:Raise();
			
		end
	end);
	
	return frame;
end

-- Create an input box
function Options:CreateSlider(name, parent, minValue, maxValue, step)
	local frame = CreateFrame("Slider", parent:GetName() .. name, parent, "OptionsSliderTemplate")
	frame:SetPoint("LEFT", parent, "LEFT", 16, 0);
	frame:SetPoint("RIGHT", parent, "RIGHT", -16, 0);
	frame:SetMinMaxValues(minValue, maxValue);
	frame:SetValueStep(step);
	frame:EnableMouseWheel(true);
	_G[frame:GetName() .. "Low"]:SetText(""); -- .. minValue);
	_G[frame:GetName() .. "High"]:SetText(""); -- .. maxValue);
	_G[frame:GetName() .. "Text"]:SetText(name);
	_G[frame:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
	_G[frame:GetName() .. "Text"]:ClearAllPoints()
	_G[frame:GetName() .. "Text"]:SetPoint("BOTTOMLEFT", frame, "TOPLEFT")
	
	local value = frame:CreateFontString(nil, "BACKGROUND");
	value:SetFontObject("GameFontHighlightSmall");
	value:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 0);
	frame.value = value;
	
	--BlizzardOptionsPanel_Slider_Enable(frame);	--colors the slider properly
	return frame;
end

-- Find the index of the given value in a table
local function indexOf(t, value, default)
	for i=1,#t do
		if(t[i] == value) then
			return i;
		end
	end
	
	return default;
end

-- Return the argument if it's a boolean value, otherwise return the default
local function correct(x, default)
	if(x == nil) then
		return default;
	else
		return x;
	end
end

-- Set the values of the UI elements based on the current settings
function Options:Populate()
	local p = AngeleDei:GetSettings();
	
	-- Display parameters
	Options.fadeOut:SetChecked(correct(p.fadeOut, true));
	Options.blink:SetChecked(correct(p.blink, false));
	Options.style:SetValue(indexOf(styleCodes, p.style, 1));
	Options.vengeanceEnabled:SetChecked(correct(p.vengeanceEnabled, false));
	Options.vengeanceStyle:SetValue(indexOf(styleCodes, p.vengeanceStyle, 1));
	
	Options.sacredDuty:SetChecked(correct(p.sacredDuty, false));
	Options.jotw:SetChecked(correct(p.jotw, false));

	Options.scale:SetValue(p.scale);
	Options.combatToggle:SetChecked(p.combatToggle);
	Options.protOnly:SetChecked(p.protOnly);
	Options.locked:SetChecked(p.locked);
	Options.sound:SetChecked(p.sound);
	
	-- Timing parameters
	Options.timing.delay:SetValue(p.delay or 250);
	Options.timing.priority:SetValue(p.priority or 500);
	Options.timing.consecration:SetChecked(p.consecration);
	Options.timing.holyShield:SetChecked(p.holyShield);
	Options.timing.hallowedGround:SetChecked(p.hallowedGround);

	-- Rotation panels
	local rotationCodes = AngeleDei:GetRotations();
	for i=1,#rotationCodes do
		local code = rotationCodes[i].name;
		local panel = Options[code];
		
		local info = (p.rotations or { })[code] or { };
		panel.page:SetValue(info.page or 0);

		for j=1,#abilities do
			for k=1,#abilities[j] do
				local ability = abilities[j][k];
				local input = panel.keystrokes[ability];
				local default = (ability == IDLE) and "Zzz" or "";
				input:SetText(info[ability] or default);
			end
		end
	end
end

-- Save the values of the UI elements into the configuration map
function Options:Save()
	local p = AngeleDei:GetSettings();
	
	-- Display parameters
	p.fadeOut = Options.fadeOut:GetChecked() and true or false;
	p.blink = Options.blink:GetChecked() and true or false;
	p.style = styleCodes[Options.style:GetValue()];
	p.vengeanceEnabled = Options.vengeanceEnabled:GetChecked() and true or false;
	p.vengeanceStyle = styleCodes[Options.vengeanceStyle:GetValue()];
	
	p.sacredDuty = Options.sacredDuty:GetChecked() and true or false;
	p.jotw = Options.jotw:GetChecked() and true or false;

	p.scale = Options.scale:GetValue();
	p.combatToggle = Options.combatToggle:GetChecked() and true or false;
	p.protOnly = Options.protOnly:GetChecked() and true or false;
	p.locked = Options.locked:GetChecked() and true or false;
	p.sound = Options.sound:GetChecked() and true or false;

	-- Timing and general rotation options
	p.delay = Options.timing.delay:GetValue();
	p.priority = Options.timing.priority:GetValue();
	p.holyShield = Options.timing.holyShield:GetChecked() and true or false;
	p.consecration = Options.timing.consecration:GetChecked() and true or false;
	p.hallowedGround = Options.timing.hallowedGround:GetChecked() and true or false;

	-- Rotation settings
	local rotationCodes = AngeleDei:GetRotations();
	for i=1,#rotationCodes do
		local code = rotationCodes[i].name;
		local panel = Options[code];
		if(p.rotations == nil) then
			p.rotations = { };
		end
		if(p.rotations[code] == nil) then
			p.rotations[code] = { };
		end
		
		local info = p.rotations[code];
		info.page = panel.page:GetValue();

		for j=1,#abilities do
			for k=1,#abilities[j] do
				local ability = abilities[j][k];
				local input = panel.keystrokes[ability];
				info[ability] = input:GetText();
			end
		end
	end
	
	-- Update the visuals after the options are saved
	AngeleDei:UpdateAppearance();
end

-- Create the configuration UI
local f = CreateFrame("Frame", nil, InterfaceOptionsFrame)
f:SetScript("OnShow", function(self)
	Options:Load(select(2, GetAddOnInfo("AngeleDei")))
	f:SetScript("OnShow", nil);
end);

-- Set default values for all parameters (if they don't exist)
function Options:SetDefaults()
	local p = AngeleDei:GetSettings();
	
	local set = function(t, name, value)
		if(t[name] == nil) then
			t[name] = value;
			return value;
		else
			return t[name];
		end
	end
	
	set(p, "scale", 1.0);
	set(p, "enabled", true);
	set(p, "combatToggle", false);
	set(p, "protOnly", false);
	set(p, "locked", false);
	set(p, "sound", true);

	set(p, "fadeOut", true);
	set(p, "blink", false);
	set(p, "style", "default");
	set(p, "vengeanceEnabled", true);
	set(p, "vengeanceStyle", "default");

	set(p, "sacredDuty", "false");
	set(p, "jotw", "false");
	
	set(p, "delay", 650);
	set(p, "priority", 325);
	set(p, "holyShield", true);
	set(p, "consecration", true);
	set(p, "hallowedGround", true);

	set(p, "rotations", { });
	
	local rotationCodes = AngeleDei:GetRotations();
	for i=1,#rotationCodes do
		local code = rotationCodes[i].name;
		set(p.rotations, code, { });
		set(p.rotations[code], "page", 0);
	
		for _,name in ipairs({ CS, SHOR, J, AS, HW, CO, HOR, INQ, HOW }) do
			set(p.rotations[code], name, "");
		end
	
		set(p.rotations[code], IDLE, LABEL_IDLE);
	end
	
	return p;
end
