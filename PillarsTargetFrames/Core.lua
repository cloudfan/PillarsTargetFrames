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

-- Actions the client blocked or forbade this session, and the addon it
-- blamed, for the probe (a stuck chat box or "Interface action failed"
-- shows up here).
ns.blocked = {}
for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
	pcall(ns.kit.events.On, event, function(addon, action)
		if #ns.blocked < 20 then
			ns.blocked[#ns.blocked + 1] = event:sub(14) .. ": " .. tostring(addon) .. " → " .. tostring(action)
		end
	end)
end

-- Shared probe rows: the client APIs the frames lean on.
local function SharedRows()
	local _, _, _, build = GetBuildInfo()
	return {
		"Build: " .. tostring(build) .. ", WOW_PROJECT_ID " .. tostring(WOW_PROJECT_ID)
			.. (WOW_PROJECT_CAMELOT and (" (Camelot " .. tostring(WOW_PROJECT_CAMELOT) .. ")") or ""),
		"TargetFrame: " .. ns.Has(TargetFrame) .. ", TargetFrame.totFrame: " .. ns.Has(TargetFrame and TargetFrame.totFrame)
			.. ", TargetFrameToT: " .. ns.Has(TargetFrameToT) .. ", FocusFrame: " .. ns.Has(FocusFrame)
			.. ", FocusFrame.totFrame: " .. ns.Has(FocusFrame and FocusFrame.totFrame),
		"UnitReaction: " .. ns.Has(UnitReaction) .. ", FACTION_BAR_COLORS: " .. ns.Has(FACTION_BAR_COLORS),
		"GetCreatureDifficultyColor: " .. ns.Has(GetCreatureDifficultyColor) .. ", GetQuestDifficultyColor: "
			.. ns.Has(GetQuestDifficultyColor) .. ", UnitCanAttack: " .. ns.Has(UnitCanAttack),
		"UnitHealthPercent: " .. ns.Has(UnitHealthPercent) .. ", UnitPowerPercent: " .. ns.Has(UnitPowerPercent)
			.. ", CurveConstants.ScaleTo100: " .. ns.Has(CurveConstants and CurveConstants.ScaleTo100)
			.. ", AbbreviateNumbers: " .. ns.Has(AbbreviateNumbers),
		"UnitCastingInfo: " .. ns.Has(UnitCastingInfo) .. ", UnitChannelInfo: " .. ns.Has(UnitChannelInfo)
			.. ", UnitCastingDuration: " .. ns.Has(UnitCastingDuration) .. ", RegisterUnitWatch: "
			.. ns.Has(RegisterUnitWatch) .. ", GetComboPoints: " .. ns.Has(GetComboPoints),
		"C_Timer.NewTicker: "
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
	rows[#rows + 1] = "  Actions blocked this session: " .. (#ns.blocked > 0 and "" or "none")
	for _, line in ipairs(ns.blocked) do
		rows[#rows + 1] = "    " .. line
	end
	for i = 1, #features do
		if features[i].probe then
			rows[#rows + 1] = ""
			rows[#rows + 1] = features[i].name .. ":"
			-- One frame's probe failing must not take the rest with it.
			local ok, extra = pcall(features[i].probe)
			if not ok then
				extra = { "probe error: " .. tostring(extra) }
			end
			for j = 1, #extra do
				rows[#rows + 1] = "  " .. tostring(extra[j])
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
			local ok, rows = pcall(ProbeRows)
			if not ok then
				rows = { "The probe failed: " .. tostring(rows) }
			end
			ns.kit:ShowCopy("Diagnostics", rows)
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
