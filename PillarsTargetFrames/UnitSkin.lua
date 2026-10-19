local addonName, ns = ...

if not ns.kit then
	return
end

-- The reskin shared by the target, target of target and focus frames, laid
-- out like Blizzard's target frame:
--
--   [ name bar      ] (  )
--   [ health bar    ] (portrait)
--   [ resource bar  ] (  )
--
-- with the level in a circle on the portrait's outer corner and the raid
-- target icon on its top. Blizzard's own health and resource bars are kept
-- and fed by the client, secret values included; they are re-anchored,
-- resized and re-textured, and Blizzard's art around them (frame texture,
-- portrait, name, level, reputation color, contextual icons) is faded out.
-- Our frames are children of Blizzard's, so they show and hide with it and
-- follow Edit Mode. Blizzard's frame itself is never moved, resized, shown,
-- hidden or given attributes; its buffs, debuffs, cast bar and threat number
-- are left alone. Clicks go to a secure button of our own over the layout.
--
-- Unit health, names, reactions and levels can be secret values on Forever:
-- they are never compared or branched on without ns.Plain, and go straight
-- into status bars, SetText, SetFormattedText and SetVertexColor.

local kit = ns.kit
local settings -- kit.settings, set by Apply

local GAP = 3 -- between the boxes, on top of their borders
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local CLASS_ICONS = "Interface\\WorldStateFrame\\Icons-Classes"
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local CROP = 0.06 -- class icons, cropped so the art fills the box
local GRAY = { 0.5, 0.5, 0.5, 1 }
local GREEN = { 0, 0.8, 0, 1 }
local GOLD = { 1, 0.82, 0, 1 }
local ELITE_TINT = { 1, 0.82, 0, 1 }
local RARE_TINT = { 0.78, 0.8, 0.86, 1 }
local LEVEL_FILL = { 0.06, 0.06, 0.06, 0.95 }

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

-- Blizzard's incoming heal and absorb display on the health bar. It is laid
-- out for Blizzard's bar size, so it is hidden while the reskin is on; we
-- draw our own incoming heals.
local HEAL_PREDICTION_KEYS = {
	"myHealPredictionBar", "otherHealPredictionBar", "totalAbsorbBar", "totalAbsorbBarOverlay",
	"overAbsorbGlow", "overHealAbsorbGlow", "healAbsorbBar", "healAbsorbBarLeftShadow",
	"healAbsorbBarRightShadow", "MyHealPredictionBar", "OtherHealPredictionBar", "TotalAbsorbBar",
	"TotalAbsorbBarOverlay", "OverAbsorbGlow", "OverHealAbsorbGlow", "HealAbsorbBar", "HealPredictionBar",
	"myHealAbsorb", "myHealAbsorbLeftShadow", "myHealAbsorbRightShadow",
}

-- Pieces of the old-style frames, by global name: <frame name><suffix>.
local OLD_ART = { "TextureFrame", "NameBackground", "Background", "Portrait", "Flash" }

local Plain, IsSecret = ns.Plain, ns.IsSecret

local function Mentions(text, word)
	return type(text) == "string" and strlower(text):find(word, 1, true) ~= nil
end

local function DebugName(region)
	local ok, name = pcall(function()
		return region.GetDebugName and region:GetDebugName() or region.GetName and region:GetName()
	end)
	return ok and name or nil
end

local function IsMask(region)
	return region.GetObjectType and region:GetObjectType() == "MaskTexture"
end

-- Shared look ---------------------------------------------------------------------------

local function Preset(list, choice)
	for _, preset in ipairs(list) do
		if preset.key == choice and preset.color then
			return preset.color
		end
	end
	return nil
end

local function BarColor(key)
	return Preset(ns.BAR_COLORS, settings[key])
end

-- A tint setting's color, or the border's own color for "default".
local function Tint(key)
	return Preset(ns.TINTS, settings[key]) or kit:GetMedia("border", "border").color
end

-- A background's color: a Background Color setting ("default" keeps the
-- background's own color) at a Background Opacity setting (0-100).
local function BackgroundColor(prefix)
	local color = Preset(ns.BACKGROUND_COLORS, settings[prefix .. "BgColor"])
		or kit:GetMedia("background", prefix .. "Background").color
	return color[1], color[2], color[3], (color[4] or 1) * settings[prefix .. "BgOpacity"] / 100
end

local function ColorSetting(key)
	if kit.GetColor then
		return kit:GetColor(key)
	end
	local color = settings[key]
	return color.r, color.g, color.b, color.a or 1
end

local function NewBackdropFrame(parent)
	local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	frame:EnableMouse(false)
	return frame
end

-- A background filling target edge to edge, under it.
local function PlaceBackground(back, target, prefix)
	local media = kit:GetMedia("background", prefix .. "Background")
	if not media.file then
		back:Hide()
		return
	end
	back:SetBackdrop({ bgFile = media.file, tile = media.tile, tileSize = media.tileSize })
	back:SetBackdropColor(BackgroundColor(prefix))
	back:ClearAllPoints()
	back:SetAllPoints(target)
	back:SetFrameStrata(target:GetFrameStrata())
	back:SetFrameLevel(math.max(0, target:GetFrameLevel() - 1))
	back:Show()
end

-- How far a border sits outside its box. A solid border goes all the way
-- out, so it never covers the box; a textured border's art has a clear strip
-- on its inner side, so it goes out by 30% of its size. Border Position moves
-- it further in (positive) or out (negative).
local function Outset(edge)
	local base = settings.border == "solid" and edge or math.floor(edge * 0.3 + 0.5)
	return base - settings.borderInset
end

-- The shared border around target, outside it, in color (the Border Tint
-- when nil).
local function PlaceBorder(border, target, color)
	local media = kit:GetMedia("border", "border")
	if not media.file then
		border:Hide()
		return
	end
	local edge = settings.borderSize
	border:SetBackdrop({ edgeFile = media.file, edgeSize = edge })
	border:SetBackdropBorderColor(unpack(color or Tint("borderTint")))
	local out = Outset(edge)
	border:ClearAllPoints()
	border:SetPoint("TOPLEFT", target, "TOPLEFT", -out, out)
	border:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", out, -out)
	border:SetFrameStrata(target:GetFrameStrata())
	border:SetFrameLevel(target:GetFrameLevel() + 3)
	border:Show()
end

-- The space between two boxes: both borders plus GAP.
local function Gap()
	local media = kit:GetMedia("border", "border")
	return GAP + (media.file and 2 * math.max(0, Outset(settings.borderSize)) or 0)
end

-- Text inside a box at an anchor, a few pixels in from the sides.
local function PlaceText(fontString, anchorKey, relativeTo)
	local point = settings[anchorKey] or "CENTER"
	local x = point:find("LEFT") and 4 or (point:find("RIGHT") and -4 or 0)
	kit:ApplyAnchor(fontString, anchorKey, x, 0, relativeTo)
