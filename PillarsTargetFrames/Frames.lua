local addonName, ns = ...

if not ns.kit then
	return
end

-- The three frames. x and y place the health bar in Blizzard's frame so the
-- default layout (bars plus portrait) sits where Blizzard's own art was:
-- Blizzard's target and focus frames have the portrait on the right, the
-- target of target on the left. The Offset settings move it from there.

ns.NewUnitSkin({
	name = "Target",
	prefix = "tf",
	unit = "target",
	frame = function()
		return TargetFrame
	end,
	x = -40,
	y = -4,
})

ns.NewUnitSkin({
	name = "Target of Target",
	prefix = "tot",
	unit = "targettarget",
	frame = function()
		return TargetFrame and TargetFrame.totFrame or TargetFrameToT
	end,
	x = 26,
	y = -4,
	small = true, -- its own regions are its art
	poll = true, -- no health events for targettarget
})

-- FocusFrame may not exist on every Forever build; /ptf probe says.
ns.NewUnitSkin({
	name = "Focus",
	prefix = "ff",
	unit = "focus",
	frame = function()
		return FocusFrame
	end,
	x = -40,
	y = -4,
})
