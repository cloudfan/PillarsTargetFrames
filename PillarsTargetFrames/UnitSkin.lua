local addonName, ns = ...

if not ns.kit then
	return
end

-- The unit frames. One layout for every frame:
--
--   [ buffs, growing up    ]
--   [ name           level ]
--   [ health bar           ] [      ]
--   [ resource bar / cast  ] [portr.]
--   [ combo points         ]
--   [ debuffs, growing down]
--
-- The bars are our own status bars, fed by the client; health, power and
-- names can be secret values on Forever and go straight into SetValue,
-- SetText and SetFormattedText. Blizzard's target, target of target and
-- focus frames are made invisible (alpha 0, kept at 0, mouse off out of
-- combat) but keep running: our frames are their children, so they show
-- when Blizzard's would (the target of target follows Blizzard's own
-- setting) and move with them in Edit Mode. Blizzard's buff and debuff
-- buttons, which addons cannot rebuild in combat, are moved onto our frames.
-- The target's pet has no Blizzard frame: its frame is ours, shown by a
-- unit watch. Clicks go to secure buttons of our own over each layout.
--
-- Nothing the client keeps from addons is shown: no threat, no aura data
-- of our own, and a secret reaction, raid icon or cast time is left out.

local kit = ns.kit
local settings -- kit.settings, set by Apply
local Plain, IsSecret = ns.Plain, ns.IsSecret

local GAP = 3 -- between the boxes, on top of their borders
local DEAD_TINT = { 0.4, 0.47, 0.6, 0.75 } -- backgrounds of dead units
local DEAD_PORTRAIT_ALPHA = 0.3
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local CLASS_ICONS = "Interface\\WorldStateFrame\\Icons-Classes"
local CROP = 0.06 -- class icons, cropped so the art fills the box
-- The ring around the player frame's totems in Wrath of the Lich King, as
-- parts of a combo point's box: the ring and the dot inside it.
local TOTEM_RING = { file = "Interface\\CharacterFrame\\TotemBorder", ring = 1.03, dot = 0.6 }
local COMBO_EMPTY = { 0.12, 0.12, 0.12, 0.85 }
local COMBO_POWER = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
local TICK = 0.2 -- refresh of units without events (target of target, target's pet)

-- Blizzard's reaction colors (FACTION_BAR_COLORS), for clients without them.
local REACTION_COLORS = {
	{ 0.8, 0.3, 0.22, 1 }, { 0.8, 0.3, 0.22, 1 }, { 0.75, 0.27, 0, 1 }, { 0.9, 0.7, 0, 1 },
	{ 0, 0.6, 0.1, 1 }, { 0, 0.6, 0.1, 1 }, { 0, 0.6, 0.1, 1 }, { 0, 0.6, 0.1, 1 },
}

local POWER_COLOR_KEYS = {
	MANA = "manaColor",
	RAGE = "rageColor",
	ENERGY = "energyColor",
	FOCUS = "focusColor",
}

-- Where a box goes when attached to another at a point: its own point, the
-- other box's point, and the direction of the gap.
local OUTSIDE = {
	TOP = { "BOTTOM", "TOP", 0, 1 },
	BOTTOM = { "TOP", "BOTTOM", 0, -1 },
	LEFT = { "RIGHT", "LEFT", -1, 0 },
	RIGHT = { "LEFT", "RIGHT", 1, 0 },
	TOPLEFT = { "BOTTOMLEFT", "TOPLEFT", 0, 1 },
	TOPRIGHT = { "BOTTOMRIGHT", "TOPRIGHT", 0, 1 },
	BOTTOMLEFT = { "TOPLEFT", "BOTTOMLEFT", 0, -1 },
	BOTTOMRIGHT = { "TOPRIGHT", "BOTTOMRIGHT", 0, -1 },
	CENTER = { "CENTER", "CENTER", 0, 0 },
}

-- The portrait goes beside: BOTTOMRIGHT is on the right, bottoms lined up.
local BESIDE = {
	TOP = OUTSIDE.TOP,
	BOTTOM = OUTSIDE.BOTTOM,
	CENTER = OUTSIDE.CENTER,
	LEFT = OUTSIDE.LEFT,
	RIGHT = OUTSIDE.RIGHT,
	TOPLEFT = { "TOPRIGHT", "TOPLEFT", -1, 0 },
	TOPRIGHT = { "TOPLEFT", "TOPRIGHT", 1, 0 },
	BOTTOMLEFT = { "BOTTOMRIGHT", "BOTTOMLEFT", -1, 0 },
	BOTTOMRIGHT = { "BOTTOMLEFT", "BOTTOMRIGHT", 1, 0 },
}

-- Portraits hold still: the model is paused on its first frame, again
-- whenever it loads a new unit.
local function HoldStill(model)
	if model.SetPaused then
		model:SetPaused(true)
	elseif model.FreezeAnimation then
		model:FreezeAnimation(0, 0, 0)
	end
end

local function Mentions(text, word)
	return type(text) == "string" and strlower(text):find(word, 1, true) ~= nil
end

-- Frames the client keeps from addons: touching one raises an error, so
-- every frame of Blizzard's we walk is checked first.
local function Forbidden(frame)
	local ok, forbidden = pcall(function()
		return frame.IsForbidden ~= nil and frame:IsForbidden()
	end)
	return not ok or forbidden and true or false
end

local function DebugName(region)
	local ok, name = pcall(function()
		return region.GetDebugName and region:GetDebugName() or region.GetName and region:GetName()
	end)
	return ok and name or nil
end

-- Shared look ---------------------------------------------------------------------------

local function Color(key)
	local r, g, b, a = kit:GetColor(key)
	return { r, g, b, a or 1 }
end

-- The Border Tint over the border's own color (tinted borders keep theirs
-- under a white tint).
local function BorderColor()
	local own = kit:GetMedia("border", "border").color
	local r, g, b, a = kit:GetColor("borderTint")
	return { r * (own[1] or 1), g * (own[2] or 1), b * (own[3] or 1), (a or 1) * (own[4] or 1) }
end

local function NewBackdropFrame(parent)
	local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	frame:EnableMouse(false)
	return frame
end

-- How far a border sits outside its box. A solid border goes all the way
-- out, so it never covers the box; a textured border's art has a clear strip
-- on its inner side, so it goes out by 30% of its size. Border Position moves
-- it further in (positive) or out (negative).
local function Outset(edge)
	local base = settings.border == "solid" and edge or math.floor(edge * 0.3 + 0.5)
	return base - settings.borderInset
end

-- The space between two boxes: both borders plus GAP.
local function Gap()
	local media = kit:GetMedia("border", "border")
	return GAP + (media.file and 2 * math.max(0, Outset(settings.borderSize)) or 0)
end

-- A background and border for a box, children of the box so they show and
-- hide with it.
local function NewBox(target)
	return { target = target, back = NewBackdropFrame(target), border = NewBackdropFrame(target) }
end

local function BackgroundColor(dead)
	if dead then
		return unpack(DEAD_TINT)
	end
	return kit:GetColor("backgroundColor")
end

local function PlaceBox(box, dead)
	local target, back, border = box.target, box.back, box.border
	local background = kit:GetMedia("background", "background")
	if background.file then
		back:SetBackdrop({ bgFile = background.file, tile = background.tile, tileSize = background.tileSize })
		back:SetBackdropColor(BackgroundColor(dead))
		back:ClearAllPoints()
		back:SetAllPoints(target)
		back:SetFrameLevel(math.max(0, target:GetFrameLevel() - 1))
		back:Show()
	else
		back:Hide()
	end
	local media = kit:GetMedia("border", "border")
	if media.file then
		local edge = settings.borderSize
		border:SetBackdrop({ edgeFile = media.file, edgeSize = edge })
		border:SetBackdropBorderColor(unpack(BorderColor()))
		local out = Outset(edge)
		border:ClearAllPoints()
		border:SetPoint("TOPLEFT", target, "TOPLEFT", -out, out)
		border:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", out, -out)
		border:SetFrameLevel(target:GetFrameLevel() + 3)
		border:Show()
	else
		border:Hide()
	end
end

local function TintBox(box, dead)
	if box.back:IsShown() then
		box.back:SetBackdropColor(BackgroundColor(dead))
	end
end

local function NewText(parent)
	local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fontString:SetWordWrap(false)
	return fontString
end

-- Text inside a box at an anchor, a few pixels in from the sides.
local function PlaceText(fontString, point, x, y, relativeTo)
	local inset = point:find("LEFT") and 4 or (point:find("RIGHT") and -4 or 0)
	fontString:ClearAllPoints()
	fontString:SetPoint(point, relativeTo, point, inset + x, y)
	fontString:SetJustifyH(point:find("LEFT") and "LEFT" or (point:find("RIGHT") and "RIGHT" or "CENTER"))
end

-- Values --------------------------------------------------------------------------------

local function Abbreviate(value)
	if value >= 1e9 then
		return format("%.1fB", value / 1e9)
	elseif value >= 1e6 then
		return format("%.1fM", value / 1e6)
	elseif value >= 1e4 then
		return format("%.0fK", value / 1e3)
	end
	return tostring(value)
