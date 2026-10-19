local addonName, ns = ...

if not ns.kit then
	return
end

-- The three frames. Each lives inside Blizzard's frame for the unit, so it
-- shows when Blizzard's would. The target and focus frames move with
-- Blizzard's in Edit Mode; the target of target has an Edit Mode box of its
-- own.

ns.NewUnitSkin({
	name = "Target",
	prefix = "tf",
	unit = "target",
	frame = function()
		return TargetFrame
	end,
	combo = true,
})

ns.NewUnitSkin({
	name = "Target of Target",
	prefix = "tot",
	unit = "targettarget",
	frame = function()
		return TargetFrame and TargetFrame.totFrame or TargetFrameToT
	end,
	small = true, -- Blizzard's frame's own pieces are made invisible
	inherit = true, -- the Target page's settings until a section is overridden
	movable = true, -- its own place, moved in Edit Mode
	poll = true, -- no events for targettarget
})

-- FocusFrame may not exist on every Forever build; /ptf probe says.
ns.NewUnitSkin({
	name = "Focus",
	prefix = "ff",
	unit = "focus",
	frame = function()
		return FocusFrame
	end,
	inherit = true, -- the Target page's settings until a section is overridden
	ownToT = true, -- Blizzard's focus frame's own target of target
})
