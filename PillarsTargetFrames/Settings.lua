local addonName, ns = ...

local API = ClaiibuAPI and ClaiibuAPI.Require(1, addonName)
ns.API = API
if not API then
	return
end

-- Presets for the tint color settings. Each color setting's dropdown lists
-- Default, these, then Custom... (Blizzard's color picker).
local TINT_PRESETS = {
	{ key = "black", label = "Black", r = 0, g = 0, b = 0 },
	{ key = "white", label = "White", r = 1, g = 1, b = 1 },
	{ key = "gold", label = "Gold", r = 1, g = 0.82, b = 0 },
	{ key = "silver", label = "Silver", r = 0.75, g = 0.75, b = 0.8 },
	{ key = "bronze", label = "Bronze", r = 0.8, g = 0.5, b = 0.2 },
	{ key = "red", label = "Red", r = 0.8, g = 0.1, b = 0.1 },
	{ key = "green", label = "Green", r = 0.2, g = 0.8, b = 0.2 },
	{ key = "blue", label = "Blue", r = 0.2, g = 0.4, b = 1 },
	{ key = "purple", label = "Purple", r = 0.6, g = 0.3, b = 0.9 },
}

-- Presets for the background color, the same as Pillars Player Frame's.
local BACKGROUND_PRESETS = {
	{ key = "black", label = "Black", r = 0, g = 0, b = 0 },
	{ key = "charcoal", label = "Charcoal", r = 0.08, g = 0.08, b = 0.08 },
	{ key = "slate", label = "Slate", r = 0.08, g = 0.1, b = 0.16 },
	{ key = "deepred", label = "Deep Red", r = 0.16, g = 0.04, b = 0.04 },
	{ key = "forest", label = "Forest", r = 0.05, g = 0.12, b = 0.06 },
	{ key = "umber", label = "Umber", r = 0.18, g = 0.12, b = 0.07 },
	{ key = "midnight", label = "Midnight", r = 0.03, g = 0.03, b = 0.08 },
}

-- Presets for bar colors.
local BAR_PRESETS = {
	{ key = "green", label = "Green", r = 0, g = 0.8, b = 0 },
	{ key = "red", label = "Red", r = 0.85, g = 0.1, b = 0.1 },
	{ key = "blue", label = "Blue", r = 0, g = 0.35, b = 1 },
	{ key = "orange", label = "Orange", r = 1, g = 0.5, b = 0.25 },
	{ key = "yellow", label = "Yellow", r = 1, g = 0.85, b = 0.1 },
	{ key = "gold", label = "Gold", r = 1, g = 0.7, b = 0 },
	{ key = "purple", label = "Purple", r = 0.6, g = 0.3, b = 0.9 },
	{ key = "cyan", label = "Cyan", r = 0.1, g = 0.8, b = 0.9 },
	{ key = "white", label = "White", r = 1, g = 1, b = 1 },
	{ key = "gray", label = "Gray", r = 0.5, g = 0.5, b = 0.5 },
}

local VALUE_TEXT = {
	{ key = "full", label = "Full Value" },
	{ key = "short", label = "Abbreviated Value" },
	{ key = "percent", label = "Percentage" },
	{ key = "both", label = "Both" },
	{ key = "none", label = "None" },
}

-- What a bar can be attached to. "bars" is the name, health and resource
-- bars together (the portrait's default).
local BAR_TARGETS = {
	{ key = "health", label = "Health Bar" },
	{ key = "power", label = "Resource Bar" },
	{ key = "name", label = "Name Bar" },
}
local PORTRAIT_TARGETS = {
	{ key = "bars", label = "All Bars (Name, Health and Resource)" },
	{ key = "health", label = "Health Bar" },
	{ key = "power", label = "Resource Bar" },
	{ key = "name", label = "Name Bar" },
}

-- The frames. Each has the same settings under its prefix (tfHealthWidth,
-- totHealthWidth, ...). combo: your combo points show on it.
ns.UNITS = {
	{ prefix = "tf", page = "Target", unit = "target", what = "target frame", combo = true },
	{ prefix = "tot", page = "Target of Target", unit = "targettarget", what = "target of target frame", inherit = true,
		movable = true },
	{ prefix = "ff", page = "Focus", unit = "focus", what = "focus frame", inherit = true },
}

-- Sections of a frame's settings. Frames with inherit = true use the
-- Target page's settings for a section until its Override toggle
-- (<prefix>Override<Section>) is checked. Enable and the frame's offsets
-- are always its own.
ns.SECTIONS = {
	{ key = "Health", label = "Health Bar", prefixes = { "Health" } },
	{ key = "Power", label = "Resource Bar", prefixes = { "Power" } },
	{ key = "Name", label = "Name Bar", prefixes = { "Name", "Level" } },
	{ key = "Portrait", label = "Portrait", prefixes = { "Portrait" } },
	{ key = "Cast", label = "Cast Bar", prefixes = { "Cast" } },
}

-- The section a per-frame setting (without its prefix) belongs to, or nil.
function ns.SectionOf(key)
	for _, section in ipairs(ns.SECTIONS) do
		for _, start in ipairs(section.prefixes) do
			if key:sub(1, #start) == start then
				return section.key
			end
		end
	end
	return nil
end

-- The layout: one design for every frame (the target frame's) ...
local LAYOUT = {
	Enabled = true,
	OffsetX = 0,
	OffsetY = 0,
	HealthWidth = 160,
	HealthHeight = 24,
	HealthColor = "color",
	HealthText = "percent",
	HealthTextPoint = "CENTER",
	PowerShow = true,
	PowerOwnSize = false,
	PowerWidth = 160,
	PowerHeight = 24,
	PowerTarget = "health",
	PowerPoint = "BOTTOM",
	PowerX = 0,
	PowerY = 0,
	PowerText = "none",
	PowerTextPoint = "CENTER",
	NameShow = true,
	NameOwnSize = false,
	NameWidth = 160,
	NameHeight = 18,
	NameTarget = "health",
	NamePoint = "TOP",
	NameX = 0,
	NameY = 0,
	NameTextShow = true,
	NameTextPoint = "LEFT",
	NameTextX = 0,
	NameTextY = 0,
	NameClassColor = false,
	NameGradient = false,
	LevelShow = true,
	LevelPoint = "RIGHT",
	LevelX = 0,
	LevelY = 0,
	PortraitShow = true,
	PortraitClass = false,
	PortraitOwnSize = false,
	PortraitWidth = 66,
	PortraitHeight = 66,
	PortraitTarget = "bars",
	PortraitPoint = "BOTTOMRIGHT",
	PortraitX = 0,
	PortraitY = 0,
	CastShow = true,
	CastSeparate = false,
	CastHideIdle = true,
	CastOwnSize = false,
	CastWidth = 160,
	CastHeight = 24,
	CastTarget = "power",
	CastPoint = "BOTTOM",
	CastX = 0,
	CastY = 0,
	CastText = true,
}

local COMBO_LAYOUT = {
	ComboShow = true,
	ComboTarget = "power",
	ComboPoint = "BOTTOM",
	ComboX = 0,
	ComboY = 0,
	ComboSize = 16,
	ComboSpacing = 4,
}

-- ... and the short list of what each frame does differently.
local OVERRIDES = {
	tf = {},
	tot = { PortraitShow = false, PowerShow = false, CastShow = false },
	ff = { PortraitShow = false },
}

local defaults = {
	barTexture = "flat",
	border = "solid",
	borderSize = 2,
	borderInset = 0,
	borderTint = { r = 0, g = 0, b = 0, a = 1 },
	background = "solid",
	backgroundColor = { r = 0.08, g = 0.08, b = 0.08, a = 0.8 },
	font = "friz",
	fontSize = 12,
	fontShadow = "soft",
	textColor = { r = 1, g = 1, b = 1, a = 1 },
	healthColor = { r = 0, g = 0.8, b = 0, a = 1 },
	manaColor = { r = 0, g = 0.35, b = 1, a = 1 },
	rageColor = { r = 0.85, g = 0.1, b = 0.1, a = 1 },
	energyColor = { r = 1, g = 0.85, b = 0.1, a = 1 },
	focusColor = { r = 1, g = 0.5, b = 0.25, a = 1 },
	castColor = { r = 1, g = 0.7, b = 0, a = 1 },
	comboColor = { r = 1, g = 0.82, b = 0, a = 1 },
}

local function Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = v
	end
	return copy
end

for _, unit in ipairs(ns.UNITS) do
	local overrides = OVERRIDES[unit.prefix]
	local function Add(list)
		for key, value in pairs(list) do
			local own = overrides[key]
			if own == nil then
				own = value
			end
			defaults[unit.prefix .. key] = Copy(own)
		end
	end
	Add(LAYOUT)
	if unit.combo then
		Add(COMBO_LAYOUT)
	end
	-- Frames moved in Edit Mode: OffsetX and OffsetY are from this point
	-- on the screen. Placed is set once the frame has been put where
	-- Blizzard's was (or next to the target frame), the first time it loads.
	if unit.movable then
		defaults[unit.prefix .. "Point"] = "CENTER"
		defaults[unit.prefix .. "Placed"] = false
	end
	-- Override toggles: on by default for every section this frame's own
	-- defaults change.
	if unit.inherit then
		for _, section in ipairs(ns.SECTIONS) do
			local changed = false
			for key in pairs(overrides) do
				if ns.SectionOf(key) == section.key then
					changed = true
				end
			end
			defaults[unit.prefix .. "Override" .. section.key] = changed
		end
	end
end

local kit = API.Settings.New(addonName, {
	title = "Pillars Target Frames",
	description = "Target, target of target and focus frames in the Pillars look. Blizzard's own "
		.. "frames are made invisible; their buffs and debuffs stay where Blizzard places them.",
	features = {
		"One layout for every frame: name bar, health bar, resource bar and portrait, with a short list of changes per frame.",
		"Every bar, the portrait, the cast bar and the combo points can be resized and attached to another bar at any anchor point.",
		"Your combo points on the target frame, in round totem borders.",
		"A cast bar over the resource bar, or a bar of its own that shows only while casting.",
		"Blizzard's own buffs and debuffs, left where Blizzard places them (set them in Edit Mode).",
		"Dead units get a gray-blue background and a faded portrait.",
		"Shared border, border tint, background, bar texture and fonts, with Custom colors.",
	},
	savedVariable = "PillarsTargetFramesDB",
	charSavedVariable = "PillarsTargetFramesCharDB",
	defaults = defaults,
	onChange = function(key, value, kit)
		ns.ApplySettings()
	end,
	onProfileChanged = function(kit)
		ns.ApplySettings()
	end,
	onMediaRegistered = function(kit)
		ns.ApplySettings()
	end,
})
ns.kit = kit

-- Pages ------------------------------------------------------------------------------
-- General first, then the rest in alphabetical order; ClaiibuAPI always adds
-- Profiles after them. Open a page with ns.pageIndex["<Name>"].

local function Color(page, spec)
	if page.Color then
		page:Color(spec)
	end
end

local function Offsets(page, key, what, min, max)
	page:Slider({ key = key .. "X", label = "Horizontal Offset",
		tooltip = "Moves the " .. what .. " right (positive) or left (negative).",
		min = min or -100, max = max or 100, step = 1, format = "%d" })
	page:Slider({ key = key .. "Y", label = "Vertical Offset",
		tooltip = "Moves the " .. what .. " up (positive) or down (negative).",
		min = min or -100, max = max or 100, step = 1, format = "%d" })
end

-- Attach To, Position and the offsets of a part of the frame.
local function Placement(page, p, part, what, targets)
	page:Dropdown({ key = p .. part .. "Target", label = "Attach To",
		tooltip = "The bar the " .. what .. " is attached to.", options = targets or BAR_TARGETS })
	page:Anchor({ key = p .. part .. "Point", label = "Position",
		tooltip = "Where the " .. what .. " attaches: TOP CENTER puts it above, BOTTOM CENTER below, LEFT and "
			.. "RIGHT beside it, CENTER on top of it." })
	Offsets(page, p .. part, what)
end

-- Own Size and the two size sliders of a part that matches the health bar
-- unless it has its own size.
local function OwnSize(page, p, part, what, matches)
	page:Checkbox({ key = p .. part .. "OwnSize", label = "Own Size",
		tooltip = "Give the " .. what .. " its own size instead of " .. matches .. "." })
	page:Slider({ key = p .. part .. "Width", label = "Width", tooltip = "Used when Own Size is checked.",
		min = 20, max = 400, step = 1, format = "%d" })
	page:Slider({ key = p .. part .. "Height", label = "Height", tooltip = "Used when Own Size is checked.",
		min = 4, max = 120, step = 1, format = "%d" })
end

-- On Focus and Target of Target: the section header and its Override toggle.
local function Section(page, unit, key, label)
	page:Header(label)
	if unit.inherit then
		page:Checkbox({ key = unit.prefix .. "Override" .. key, label = "Override Target's " .. label,
			tooltip = "Unchecked, the " .. unit.what .. " uses the Target page's " .. strlower(label)
				.. " settings and the ones below are ignored. Checked, it uses the settings below." })
	end
end

local function UnitPage(page, unit)
	local p, what = unit.prefix, unit.what
	page:Header(unit.page)
	if unit.unit == "targettarget" then
		page:Text("Shows when Blizzard's own target of target frame would: turn it on or off in Edit Mode "
			.. "(the target frame's Target of Target option). It shows no buffs or debuffs.")
	else
		page:Text("Blizzard's " .. what .. " is made invisible and this one shows in its place. Move it in Edit Mode.")
	end
	if unit.inherit then
		page:Text("Each section follows the Target page until you check its Override toggle; the toggle starts "
			.. "checked where this frame's own defaults differ.")
	end
	page:Checkbox({ key = p .. "Enabled", reload = true, label = "Enable",
		tooltip = "Show this frame. Unchecked, Blizzard's frame comes back after a reload." })
	if unit.movable then
		page:Text("Move it in Edit Mode (Escape → Edit Mode): it has its own box there, labeled " .. unit.page
			.. ". Or set its place on the screen here.")
		page:Anchor({ key = p .. "Point", label = "Screen Position",
			tooltip = "The point of the screen the offsets count from. Edit Mode keeps it when you drag the frame." })
		Offsets(page, p .. "Offset", "frame on the screen", -1500, 1500)
		page:Button({ label = "", text = "Put Back by the Target Frame",
			tooltip = "Move the frame back to its first place: where Blizzard's own frame was, or beside the target frame.",
			onClick = function(kit) kit:Set(p .. "Placed", false) end })
	else
		Offsets(page, p .. "Offset", "frame inside Blizzard's frame", -200, 200)
	end

	Section(page, unit, "Health", "Health Bar")
	page:Slider({ key = p .. "HealthWidth", label = "Width",
		tooltip = "Width of the health bar. The other bars match it unless they have their own size.",
		min = 20, max = 400, step = 1, format = "%d" })
	page:Slider({ key = p .. "HealthHeight", label = "Height", min = 4, max = 120, step = 1, format = "%d" })
	page:Dropdown({ key = p .. "HealthColor", label = "Color",
		tooltip = "Health Color from the Look page, the unit's reaction (hostile red, neutral yellow, friendly "
			.. "green), or players' class colors. Where the client keeps the reaction secret, Health Color is used.",
		options = { { key = "color", label = "Health Color" }, { key = "reaction", label = "Reaction" },
			{ key = "class", label = "Class Color (Players)" } } })
	page:Dropdown({ key = p .. "HealthText", label = "Text", options = VALUE_TEXT })
	page:Anchor({ key = p .. "HealthTextPoint", label = "Text Position" })

	Section(page, unit, "Power", "Resource Bar")
	page:Checkbox({ key = p .. "PowerShow", label = "Show Resource Bar", tooltip = "The unit's mana, rage, energy or focus." })
	OwnSize(page, p, "Power", "resource bar", "the health bar's")
	Placement(page, p, "Power", "resource bar")
	page:Dropdown({ key = p .. "PowerText", label = "Text", options = VALUE_TEXT })
	page:Anchor({ key = p .. "PowerTextPoint", label = "Text Position" })

	Section(page, unit, "Name", "Name Bar")
	page:Checkbox({ key = p .. "NameShow", label = "Show Name Bar" })
	page:Checkbox({ key = p .. "NameGradient", label = "Gradient Instead of Background",
		tooltip = "In place of the name bar's background and border: a gradient in the Background Color, solid "
			.. "on the side facing the bar it is attached to and fading out away from it (from the bottom when "
			.. "attached above a bar, from the top below one, from the left when on a bar's right, from the right "
			.. "on its left). At CENTER the background and border stay." })
	OwnSize(page, p, "Name", "name bar", "the health bar's width")
	Placement(page, p, "Name", "name bar")
	page:Checkbox({ key = p .. "NameTextShow", label = "Show Name" })
	page:Anchor({ key = p .. "NameTextPoint", label = "Name Position", tooltip = "Where the name sits on the name bar." })
	Offsets(page, p .. "NameText", "name", -100, 100)
	page:Checkbox({ key = p .. "NameClassColor", label = "Class Colored Name",
		tooltip = "Players' names in their class color instead of Text Color." })
	page:Checkbox({ key = p .. "LevelShow", label = "Show Level" })
	page:Anchor({ key = p .. "LevelPoint", label = "Level Position", tooltip = "Where the level sits on the name bar." })
	Offsets(page, p .. "Level", "level", -100, 100)

	Section(page, unit, "Portrait", "Portrait")
	page:Checkbox({ key = p .. "PortraitShow", label = "Show Portrait", tooltip = "The unit's 3D portrait." })
	page:Checkbox({ key = p .. "PortraitClass", label = "Class Icon Instead",
		tooltip = "Players' class icon in place of the portrait (the portrait stays for others)." })
	page:Checkbox({ key = p .. "PortraitOwnSize", label = "Own Size",
		tooltip = "Unchecked, the portrait is square and as tall as the name, health and resource bars together." })
	page:Slider({ key = p .. "PortraitWidth", label = "Width", tooltip = "Used when Own Size is checked.",
		min = 10, max = 200, step = 1, format = "%d" })
	page:Slider({ key = p .. "PortraitHeight", label = "Height", tooltip = "Used when Own Size is checked.",
		min = 10, max = 200, step = 1, format = "%d" })
	page:Dropdown({ key = p .. "PortraitTarget", label = "Attach To",
		tooltip = "All Bars puts the portrait beside the name, health and resource bars together.",
		options = PORTRAIT_TARGETS })
	page:Anchor({ key = p .. "PortraitPoint", label = "Position",
		tooltip = "BOTTOM RIGHT: beside the bars on the right, bottoms lined up. LEFT and RIGHT points put it "
			.. "beside, TOP and BOTTOM above or below, CENTER on top." })
	Offsets(page, p .. "Portrait", "portrait")

	Section(page, unit, "Cast", "Cast Bar")
	page:Checkbox({ key = p .. "CastShow", label = "Show Cast Bar",
		tooltip = "What the unit is casting, over the resource bar (over the health bar's bottom without one)." })
	page:Checkbox({ key = p .. "CastSeparate", label = "Separate Bar",
		tooltip = "A cast bar of its own, attached below the resource bar, instead of over it." })
	page:Checkbox({ key = p .. "CastHideIdle", label = "Hide When Not Casting",
		tooltip = "The separate bar shows only while the unit casts. Unchecked, it stays as an empty bar." })
	OwnSize(page, p, "Cast", "separate cast bar", "the resource bar's")
	Placement(page, p, "Cast", "separate cast bar")
	page:Checkbox({ key = p .. "CastText", label = "Spell Name", tooltip = "The name of the spell on the cast bar." })

	if unit.combo then
		page:Header("Combo Points")
		page:Text("Your combo points (rogues, and druids in cat form) in round totem borders tinted with the Border Tint.")
		page:Checkbox({ key = p .. "ComboShow", label = "Show Combo Points" })
		Placement(page, p, "Combo", "combo points")
		page:Slider({ key = p .. "ComboSize", label = "Size", min = 8, max = 40, step = 1, format = "%d" })
		page:Slider({ key = p .. "ComboSpacing", label = "Spacing", min = -4, max = 20, step = 1, format = "%d" })
	end

end

local PAGES = {}

PAGES["General"] = function(page)
	page:Header("Pillars Target Frames")
	page:Text("Target, target of target and focus frames in the Pillars look. Each frame has its "
		.. "own page; the Look page (border, background, bar texture, fonts and colors) is shared.\n"
		.. "Blizzard's target, target of target and focus frames, and everything on them, are made invisible. "
		.. "The new frames show when Blizzard's would and move with them in Edit Mode. Blizzard's buffs and "
		.. "debuffs stay where Blizzard places them: change Buffs on Top and their sizes in Edit Mode (target "
		.. "frame), and line the new frame up with them using its offsets. The addon never moves them; on this "
		.. "client that blocks Blizzard's code (chat's Enter key stops working). The threat number and other "
		.. "things the client keeps from addons are not shown.\n"
		.. "Left-click a frame to target the unit, right-click for its menu. Turning a frame off brings "
		.. "Blizzard's back after a reload.")
	page:Button({ label = "", text = "Diagnostics",
		tooltip = "What this client supports, in a window to copy for bug reports.",
		onClick = function() SlashCmdList.PILLARSTARGETFRAMES("probe") end })
end

PAGES["Focus"] = function(page)
	UnitPage(page, ns.UNITS[3])
end

PAGES["Look"] = function(page)
	page:Header("Border")
	page:MediaDropdown({ key = "border", mediaType = "border", label = "Border" })
	page:Slider({ key = "borderSize", label = "Border Size", tooltip = "Thickness of the borders.",
		min = 1, max = 32, step = 1, format = "%d" })
	page:Slider({ key = "borderInset", label = "Border Position",
		tooltip = "Moves the borders in (positive) or out (negative). If you see a gap between a bar and its "
			.. "border, move the border in until it closes.", min = -16, max = 16, step = 1, format = "%d" })
	Color(page, { key = "borderTint", label = "Border Tint", hasAlpha = true, presets = TINT_PRESETS,
		tooltip = "Color of the borders and the combo points' totem rings." })

	page:Header("Background")
	page:MediaDropdown({ key = "background", mediaType = "background", label = "Background" })
	Color(page, { key = "backgroundColor", label = "Background Color", hasAlpha = true, presets = BACKGROUND_PRESETS,
		tooltip = "Color and opacity of the background behind every bar and the portrait. Dead units always get gray-blue." })

	page:Header("Bars")
	page:MediaDropdown({ key = "barTexture", mediaType = "statusbar", label = "Bar Texture" })
	Color(page, { key = "healthColor", label = "Health Color", presets = BAR_PRESETS })
	Color(page, { key = "manaColor", label = "Mana Color", presets = BAR_PRESETS })
	Color(page, { key = "rageColor", label = "Rage Color", presets = BAR_PRESETS })
	Color(page, { key = "energyColor", label = "Energy Color", presets = BAR_PRESETS })
	Color(page, { key = "focusColor", label = "Focus Color", tooltip = "Hunter pets' focus.", presets = BAR_PRESETS })
	Color(page, { key = "castColor", label = "Cast Bar Color", presets = BAR_PRESETS })
	Color(page, { key = "comboColor", label = "Combo Point Color", presets = BAR_PRESETS })

	page:Header("Text")
	page:MediaDropdown({ key = "font", mediaType = "font", label = "Font" })
	page:Slider({ key = "fontSize", label = "Font Size", min = 6, max = 24, step = 1, format = "%d" })
	page:FontShadow({ key = "fontShadow" })
	Color(page, { key = "textColor", label = "Text Color", presets = TINT_PRESETS })
end

PAGES["Target"] = function(page)
	UnitPage(page, ns.UNITS[1])
end

PAGES["Target of Target"] = function(page)
	UnitPage(page, ns.UNITS[2])
end

local PAGE_ORDER = { "General", "Focus", "Look", "Target", "Target of Target" }

-- The kit:Open index of each page: 1 is the landing page.
ns.pageIndex = {}
for i, name in ipairs(PAGE_ORDER) do
	PAGES[name](kit:AddPage(name))
	ns.pageIndex[name] = i + 1
end

kit:OnReady(function()
	ns.settingsReady = true
	ns.ApplySettings()
end)