end

-- The value as shown (string, number or secret) and the percent 0-100
-- (number, secret, or nil when it cannot be had). percentOf() returns the
-- percent from the client's secret-safe helper.
local function Pieces(value, max, percentOf, short)
	if not IsSecret(value) and not IsSecret(max) then
		local shown = short and Abbreviate(value) or (BreakUpLargeNumbers and BreakUpLargeNumbers(value) or value)
		local percent = (max and max > 0) and math.floor(value / max * 100 + 0.5) or 0
		return shown, percent
	end
	local shown = value
	if short and AbbreviateNumbers then
		local ok, result = pcall(AbbreviateNumbers, value)
		if ok then
			shown = result
		end
	end
	return shown, percentOf()
end

-- Writes value text in one of the modes: "full", "short", "percent",
-- "both" or "none". Secret values go straight into SetFormattedText.
local function SetValueText(fontString, mode, value, max, percentOf)
	if mode == "none" then
		fontString:SetText("")
		return
	end
	local shown, percent = Pieces(value, max, percentOf, mode ~= "full")
	local ok
	if mode == "percent" then
		ok = percent ~= nil and pcall(fontString.SetFormattedText, fontString, "%.0f%%", percent)
	elseif mode == "both" then
		ok = percent ~= nil and pcall(fontString.SetFormattedText, fontString, "%s  %.0f%%", shown, percent)
		if not ok then
			ok = pcall(fontString.SetFormattedText, fontString, "%s", shown)
		end
	else
		ok = pcall(fontString.SetFormattedText, fontString, "%s", shown)
	end
	if not ok then
		fontString:SetText("")
	end
end

local function HealthPercentOf(unit)
	return function()
		if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
			local ok, result = pcall(UnitHealthPercent, unit, true, CurveConstants.ScaleTo100)
			if ok then
				return result
			end
		end
		return nil
	end
end

local function PowerPercentOf(unit)
	return function()
		if UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100 then
			local ok, result = pcall(UnitPowerPercent, unit, UnitPowerType(unit), false, CurveConstants.ScaleTo100)
			if ok then
				return result
			end
		end
		return nil
	end
end

-- Unit facts, nil when the client keeps them secret --------------------------------------

local function ClassToken(unit)
	if not Plain(UnitIsPlayer(unit)) then
		return nil
	end
	local _, token = UnitClass(unit)
	return Plain(token)
end

local function ClassColor(unit)
	local token = ClassToken(unit)
	if not token then
		return nil
	end
	if C_ClassColor and C_ClassColor.GetClassColor then
		local color = C_ClassColor.GetClassColor(token)
		if color then
			return { color.r, color.g, color.b, 1 }
		end
	end
	local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
	return color and { color.r, color.g, color.b, 1 } or nil
end

local function ReactionColor(unit)
	local reaction = UnitReaction and Plain(UnitReaction(unit, "player"))
	if type(reaction) ~= "number" then
		return nil
	end
	local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
	if type(color) == "table" and color.r then
		return { color.r, color.g, color.b, 1 }
	end
	return REACTION_COLORS[reaction]
end

local function Dead(unit)
	return Plain(UnitIsDeadOrGhost(unit)) and true or false
end

-- Blizzard's difficulty colors for units you can attack, gold for the rest.
local function LevelColor(unit, level)
	if Plain(UnitCanAttack("player", unit)) == false then
		return { 1, 0.82, 0, 1 }
	end
	local color = GetCreatureDifficultyColor and GetCreatureDifficultyColor(level)
		or GetQuestDifficultyColor and GetQuestDifficultyColor(level)
	if type(color) == "table" and color.r then
		return { color.r, color.g, color.b, 1 }
	end
	return { 1, 0.82, 0, 1 }
end

-- Blizzard's frames, invisible ------------------------------------------------------------
-- Alpha 0, put back to 0 whenever Blizzard sets it (cast bars and flashes
-- animate their alpha), and no mouse (out of combat).

local invisible = {}
local uncovered = {} -- pieces that hold Blizzard's buff buttons (see Uncover)
local settingAlpha = false

local function KeepInvisible(region, alpha)
	if settingAlpha or not invisible[region] then
		return
	end
	if IsSecret(alpha) or alpha ~= 0 then
		settingAlpha = true
		region:SetAlpha(0)
		settingAlpha = false
	end
end

local function MakeInvisible(region)
	if type(region) ~= "table" or Forbidden(region) or not region.SetAlpha or uncovered[region] then
		return false
	end
	if not invisible[region] then
		invisible[region] = true
		hooksecurefunc(region, "SetAlpha", KeepInvisible)
	end
	settingAlpha = true
	region:SetAlpha(0)
	settingAlpha = false
	return true
end

local function NoMouse(key, frames)
	kit.events.AfterCombat(key, function()
		for _, frame in ipairs(frames) do
			-- Never on Blizzard's protected frames (the unit buttons themselves).
			if type(frame) == "table" and not Forbidden(frame) and frame.EnableMouse
				and not (frame.IsProtected and frame:IsProtected()) then
				frame:EnableMouse(false)
			end
		end
	end)
end

-- The skin ---------------------------------------------------------------------------------

local Skin = {}
Skin.__index = Skin
local skins = {}
ns.skins = skins

-- A setting of this frame. Focus and target of target take the target
-- frame's value for a section until its Override toggle is checked.
function Skin:Get(key)
	if self.spec.inherit then
		local section = ns.SectionOf(key)
		if section and not settings[self.prefix .. "Override" .. section] then
			return settings["tf" .. key]
		end
	end
	return settings[self.prefix .. key]
end

-- Blizzard's frame: the one ours lives in (for the target's pet, the target
-- frame it is placed against).
function Skin:Blizzard()
	return self.spec.frame()
end

function Skin:Ready()
	return self.active and self.holder ~= nil
end

function Skin:Named(suffix)
	local frame = self:Blizzard()
	local name = frame and frame.GetName and frame:GetName()
	return name and _G[name .. suffix] or nil
end

