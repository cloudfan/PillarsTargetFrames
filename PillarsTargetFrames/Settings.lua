local addonName, ns = ...

local API = ClaiibuAPI and ClaiibuAPI.Require(1, addonName)
ns.API = API
if not API then
	return
end

-- Border tints. "default" keeps the border's own color; "class" is the
-- unit's class color (players only, the border's own color otherwise).
ns.TINTS = {
	{ key = "default", label = "Border's Own" },
	{ key = "gold", label = "Gold", color = { 1, 0.82, 0, 1 } },
	{ key = "silver", label = "Silver", color = { 0.75, 0.75, 0.8, 1 } },
	{ key = "bronze", label = "Bronze", color = { 0.8, 0.5, 0.2, 1 } },
	{ key = "white", label = "White", color = { 1, 1, 1, 1 } },
	{ key = "black", label = "Black", color = { 0, 0, 0, 1 } },
	{ key = "red", label = "Red", color = { 0.8, 0.1, 0.1, 1 } },
	{ key = "green", label = "Green", color = { 0.2, 0.8, 0.2, 1 } },
	{ key = "blue", label = "Blue", color = { 0.2, 0.4, 1, 1 } },
	{ key = "purple", label = "Purple", color = { 0.6, 0.3, 0.9, 1 } },
}

-- Background colors, the same as Pillars Player Frame's. "default" keeps the
-- background's own color.
ns.BACKGROUND_COLORS = {
	{ key = "default", label = "Default" },
	{ key = "black", label = "Black", color = { 0, 0, 0, 1 } },
	{ key = "charcoal", label = "Charcoal", color = { 0.08, 0.08, 0.08, 1 } },
	{ key = "slate", label = "Slate", color = { 0.08, 0.1, 0.16, 1 } },
	{ key = "deepred", label = "Deep Red", color = { 0.16, 0.04, 0.04, 1 } },
	{ key = "forest", label = "Forest", color = { 0.05, 0.12, 0.06, 1 } },
	{ key = "umber", label = "Umber", color = { 0.18, 0.12, 0.07, 1 } },
	{ key = "midnight", label = "Midnight", color = { 0.03, 0.03, 0.08, 1 } },
	{ key = "smoke", label = "Smoke", color = { 0, 0, 0, 0.35 } },
}

-- Bar colors, the same as Pillars Player Frame's.
ns.BAR_COLORS = {
	{ key = "green", label = "Green", color = { 0, 0.8, 0, 1 } }, -- Blizzard's health green
	{ key = "red", label = "Red", color = { 0.85, 0.1, 0.1, 1 } },
	{ key = "blue", label = "Blue", color = { 0, 0, 1, 1 } }, -- Blizzard's mana blue
	{ key = "orange", label = "Orange", color = { 1, 0.5, 0.25, 1 } }, -- Blizzard's focus orange
	{ key = "yellow", label = "Yellow", color = { 1, 1, 0, 1 } }, -- Blizzard's energy yellow
	{ key = "purple", label = "Purple", color = { 0.6, 0.3, 0.9, 1 } },
	{ key = "cyan", label = "Cyan", color = { 0.1, 0.8, 0.9, 1 } },
	{ key = "white", label = "White", color = { 1, 1, 1, 1 } },
	{ key = "gray", label = "Gray", color = { 0.5, 0.5, 0.5, 1 } },
	{ key = "paleblue", label = "Pale Blue", color = { 0.7, 0.92, 1, 1 } }, -- #B3EBFF
}