end

-- A texture cut to a circle, or back to its rectangle.
local function SetRound(texture, mask, on)
	if not mask or texture.roundMask == on then
		return
	end
	if on then
		texture:AddMaskTexture(mask)
	else
		texture:RemoveMaskTexture(mask)
	end
	texture.roundMask = on
end

local function NewCircleMask(parent, texture)
	if not parent.CreateMaskTexture then
		return nil
	end
	local mask = parent:CreateMaskTexture()
	mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(texture)
	return mask
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

-- Unit facts, nil when the client keeps them secret --------------------------------------

local function ClassToken(unit)
	local isPlayer = Plain(UnitIsPlayer(unit))
	if not isPlayer then
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

-- Blizzard's health bar reaction color: hostile red, neutral yellow,
-- friendly green.
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

-- Blizzard's name bar color: UnitSelectionColor (red, yellow, green, blue
-- for other players). Nil when secret.
local function SelectionColor(unit)
	if not UnitSelectionColor then
		return nil
	end
	local r, g, b = UnitSelectionColor(unit)
	if IsSecret(r) or IsSecret(g) or IsSecret(b) or type(r) ~= "number" then
		return nil
	end
	return { r, g, b, 1 }
end

local function Tapped(unit)
	return UnitIsTapDenied and Plain(UnitIsTapDenied(unit)) and true or false
end

-- "dead", "ghost", "offline" or nil.
local function State(unit)
	if Plain(UnitIsConnected(unit)) == false and Plain(UnitIsPlayer(unit)) then
		return "offline"
	end
	if Plain(UnitIsGhost(unit)) then
		return "ghost"
	end
	if Plain(UnitIsDead(unit)) then
		return "dead"
	end
	return nil
end

local STATE_TEXT = {
	dead = DEAD or "Dead",
	ghost = "Ghost",
	offline = PLAYER_OFFLINE or "Offline",
}

local function Classification(unit)
	return UnitClassification and Plain(UnitClassification(unit)) or nil
end

-- The skin ---------------------------------------------------------------------------------

local Skin = {}
Skin.__index = Skin
local skins = {}
ns.skins = skins

function Skin:Get(key)
	return settings[self.prefix .. key]
end

function Skin:Frame()
	return self.spec.frame()
end

-- On, and our frames exist (the first layout may wait for combat to end).
function Skin:Ready()
	return self.active and self.holder ~= nil
end

-- A part of Blizzard's frame by global name: <frame name><suffix>.
function Skin:Named(suffix)
	local frame = self:Frame()
	local name = frame and frame.GetName and frame:GetName()
	return name and _G[name .. suffix] or nil
end

local function IsBar(bar)
	return type(bar) == "table" and bar.SetStatusBarTexture ~= nil and bar or nil
end

function Skin:Main()
	local frame = self:Frame()
	local content = frame and frame.TargetFrameContent
	local main = type(content) == "table" and content.TargetFrameContentMain
	return type(main) == "table" and main or nil
end

function Skin:Contextual()
	local frame = self:Frame()
	local content = frame and frame.TargetFrameContent
	local contextual = type(content) == "table" and content.TargetFrameContentContextual
	return type(contextual) == "table" and contextual or nil
end

function Skin:HealthBar()
	local frame = self:Frame()
	if not frame then
		return nil
	end
	local main = self:Main()
	local container = main and main.HealthBarsContainer
	return IsBar(frame.healthbar) or IsBar(frame.HealthBar)
		or IsBar(type(container) == "table" and container.HealthBar) or IsBar(self:Named("HealthBar"))
end

function Skin:PowerBar()
	local frame = self:Frame()
	if not frame then
		return nil
	end
	local main = self:Main()
	return IsBar(frame.manabar) or IsBar(frame.ManaBar) or IsBar(main and main.ManaBar) or IsBar(self:Named("ManaBar"))
end

-- Blizzard art ---------------------------------------------------------------------------

