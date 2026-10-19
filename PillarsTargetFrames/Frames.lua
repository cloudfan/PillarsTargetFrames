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
	auras = true,
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
	auras = true,
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
	poll = true, -- no events for targetpet
})
