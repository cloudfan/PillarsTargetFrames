local addonName, ns = ...

if not ns.kit then
	return
end

-- The four frames. Each lives inside Blizzard's frame for the unit, so it
-- shows when Blizzard's would and moves with it in Edit Mode; the target's
-- pet, which Blizzard has no frame for, is placed against the target frame.

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

ns.NewUnitSkin({
	name = "Target's Pet",
	prefix = "tp",
	unit = "targetpet",
	frame = function()
		return TargetFrame
	end,
	pet = true,
	movable = true, -- its own place, moved in Edit Mode
	poll = true, -- no events for targetpet
})
