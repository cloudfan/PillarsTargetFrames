local addonName, ns = ...

if not ns.kit then
	return
end

-- Each frame registers an apply function and a probe function.
-- ns.ApplySettings runs every apply function with the current settings.
local features = {}

function ns.RegisterFeature(name, apply, probe)
	features[#features + 1] = { name = name, apply = apply, probe = probe }
end

function ns.ApplySettings()
	if not ns.settingsReady then
		return
	end
	local settings = ns.kit.settings
	for i = 1, #features do
		features[i].apply(settings)
	end
end

function ns.IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) and true or false
end

-- A value the addon may compare or branch on: nil when it is secret.
function ns.Plain(value)
	if ns.IsSecret(value) then
		return nil
	end
	return value
end

-- "yes" or a red MISSING, for probe rows.
function ns.Has(value)
	return value ~= nil and "yes" or "|cffff4040MISSING|r"
end

-- Shared probe rows: the client APIs the frames lean on.
local function SharedRows()
	local _, _, _, build = GetBuildInfo()
	return {
		"Build: " .. tostring(build) .. ", WOW_PROJECT_ID " .. tostring(WOW_PROJECT_ID)
			.. (WOW_PROJECT_CAMELOT and (" (Camelot " .. tostring(WOW_PROJECT_CAMELOT) .. ")") or ""),
		"TargetFrame: " .. ns.Has(TargetFrame) .. ", TargetFrame.totFrame: " .. ns.Has(TargetFrame and TargetFrame.totFrame)
			.. ", TargetFrameToT: " .. ns.Has(TargetFrameToT) .. ", FocusFrame: " .. ns.Has(FocusFrame),
		"SetPortraitTexture: " .. ns.Has(SetPortraitTexture) .. ", UnitSelectionColor: " .. ns.Has(UnitSelectionColor)
			.. ", UnitReaction: " .. ns.Has(UnitReaction) .. ", FACTION_BAR_COLORS: " .. ns.Has(FACTION_BAR_COLORS),
		"UnitIsTapDenied: " .. ns.Has(UnitIsTapDenied) .. ", UnitClassification: " .. ns.Has(UnitClassification)
			.. ", GetRaidTargetIndex: " .. ns.Has(GetRaidTargetIndex),
		"GetCreatureDifficultyColor: " .. ns.Has(GetCreatureDifficultyColor) .. ", GetQuestDifficultyColor: "
			.. ns.Has(GetQuestDifficultyColor) .. ", UnitCanAttack: " .. ns.Has(UnitCanAttack),
		"UnitHealthPercent: " .. ns.Has(UnitHealthPercent) .. ", UnitPowerPercent: " .. ns.Has(UnitPowerPercent)
			.. ", CurveConstants.ScaleTo100: " .. ns.Has(CurveConstants and CurveConstants.ScaleTo100)
			.. ", AbbreviateNumbers: " .. ns.Has(AbbreviateNumbers),
		"UnitGetIncomingHeals: " .. ns.Has(UnitGetIncomingHeals) .. ", C_Timer.NewTicker: "
			.. ns.Has(C_Timer and C_Timer.NewTicker) .. ", issecretvalue: " .. ns.Has(issecretvalue),
		"Events that could not be registered: "
			.. (#(ns.missingEvents or {}) > 0 and table.concat(ns.missingEvents, ", ") or "none"),
	}
end

local function ProbeRows()
	local rows = ns.kit:ProbeRows()
	rows[#rows + 1] = ""
	rows[#rows + 1] = "Client:"
	for _, row in ipairs(SharedRows()) do
		rows[#rows + 1] = "  " .. row
	end
	for i = 1, #features do
		if features[i].probe then
			rows[#rows + 1] = ""
			rows[#rows + 1] = features[i].name .. ":"
			local extra = features[i].probe()
			for j = 1, #extra do
				rows[#rows + 1] = "  " .. extra[j]
			end
		end
	end
	return rows
end

-- /ptf opens the settings; /ptf <page> opens a page by the start of its
-- name (/ptf focus, /ptf look); /ptf probe and /ptf profiles.
SLASH_PILLARSTARGETFRAMES1 = "/ptf"
SLASH_PILLARSTARGETFRAMES2 = "/pillarstargetframes"
SlashCmdList.PILLARSTARGETFRAMES = function(msg)
	if not ns.kit then return end
	local command = strlower(strtrim(msg or ""))
	if command == "probe" then
		if ns.kit.ShowCopy then
			ns.kit:ShowCopy("Diagnostics", ProbeRows())
		else
			ns.kit:ShowProbe()
		end
		return
	elseif command == "profiles" then
		ns.kit:Open(ns.kit:ProfilesIndex())
		return
	elseif command ~= "" then
		if command == "tot" then
			command = "target of"
		end
		-- The shortest matching page name wins: /ptf target opens Target,
		-- /ptf target of (or /ptf tot) opens Target of Target.
		local best, bestLength
		for name, index in pairs(ns.pageIndex) do
			if strlower(name):find(command, 1, true) == 1 and (not bestLength or #name < bestLength) then
				best, bestLength = index, #name
			end
		end
		if best then
			ns.kit:Open(best)
			return
		end
	end
	ns.kit:Open()
end