-- Health bar colors: the bar colors, plus the unit's reaction and class.
local HEALTH_COLORS = {
	{ key = "reaction", label = "Reaction (Hostile Red, Neutral Yellow, Friendly Green)" },
	{ key = "class", label = "Class Color (Players), Reaction (NPCs)" },
}
for _, color in ipairs(ns.BAR_COLORS) do
	HEALTH_COLORS[#HEALTH_COLORS + 1] = color
end

local VALUE_TEXT = {
	{ key = "full", label = "Full Value" },
	{ key = "short", label = "Abbreviated Value" },
	{ key = "percent", label = "Percentage" },
	{ key = "both", label = "Both" },
	{ key = "none", label = "None" },
}

-- The three frames. Each has the same settings under its own prefix:
-- tfHealthWidth, totHealthWidth, ffHealthWidth.
ns.UNITS = {
	{ prefix = "tf", page = "Target", what = "target frame" },
	{ prefix = "tot", page = "Target of Target", what = "target of target frame" },
	{ prefix = "ff", page = "Focus", what = "focus frame" },
}

-- Per-frame defaults: the target frame's, with the target of target's
-- differences below.
local UNIT_DEFAULTS = {
	Enabled = true,
	OffsetX = 0,
	OffsetY = 0,
	HealthWidth = 150,
	HealthHeight = 26,
	PowerHeight = 10,
	NameHeight = 18,
	FontSize = 12,
	HealthColor = "green",
	HealthTapped = true,
	HealthText = "both",
	HealthTextAnchor = "CENTER",
	PowerText = "none",
	HealPredict = true,
	NameBar = "reaction",
	NameText = "short",
	NameAnchor = "CENTER",
	NameColor = { r = 1, g = 0.82, b = 0, a = 1 }, -- Blizzard's gold
	NameClassColor = false,
	Level = true,
	LevelPos = "badge",
	LevelColor = true,
	Portrait = "portrait",
	PortraitShape = "round",
	PortraitSide = "right",
	PortraitFit = true,
	PortraitSize = 60,
	Classification = true,
	RaidIcon = true,
	RaidIconSize = 20,
}

local UNIT_OVERRIDES = {
	tot = {
		HealthWidth = 80,
		HealthHeight = 12,
		PowerHeight = 6,
		NameHeight = 14,
		FontSize = 10,
		HealthText = "none",
		NameAnchor = "LEFT",
		Level = false,
		PortraitSide = "left",
		RaidIconSize = 14,
	},
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

local defaults = {
	barTexture = "blizzard",
	border = "solid",
	borderSize = 2,
	borderInset = 0,
	borderTint = "black",
	font = "friz",
	fontShadow = "soft",
	healthBackground = "solid",
	healthBgColor = "black",
	healthBgOpacity = 50,
	powerBackground = "solid",
	powerBgColor = "black",
	powerBgOpacity = 50,
	nameBackground = "solid",
	nameBgColor = "charcoal",
	nameBgOpacity = 90,
	manaColor = "blue",
	rageColor = "red",
	energyColor = "yellow",
	focusColor = "orange",
	healPredictColor = "paleblue",
	healPredictOpacity = 60,
}
for _, unit in ipairs(ns.UNITS) do
	local overrides = UNIT_OVERRIDES[unit.prefix] or {}
	for key, value in pairs(UNIT_DEFAULTS) do
		local own = overrides[key]
		if own == nil then
			own = value
		end
		defaults[unit.prefix .. key] = Copy(own)
	end
end

local kit = API.Settings.New(addonName, {
	title = "Pillars Target Frames",
	description = "A reskin of Blizzard's target, target of target and focus frames, laid out like the "
		.. "default target frame. Each frame has its own page; the Look page is shared.",
	features = {
		"The target, target of target and focus frames, each with a portrait, a name bar, health and resource bars.",
		"Blizzard's look: a round portrait, the name bar in the unit's reaction color, the level by difficulty.",
		"Elite and rare units get a gold or silver ring; tapped units go gray; raid target icons on the portrait.",
		"Health and resource text, incoming heals, and the dead and offline states.",
		"Blizzard's buffs, debuffs, cast bars and Edit Mode positions are kept.",
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

-- Background, background color and opacity rows for a box.
local function BackgroundRows(page, prefix, what)
	page:MediaDropdown({ key = prefix .. "Background", mediaType = "background", label = what .. " Background" })
	page:Dropdown({ key = prefix .. "BgColor", label = what .. " Background Color",
		tooltip = "Color of the " .. strlower(what) .. " background. Default keeps the background's own color.",
		options = ns.BACKGROUND_COLORS })
	page:Slider({ key = prefix .. "BgOpacity", label = what .. " Background Opacity", min = 0, max = 100, step = 5,
		format = "%d%%" })
end

-- The settings of one frame. reload = true on the ones that move, resize or
-- re-enable Blizzard's bars.
local function UnitPage(page, unit)
	local p, what = unit.prefix, unit.what
	page:Header(unit.page)
	page:Text("Blizzard's " .. what .. " in the Pillars look. Blizzard's own buffs, debuffs and cast bar "
		.. "stay where Blizzard puts them; move the whole frame in Edit Mode, or with the offsets below.")
	page:Checkbox({ key = p .. "Enabled", reload = true, label = "Enable",
		tooltip = "Reskin the " .. what .. ". Turning it off takes effect after a reload." })

	page:Header("Size and Position")
	page:Slider({ key = p .. "OffsetX", reload = true, label = "Horizontal Offset",
		tooltip = "Moves the bars right (positive) or left (negative) inside Blizzard's frame, for instance away "
			.. "from its buffs.", min = -100, max = 100, step = 1, format = "%d" })
	page:Slider({ key = p .. "OffsetY", reload = true, label = "Vertical Offset",
		tooltip = "Moves the bars up (positive) or down (negative) inside Blizzard's frame.",
		min = -100, max = 100, step = 1, format = "%d" })
	page:Slider({ key = p .. "HealthWidth", reload = true, label = "Width",
		tooltip = "Width of the health bar; the name and resource bars match it.", min = 40, max = 400, step = 2, format = "%d" })
	page:Slider({ key = p .. "HealthHeight", reload = true, label = "Health Bar Height", min = 6, max = 80, step = 1,
		format = "%d" })
	page:Slider({ key = p .. "PowerHeight", reload = true, label = "Resource Bar Height", min = 2, max = 40, step = 1,
		format = "%d" })
	page:Slider({ key = p .. "NameHeight", label = "Name Bar Height", min = 8, max = 40, step = 1, format = "%d" })
	page:Slider({ key = p .. "FontSize", label = "Font Size", tooltip = "Size of all text on this frame.",
		min = 6, max = 24, step = 1, format = "%d" })

	page:Header("Health and Resource")
	page:Dropdown({ key = p .. "HealthColor", label = "Health Color",
		tooltip = "Color of the health bar. Blizzard's is Green. Reaction follows the name bar: hostile red, "
			.. "neutral yellow, friendly green.", options = HEALTH_COLORS })
	page:Checkbox({ key = p .. "HealthTapped", label = "Gray When Tapped",
		tooltip = "Gray health bar and name bar for a unit someone else has tapped, as Blizzard's frame does." })
	page:Dropdown({ key = p .. "HealthText", label = "Health Text", tooltip = "Text on the health bar.",
		options = VALUE_TEXT })
	page:Anchor({ key = p .. "HealthTextAnchor", label = "Health Text Position" })
	page:Dropdown({ key = p .. "PowerText", label = "Resource Text",
		tooltip = "Text on the resource bar: the unit's mana, rage, energy or focus.", options = VALUE_TEXT })
	page:Checkbox({ key = p .. "HealPredict", label = "Incoming Heals",
		tooltip = "Heals being cast on the unit as a lighter bar after its health. Blizzard's own incoming heal "
			.. "display is hidden while the reskin is on; the color is on the Look page." })

	page:Header("Name and Level")
	page:Dropdown({ key = p .. "NameBar", label = "Name Bar Color",
		tooltip = "Reaction is Blizzard's: hostile red, neutral yellow, friendly green, other players blue. "
			.. "Class Color uses a player's class color. Background only shows the name bar background from the Look page.",
		options = { { key = "reaction", label = "Reaction (Blizzard's)" }, { key = "class", label = "Class Color (Players)" },
			{ key = "plain", label = "Background Only" } } })
	page:Dropdown({ key = p .. "NameText", label = "Name",
		options = { { key = "full", label = "Name and Realm" }, { key = "short", label = "Name Only" },
			{ key = "none", label = "None" } } })
	page:Anchor({ key = p .. "NameAnchor", label = "Name Position" })
	if page.Color then
		page:Color({ key = p .. "NameColor", label = "Name Color", tooltip = "Color of the name. Blizzard's is gold." })
	end
	page:Checkbox({ key = p .. "NameClassColor", label = "Class Colored Name",
		tooltip = "Players' names in their class color instead of Name Color." })
	page:Checkbox({ key = p .. "Level", label = "Level", tooltip = "Show the unit's level." })
	page:Dropdown({ key = p .. "LevelPos", label = "Level Position",
		tooltip = "On the Portrait: in a small circle on the portrait's outer bottom corner, like the old target "
			.. "frame. Without a portrait it goes on the name bar.",
		options = { { key = "badge", label = "On the Portrait" }, { key = "name", label = "On the Name Bar" } } })
	page:Checkbox({ key = p .. "LevelColor", label = "Color Level by Difficulty",
		tooltip = "Enemies' levels in Blizzard's difficulty colors, gray to red; ?? for a level far above yours." })

	page:Header("Portrait")
	page:Dropdown({ key = p .. "Portrait", label = "Portrait",
		tooltip = "Blizzard's round portrait picture, the 3D model (always square), the class icon for players "
			.. "(the portrait for others), or none.",
		options = { { key = "portrait", label = "Portrait (Blizzard's)" }, { key = "model", label = "3D Model" },
			{ key = "class", label = "Class Icon" }, { key = "none", label = "None" } } })
	page:Dropdown({ key = p .. "PortraitShape", label = "Shape",
		tooltip = "Round: a ring in the Border Tint, as thick as Border Size. Square: the name bar's background "
			.. "and the shared border.",
		options = { { key = "round", label = "Round" }, { key = "square", label = "Square" } } })
	page:Dropdown({ key = p .. "PortraitSide", label = "Side",
		tooltip = "Which side of the bars the portrait is on. Blizzard's target and focus frames have it on the "
			.. "right, the target of target on the left.",
		options = { { key = "right", label = "Right" }, { key = "left", label = "Left" } } })
	page:Checkbox({ key = p .. "PortraitFit", label = "Match Bar Height",
		tooltip = "Make the portrait as tall as the name, health and resource bars together." })
	page:Slider({ key = p .. "PortraitSize", label = "Size", tooltip = "Used when Match Bar Height is unchecked.",
		min = 16, max = 140, step = 1, format = "%d" })
	page:Checkbox({ key = p .. "Classification", label = "Elite and Rare Ring",
		tooltip = "In place of Blizzard's dragon: a gold ring or border for elites and world bosses, silver for rares." })
	page:Checkbox({ key = p .. "RaidIcon", label = "Raid Target Icon",
		tooltip = "The unit's raid target icon (skull, cross and the rest) at the top of the portrait." })
	page:Slider({ key = p .. "RaidIconSize", label = "Raid Target Icon Size", min = 8, max = 48, step = 1, format = "%d" })
end

local PAGES = {}

PAGES["General"] = function(page)
	page:Header("Pillars Target Frames")
	page:Text("A reskin of Blizzard's target, target of target and focus frames, laid out like Blizzard's "
		.. "target frame: a portrait beside a name bar, the health bar and the resource bar.\n"
		.. "Each frame has its own page; the Look page (bar texture, border, font, backgrounds and resource "
		.. "colors) is shared by all three.\n"
		.. "The frames stay Blizzard's: they show when Blizzard shows them, keep Blizzard's buffs, debuffs, "
		.. "cast bars and threat number, and move with Edit Mode (Escape → Edit Mode). Left-click targets the "
		.. "unit, right-click opens its menu.\n"
		.. "Turning a frame off takes effect after a reload (/reload). /ptf probe shows what this client supports.")
	page:Button({ label = "", text = "Diagnostics", tooltip = "What this client supports, in a window to copy for bug reports.",
		onClick = function() SlashCmdList.PILLARSTARGETFRAMES("probe") end })
end

PAGES["Focus"] = function(page)
	UnitPage(page, ns.UNITS[3])
end

PAGES["Look"] = function(page)
	page:Header("Look")
	page:Text("Shared by the target, target of target and focus frames.")
	page:MediaDropdown({ key = "barTexture", reload = true, mediaType = "statusbar", label = "Bar Texture",
		tooltip = "Texture of the health, resource and name bars. Blizzard's is the default look." })
	page:MediaDropdown({ key = "border", mediaType = "border", label = "Border" })
	page:Slider({ key = "borderSize", label = "Border Size", tooltip = "Thickness of the borders and the round portrait's ring.",
		min = 1, max = 32, step = 1, format = "%d" })
	page:Slider({ key = "borderInset", label = "Border Position",
		tooltip = "Moves the borders in (positive) or out (negative). If you see a gap between a bar and its border, "
			.. "move the border in until it closes.", min = -16, max = 16, step = 1, format = "%d" })
	page:Dropdown({ key = "borderTint", label = "Border Tint", tooltip = "Color of the borders and the portrait ring.",
		options = ns.TINTS })
	page:MediaDropdown({ key = "font", mediaType = "font", label = "Font" })
	page:FontShadow({ key = "fontShadow" })

	page:Header("Backgrounds")
	BackgroundRows(page, "health", "Health Bar")
	BackgroundRows(page, "power", "Resource Bar")
	BackgroundRows(page, "name", "Name Bar")

	page:Header("Colors")
	page:Dropdown({ key = "manaColor", label = "Mana Color", options = ns.BAR_COLORS })
	page:Dropdown({ key = "rageColor", label = "Rage Color", options = ns.BAR_COLORS })
	page:Dropdown({ key = "energyColor", label = "Energy Color", options = ns.BAR_COLORS })
	page:Dropdown({ key = "focusColor", label = "Focus Color", tooltip = "Hunter pets' focus.", options = ns.BAR_COLORS })
	page:Dropdown({ key = "healPredictColor", label = "Incoming Heal Color",
		tooltip = "Color of the incoming heal bar. Pale Blue is #B3EBFF.", options = ns.BAR_COLORS })
	page:Slider({ key = "healPredictOpacity", label = "Incoming Heal Opacity", min = 10, max = 100, step = 5,
		format = "%d%%" })
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
