-- Version: English
-- Translation by: n/a

-- Key bindings
BINDING_HEADER_ANGELE_DEI			= "Angele Dei";
BINDING_NAME_TOGGLE_ROTATION		= "Toggle single-target / AOE";
BINDING_NAME_SINGLE_TARGET_ROTATION	= "Switch to single-target";
BINDING_NAME_AOE_ROTATION			= "Switch to AOE";

-- Styles / colors ("Cerenkov" as in "Cerenkov radiaton")
STYLES = { 
	"|cFF40C0FFCerenkov|r", "|cFFFF0000Red|r", "|cFFFF8000Orange|r", "|cFFFFC000Gold|r", "|cFFFFFF00Yellow|r", "|cFFC0FF00Lime|r", "|cFF00FF00Green|r", 
	"|cFF00FFFFCyan|r", "|cFF0040FFBlue|r", "|cFFC000FFPurple|r", "|cFFFF00FFMagenta|r", "|cFFFFFFFFWhite|r", "|cFFFF0000Sto|cFFFFFF00pli|cFF00FF00ght|r"
};

-- Command line help
CMDLINE_HELP = {
	"Usage: |cFFFFD000/ad |cFFFFFF00<command>|r or |cFFFFD000/angeledei |cFFFFFF00<command>|r",
	"    |cFFFFD000cfg|r - open configuration window",
	"    |cFFFFD000show|r or |cFFFFD000on|r - enable Angele Dei",
	"    |cFFFFD000hide|r or |cFFFFD000off|r - disable Angele Dei",
	"    |cFFFFD000reset|r - move Angele Dei window to the center of the screen",
	"    |cFFFFD000move|r - unlock Angele Dei window for 10 seconds (if locked)"
};

-- Various message
MESSAGE_WRONG_CLASS = "|cFFFFD000Angele Dei|r: disabled because you are |cFFFF0000not a Paladin|r.";
MESSAGE_WELCOME = "|cFFFFD000Angele Dei|r: Protection Paladin rotation made easy.";



-- Configuraton panel: General
SECTION_MISC = "Misc. settings";
LABEL_COMBAT_TOGGLE = "Toggle addon when combat starts or ends";
LABEL_PROT_ONLY = "Enable addon for |cFF00FFFFprotection spec|r only";
LABEL_LOCKED = "Lock frame (use |cFFFFD000/ad move|r to move it)";
LABEL_SCALE = "Frame scale";

-- Configuration panel: Holy Power and procs
TITLE_PROCS = "Holy Power and procs";
SUBTITLE_PROCS = "Visual indicator settings for Holy Power and various procs";

SECTION_HOPO = "Holy Power indicator settings";
LABEL_FADEOUT = "Fade out |cFF00FFFF1|r and |cFF00FFFF2|r Holy Power lights";
LABEL_BLINK = "Blink at |cFF00FFFF3|r Holy Power";
LABEL_HOPO_STYLE = "Holy Power indicator style";

SECTION_VENGEANCE = "Vengeance indicator settings";
LABEL_VENGEANCE_ENABLE = "Enable Vengeance indicator";
LABEL_VENGEANCE_STYLE = "Vengeance indicator style";

SECTION_BUFFS = "Buff indicator settings";
LABEL_SACRED_DUTY = "Show |cFF00FFFFSacred Duty|r indicator";
LABEL_JOTW = "Show |cFF00FFFFJudgements of the Wise|r indicator";

-- Configuration panel: General rotation settings
TITLE_ROTATION_GENERAL = "General rotation settings";
SUBTITLE_ROTATION_GENERAL = "Timing, ability toggles etc";

LABEL_MSEC = " msec";
LABEL_DELAY = "|cFFFFD000Crusader Strike|r delay threshold (msec)";
LABEL_OVERRIDE = "Priority override threshold (msec)";

-- Configuration pane: Rotations
LABEL_BIND = "Bind to action bar page";
LABEL_DISABLED = "|cFFFF8080Disabled|r";
LABEL_PAGE = "Page ";
LABEL_IDLE = "Zzz";

SECTION_KEYSTROKES = "Keystroke labels";

-- Rotation titles and subtitles
TITLE_SINGLE_939 = "Single target (939)";
SUBTITLE_SINGLE_939 = "Theck's |cFFFFC0C0CS-J-CS-X-CS-ShoR|r rotation. Also known as \"939\".";
TITLE_AOE_939 = "AOE (939)";
SUBTITLE_AOE_939 = "AOE rotation (initial version), pending theorycrafting results.";