-- Blizzard's art and text around the bars, faded out while the reskin is on.
-- Only named containers are walked, so Blizzard's buffs, debuffs, cast bar
-- and threat number (children of the frame itself) are never touched.
function Skin:ArtToFade()
	local list, seen = {}, {}
	local frame = self:Frame()
	local function Add(region)
		if type(region) == "table" and region.SetAlpha and not seen[region] and not IsMask(region)
			and region ~= self.holder then
			seen[region] = true
			list[#list + 1] = region
		end
	end
	local function AddRegions(owner)
		if type(owner) == "table" and owner.GetRegions then
			for _, region in ipairs({ owner:GetRegions() }) do
				Add(region)
			end
		end
	end
	if not frame then
		return list
	end
	-- Modern frame: frame texture, portrait, flash and boss dragon.
	Add(frame.TargetFrameContainer)
	-- Name, level and reputation color.
	AddRegions(self:Main())
	-- Leader, PvP, quest, high level skull, raid target icon and the rest;
	-- the threat number stays.
	local contextual = self:Contextual()
	if contextual then
		AddRegions(contextual)
		for _, child in ipairs({ contextual:GetChildren() }) do
			if not Mentions(DebugName(child), "threat") then
				Add(child)
			end
		end
	end
	-- Dead and status text around the health bar.
	local health = self:HealthBar()
	local container = health and health:GetParent()
	if container and container ~= frame then
		AddRegions(container)
	end
	-- The target of target's own portrait, frame texture and name.
	if self.spec.small then
		AddRegions(frame)
	end
	-- Old-style frames.
	for _, suffix in ipairs(OLD_ART) do
		Add(self:Named(suffix))
	end
	for _, bar in ipairs({ health or false, self:PowerBar() or false }) do
		if bar then
			Add(bar.TextString)
			Add(bar.LeftText)
			Add(bar.RightText)
		end
	end
	return list
end

function Skin:FadeArt()
	for _, region in ipairs(self:ArtToFade()) do
		if self.faded[region] == nil then
			-- A secret opacity cannot be put back from addon code; use full.
			local alpha = region:GetAlpha()
			self.faded[region] = IsSecret(alpha) and 1 or alpha
		end
		region:SetAlpha(0)
	end
end

function Skin:UnfadeArt()
	for region, alpha in pairs(self.faded) do
		region:SetAlpha(alpha)
	end
	self.faded = {}
end

-- Everything Blizzard draws on its own bars besides the fill: animated
-- health loss, heal prediction and absorbs, full power flashes, sparks.
function Skin:Overlays()
	local list, seen = {}, {}
	local function Add(region)
		if type(region) == "table" and region.Hide and not seen[region] and not IsMask(region) then
			seen[region] = true
			list[#list + 1] = region
		end
	end
	local health, power = self:HealthBar(), self:PowerBar()
	for _, bar in ipairs({ health or false, power or false }) do
		if bar then
			local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
			for _, region in ipairs({ bar:GetRegions() }) do
				if region ~= fill then
					Add(region)
				end
			end
			for _, child in ipairs({ bar:GetChildren() }) do
				if not (child.IsProtected and child:IsProtected()) then
					Add(child)
				end
			end
		end
	end
	local frame = self:Frame()
	for _, owner in ipairs({ frame or false, health or false, health and health:GetParent() or false }) do
		if type(owner) == "table" then
			for _, key in ipairs(HEAL_PREDICTION_KEYS) do
				Add(rawget(owner, key))
			end
		end
	end
	return list
end

-- Overlays are hidden, and hidden again whenever Blizzard shows them.
function Skin:HideOverlays()
	local skin = self
	local function KeepHidden(region)
		if skin.active and region:IsShown() then
			region:Hide()
		end
	end
	for _, region in ipairs(self:Overlays()) do
		if not self.overlayHooked[region] then
			self.overlayHooked[region] = true
			hooksecurefunc(region, "Show", KeepHidden)
			if region.SetShown then
				hooksecurefunc(region, "SetShown", KeepHidden)
			end
		end
		region:Hide()
	end
end

-- Modern bars are masked to the old frame shape; drop the masks so the bar
-- fills its rectangle.
function Skin:RemoveMasks(bar)
	local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	if not (texture and texture.GetNumMaskTextures) then
		return
	end
	for i = texture:GetNumMaskTextures(), 1, -1 do
		local mask = texture:GetMaskTexture(i)
		if mask then
			texture:RemoveMaskTexture(mask)
			self.removedMasks[#self.removedMasks + 1] = { texture, mask }
		end
	end
end

function Skin:RestoreMasks()
	for _, pair in ipairs(self.removedMasks) do
		pair[1]:AddMaskTexture(pair[2])
	end
	self.removedMasks = {}
end

-- Our bar texture on Blizzard's bar, again whenever Blizzard sets its own.
function Skin:Retexture(bar)
	if not (self.active and bar) then
		return
	end
	self.layingOut = true
	bar:SetStatusBarTexture(kit:GetMedia("statusbar", "barTexture").file)
	self.layingOut = false
	self:RemoveMasks(bar)
end

-- Building -------------------------------------------------------------------------------

local function NewText(parent)
	local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fontString:SetWordWrap(false)
	return fontString
end

function Skin:Layer(level)
	local frame = CreateFrame("Frame", nil, self.holder)
	frame:SetFrameLevel(self.holder:GetFrameLevel() + level)
	return frame
end

function Skin:CreatePortrait()
	local portrait = CreateFrame("Frame", nil, self.holder)
	portrait.back = NewBackdropFrame(portrait)
	portrait.border = NewBackdropFrame(portrait)
	-- Round: a disc in the ring color behind the picture, a little larger,
	-- shows as a ring around it.
	portrait.ring = portrait:CreateTexture(nil, "BACKGROUND")
	portrait.ringMask = NewCircleMask(portrait, portrait.ring)
	SetRound(portrait.ring, portrait.ringMask, true)
	portrait.picture = portrait:CreateTexture(nil, "ARTWORK")
	portrait.picture:SetAllPoints(portrait)
	portrait.pictureMask = NewCircleMask(portrait, portrait.picture)
	portrait.class = portrait:CreateTexture(nil, "ARTWORK")
	portrait.class:SetAllPoints(portrait)
	portrait.classMask = NewCircleMask(portrait, portrait.class)
	portrait.model = CreateFrame("PlayerModel", nil, portrait)
	portrait.model:SetAllPoints(portrait)
	return portrait
end

-- The level circle on the portrait's outer bottom corner.
function Skin:CreateBadge()
	local badge = CreateFrame("Frame", nil, self.holder)
	badge.ring = badge:CreateTexture(nil, "BACKGROUND")
	badge.ring:SetAllPoints(badge)
	SetRound(badge.ring, NewCircleMask(badge, badge.ring), true)
	badge.fill = badge:CreateTexture(nil, "BORDER")
	SetRound(badge.fill, NewCircleMask(badge, badge.fill), true)
	return badge
end

function Skin:Create()
	local frame = self:Frame()
	local holder = CreateFrame("Frame", nil, frame)
	self.holder = holder
	holder:SetAllPoints(frame)
	holder:SetFrameLevel(frame:GetFrameLevel() + 2)
	local parts, texts = self.parts, self.texts
	parts.healthBack = NewBackdropFrame(holder)
	parts.healthBorder = NewBackdropFrame(holder)
	parts.powerBack = NewBackdropFrame(holder)
	parts.powerBorder = NewBackdropFrame(holder)
	parts.name = CreateFrame("Frame", nil, holder)
	parts.nameBack = NewBackdropFrame(parts.name)
	parts.nameBorder = NewBackdropFrame(parts.name)
	parts.nameColor = parts.name:CreateTexture(nil, "ARTWORK")
	parts.nameColor:SetAllPoints(parts.name)
	parts.portrait = self:CreatePortrait()
	parts.badge = self:CreateBadge()
	parts.raidLayer = self:Layer(16)
	parts.raid = parts.raidLayer:CreateTexture(nil, "OVERLAY")
	parts.raid:SetTexture(RAID_ICONS)
	parts.raid:Hide()
	-- Incoming heals: a bar of our own after the health bar's fill, clipped
	-- to the health bar.
	parts.healClip = CreateFrame("Frame", nil, holder)
	if parts.healClip.SetClipsChildren then
		parts.healClip:SetClipsChildren(true)
	end
	parts.heal = CreateFrame("StatusBar", nil, parts.healClip)
	parts.heal:SetMinMaxValues(0, 1)
	parts.heal:SetValue(0)
	-- Text sits on frames above the bars and the portrait so nothing covers it.
	parts.healthText = self:Layer(8)
	parts.powerText = self:Layer(8)
	parts.nameText = self:Layer(12)
	texts.health = NewText(parts.healthText)
	texts.power = NewText(parts.powerText)
	texts.name = NewText(parts.nameText)
	texts.level = NewText(parts.nameText)
	texts.badge = NewText(parts.badge)
	local skin = self
	holder:SetScript("OnShow", function()
		skin:Refresh()
		skin:StartTicker()
	end)
	holder:SetScript("OnHide", function()
		skin:StopTicker()
	end)
end

-- The target of target has no health events of its own: while it shows,
-- its text and colors are refreshed a few times a second. Blizzard updates
-- its bars itself.
function Skin:StartTicker()
	if not (self.spec.poll and self:Ready() and self.holder:IsVisible() and C_Timer and C_Timer.NewTicker)
		or self.ticker then
		return
	end
	local skin = self
	self.ticker = C_Timer.NewTicker(0.2, function()
		skin:Tick()
	end)
end

function Skin:StopTicker()
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
end

function Skin:Tick()
	if not self.active then
		self:StopTicker()
		return
	end
	self:HealthChanged()
	self:UpdatePowerText()
	self:ApplyPowerColor()
end

-- Clicks ---------------------------------------------------------------------------------

-- Our own secure unit button over the whole layout: left-click targets the
-- unit, right-click opens its menu. Created and placed out of combat only.
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

-- The layout's rectangle, in holder coordinates.
function Skin:LayoutRect()
	local holder = self.holder
	local scale = holder:GetEffectiveScale()
	local hl, hb = holder:GetLeft(), holder:GetBottom()
	if not (hl and hb) then
		return nil
	end
	local parts = self.parts
	local left, right, top, bottom
	for _, frame in ipairs({ self:HealthBar() or false, self:PowerBar() or false, parts.name, parts.portrait }) do
		local l, r, t, b = frame and frame:GetLeft(), frame and frame:GetRight(), frame and frame:GetTop(),
			frame and frame:GetBottom()
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

function Skin:PlaceClicker()
	local skin = self
	kit.events.AfterCombat(self.prefix .. "Clicker", function()
		if not skin.active then
			return
		end
		skin:CreateClicker()
		if not skin.clicker then
			return
		end
		local x, y, width, height = skin:LayoutRect()
		if not x then
			-- No size yet (the frame is hidden until there is a target): try a
			-- few more times; the next layout or OnShow places it.
			skin.clickerTries = skin.clickerTries + 1
			if skin.clickerTries <= 10 then
				kit.events.Defer(skin.prefix .. "ClickerRetry", function() skin:PlaceClicker() end, 0.2)
			end
			return
		end
		skin.clickerTries = 0
		skin.clicker:ClearAllPoints()
		skin.clicker:SetPoint("BOTTOMLEFT", skin.holder, "BOTTOMLEFT", x, y)
		skin.clicker:SetSize(width, height)
		skin.clicker:Show()
		skin.clickerPlaced = true
		-- Edit Mode's highlight covers our layout instead of the old frame.
		local selection = skin:Frame().Selection
		if type(selection) == "table" and selection.SetPoint and not selection:IsProtected() then
			if not skin.selectionPoints then
				skin.selectionPoints = {}
				for i = 1, selection:GetNumPoints() do
					skin.selectionPoints[i] = { selection:GetPoint(i) }
				end
			end
			selection:ClearAllPoints()
			selection:SetPoint("BOTTOMLEFT", skin.holder, "BOTTOMLEFT", x, y)
			selection:SetSize(width, height)
		end
	end)
end

-- Colors ---------------------------------------------------------------------------------

-- Sets a color from a table, or straight from UnitSelectionColor when the
-- color is secret. Returns how it was set, for /ptf probe.
local function SetColor(setter, target, color, unit, fallback)
	if color then
		setter(target, color[1], color[2], color[3])
		return "plain"
	end
	if UnitSelectionColor then
		local ok = pcall(function()
			setter(target, UnitSelectionColor(unit))
		end)
		if ok then
			return "secret, passed through"
		end
	end
	setter(target, fallback[1], fallback[2], fallback[3])
	return "secret, fallback"
end

function Skin:ApplyHealthColor()
	local bar = self:HealthBar()
	if not (self:Ready() and bar) then
		return
	end
	local unit = self.unit
	local color, setFrom
	if self:Get("HealthTapped") and Tapped(unit) then
		color = GRAY
	elseif State(unit) then
		color = GRAY
	else
		local mode = self:Get("HealthColor")
		if mode == "class" then
			color = ClassColor(unit) or ReactionColor(unit)
			setFrom = true
		elseif mode == "reaction" then
			color = ReactionColor(unit)
			setFrom = true
		else
			color = BarColor(self.prefix .. "HealthColor") or GREEN
		end
	end
	self.layingOut = true
	if color or not setFrom then
		bar:SetStatusBarColor(color[1], color[2], color[3])
		self.healthColorMode = "plain"
	else
		self.healthColorMode = SetColor(bar.SetStatusBarColor, bar, nil, unit, GREEN)
	end
	self.layingOut = false
end

function Skin:ApplyPowerColor()
	local bar = self:PowerBar()
	if not (self:Ready() and bar) then
		return
	end
	local _, token = UnitPowerType(self.unit)
	token = Plain(token)
	local key = token and POWER_COLOR_KEYS[token]
	local color = key and BarColor(key)
	if not color and token and PowerBarColor and type(PowerBarColor[token]) == "table" then
		local blizzard = PowerBarColor[token]
		color = blizzard.r and { blizzard.r, blizzard.g, blizzard.b, 1 } or nil
	end
	if color then
		self.layingOut = true
		bar:SetStatusBarColor(color[1], color[2], color[3])
		self.layingOut = false
	end
end

-- The name bar: Blizzard's reputation color strip, in the bar texture.
function Skin:UpdateNameBar()
	local strip = self.parts.nameColor
	if not strip then
		return
	end
	local mode = self:Get("NameBar")
	if mode == "plain" then
		strip:Hide()
		self.nameBarMode = "background only"
		return
	end
	local unit = self.unit
	local color
	if self:Get("HealthTapped") and Tapped(unit) then
		color = GRAY
	elseif mode == "class" then
		color = ClassColor(unit) or SelectionColor(unit)
	else
		color = SelectionColor(unit)
	end
	self.nameBarMode = SetColor(strip.SetVertexColor, strip, color, unit, GRAY)
	strip:SetAlpha(settings.nameBgOpacity / 100)
	strip:Show()
end

-- The portrait's ring or border: gold for elites and world bosses, silver
-- for rares, else the Border Tint.
function Skin:PortraitTint()
	if self:Get("Classification") then
		local class = Classification(self.unit)
		if class == "elite" or class == "worldboss" then
			return ELITE_TINT
		elseif class == "rare" or class == "rareelite" then
			return RARE_TINT
		end
	end
	return Tint("borderTint")
end

function Skin:TintPortrait()
	local portrait = self.parts.portrait
	if not portrait then
		return
	end
	local tint = self:PortraitTint()
	portrait.ring:SetColorTexture(tint[1], tint[2], tint[3], tint[4] or 1)
	if portrait.border:IsShown() then
		portrait.border:SetBackdropBorderColor(unpack(tint))
	end
	self.parts.badge.ring:SetColorTexture(tint[1], tint[2], tint[3], tint[4] or 1)
end

-- Content --------------------------------------------------------------------------------

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

function Skin:UpdateHealthText()
	if not self:Ready() then
		return
	end
	local unit, text = self.unit, self.texts.health
	local state = State(unit)
	if state then
		text:SetText(STATE_TEXT[state])
		return
	end
	SetValueText(text, self:Get("HealthText"), UnitHealth(unit), UnitHealthMax(unit), self.healthPercentOf)
end

function Skin:UpdatePowerText()
	if not self:Ready() then
		return
	end
	local unit, text = self.unit, self.texts.power
	local powerType = UnitPowerType(unit)
	local max = UnitPowerMax(unit, powerType)
	if State(unit) or Plain(max) == 0 then
		text:SetText("")
		return
	end
	SetValueText(text, self:Get("PowerText"), UnitPower(unit, powerType), max, self.powerPercentOf)
end

function Skin:UpdateHeals()
	local heal = self.parts.heal
	if not heal then
		return
	end
	if not (self.active and self:Get("HealPredict") and UnitGetIncomingHeals) then
		self.healMode = (self.active and self:Get("HealPredict")) and "unavailable" or "off"
		self.parts.healClip:Hide()
		return
	end
	local unit = self.unit
	local ok = pcall(function()
		local incoming = UnitGetIncomingHeals(unit)
		if not IsSecret(incoming) and incoming == nil then
			incoming = 0
		end
		heal:SetMinMaxValues(0, UnitHealthMax(unit))
		heal:SetValue(incoming)
	end)
	self.healMode = ok and "on" or "unavailable"
	self.parts.healClip:SetShown(ok)
end

function Skin:UpdateName()
	if not self:Ready() then
		return
	end
	local unit, text = self.unit, self.texts.name
	local mode = self:Get("NameText")
	if mode == "none" then
		text:SetText("")
	else
		local name, realm = UnitName(unit)
		if IsSecret(name) or IsSecret(realm) or mode == "short" or not realm or realm == "" then
			text:SetText(name or "")
		else
			text:SetText(name .. "-" .. realm)
		end
	end
	local class = self:Get("NameClassColor") and ClassColor(unit)
	if class then
		text:SetTextColor(class[1], class[2], class[3])
	else
		local r, g, b = ColorSetting(self.prefix .. "NameColor")
		text:SetTextColor(r, g, b)
	end
end

-- The level's color: Blizzard's difficulty colors for units you can attack,
-- gold for the rest.
local function LevelColor(unit, level)
	local attackable = Plain(UnitCanAttack("player", unit))
	if attackable == false then
		return GOLD
	end
	local color = GetCreatureDifficultyColor and GetCreatureDifficultyColor(level)
		or GetQuestDifficultyColor and GetQuestDifficultyColor(level)
	if type(color) == "table" and color.r then
		return { color.r, color.g, color.b, 1 }
	end
	return GOLD
end

function Skin:UpdateLevel()
	if not self:Ready() then
		return
	end
	local onBadge = self:BadgeShown()
	local text = onBadge and self.texts.badge or self.texts.level
	self.texts.badge:SetText("")
	self.texts.level:SetText("")
	self.parts.badge:SetShown(onBadge)
	if not self:Get("Level") then
		return
	end
	local unit = self.unit
	local level = UnitLevel(unit)
	local color = GOLD
	if IsSecret(level) then
		if not pcall(text.SetFormattedText, text, "%s", level) then
			text:SetText("")
		end
	elseif type(level) == "number" and level <= 0 then
		text:SetText("??")
		color = { 1, 0.1, 0.1, 1 }
	else
		text:SetText(level or "")
		if self:Get("LevelColor") and type(level) == "number" then
			color = LevelColor(unit, level)
		end
	end
	text:SetTextColor(color[1], color[2], color[3])
end

function Skin:UpdateRaidIcon()
	local raid = self.parts.raid
	if not raid then
		return
	end
	local index = self.active and self:Get("RaidIcon") and GetRaidTargetIndex and GetRaidTargetIndex(self.unit)
	if IsSecret(index) then
		self.raidMode = "secret"
		raid:Hide()
		return
	end
	if type(index) ~= "number" or index < 1 or index > 8 then
		self.raidMode = "none"
		raid:Hide()
		return
	end
	self.raidMode = "icon " .. index
	local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
	raid:SetTexCoord(column * 0.25, (column + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
	raid:Show()
end

function Skin:PortraitMode()
	local mode = self:Get("Portrait")
	if mode == "class" and not ClassToken(self.unit) then
		return "portrait" -- NPCs have no class icon
	end
	if mode == "model" and Plain(UnitIsVisible(self.unit)) == false then
		return "portrait" -- out of sight: no model to show
	end
	return mode
end

function Skin:UpdatePortrait()
	local portrait = self.parts.portrait
	if not (self:Ready() and portrait) then
		return
	end
	local mode = self:PortraitMode()
	portrait:SetShown(mode ~= "none")
	portrait.picture:SetShown(mode == "portrait")
	portrait.class:SetShown(mode == "class")
	portrait.model:SetShown(mode == "model")
	local unit = self.unit
	if mode == "portrait" then
		if not (SetPortraitTexture and pcall(SetPortraitTexture, portrait.picture, unit)) then
			portrait.picture:SetTexture("Interface\\CharacterFrame\\TempPortrait")
		end
	elseif mode == "class" then
		local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[ClassToken(unit)]
		portrait.class:SetTexture(CLASS_ICONS)
		if coords then
			local left, right, top, bottom = unpack(coords)
			local w, h = (right - left) * CROP, (bottom - top) * CROP
			portrait.class:SetTexCoord(left + w, right - w, top + h, bottom - h)
		else
			portrait.class:SetTexCoord(0, 1, 0, 1)
		end
	elseif mode == "model" then
		portrait.model:SetUnit(unit)
		if portrait.model.SetPortraitZoom then
			portrait.model:SetPortraitZoom(1)
		end
		if portrait.model.SetCamDistanceScale then
			portrait.model:SetCamDistanceScale(1)
		end
	end
	-- A model is always square; switching modes may change the shape.
	if self.shapeFor ~= mode then
		self:StylePortrait()
	end
	self:UpdateLevel()
end

function Skin:HealthChanged()
	self:UpdateHeals()
	self:UpdateHealthText()
	self:ApplyHealthColor()
end

function Skin:PowerChanged()
	self:UpdatePowerText()
	self:ApplyPowerColor()
end

-- Name, faction or flags changed: everything that depends on who it is.
function Skin:UpdateColors()
	self:ApplyHealthColor()
	self:UpdateNameBar()
	self:UpdateName()
	self:TintPortrait()
end

function Skin:UpdateClassification()
	self:TintPortrait()
end

-- Everything that depends on the unit: a new target, focus or target's target.
function Skin:Refresh()
	if not self:Ready() or Plain(UnitExists(self.unit)) == false then
		return
	end
	self:UpdatePortrait()
	self:UpdateColors()
	self:UpdateLevel()
	self:UpdateRaidIcon()
	self:HealthChanged()
	self:PowerChanged()
	if not self.clickerPlaced then
		self.clickerTries = 0
		self:PlaceClicker()
	end
end

-- Layout ---------------------------------------------------------------------------------

function Skin:BadgeShown()
	return self:Get("Level") and self:Get("LevelPos") == "badge" and self.parts.portrait ~= nil
		and self.parts.portrait:IsShown()
end

-- The portrait's shape: round (a ring) or square (background and border).
-- A 3D model is always square.
function Skin:StylePortrait()
	local portrait = self.parts.portrait
	local mode = self:PortraitMode()
	self.shapeFor = mode
	local round = self:Get("PortraitShape") == "round" and mode ~= "model" and portrait.pictureMask ~= nil
	SetRound(portrait.picture, portrait.pictureMask, round)
	SetRound(portrait.class, portrait.classMask, round)
	if round then
		portrait.back:Hide()
		portrait.border:Hide()
		portrait.picture:SetTexCoord(0, 1, 0, 1)
		local thickness = math.max(1, settings.borderSize)
		portrait.ring:ClearAllPoints()
		portrait.ring:SetPoint("TOPLEFT", portrait, "TOPLEFT", -thickness, thickness)
		portrait.ring:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", thickness, -thickness)
		portrait.ring:Show()
	else
		portrait.ring:Hide()
		-- Blizzard's portrait picture is round: crop it to fill the square.
		portrait.picture:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		PlaceBackground(portrait.back, portrait, "name")
		PlaceBorder(portrait.border, portrait, self:PortraitTint())
	end
	self:TintPortrait()
end

function Skin:LayoutNow()
	local health, power = self:HealthBar(), self:PowerBar()
	if not (self.active and health) then
		return
	end
	if not self.holder then
		self:Create()
	end
	local holder, parts, texts = self.holder, self.parts, self.texts
	-- Our click button is protected: its parent is shown out of combat only.
	if not holder:IsShown() and not InCombatLockdown() then
		holder:Show()
	end
	self:FadeArt()
	self:HideOverlays()
	local texture = kit:GetMedia("statusbar", "barTexture").file
	local width = self:Get("HealthWidth")
	local healthHeight, powerHeight, nameHeight = self:Get("HealthHeight"), self:Get("PowerHeight"), self:Get("NameHeight")
	local gap = Gap()
	self.layingOut = true

	-- Health bar: the center of the layout, at a fixed spot in Blizzard's frame.
	health:ClearAllPoints()
	health:SetPoint("CENTER", holder, "CENTER", self.spec.x + self:Get("OffsetX"), self.spec.y + self:Get("OffsetY"))
	health:SetSize(width, healthHeight)
	health:SetStatusBarTexture(texture)
	self:RemoveMasks(health)

	-- Resource bar, under it.
	if power then
		power:ClearAllPoints()
		power:SetPoint("TOP", health, "BOTTOM", 0, -gap)
		power:SetSize(width, powerHeight)
		power:SetStatusBarTexture(texture)
		self:RemoveMasks(power)
	end
	self.layingOut = false

	PlaceBackground(parts.healthBack, health, "health")
	PlaceBorder(parts.healthBorder, health)
	parts.healthText:SetAllPoints(health)
	if power then
		PlaceBackground(parts.powerBack, power, "power")
		PlaceBorder(parts.powerBorder, power)
		parts.powerText:SetAllPoints(power)
		self:UpdatePowerShown()
	end

	-- Incoming heals, after the health bar's fill.
	local clip, heal = parts.healClip, parts.heal
	clip:ClearAllPoints()
	clip:SetAllPoints(health)
	clip:SetFrameLevel(health:GetFrameLevel() + 1)
	local fill = health:GetStatusBarTexture()
	heal:ClearAllPoints()
	if type(fill) == "table" and fill.GetObjectType then
		heal:SetPoint("TOPLEFT", fill, "TOPRIGHT")
		heal:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
	else
		heal:SetPoint("TOPLEFT", health, "TOPLEFT")
		heal:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT")
	end
	heal:SetWidth(width)
	heal:SetStatusBarTexture(texture)
	local healColor = BarColor("healPredictColor") or GREEN
	heal:SetStatusBarColor(healColor[1], healColor[2], healColor[3], settings.healPredictOpacity / 100)

	-- Name bar, above the health bar, with the reaction color strip.
	local nameBar = parts.name
	nameBar:SetSize(width, nameHeight)
	nameBar:ClearAllPoints()
	nameBar:SetPoint("BOTTOM", health, "TOP", 0, gap)
	nameBar:SetFrameLevel(health:GetFrameLevel() + 4)
	PlaceBackground(parts.nameBack, nameBar, "name")
	PlaceBorder(parts.nameBorder, nameBar)
	parts.nameColor:SetTexture(texture)
	parts.nameText:SetAllPoints(nameBar)

	-- Portrait: beside the bars, centered on them.
	local portrait = parts.portrait
	local stack = nameHeight + healthHeight + powerHeight + 2 * gap
	local size = self:Get("PortraitFit") and stack or self:Get("PortraitSize")
	local right = self:Get("PortraitSide") ~= "left"
	local middle = (nameHeight - powerHeight) / 2
	portrait:SetSize(size, size)
	portrait:ClearAllPoints()
	if right then
		portrait:SetPoint("LEFT", health, "RIGHT", gap, middle)
	else
		portrait:SetPoint("RIGHT", health, "LEFT", -gap, middle)
	end
	portrait:SetFrameLevel(nameBar:GetFrameLevel() + 2)
	self:StylePortrait()

	-- Level circle on the portrait's outer bottom corner.
	local fontSize = self:Get("FontSize")
	local badge = parts.badge
	local badgeSize = math.max(14, math.floor(fontSize * 1.9 + 0.5))
	local thickness = math.max(1, math.min(settings.borderSize, math.floor(badgeSize / 5)))
	badge:SetSize(badgeSize, badgeSize)
	badge:ClearAllPoints()
	local inset = size * 0.12
	if right then
		badge:SetPoint("CENTER", portrait, "BOTTOMRIGHT", -inset, inset)
	else
		badge:SetPoint("CENTER", portrait, "BOTTOMLEFT", inset, inset)
	end
	badge:SetFrameLevel(portrait:GetFrameLevel() + 6)
	badge.fill:ClearAllPoints()
	badge.fill:SetPoint("TOPLEFT", badge, "TOPLEFT", thickness, -thickness)
	badge.fill:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -thickness, thickness)
	badge.fill:SetColorTexture(unpack(LEVEL_FILL))
	texts.badge:ClearAllPoints()
	texts.badge:SetPoint("CENTER", badge, "CENTER", 0, 0)

	-- Raid target icon on the portrait's top (the name bar's without one).
	local raidSize = self:Get("RaidIconSize")
	parts.raid:SetSize(raidSize, raidSize)
	parts.raid:ClearAllPoints()
	if self:Get("Portrait") ~= "none" then
		parts.raid:SetPoint("CENTER", portrait, "TOP", 0, 0)
	else
		parts.raid:SetPoint("CENTER", nameBar, "TOP", 0, 0)
	end

	-- Fonts: the shared font and shadow at this frame's size.
	for _, fontString in pairs(texts) do
		kit:ApplyFont(fontString, "font", fontSize, "fontShadow")
	end
	PlaceText(texts.health, self.prefix .. "HealthTextAnchor", health)
	texts.power:ClearAllPoints()
	texts.power:SetPoint("CENTER", power or health, "CENTER")
	-- Level on the name bar: on the portrait's side; the name keeps clear of it.
	texts.level:ClearAllPoints()
	texts.level:SetPoint(right and "RIGHT" or "LEFT", nameBar, right and "RIGHT" or "LEFT", right and -4 or 4, 0)
	PlaceText(texts.name, self.prefix .. "NameAnchor", nameBar)
	local namePoint = self:Get("NameAnchor") or "CENTER"
	texts.name:SetJustifyH(namePoint:find("LEFT") and "LEFT" or (namePoint:find("RIGHT") and "RIGHT" or "CENTER"))
	local levelOnBar = self:Get("Level") and (self:Get("LevelPos") ~= "badge" or self:Get("Portrait") == "none")
	texts.name:SetWidth(math.max(10, width - 8 - (levelOnBar and fontSize * 2.2 or 0)))

	self:Retexture(health)
	self:ApplyPowerColor()
	self:Refresh()
	self.clickerTries = 0
	self:PlaceClicker()
end

-- Our resource bar background and border show with Blizzard's bar (Blizzard
-- hides it for units without one).
function Skin:UpdatePowerShown()
	local power = self:PowerBar()
	local shown = self.active and power and power:IsShown() and true or false
	if self.parts.powerBack then
		self.parts.powerBack:SetShown(shown and kit:GetMedia("background", "powerBackground").file ~= nil)
		self.parts.powerBorder:SetShown(shown and kit:GetMedia("border", "border").file ~= nil)
		self.parts.powerText:SetShown(shown)
	end
end

function Skin:Protected()
	for _, frame in ipairs({ self:HealthBar() or false, self:PowerBar() or false }) do
		if frame and frame.IsProtected and frame:IsProtected() then
			return true
		end
	end
	return false
end

function Skin:Layout()
	local skin = self
	if self:Protected() then
		kit.events.AfterCombat(self.prefix .. "Layout", function() skin:LayoutNow() end)
	else
		self:LayoutNow()
	end
end

-- Next frame, after Blizzard has finished laying out its own frame.
function Skin:RequestLayout()
	if self.active then
		local skin = self
		kit.events.Defer(self.prefix .. "Layout", function() skin:Layout() end)
	end
end

function Skin:Restore()
	self:StopTicker()
	self:UnfadeArt()
	self:RestoreMasks()
	local skin = self
	kit.events.AfterCombat(self.prefix .. "Restore", function()
		if skin.active then
			return -- turned back on meanwhile
		end
		if skin.holder then
			skin.holder:Hide() -- also hides our click button
		end
		local selection = skin:Frame() and skin:Frame().Selection
		if skin.selectionPoints and type(selection) == "table" then
			selection:ClearAllPoints()
			for _, point in ipairs(skin.selectionPoints) do
				selection:SetPoint(unpack(point))
			end
			skin.selectionPoints = nil
		end
	end)
	-- Blizzard's bars stay where we put them until Blizzard lays its frame out
	-- again; calling its layout code from here could taint the frame.
	kit:Print(self.spec.name .. " is off. Reload the interface (/reload) to fully restore Blizzard's frame.")
end

-- Hooks ----------------------------------------------------------------------------------

function Skin:Hook()
	if self.hooked then
		return
	end
	self.hooked = true
	local skin = self
	local health, power = self:HealthBar(), self:PowerBar()
	local function OnMoved()
		if not skin.layingOut then
			skin:RequestLayout()
		end
	end
	for _, bar in ipairs({ health or false, power or false }) do
		if bar then
			hooksecurefunc(bar, "SetPoint", OnMoved)
		end
	end
	-- Blizzard recolors and re-textures its bars on updates; put ours back.
	if health then
		hooksecurefunc(health, "SetStatusBarColor", function()
			if not skin.layingOut then
				skin:ApplyHealthColor()
			end
		end)
	end
	if power then
		hooksecurefunc(power, "SetStatusBarColor", function()
			if not skin.layingOut then
				skin:ApplyPowerColor()
			end
		end)
		power:HookScript("OnShow", function() skin:UpdatePowerShown() end)
		power:HookScript("OnHide", function() skin:UpdatePowerShown() end)
	end
	for _, bar in ipairs({ health or false, power or false }) do
		if bar then
			for _, method in ipairs({ "SetStatusBarTexture", "SetStatusBarAtlas" }) do
				if bar[method] then
					hooksecurefunc(bar, method, function()
						if not skin.layingOut and skin.active then
							skin:Retexture(bar)
							if bar == power then
								skin:ApplyPowerColor()
							else
								skin:ApplyHealthColor()
							end
						end
					end)
				end
			end
		end
	end
	-- Blizzard's own updates of the frame: the unit's faction, classification
	-- or level may have changed. Not on the target of target, which Blizzard
	-- updates every frame.
	local frame = self:Frame()
	for _, method in ipairs(self.spec.small and {} or { "CheckClassification", "CheckFaction", "CheckLevel", "Update" }) do
		if type(frame[method]) == "function" then
			hooksecurefunc(frame, method, function()
				if skin.active then
					kit.events.Defer(skin.prefix .. "Refresh", function() skin:Refresh() end)
				end
			end)
		end
	end
end

-- Apply and probe ------------------------------------------------------------------------

function Skin:Apply(current)
	settings = current
	if not (self:Frame() and self:HealthBar()) then
		self.missing = true
		return
	end
	self.missing = false
	if self:Get("Enabled") then
		self.active = true
		self:Hook()
		self:Layout()
		self:StartTicker()
	elseif self.active then
		self.active = false
		self:Restore()
	end
end

-- Visible pieces of Blizzard's frame that are not ours, the bars or the
-- auras' and cast bar's frames, to find leftover art.
function Skin:LeftoverArt()
	local found = {}
	local frame = self:Frame()
	local skip = { [self:HealthBar() or false] = true, [self:PowerBar() or false] = true }
	-- Every skin's frames, and the target of target inside the target frame.
	for _, skin in ipairs(skins) do
		skip[skin.holder or false] = true
		if skin ~= self then
			skip[skin:Frame() or false] = true
		end
	end
	local function Walk(owner, depth)
		local name = DebugName(owner)
		if depth > 5 or skip[owner] or owner == frame.spellbar or owner == frame.Selection or Mentions(name, "buff")
			or Mentions(name, "aura") or Mentions(name, "spellbar") then
			return
		end
		for _, region in ipairs({ owner:GetRegions() }) do
			local visible, alpha = region:IsVisible(), region:GetAlpha()
			if not IsSecret(visible) and not IsSecret(alpha) and visible and alpha > 0 and #found < 30 then
				local atlas = region.GetAtlas and region:GetAtlas()
				if IsSecret(atlas) then
					atlas = "(secret)"
				end
				found[#found + 1] = "    " .. tostring(DebugName(region)) .. (atlas and (" atlas " .. atlas) or "")
			end
		end
		for _, child in ipairs({ owner:GetChildren() }) do
			Walk(child, depth + 1)
		end
	end
	if frame then
		Walk(frame, 0)
	end
	return found
end

local function SecretWord(value)
	return IsSecret(value) and "secret" or "plain"
end

function Skin:Probe()
	local frame, unit = self:Frame(), self.unit
	local rows = {
		"Frame: " .. ns.Has(frame) .. " (" .. tostring(frame and DebugName(frame)) .. "), health bar: "
			.. ns.Has(self:HealthBar()) .. ", resource bar: " .. ns.Has(self:PowerBar())
			.. ", modern content: " .. ns.Has(self:Main()),
		"Reskin active: " .. (self.active and "yes" or "no") .. (self.missing and " (frame or health bar missing)" or ""),
	}
	local exists = Plain(UnitExists(unit))
	if exists then
		local name = UnitName(unit)
		rows[#rows + 1] = "Unit " .. unit .. ": health " .. SecretWord(UnitHealth(unit)) .. ", name " .. SecretWord(name)
			.. ", reaction " .. SecretWord(UnitReaction and UnitReaction(unit, "player"))
			.. ", level " .. SecretWord(UnitLevel(unit))
			.. ", classification " .. SecretWord(UnitClassification and UnitClassification(unit))
			.. ", tapped " .. SecretWord(UnitIsTapDenied and UnitIsTapDenied(unit))
			.. ", raid icon " .. SecretWord(GetRaidTargetIndex and GetRaidTargetIndex(unit))
	else
		rows[#rows + 1] = "Unit " .. unit .. ": none (pick one to see which of its values are secret)"
	end
	rows[#rows + 1] = "Health color: " .. tostring(self.healthColorMode) .. ", name bar: " .. tostring(self.nameBarMode)
		.. ", incoming heals: " .. tostring(self.healMode) .. ", raid icon: " .. tostring(self.raidMode)
	rows[#rows + 1] = "Art faded: " .. #self:ArtToFade() .. ", bar overlays hidden: " .. #self:Overlays()
		.. ", Edit Mode highlight: " .. ns.Has(frame and type(frame.Selection) == "table" and frame.Selection or nil)
	rows[#rows + 1] = "Click button: " .. (self.clicker and "yes" or "no (made out of combat, once the frame has shown)")
		.. (self.spec.poll and (", refresh ticker: " .. (self.ticker and "running" or "stopped")) or "")
	rows[#rows + 1] = "Blizzard art still visible:"
	for _, line in ipairs(self:LeftoverArt()) do
		rows[#rows + 1] = line
	end
	return rows
end

-- spec: name, prefix, unit, frame (function returning Blizzard's frame),
-- x and y (the health bar's spot in Blizzard's frame), small (the target of
-- target: its own regions are art), poll (no health events for the unit).
function ns.NewUnitSkin(spec)
	local skin = setmetatable({
		spec = spec,
		prefix = spec.prefix,
		unit = spec.unit,
		active = false,
		hooked = false,
		layingOut = false,
		parts = {},
		texts = {},
		faded = {},
		overlayHooked = {},
		removedMasks = {},
		clickerTries = 0,
		healthPercentOf = HealthPercentOf(spec.unit),
		powerPercentOf = PowerPercentOf(spec.unit),
	}, Skin)
	skins[#skins + 1] = skin
	ns.RegisterFeature(spec.name, function(current) skin:Apply(current) end, function() return skin:Probe() end)
	return skin
end

-- Events ---------------------------------------------------------------------------------
-- One handler per event, dispatched to the skins showing that unit.

ns.missingEvents = {}

local function On(event, handler)
	if not pcall(kit.events.On, event, handler) then
		ns.missingEvents[#ns.missingEvents + 1] = event
	end
end

local UNIT_EVENTS = {
	UNIT_HEALTH = "HealthChanged",
	UNIT_MAXHEALTH = "HealthChanged",
	UNIT_HEAL_PREDICTION = "UpdateHeals",
	UNIT_POWER_UPDATE = "UpdatePowerText",
	UNIT_POWER_FREQUENT = "UpdatePowerText",
	UNIT_MAXPOWER = "UpdatePowerText",
	UNIT_DISPLAYPOWER = "PowerChanged",
	UNIT_NAME_UPDATE = "UpdateColors",
	UNIT_FACTION = "UpdateColors",
	UNIT_FLAGS = "UpdateColors",
	UNIT_CONNECTION = "Refresh",
	UNIT_LEVEL = "UpdateLevel",
	UNIT_CLASSIFICATION_CHANGED = "UpdateClassification",
	UNIT_PORTRAIT_UPDATE = "UpdatePortrait",
	UNIT_MODEL_CHANGED = "UpdatePortrait",
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

-- A whole skin refresh for the skins whose unit is in the list.
local function RefreshUnits(units)
	return function()
		for _, skin in ipairs(skins) do
			if skin.active and units[skin.unit] then
				skin:Refresh()
			end
		end
	end
end

On("PLAYER_TARGET_CHANGED", RefreshUnits({ target = true, targettarget = true }))
On("PLAYER_FOCUS_CHANGED", RefreshUnits({ focus = true }))
-- The target's target changed.
On("UNIT_TARGET", function(unit)
	if unit == "target" then
		RefreshUnits({ targettarget = true })()
	end
end)
On("RAID_TARGET_UPDATE", function()
	for _, skin in ipairs(skins) do
		skin:UpdateRaidIcon()
	end
end)
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED" }) do
	On(event, function()
		for _, skin in ipairs(skins) do
			skin:RequestLayout()
		end
	end)
end