-- Everything of Blizzard's frame to make invisible: its art, bars, text,
-- cast bar and threat number. Its buff and debuff buttons stay (they are
-- moved onto our frame), and so does Edit Mode's highlight.
function Skin:BlizzardPieces()
	local frame = self:Blizzard()
	local list = {}
	local function Add(region)
		if type(region) == "table" and region ~= self.holder and region ~= frame.Selection then
			list[#list + 1] = region
		end
	end
	if self.spec.small then
		-- The target of target: our frame is its child, so its own pieces go.
		for _, region in ipairs({ frame:GetRegions() }) do
			Add(region)
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			Add(child)
		end
		return list
	end
	Add(frame.TargetFrameContainer)
	Add(frame.TargetFrameContent)
	Add(frame.spellbar)
	Add(frame.threatIndicator)
	Add(frame.threatNumericIndicator)
	for _, suffix in ipairs({ "TextureFrame", "NameBackground", "Background", "Portrait", "Flash", "HealthBar",
		"ManaBar", "SpellBar", "NumericalThreat" }) do
		Add(self:Named(suffix))
	end
	-- The focus frame's own target of target.
	if self.spec.ownToT then
		Add(frame.totFrame)
	end
	return list
end

function Skin:HideBlizzard()
	if self.spec.pet then
		return
	end
	local pieces = self:BlizzardPieces()
	local count = 0
	for _, region in ipairs(pieces) do
		if MakeInvisible(region) then
			count = count + 1
		end
	end
	self.hiddenCount = count
	pieces[#pieces + 1] = self:Blizzard()
	NoMouse(self.prefix .. "NoMouse", pieces)
end

-- Building -------------------------------------------------------------------------------

local function NewBar(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end

function Skin:Create()
	local blizzard = self:Blizzard()
	local parent = blizzard
	if self.spec.movable then
		-- A plain frame on the screen that the frame is placed on, moved in
		-- Edit Mode through ClaiibuAPI. It is as big as the layout, so Edit
		-- Mode's box covers it even while the frame itself is hidden.
		local root = CreateFrame("Frame", nil, UIParent)
		root:SetSize(1, 1)
		root:SetFrameStrata(blizzard:GetFrameStrata())
		self.root = root
	end
	if self.spec.pet then
		-- Shown by a unit watch while the target has a pet.
		local watcher = CreateFrame("Frame", nil, self.root, "SecureHandlerStateTemplate")
		watcher:SetAllPoints(self.root)
		watcher:SetAttribute("unit", self.unit)
		RegisterUnitWatch(watcher)
		self.watcher = watcher
		parent = watcher
	end
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(1, 1)
	holder:SetFrameStrata(blizzard:GetFrameStrata())
	holder:SetFrameLevel(blizzard:GetFrameLevel() + 5)
	self.holder = holder
	local parts, texts = self.parts, self.texts

	parts.health = NewBar(holder)
	parts.healthBox = NewBox(parts.health)
	parts.power = NewBar(holder)
	parts.powerBox = NewBox(parts.power)
	parts.name = CreateFrame("Frame", nil, holder)
	parts.nameBox = NewBox(parts.name)
	parts.nameGradient = parts.name:CreateTexture(nil, "BACKGROUND")
	parts.nameGradient:SetAllPoints(parts.name)
	parts.nameGradient:Hide()

	local portrait = CreateFrame("Frame", nil, holder)
	portrait.model = CreateFrame("PlayerModel", nil, portrait)
	portrait.model:SetAllPoints(portrait)
	-- A model given its unit while hidden can stay blank: give it again
	-- whenever it shows.
	local unit = self.unit
	portrait.model:SetScript("OnShow", function(model)
		if Plain(UnitExists(unit)) ~= false then
			model:SetUnit(unit)
			if model.SetPortraitZoom then
				model:SetPortraitZoom(1)
			end
			HoldStill(model)
		end
	end)
	portrait.model:SetScript("OnModelLoaded", HoldStill)
	portrait.class = portrait:CreateTexture(nil, "ARTWORK")
	portrait.class:SetAllPoints(portrait)
	parts.portrait = portrait
	parts.portraitBox = NewBox(portrait)

	parts.cast = NewBar(holder)
	parts.castBox = NewBox(parts.cast)
	parts.cast:Hide()
	local skin = self
	parts.cast:SetScript("OnUpdate", function(bar)
		skin:CastTick(bar)
	end)

	parts.combo = CreateFrame("Frame", nil, holder)
	parts.combo.points = {}
	parts.combo:Hide()
	parts.buffAnchor = CreateFrame("Frame", nil, holder)
	parts.debuffAnchor = CreateFrame("Frame", nil, holder)

	-- Text sits on layers above the bars and portrait so nothing covers it.
	local function Layer(level)
		local frame = CreateFrame("Frame", nil, holder)
		frame:SetFrameLevel(holder:GetFrameLevel() + level)
		return frame
	end
	parts.healthText = Layer(10)
	parts.powerText = Layer(10)
	parts.nameText = Layer(12)
	parts.castText = Layer(14)
	texts.health = NewText(parts.healthText)
	texts.power = NewText(parts.powerText)
	texts.name = NewText(parts.nameText)
	texts.level = NewText(parts.nameText)
	texts.cast = NewText(parts.castText)

	holder:SetScript("OnShow", function()
		skin:Refresh()
		skin:StartTicker()
	end)
	holder:SetScript("OnHide", function()
		skin:StopTicker()
	end)
end

function Skin:ComboPoint(index)
	local points = self.parts.combo.points
	if not points[index] then
		local point = CreateFrame("Frame", nil, self.parts.combo)
		point.dot = point:CreateTexture(nil, "ARTWORK")
		point.dot:SetPoint("CENTER")
		if point.CreateMaskTexture then
			local mask = point:CreateMaskTexture()
			mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetAllPoints(point.dot)
			point.dot:AddMaskTexture(mask)
		end
		point.ring = point:CreateTexture(nil, "OVERLAY")
		point.ring:SetTexture(TOTEM_RING.file)
		point.ring:SetPoint("CENTER")
		if point.ring.SetDesaturated then
			point.ring:SetDesaturated(true)
		end
		points[index] = point
	end
	return points[index]
end

-- Units without events: refreshed a few times a second while they show.

function Skin:StartTicker()
	if not (self.spec.poll and self:Ready() and self.holder:IsVisible() and C_Timer and C_Timer.NewTicker)
		or self.ticker then
		return
	end
	local skin = self
	self.ticker = C_Timer.NewTicker(TICK, function()
		if not skin.active then
			skin:StopTicker()
			return
		end
		skin:UpdateHealth()
		skin:UpdatePower()
		skin:UpdateName()
		skin:UpdateCast()
	end)
end

function Skin:StopTicker()
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
end

-- Clicks ---------------------------------------------------------------------------------

-- Our own secure unit button over the layout: left-click targets the unit,
-- right-click opens its menu. Created and placed out of combat only.
function Skin:CreateClicker()
	if self.clicker or InCombatLockdown() then
		return
	end
	local clicker = CreateFrame("Button", nil, self.holder, "SecureUnitButtonTemplate")
	clicker:SetAttribute("unit", self.unit)
	clicker:SetAttribute("type1", "target")
	clicker:SetAttribute("type2", "togglemenu")
	clicker:RegisterForClicks("AnyUp")
	clicker:SetFrameLevel(self.holder:GetFrameLevel() + 20)
	local unit = self.unit
	clicker:SetScript("OnEnter", function(button)
		GameTooltip_SetDefaultAnchor(GameTooltip, button)
		GameTooltip:SetUnit(unit)
		GameTooltip:Show()
	end)
	clicker:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	self.clicker = clicker
end

-- The rectangle of the shown bars and portrait, in holder coordinates.
function Skin:LayoutRect()
	local holder = self.holder
	local hl, hb = holder:GetLeft(), holder:GetBottom()
	if not (hl and hb) then
		return nil
	end
	local scale = holder:GetEffectiveScale()
	local parts = self.parts
	local left, right, top, bottom
	for _, frame in ipairs({ parts.health, parts.power, parts.name, parts.portrait }) do
		local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
		if l and r and t and b and frame:IsShown() then
			local s = frame:GetEffectiveScale() / scale
			l, r, t, b = l * s, r * s, t * s, b * s
			left = left and math.min(left, l) or l
			right = right and math.max(right, r) or r
			top = top and math.max(top, t) or t
			bottom = bottom and math.min(bottom, b) or b
		end
	end
	if not left then
		return nil
	end
	return left - hl, bottom - hb, right - left, top - bottom
end

-- Out of combat: the holder's place (it holds a secure button), the click
-- button and Edit Mode's highlight.
function Skin:PlaceSecure()
	local skin = self
	kit.events.AfterCombat(self.prefix .. "Secure", function()
		if not skin.active then
			return
		end
		local holder, blizzard = skin.holder, skin:Blizzard()
		holder:ClearAllPoints()
		if skin.root then
			-- The target of target stays a child of Blizzard's frame (so it
			-- shows when Blizzard's would) but sits on its own place.
			local extent = skin.extent
			skin.root:SetSize(extent.width, extent.height)
			kit:ApplyAnchor(skin.root, skin.prefix .. "Point", skin.prefix .. "OffsetX", skin.prefix .. "OffsetY")
			holder:SetPoint("CENTER", skin.root, "CENTER", extent.dx, extent.dy)
			if skin.mover then
				skin.mover:UpdateBounds()
			end
		else
			holder:SetPoint("CENTER", blizzard, "CENTER", skin:Get("OffsetX"), skin:Get("OffsetY"))
		end
		skin:CreateClicker()
		local x, y, width, height = skin:LayoutRect()
		if not x then
			-- No size yet (hidden until there is a unit): OnShow places it.
			skin.clickerPlaced = false
			return
		end
		skin.clicker:ClearAllPoints()
		skin.clicker:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x, y)
		skin.clicker:SetSize(width, height)
		skin.clicker:Show()
		skin.clickerPlaced = true
	end)
end

-- Layout ---------------------------------------------------------------------------------

local function StackKey(target, point)
	return tostring(target) .. point
end

-- Attaches frame to target outside its point side. Boxes attached to the
-- same side of the same box stack outward in the order they are attached
-- (combo points, then the separate cast bar, then debuffs below the
-- resource bar).
-- A hidden box is placed but takes no room.
function Skin:Attach(frame, target, point, x, y, hidden)
	local spec = OUTSIDE[point] or OUTSIDE.BOTTOM
	local gap = self.gap
	local key = StackKey(target, point)
	local extra = point ~= "CENTER" and (self.stack[key] or 0) or 0
	frame:ClearAllPoints()
	frame:SetPoint(spec[1], target, spec[2], spec[3] * (gap + extra) + x, spec[4] * (gap + extra) + y)
	if point ~= "CENTER" and not hidden then
		local size = spec[3] ~= 0 and frame:GetWidth() or frame:GetHeight()
		self.stack[key] = extra + size + gap
	end
end

-- A bar to attach to: the one named if it shows, else the health bar.
function Skin:Target(name, placed)
	local parts = self.parts
	if name == "power" and self:Get("PowerShow") and (not placed or placed.power) then
		return parts.power, "power"
	elseif name == "name" and self:Get("NameShow") and (not placed or placed.name) then
		return parts.name, "name"
	end
	return parts.health, "health"
end

-- The layout's size around the health bar's center, for the box Edit Mode
-- shows around a moved frame: width, height, and where the health bar's
-- center sits from the box's center.
function Skin:SetExtent(above, below, portraitSide, portraitWidth)
	local width, height = self:Get("HealthWidth"), self:Get("HealthHeight")
	local left, right = -width / 2, width / 2
	local top, bottom = height / 2 + above, -(height / 2 + below)
	if portraitSide > 0 then
		right = right + self.gap + portraitWidth
	elseif portraitSide < 0 then
		left = left - self.gap - portraitWidth
	end
	self.extent = { width = right - left, height = top - bottom, dx = -(left + right) / 2, dy = -(top + bottom) / 2 }
end

function Skin:LayoutPortrait(heights)
	local portrait = self.parts.portrait
	local parts, gap = self.parts, self.gap
	-- How far the name bar reaches above the health bar and the resource bar
	-- below it, when they are attached there.
	local above, below = 0, 0
	if self:Get("NameShow") and heights.nameTarget == "health" and heights.namePoint:find("TOP") then
		above = gap + heights.name + self:Get("NameY")
	end
	if self:Get("PowerShow") and heights.powerTarget == "health" and heights.powerPoint:find("BOTTOM") then
		below = gap + heights.power - self:Get("PowerY")
	end
	local shown = self:Get("PortraitShow")
	portrait:SetShown(shown)
	if not shown then
		self:SetExtent(above, below, 0, 0)
		return
	end
	local point = self:Get("PortraitPoint") or "BOTTOMRIGHT"
	local targetName = self:Get("PortraitTarget")
	local width, height
	if self:Get("PortraitOwnSize") then
		width, height = self:Get("PortraitWidth"), self:Get("PortraitHeight")
	else
		height = heights.health + above + below
		width = height
	end
	portrait:SetSize(width, height)
	local target, y = parts.health, 0
	if targetName == "bars" then
		if point:find("BOTTOM") then
			y = -below
		elseif point:find("TOP") then
			y = above
		else
			y = (above - below) / 2
		end
	else
		target = self:Target(targetName)
	end
	local spec = BESIDE[point] or BESIDE.BOTTOMRIGHT
	self:SetExtent(above, below, (targetName == "bars" or targetName == "health") and spec[3] or 0, width)
	portrait:ClearAllPoints()
	portrait:SetPoint(spec[1], target, spec[2], spec[3] * gap + self:Get("PortraitX"),
		spec[4] * gap + y + self:Get("PortraitY"))
	portrait:SetFrameLevel(parts.health:GetFrameLevel() + 2)
	PlaceBox(parts.portraitBox, self.dead)
	portrait.class:SetTexture(CLASS_ICONS)
end

-- Sets a texture to a gradient between two { r, g, b, a } colors: bottom to
-- top for VERTICAL, left to right for HORIZONTAL.
local function SetGradient(texture, orientation, from, to)
	texture:SetColorTexture(1, 1, 1, 1)
	if CreateColor and texture.SetGradient then
		texture:SetGradient(orientation, CreateColor(unpack(from)), CreateColor(unpack(to)))
	elseif texture.SetGradientAlpha then
		texture:SetGradientAlpha(orientation, from[1], from[2], from[3], from[4], to[1], to[2], to[3], to[4])
	else
		texture:SetColorTexture(to[1], to[2], to[3], (from[4] + to[4]) / 2)
	end
end

-- The name bar's gradient: solid on the side facing the bar it is attached
-- to, clear on the far side, in the Background Color (gray-blue when dead).
-- Its background and border go while it shows; at CENTER they stay.
function Skin:PaintNameGradient()
	local parts = self.parts
	local gradient, box = parts.nameGradient, parts.nameBox
	local spec = OUTSIDE[self:Get("NamePoint")] or OUTSIDE.CENTER
	local on = self:Get("NameGradient") and (spec[3] ~= 0 or spec[4] ~= 0)
	if not on then
		gradient:Hide()
		return
	end
	box.back:Hide()
	box.border:Hide()
	local r, g, b, a = BackgroundColor(self.dead)
	local solid, clear = { r, g, b, a or 1 }, { r, g, b, 0 }
	if spec[4] > 0 then
		SetGradient(gradient, "VERTICAL", solid, clear) -- above a bar: from the bottom
	elseif spec[4] < 0 then
		SetGradient(gradient, "VERTICAL", clear, solid) -- below a bar: from the top
	elseif spec[3] > 0 then
		SetGradient(gradient, "HORIZONTAL", solid, clear) -- on a bar's right: from the left
	else
		SetGradient(gradient, "HORIZONTAL", clear, solid) -- on a bar's left: from the right
	end
	gradient:Show()
end

function Skin:LayoutCombo()
	local combo = self.parts.combo
	local count = self:ComboMax()
	local size, spacing = self:Get("ComboSize"), self:Get("ComboSpacing")
	combo:SetSize(count * size + (count - 1) * spacing, size)
	local color = BorderColor()
	for i = 1, math.max(count, #combo.points) do
		local point = self:ComboPoint(i)
		point:SetShown(i <= count)
		point:SetSize(size, size)
		point:ClearAllPoints()
		point:SetPoint("LEFT", combo, "LEFT", (i - 1) * (size + spacing), 0)
		point.dot:SetSize(size * TOTEM_RING.dot, size * TOTEM_RING.dot)
		point.ring:SetSize(size * TOTEM_RING.ring, size * TOTEM_RING.ring)
		point.ring:SetVertexColor(color[1], color[2], color[3], color[4])
	end
	self.comboCount = count
end

function Skin:LayoutNow()
	if not self.active then
		return
	end
	if not self.holder then
		if self.spec.pet and InCombatLockdown() then
			-- Its unit watch is secure: made out of combat.
			local skin = self
			kit.events.AfterCombat(self.prefix .. "Create", function() skin:LayoutNow() end)
			return
		end
		self:Create()
		if self.root then
			self:AddMover()
		end
	end
	self:HideBlizzard()
	local parts, texts = self.parts, self.texts
	local texture = kit:GetMedia("statusbar", "barTexture").file
	local gap = Gap()
	self.gap = gap
	self.stack = {}
	self.dead = self.unitExists and Dead(self.unit) or false

	-- Health bar: the center of the layout.
	local health = parts.health
	local width, healthHeight = self:Get("HealthWidth"), self:Get("HealthHeight")
	health:SetSize(width, healthHeight)
	health:ClearAllPoints()
	health:SetPoint("CENTER", self.holder, "CENTER")
	health:SetStatusBarTexture(texture)
	PlaceBox(parts.healthBox, self.dead)

	-- Name and resource bars: own size or the health bar's; attached to the
	-- health bar or each other, in an order that works.
	local power, name = parts.power, parts.name
	local powerHeight = self:Get("PowerOwnSize") and self:Get("PowerHeight") or healthHeight
	power:SetSize(self:Get("PowerOwnSize") and self:Get("PowerWidth") or width, powerHeight)
	power:SetStatusBarTexture(texture)
	power:SetShown(self:Get("PowerShow"))
	local nameHeight = self:Get("NameHeight")
	name:SetSize(self:Get("NameOwnSize") and self:Get("NameWidth") or width, nameHeight)
	name:SetShown(self:Get("NameShow"))
	name:SetFrameLevel(health:GetFrameLevel() + 2)
	local placed = { health = true }
	local heights = { health = healthHeight, power = powerHeight, name = nameHeight }
	local function Place(part, frame)
		local target, targetName = self:Target(self:Get(part .. "Target"), placed)
		if target == frame then
			target, targetName = health, "health"
		end
		local point = self:Get(part .. "Point")
		self:Attach(frame, target, point, self:Get(part .. "X"), self:Get(part .. "Y"), not self:Get(part .. "Show"))
		heights[strlower(part) .. "Target"] = targetName
		heights[strlower(part) .. "Point"] = point
	end
	-- The one attached to the other goes second.
	if self:Get("NameTarget") == "power" then
		Place("Power", power)
		placed.power = true
		Place("Name", name)
	else
		Place("Name", name)
		placed.name = true
		Place("Power", power)
	end
	PlaceBox(parts.powerBox, self.dead)
	PlaceBox(parts.nameBox, self.dead)
	self:PaintNameGradient()

	self:LayoutPortrait(heights)

	-- Combo points, the separate cast bar, then the auras: in that order, so
	-- they stack when attached to the same side of the same bar.
	if self.spec.combo then
		self:LayoutCombo()
		local wanted = self:ComboWanted()
		parts.combo:SetShown(wanted)
		self.comboShown = wanted
		if wanted then
			self:Attach(parts.combo, self:Target(self:Get("ComboTarget")), self:Get("ComboPoint"),
				self:Get("ComboX"), self:Get("ComboY"))
		end
	end

	local cast = parts.cast
	cast:SetStatusBarTexture(texture)
	local castColor = Color("castColor")
	cast:SetStatusBarColor(castColor[1], castColor[2], castColor[3])
	if self:Get("CastSeparate") then
		local base = self:Get("PowerShow") and power or health
		cast:SetSize(self:Get("CastOwnSize") and self:Get("CastWidth") or base:GetWidth(),
			self:Get("CastOwnSize") and self:Get("CastHeight") or base:GetHeight())
		self:Attach(cast, self:Target(self:Get("CastTarget")), self:Get("CastPoint"), self:Get("CastX"), self:Get("CastY"))
	else
		-- Over the resource bar at its size; over the health bar's bottom
		-- without one.
		cast:ClearAllPoints()
		if self:Get("PowerShow") then
			cast:SetAllPoints(power)
		else
			cast:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT")
			cast:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT")
			cast:SetHeight(math.max(4, math.floor(healthHeight / 2)))
		end
	end
	cast:SetFrameLevel(math.max(power:GetFrameLevel(), health:GetFrameLevel()) + 4)
	PlaceBox(parts.castBox, false)
	parts.castText:SetAllPoints(cast)

	if self.spec.auras then
		for _, kind in ipairs({ "Buff", "Debuff" }) do
			local anchor = parts[strlower(kind) .. "Anchor"]
			anchor:SetSize(width, self:Get(kind .. "Size"))
			self:Attach(anchor, self:Target(self:Get(kind .. "Target")), self:Get(kind .. "Point"),
				self:Get(kind .. "X"), self:Get(kind .. "Y"))
		end
	end

	-- Text: the shared font, shadow and size.
	for _, fontString in pairs(texts) do
		kit:ApplyFont(fontString, "font", "fontSize", "fontShadow")
	end
	parts.healthText:SetAllPoints(health)
	parts.powerText:SetAllPoints(power)
	parts.nameText:SetAllPoints(name)
	PlaceText(texts.health, self:Get("HealthTextPoint"), 0, 0, health)
	PlaceText(texts.power, self:Get("PowerTextPoint"), 0, 0, power)
	PlaceText(texts.name, self:Get("NameTextPoint"), self:Get("NameTextX"), self:Get("NameTextY"), name)
	PlaceText(texts.level, self:Get("LevelPoint"), self:Get("LevelX"), self:Get("LevelY"), name)
	texts.name:SetWidth(math.max(10, name:GetWidth() - 8 - (self:Get("LevelShow") and settings.fontSize * 2.5 or 0)))
	PlaceText(texts.cast, "CENTER", 0, 0, cast)
	texts.cast:SetWidth(math.max(10, cast:GetWidth() - 8))

	self:Refresh()
	self:PlaceSecure()
end

function Skin:Layout()
	local skin = self
	kit.events.Defer(self.prefix .. "Layout", function()
		skin:LayoutNow()
	end)
end

-- Content --------------------------------------------------------------------------------

function Skin:ApplyHealthColor()
	local bar, unit = self.parts.health, self.unit
	local mode = self:Get("HealthColor")
	local color
	if mode == "class" then
		color = ClassColor(unit) or ReactionColor(unit)
	elseif mode == "reaction" then
		color = ReactionColor(unit)
	end
	color = color or Color("healthColor")
	bar:SetStatusBarColor(color[1], color[2], color[3])
end

function Skin:UpdateHealth()
	if not self:Ready() then
		return
	end
	local unit, bar = self.unit, self.parts.health
	local value, max = UnitHealth(unit), UnitHealthMax(unit)
	bar:SetMinMaxValues(0, max)
	bar:SetValue(value)
	SetValueText(self.texts.health, self:Get("HealthText"), value, max, self.healthPercentOf)
	self:UpdateDead()
end

function Skin:UpdatePower()
	if not self:Ready() then
		return
	end
	local unit, bar = self.unit, self.parts.power
	local powerType, token = UnitPowerType(unit)
	local value, max = UnitPower(unit, powerType), UnitPowerMax(unit, powerType)
	bar:SetMinMaxValues(0, max)
	bar:SetValue(value)
	token = Plain(token)
	local key = token and POWER_COLOR_KEYS[token]
	local color = key and Color(key)
	if not color and token and PowerBarColor and type(PowerBarColor[token]) == "table" and PowerBarColor[token].r then
		local blizzard = PowerBarColor[token]
		color = { blizzard.r, blizzard.g, blizzard.b, 1 }
	end
	color = color or Color("manaColor")
	bar:SetStatusBarColor(color[1], color[2], color[3])
	if Plain(max) == 0 then
		self.texts.power:SetText("")
	else
		SetValueText(self.texts.power, self:Get("PowerText"), value, max, self.powerPercentOf)
	end
end

-- Dead units: the gray-blue background on every box, the portrait faded.
function Skin:UpdateDead()
	local dead = Dead(self.unit)
	if dead == self.dead then
		return
	end
	self.dead = dead
	local parts = self.parts
	for _, box in ipairs({ parts.healthBox, parts.powerBox, parts.nameBox, parts.portraitBox }) do
		TintBox(box, dead)
	end
	self:PaintNameGradient()
	parts.portrait.model:SetAlpha(dead and DEAD_PORTRAIT_ALPHA or 1)
	parts.portrait.class:SetAlpha(dead and DEAD_PORTRAIT_ALPHA or 1)
end

function Skin:UpdateName()
	if not self:Ready() then
		return
	end
	local unit, texts = self.unit, self.texts
	if self:Get("NameTextShow") then
		local name = UnitName(unit)
		texts.name:SetText(name or "")
		local color = self:Get("NameClassColor") and ClassColor(unit) or Color("textColor")
		texts.name:SetTextColor(color[1], color[2], color[3])
	else
		texts.name:SetText("")
	end
	local text = texts.level
	if not self:Get("LevelShow") then
		text:SetText("")
		return
	end
	local level = UnitLevel(unit)
	local color = Color("textColor")
	if IsSecret(level) then
		if not pcall(text.SetFormattedText, text, "%s", level) then
			text:SetText("")
		end
	elseif type(level) == "number" and level <= 0 then
		text:SetText("??")
		color = { 1, 0.1, 0.1, 1 }
	else
		text:SetText(level or "")
		if type(level) == "number" then
			color = LevelColor(unit, level)
		end
	end
	text:SetTextColor(color[1], color[2], color[3])
end

function Skin:UpdatePortrait()
	if not self:Ready() then
		return
	end
	local portrait, unit = self.parts.portrait, self.unit
	local token = self:Get("PortraitClass") and ClassToken(unit)
	local coords = token and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token] or nil
	local useClass = coords ~= nil
	portrait.class:SetShown(useClass)
	portrait.model:SetShown(not useClass)
	if useClass then
		local left, right, top, bottom = unpack(coords)
		local w, h = (right - left) * CROP, (bottom - top) * CROP
		portrait.class:SetTexCoord(left + w, right - w, top + h, bottom - h)
	else
		portrait.model:SetUnit(unit)
		if portrait.model.SetPortraitZoom then
			portrait.model:SetPortraitZoom(1)
		end
		if portrait.model.SetCamDistanceScale then
			portrait.model:SetCamDistanceScale(1)
		end
		HoldStill(portrait.model)
	end
end

-- Cast bar ---------------------------------------------------------------------------------
-- From UnitCastingInfo / UnitChannelInfo. With plain times the bar fills by
-- itself (OnUpdate while casting); with secret times the client's duration
-- object drives it when this build has one, else the bar stays hidden.

function Skin:CastInfo()
	local unit = self.unit
	local name, _, texture, startMS, endMS = UnitCastingInfo(unit)
	local channel = false
	if not IsSecret(name) and name == nil and UnitChannelInfo then
		name, _, texture, startMS, endMS = UnitChannelInfo(unit)
		channel = true
	end
	if not IsSecret(name) and name == nil then
		return nil
	end
	return name, startMS, endMS, channel
end

function Skin:UpdateCast()
	if not self:Ready() then
		return
	end
	local cast = self.parts.cast
	local shown = self:Get("CastShow")
	local name, startMS, endMS, channel = nil, nil, nil, false
	if shown then
		name, startMS, endMS, channel = self:CastInfo()
	end
	cast.casting = false
	if IsSecret(name) or name ~= nil then
		if not IsSecret(startMS) and not IsSecret(endMS) and type(startMS) == "number" and type(endMS) == "number" then
			cast.startTime, cast.endTime, cast.channel = startMS / 1000, endMS / 1000, channel
			cast:SetMinMaxValues(0, math.max(0.001, cast.endTime - cast.startTime))
			cast.casting = true
			self.castMode = "plain"
		else
			cast.startTime = nil
			local getDuration = channel and UnitChannelDuration or UnitCastingDuration
			local ok = getDuration and cast.SetTimerDuration and pcall(function()
				cast:SetTimerDuration(getDuration(self.unit))
			end)
			cast.casting = ok and true or false
			self.castMode = ok and "secret, client timer" or "secret, not shown"
		end
	end
	if cast.casting then
		self.texts.cast:SetText(self:Get("CastText") and name or "")
		if cast.startTime then
			self:CastTick(cast)
		end
		cast:Show()
	elseif shown and self:Get("CastSeparate") and not self:Get("CastHideIdle") then
		-- Kept as an empty bar.
		cast:SetMinMaxValues(0, 1)
		cast:SetValue(0)
		self.texts.cast:SetText("")
		cast:Show()
	else
		cast:Hide()
	end
end

function Skin:CastTick(cast)
	if not (cast.casting and cast.startTime) then
		return
	end
	local now = GetTime()
	if now >= cast.endTime then
		self:UpdateCast()
		return
	end
	local elapsed = now - cast.startTime
	cast:SetValue(cast.channel and (cast.endTime - cast.startTime - elapsed) or elapsed)
end

-- Combo points -----------------------------------------------------------------------------

-- Rogues, and druids in cat form (energy).
function Skin:ComboWanted()
	if not (self.spec.combo and self:Get("ComboShow")) then
		return false
	end
	local _, token = UnitClass("player")
	token = Plain(token)
	if token == "ROGUE" then
		return true
	end
	if token == "DRUID" then
		local _, power = UnitPowerType("player")
		return Plain(power) == "ENERGY"
	end
	return false
end

function Skin:ComboMax()
	local max = UnitPowerMax("player", COMBO_POWER)
	max = Plain(max)
	if type(max) ~= "number" or max < 1 or max > 10 then
		return 5
	end
	return max
end

function Skin:UpdateCombo()
	if not (self:Ready() and self.spec.combo) then
		return
	end
	local combo = self.parts.combo
	local wanted = self:ComboWanted()
	if wanted ~= (self.comboShown or false) or (wanted and self:ComboMax() ~= self.comboCount) then
		-- Shown, hidden or a new number of points: the stack below changes.
		self:Layout()
		return
	end
	if not wanted then
		return
	end
	local count = UnitPower("player", COMBO_POWER)
	if (IsSecret(count) or count == nil) and GetComboPoints then
		count = GetComboPoints("player", "target")
	end
	if IsSecret(count) or type(count) ~= "number" then
		-- Kept from addons on this build: not shown.
		self.comboMode = "secret, not shown"
		combo:SetAlpha(0)
		return
	end
	self.comboMode = "plain"
	combo:SetAlpha(1)
	local color = Color("comboColor")
	for i = 1, self.comboCount do
		local dot = combo.points[i].dot
		if i <= count then
			dot:SetColorTexture(color[1], color[2], color[3], 1)
		else
			dot:SetColorTexture(unpack(COMBO_EMPTY))
		end
	end
end

-- Buffs and debuffs --------------------------------------------------------------------------
-- Blizzard's own buttons, moved after Blizzard places them: a grid on our
-- anchor, as wide as the health bar, growing away from the bar it is
-- attached to.

local IsDebuffButton

local function LooksLikeAura(frame)
	if type(frame) ~= "table" or Forbidden(frame) then
		return false
	end
	local ok, looks = pcall(function()
		return (frame.Icon or frame.icon) ~= nil and (frame.Cooldown or frame.cooldown) ~= nil
	end)
	return ok and looks or false
end

IsDebuffButton = function(button)
	local name = DebugName(button)
	if Mentions(name, "debuff") then
		return true
	end
	if Mentions(name, "buff") then
		return false
	end
	return (button.Border or button.DebuffBorder) ~= nil
end

-- Fields of Blizzard's frame that hand out frames (frame pools), by key.
function Skin:FramePools()
	local list = {}
	local frame = self:Blizzard()
	for key, value in pairs(frame) do
		if type(key) == "string" and type(value) == "table" and type(value.EnumerateActive) == "function" then
			list[#list + 1] = { key = key, pool = value }
		end
	end
	return list
end

-- Our own frames and Blizzard's pieces that hold no auras.
function Skin:NotAuraHolders()
	local skip = {}
	for _, skin in ipairs(skins) do
		skip[skin.holder or false] = true
		skip[skin.root or false] = true
		if skin ~= self then
			skip[skin:Blizzard() or false] = true
		end
	end
	local frame = self:Blizzard()
	skip[frame.spellbar or false] = true
	skip[frame.Selection or false] = true
	skip[frame.totFrame or false] = true
	return skip
end

function Skin:ScanAuras(owner, buffs, debuffs, depth, skip)
	skip = skip or self:NotAuraHolders()
	if depth == 0 then
		self.forbiddenCount = 0
	end
	for _, child in ipairs({ owner:GetChildren() }) do
		if Forbidden(child) then
			self.forbiddenCount = (self.forbiddenCount or 0) + 1
		elseif not skip[child] then
			if LooksLikeAura(child) then
				if child:IsShown() then
					local list = IsDebuffButton(child) and debuffs or buffs
					list[#list + 1] = child
				end
			elseif depth < 4 then
				self:ScanAuras(child, buffs, debuffs, depth + 1, skip)
			end
		end
	end
end

-- For /ptf probe: what Blizzard's frame holds, to find where this build
-- keeps its buff buttons.
function Skin:AuraReport()
	local frame = self:Blizzard()
	local rows = {}
	local pools = {}
	for _, entry in ipairs(self:FramePools()) do
		pools[#pools + 1] = entry.key
	end
	rows[#rows + 1] = "Pools on the frame: " .. (#pools > 0 and table.concat(pools, ", ") or "none")
	local fields = {}
	for key, value in pairs(frame) do
		if type(key) == "string" and (Mentions(key, "aura") or Mentions(key, "buff")) then
			fields[#fields + 1] = key .. " (" .. type(value) .. ")"
		end
	end
	table.sort(fields)
	rows[#rows + 1] = "Aura fields on the frame: " .. (#fields > 0 and table.concat(fields, ", ") or "none")
	local skip = self:NotAuraHolders()
	local count = 0
	local function Walk(owner, depth, indent)
		for _, child in ipairs({ owner:GetChildren() }) do
			if count >= 40 then
				return
			end
			if Forbidden(child) then
				count = count + 1
				rows[#rows + 1] = indent .. "(a frame forbidden to addons)"
			elseif not skip[child] then
				count = count + 1
				local keys = {}
				for _, key in ipairs({ "Icon", "icon", "Cooldown", "cooldown", "Border", "Count", "count" }) do
					if child[key] ~= nil then
						keys[#keys + 1] = key
					end
				end
				local width, height = child:GetWidth(), child:GetHeight()
				local alpha = child.GetEffectiveAlpha and child:GetEffectiveAlpha()
				rows[#rows + 1] = indent .. tostring(DebugName(child)) .. " [" .. tostring(child:GetObjectType()) .. "] "
					.. (IsSecret(width) and "?" or format("%.0f", width or 0)) .. "x"
					.. (IsSecret(height) and "?" or format("%.0f", height or 0)) .. ", shown " .. tostring(child:IsShown())
					.. ", opacity " .. (IsSecret(alpha) and "secret" or tostring(alpha))
					.. (#keys > 0 and (", has " .. table.concat(keys, " ")) or "")
				if depth < 2 then
					Walk(child, depth + 1, indent .. "  ")
				end
			end
		end
	end
	rows[#rows + 1] = "Children of " .. tostring(DebugName(frame)) .. " (not ours):"
	local ok, problem = pcall(Walk, frame, 0, "  ")
	if not ok then
		rows[#rows + 1] = "  (stopped: " .. tostring(problem) .. ")"
	end
	rows[#rows + 1] = "Frames forbidden to addons seen while looking for buffs: " .. tostring(self.forbiddenCount or 0)
	return rows
end

-- Blizzard's buff and debuff buttons in their order.
function Skin:AuraButtons()
	local frame = self:Blizzard()
	local buffs, debuffs = {}, {}
	local pools = frame.auraPools
	if type(pools) == "table" and pools.EnumerateActiveByTemplate then
		pcall(function()
			for button in pools:EnumerateActiveByTemplate("TargetBuffFrameTemplate") do
				buffs[#buffs + 1] = button
			end
			for button in pools:EnumerateActiveByTemplate("TargetDebuffFrameTemplate") do
				debuffs[#debuffs + 1] = button
			end
		end)
		self.auraSource = "aura pools"
	end
	-- Pools under other template names: every active button, debuffs told
	-- apart by name or by the debuff border Blizzard gives them.
	if #buffs == 0 and #debuffs == 0 and type(pools) == "table" and pools.EnumerateActive then
		pcall(function()
			for button in pools:EnumerateActive() do
				local name = DebugName(button)
				if Mentions(name, "debuff") or (button.Border and not Mentions(name, "buff")) then
					debuffs[#debuffs + 1] = button
				else
					buffs[#buffs + 1] = button
				end
			end
		end)
		self.auraSource = "aura pools (all)"
	end
	-- Any other pool Blizzard keeps on the frame, whatever its name.
	if #buffs == 0 and #debuffs == 0 then
		for _, entry in ipairs(self:FramePools()) do
			pcall(function()
				for button in entry.pool:EnumerateActive() do
					if type(button) == "table" and not Forbidden(button) and button:IsShown() then
						local isDebuff = Mentions(entry.key, "debuff") or (not Mentions(entry.key, "buff")
							and IsDebuffButton(button))
						local list = isDebuff and debuffs or buffs
						list[#list + 1] = button
					end
				end
			end)
		end
		if #buffs + #debuffs > 0 then
			self.auraSource = "pools on the frame"
		end
	end
	-- Buttons that look like auras (an icon and a cooldown) anywhere in the
	-- frame, outside our own frames and the target of target.
	if #buffs == 0 and #debuffs == 0 then
		self:ScanAuras(frame, buffs, debuffs, 0)
		if #buffs + #debuffs > 0 then
			self.auraSource = "found in the frame"
		end
	end
	if #buffs == 0 and #debuffs == 0 then
		local name = frame:GetName()
		for _, pair in ipairs({ { "Buff", buffs }, { "Debuff", debuffs } }) do
			for i = 1, 40 do
				local button = name and _G[name .. pair[1] .. i]
				if not button then
					break
				end
				if button:IsShown() then
					pair[2][#pair[2] + 1] = button
				end
			end
		end
		self.auraSource = self.auraSource or "named buttons"
	end
	-- Blizzard's order: by aura index, else where Blizzard put them (rows
	-- from the top, left to right).
	local function Order(list)
		local keys = {}
		for _, button in ipairs(list) do
			local index = Plain(button.auraIndex) or Plain(button.GetID and button:GetID())
			local top, left = button:GetTop(), button:GetLeft()
			keys[button] = { type(index) == "number" and index or 1000, -(Plain(top) or 0), Plain(left) or 0 }
		end
		table.sort(list, function(a, b)
			local ka, kb = keys[a], keys[b]
			for i = 1, 3 do
				if ka[i] ~= kb[i] then
					return ka[i] < kb[i]
				end
			end
			return false
		end)
	end
	Order(buffs)
	Order(debuffs)
	return buffs, debuffs
end

function Skin:PlaceAuras(list, kind)
	local show = self:Get(kind .. "Show")
	local anchor = self.parts[strlower(kind) .. "Anchor"]
	local size, spacing = self:Get(kind .. "Size"), self:Get("AuraSpacing")
	local point = self:Get(kind .. "Point") or "TOP"
	local up = (OUTSIDE[point] or OUTSIDE.TOP)[4] > 0
	local perRow = math.max(1, math.floor((anchor:GetWidth() + spacing) / (size + spacing)))
	local inCombat = InCombatLockdown()
	for i, button in ipairs(list) do
		if not show then
			button:SetAlpha(0)
			if not inCombat and button.EnableMouse then
				button:EnableMouse(false)
			end
		else
			button:SetAlpha(1)
			if not inCombat and button.EnableMouse then
				button:EnableMouse(true)
			end
			local row, column = math.floor((i - 1) / perRow), (i - 1) % perRow
			local inRow = math.min(perRow, #list - row * perRow)
			-- Rows centered, or from the side the point names.
			local rowWidth = inRow * size + (inRow - 1) * spacing
			local x
			if point:find("LEFT") then
				x = 0
			elseif point:find("RIGHT") then
				x = anchor:GetWidth() - rowWidth
			else
				x = (anchor:GetWidth() - rowWidth) / 2
			end
			x = x + column * (size + spacing)
			local y = row * (size + spacing)
			-- Scaled, so the button's own art (borders, count) keeps its shape;
			-- offsets are in the button's scaled units.
			local base = button:GetWidth()
			local scale = (type(base) == "number" and base > 0) and size / base or 1
			button:SetScale(scale)
			button:ClearAllPoints()
			if up then
				button:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", x / scale, y / scale)
			else
				button:SetPoint("TOPLEFT", anchor, "TOPLEFT", x / scale, -y / scale)
			end
		end
	end
end

-- Whether frame is one of the buttons or holds one.
local function HoldsAny(frame, buttons)
	for _, button in ipairs(buttons) do
		local walk = button
		while walk do
			if walk == frame then
				return true
			end
			walk = walk:GetParent()
		end
	end
	return false
end

-- Blizzard's buttons live inside its frame; if one sits in a piece that was
-- made invisible, that piece is made visible again and its other pieces
-- are made invisible instead, so the buttons show and the art does not.
function Skin:Uncover(buttons)
	local frame = self:Blizzard()
	for _, button in ipairs(buttons) do
		local chain, walk = {}, button:GetParent()
		while walk and walk ~= frame and walk ~= UIParent do
			chain[#chain + 1] = walk
			walk = walk:GetParent()
		end
		for i = #chain, 1, -1 do
			local piece = chain[i]
			if invisible[piece] then
				invisible[piece] = nil
				uncovered[piece] = true
				piece:SetAlpha(1)
				self.uncovered = (self.uncovered or 0) + 1
				for _, region in ipairs({ piece:GetRegions() }) do
					MakeInvisible(region)
				end
				for _, child in ipairs({ piece:GetChildren() }) do
					if not HoldsAny(child, buttons) and child ~= self.holder then
						MakeInvisible(child)
					end
				end
			end
		end
		-- A button made invisible itself (it was one of the pieces).
		if invisible[button] then
			invisible[button] = nil
		end
	end
	-- For /ptf probe: where the first button lives and how visible it is.
	local first = buttons[1]
	if first then
		local names, walk = {}, first:GetParent()
		while walk and #names < 6 do
			names[#names + 1] = tostring(DebugName(walk))
			walk = walk:GetParent()
		end
		local alpha = first.GetEffectiveAlpha and first:GetEffectiveAlpha()
		self.auraWhere = table.concat(names, " < ") .. ", opacity "
			.. (IsSecret(alpha) and "secret" or tostring(alpha)) .. ", shown " .. tostring(first:IsVisible())
	end
end

function Skin:ReanchorAuras()
	if not (self:Ready() and self.spec.auras) then
		return
	end
	local ok, problem = pcall(self.MoveAuras, self)
	self.auraError = not ok and tostring(problem) or nil
end

function Skin:MoveAuras()
	local buffs, debuffs = self:AuraButtons()
	self.auraCounts = #buffs .. " buffs, " .. #debuffs .. " debuffs"
	local all = {}
	for _, list in ipairs({ buffs, debuffs }) do
		for _, button in ipairs(list) do
			all[#all + 1] = button
		end
	end
	self:Uncover(all)
	self:PlaceAuras(buffs, "Buff")
	self:PlaceAuras(debuffs, "Debuff")
end

-- Refresh ----------------------------------------------------------------------------------

-- Everything that depends on the unit: a new target, focus, target's target
-- or target's pet.
function Skin:Refresh()
	if not self:Ready() then
		return
	end
	self.unitExists = Plain(UnitExists(self.unit)) ~= false
	if not self.unitExists then
		return
	end
	self:UpdatePortrait()
	self:ApplyHealthColor()
	self:UpdateName()
	self:UpdateHealth()
	self:UpdatePower()
	self:UpdateCast()
	self:UpdateCombo()
	self:ReanchorAuras()
	if not self.clickerPlaced then
		self:PlaceSecure()
	end
end

-- Hooks ------------------------------------------------------------------------------------

function Skin:Hook()
	if self.hooked or not self.spec.auras then
		self.hooked = true
		return
	end
	self.hooked = true
	local skin, frame = self, self:Blizzard()
	local function Reanchor()
		if skin.active then
			skin:ReanchorAuras()
		end
	end
	-- After Blizzard places its buttons.
	for _, method in ipairs({ "UpdateAuras", "UpdateAuraPositions" }) do
		if type(frame[method]) == "function" then
			hooksecurefunc(frame, method, Reanchor)
		end
	end
	for _, name in ipairs({ "TargetFrame_UpdateAuras", "TargetFrame_UpdateAuraPositions" }) do
		if type(_G[name]) == "function" then
			hooksecurefunc(name, function(owner)
				if owner == frame then
					Reanchor()
				end
			end)
		end
	end
end

-- Moved frames --------------------------------------------------------------------------

-- Where a point of a frame is, as offsets from the screen's center.
local function ScreenOffset(frame, point)
	if not (frame and frame.GetCenter) then
		return nil
	end
	local x, y = frame:GetCenter()
	if point == "LEFT" then
		x = frame:GetLeft()
	end
	if not (x and y) or IsSecret(x) or IsSecret(y) then
		return nil
	end
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * scale - UIParent:GetWidth() / 2, y * scale - UIParent:GetHeight() / 2
end

-- The first time (or after "Put Back"): the target of target where
-- Blizzard's was, the target's pet just left of the target frame.
function Skin:PlaceFirst()
	local skin = self
	kit.events.Defer(self.prefix .. "PlaceFirst", function()
		local x, y
		if skin.spec.pet then
			x, y = ScreenOffset(TargetFrame, "LEFT")
			if x then
				x = x - skin:Get("HealthWidth") / 2 - 60
			end
		else
			x, y = ScreenOffset(skin:Blizzard())
		end
		-- Placed goes first, so the changes below do not come back here.
		kit:Set(skin.prefix .. "Placed", true)
		kit:Set(skin.prefix .. "Point", "CENTER")
		kit:Set(skin.prefix .. "OffsetX", math.floor((x or 0) + 0.5))
		kit:Set(skin.prefix .. "OffsetY", math.floor((y or 0) + 0.5))
	end)
end

-- Its own box in Blizzard's Edit Mode (ClaiibuAPI 1.4.0 and newer).
function Skin:AddMover()
	if self.mover or not kit.AddEditMode then
		return
	end
	local skin = self
	self.mover = kit:AddEditMode({
		frame = function() return skin.root end,
		label = self.spec.name,
		pointKey = self.prefix .. "Point",
		xKey = self.prefix .. "OffsetX",
		yKey = self.prefix .. "OffsetY",
		regions = function() return { skin.root } end,
	})
end

-- Apply and probe ------------------------------------------------------------------------

function Skin:Apply(current)
	settings = current
	if not self:Blizzard() then
		self.missing = true
		return
	end
	self.missing = false
	if self:Get("Enabled") then
		self.active = true
		self:Hook()
		if self.spec.movable and not self:Get("Placed") then
			self:PlaceFirst()
		end
		self:Layout()
	elseif self.active then
		self.active = false
		self:StopTicker()
		local skin = self
		kit.events.AfterCombat(self.prefix .. "Off", function()
			if not skin.active and skin.holder then
				skin.holder:Hide() -- also hides our click button
			end
		end)
		kit:Print(self.spec.name .. " is off. Reload the interface (/reload) to bring back Blizzard's frame.")
	end
end

local function SecretWord(value)
	return IsSecret(value) and "secret" or "plain"
end

function Skin:Probe()
	local frame, unit = self:Blizzard(), self.unit
	local rows = {
		"Blizzard frame: " .. ns.Has(frame) .. " (" .. tostring(frame and DebugName(frame)) .. ")"
			.. (self.spec.pet and ", unit watch: " .. ns.Has(RegisterUnitWatch) or "")
			.. ", pieces made invisible: " .. tostring(self.hiddenCount or 0),
		"Active: " .. (self.active and "yes" or "no") .. (self.missing and " (Blizzard's frame is missing)" or "")
			.. ", shown: " .. tostring(self.holder and self.holder:IsVisible() or false),
	}
	if Plain(UnitExists(unit)) then
		rows[#rows + 1] = "Unit " .. unit .. ": health " .. SecretWord(UnitHealth(unit)) .. ", name "
			.. SecretWord(UnitName(unit)) .. ", reaction " .. SecretWord(UnitReaction and UnitReaction(unit, "player"))
			.. ", level " .. SecretWord(UnitLevel(unit)) .. ", dead " .. SecretWord(UnitIsDeadOrGhost(unit))
	else
		rows[#rows + 1] = "Unit " .. unit .. ": none (pick one to see which of its values are secret)"
	end
	rows[#rows + 1] = "Cast bar: " .. tostring(self.castMode or "no cast seen") .. ", UnitCastingDuration: "
		.. ns.Has(UnitCastingDuration) .. ", SetTimerDuration: "
		.. ns.Has(self.parts.cast and self.parts.cast.SetTimerDuration or nil)
	if self.spec.combo then
		rows[#rows + 1] = "Combo points: " .. tostring(self.comboMode or "not shown") .. ", wanted: "
			.. tostring(self.holder and self:ComboWanted() or false)
	end
	if self.spec.auras then
		rows[#rows + 1] = "Auras: " .. tostring(self.auraCounts or "none seen") .. " from "
			.. tostring(self.auraSource or "-") .. ", UpdateAuras hook: " .. ns.Has(frame and frame.UpdateAuras)
			.. ", auraPools: " .. ns.Has(frame and frame.auraPools)
		if self.auraError then
			rows[#rows + 1] = "Moving auras failed: " .. self.auraError
		end
		rows[#rows + 1] = "First aura button in: " .. tostring(self.auraWhere or "-")
			.. ", pieces made visible again for them: " .. tostring(self.uncovered or 0)
		if frame then
			for _, row in ipairs(self:AuraReport()) do
				rows[#rows + 1] = row
			end
		end
	end
	if self.root then
		rows[#rows + 1] = "Edit Mode box: " .. (self.mover and "yes" or "no (needs ClaiibuAPI 1.4.0)")
			.. ", position " .. tostring(self:Get("Point")) .. " " .. tostring(self:Get("OffsetX")) .. ", "
			.. tostring(self:Get("OffsetY"))
		if self.watcher then
			rows[#rows + 1] = "Unit watch frame shown: " .. tostring(self.watcher:IsShown()) .. ", targetpet exists: "
				.. tostring(Plain(UnitExists(self.unit)))
		end
	end
	rows[#rows + 1] = "Click button: " .. (self.clicker and "yes" or "no (made out of combat, once the frame shows)")
		.. (self.spec.poll and (", refresh ticker: " .. (self.ticker and "running" or "stopped")) or "")
	return rows
end

-- spec: name, prefix, unit, frame (function returning Blizzard's frame),
-- small (the target of target: its own pieces are made invisible), pet (our
-- own frame by a unit watch), ownToT (the frame has a target of target of
-- its own to make invisible), auras, combo, poll (no events for the unit),
-- inherit (the Target page's settings until a section is overridden),
-- movable (its own place on the screen, with an Edit Mode box).
function ns.NewUnitSkin(spec)
	local skin = setmetatable({
		spec = spec,
		prefix = spec.prefix,
		unit = spec.unit,
		active = false,
		parts = {},
		texts = {},
		stack = {},
		gap = GAP,
		dead = false,
		unitExists = false,
		healthPercentOf = HealthPercentOf(spec.unit),
		powerPercentOf = PowerPercentOf(spec.unit),
	}, Skin)
	skins[#skins + 1] = skin
	ns.RegisterFeature(spec.name, function(current) skin:Apply(current) end, function() return skin:Probe() end)
	return skin
end

-- Events ---------------------------------------------------------------------------------
-- One handler per event, dispatched to the frames showing that unit.

ns.missingEvents = {}

local function On(event, handler)
	local ok, known = pcall(kit.events.On, event, handler)
	if not ok or known == false then
		ns.missingEvents[#ns.missingEvents + 1] = event
	end
end

local UNIT_EVENTS = {
	UNIT_HEALTH = "UpdateHealth",
	UNIT_MAXHEALTH = "UpdateHealth",
	UNIT_POWER_UPDATE = "UpdatePower",
	UNIT_POWER_FREQUENT = "UpdatePower",
	UNIT_MAXPOWER = "UpdatePower",
	UNIT_DISPLAYPOWER = "UpdatePower",
	UNIT_NAME_UPDATE = "UpdateName",
	UNIT_LEVEL = "UpdateName",
	UNIT_FACTION = "ApplyHealthColor",
	UNIT_FLAGS = "UpdateHealth",
	UNIT_CONNECTION = "Refresh",
	UNIT_PORTRAIT_UPDATE = "UpdatePortrait",
	UNIT_MODEL_CHANGED = "UpdatePortrait",
	UNIT_SPELLCAST_START = "UpdateCast",
	UNIT_SPELLCAST_STOP = "UpdateCast",
	UNIT_SPELLCAST_FAILED = "UpdateCast",
	UNIT_SPELLCAST_INTERRUPTED = "UpdateCast",
	UNIT_SPELLCAST_DELAYED = "UpdateCast",
	UNIT_SPELLCAST_CHANNEL_START = "UpdateCast",
	UNIT_SPELLCAST_CHANNEL_STOP = "UpdateCast",
	UNIT_SPELLCAST_CHANNEL_UPDATE = "UpdateCast",
}

for event, method in pairs(UNIT_EVENTS) do
	On(event, function(unit)
		for _, skin in ipairs(skins) do
			if skin.active and skin.unit == unit then
				skin[method](skin)
			end
		end
	end)
end

-- Blizzard places its buttons on UNIT_AURA too; ours move them the next
-- frame, after it.
On("UNIT_AURA", function(unit)
	for _, skin in ipairs(skins) do
		if skin.active and skin.spec.auras and skin.unit == unit then
			kit.events.Defer(skin.prefix .. "Auras", function() skin:ReanchorAuras() end)
		end
	end
end)

local function RefreshUnits(units)
	for _, skin in ipairs(skins) do
		if skin.active and units[skin.unit] then
			skin:Refresh()
		end
	end
end

On("PLAYER_TARGET_CHANGED", function()
	RefreshUnits({ target = true, targettarget = true, targetpet = true })
end)
On("PLAYER_FOCUS_CHANGED", function()
	RefreshUnits({ focus = true })
end)
On("UNIT_TARGET", function(unit)
	if unit == "target" then
		RefreshUnits({ targettarget = true })
	end
end)
On("UNIT_PET", function(unit)
	if unit == "target" then
		RefreshUnits({ targetpet = true })
	end
end)

-- Your combo points.
local function ComboChanged()
	for _, skin in ipairs(skins) do
		if skin.active and skin.spec.combo then
			skin:UpdateCombo()
		end
	end
end
On("UNIT_POWER_UPDATE", function(unit)
	if unit == "player" then
		ComboChanged()
	end
end)
On("UNIT_MAXPOWER", function(unit)
	if unit == "player" then
		ComboChanged()
	end
end)
On("UPDATE_SHAPESHIFT_FORM", ComboChanged)

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED" }) do
	On(event, function()
		for _, skin in ipairs(skins) do
			if skin.active then
				skin:Layout()
			end
		end
	end)
end
