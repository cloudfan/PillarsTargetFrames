local addonName, ns = ...

if not ns.kit then
	return
end

-- A test of what this client lets addon code read about the target's
-- auras, in and out of combat, for /ptf probe. It decides whether the
-- frames can draw buff and debuff icons of their own: Blizzard's own
-- buttons are never touched (moving them blocks Blizzard's aura code and
-- taints chat), so own icons are the only way to place auras elsewhere.
--
-- Only aura functions are called (C_UnitAuras, the old UnitBuff /
-- UnitDebuff / UnitAura globals if this client has them, AuraUtil), each
-- call protected; nothing is compared or
-- branched on unless ns.Plain says the value is not secret. The test runs
-- when the probe opens, shortly after combat starts, and on target changes
-- (at most every few seconds). No UNIT_AURA handler: its payload is secret
-- in combat and the test does not need it.

local kit = ns.kit
local Plain, IsSecret = ns.Plain, ns.IsSecret

local THROTTLE = 5 -- seconds between automatic runs
local results = {} -- ["in combat"] / ["out of combat"] = { time, rows }
local lastRun = 0

-- How a value came back, without revealing it.
local function Describe(value)
	if IsSecret(value) then
		return "secret"
	end
	if value == nil then
		return "nil"
	end
	local kind = type(value)
	if kind == "string" then
		return value == "" and "empty text" or "text"
	end
	return kind
end

-- Calls fn(...) protected: "ok", or "error: <message>", and its results.
local function Try(fn, ...)
	if type(fn) ~= "function" then
		return "missing"
	end
	local packed = { pcall(fn, ...) }
	if not packed[1] then
		return "error: " .. tostring(packed[2])
	end
	return "ok", packed[2], packed[3]
end

-- What came back in an AuraData table: which fields are plain or secret.
local function DescribeAura(data)
	if IsSecret(data) or type(data) ~= "table" then
		return Describe(data)
	end
	return "table; icon " .. Describe(data.icon) .. ", name " .. Describe(data.name) .. ", applications "
		.. Describe(data.applications) .. ", duration " .. Describe(data.duration) .. ", expirationTime "
		.. Describe(data.expirationTime) .. ", dispelName " .. Describe(data.dispelName) .. ", auraInstanceID "
		.. Describe(data.auraInstanceID)
end

-- The instance ID helpers, given an ID that is not secret.
local function TestInstance(rows, id, indent)
	local api = C_UnitAuras
	local durationStatus, duration = Try(api.GetAuraDuration, "target", id)
	rows[#rows + 1] = indent .. "GetAuraDuration: " .. durationStatus
		.. (durationStatus == "ok" and (", " .. Describe(duration)) or "")
	local countStatus, count = Try(api.GetAuraApplicationDisplayCount, "target", id, 2)
	rows[#rows + 1] = indent .. "GetAuraApplicationDisplayCount: " .. countStatus
		.. (countStatus == "ok" and (", " .. Describe(count)) or "")
end

-- Each way of reading auras on its own, so one refusal does not hide the
-- others: the sorted ID list, the slot functions, the old globals and
-- Blizzard's AuraUtil helper.
local function TestFilter(rows, filter)
	local api = C_UnitAuras or {}

	local status, ids = Try(api.GetUnitAuraInstanceIDs, "target", filter)
	if status ~= "ok" then
		rows[#rows + 1] = filter .. " GetUnitAuraInstanceIDs: " .. status
	elseif IsSecret(ids) or type(ids) ~= "table" then
		rows[#rows + 1] = filter .. " GetUnitAuraInstanceIDs: " .. Describe(ids)
	else
		rows[#rows + 1] = filter .. " GetUnitAuraInstanceIDs: " .. #ids .. " auras, first ID " .. Describe(ids[1])
	end

	local indexStatus, data = Try(api.GetAuraDataByIndex, "target", 1, filter)
	rows[#rows + 1] = filter .. " GetAuraDataByIndex(1): " .. indexStatus
		.. (indexStatus == "ok" and (", " .. DescribeAura(data)) or "")
	if indexStatus == "ok" and type(data) == "table" and not IsSecret(data) then
		-- With the ID as it came back (the timer and stack helpers may refuse
		-- a secret ID from addon code).
		if IsSecret(data.auraInstanceID) or data.auraInstanceID ~= nil then
			TestInstance(rows, data.auraInstanceID, "  ")
		end
	end

	local byIndex = filter == "HELPFUL" and api.GetBuffDataByIndex or api.GetDebuffDataByIndex
	local byName = filter == "HELPFUL" and "GetBuffDataByIndex" or "GetDebuffDataByIndex"
	local byStatus, byData = Try(byIndex, "target", 1)
	rows[#rows + 1] = filter .. " " .. byName .. "(1): " .. byStatus
		.. (byStatus == "ok" and (", " .. DescribeAura(byData)) or "")

	-- The old globals: Unit[Buff|Debuff|Aura] return name, icon, ... in a row.
	local oldName = filter == "HELPFUL" and "UnitBuff" or "UnitDebuff"
	local oldStatus, name, icon = Try(_G[oldName], "target", 1)
	rows[#rows + 1] = filter .. " " .. oldName .. "(1): " .. oldStatus
		.. (oldStatus == "ok" and (", name " .. Describe(name) .. ", second value " .. Describe(icon)) or "")
	local auraStatus, auraName = Try(UnitAura, "target", 1, filter)
	rows[#rows + 1] = filter .. " UnitAura(1): " .. auraStatus
		.. (auraStatus == "ok" and (", first value " .. Describe(auraName)) or "")

	-- Blizzard's helper, with packed AuraData.
	if AuraUtil and AuraUtil.ForEachAura then
		local seen, first = 0, nil
		local helperStatus = Try(AuraUtil.ForEachAura, "target", filter, nil, function(aura)
			seen = seen + 1
			first = first or aura
			return seen >= 3
		end, true)
		rows[#rows + 1] = filter .. " AuraUtil.ForEachAura: " .. helperStatus .. ", " .. seen .. " seen"
			.. (first and (", first " .. DescribeAura(first)) or "")
	else
		rows[#rows + 1] = filter .. " AuraUtil.ForEachAura: missing"
	end
end

local function RunTest(reason)
	local combat = InCombatLockdown() and "in combat" or "out of combat"
	local rows = {}
	local exists = Plain(UnitExists("target"))
	if not exists then
		rows[#rows + 1] = "no target (" .. Describe(UnitExists("target")) .. ")"
	else
		TestFilter(rows, "HELPFUL")
		TestFilter(rows, "HARMFUL")
	end
	results[combat] = { time = GetTime(), reason = reason, rows = rows }
	lastRun = GetTime()
end

local function RunThrottled(reason)
	if GetTime() - lastRun >= THROTTLE then
		pcall(RunTest, reason)
	end
end

kit.events.On("PLAYER_REGEN_DISABLED", function()
	-- A moment into combat, once the client has restricted the auras.
	if C_Timer and C_Timer.After then
		C_Timer.After(2, function()
			if InCombatLockdown() then
				lastRun = 0
				RunThrottled("combat started")
			end
		end)
	end
end)
kit.events.On("PLAYER_TARGET_CHANGED", function()
	RunThrottled("target changed")
end)

-- Widgets the own icons would feed: made once, never shown.
local testCooldown, testBar

local function Probe()
	pcall(RunTest, "probe opened")
	testCooldown = testCooldown or CreateFrame("Cooldown")
	testBar = testBar or CreateFrame("StatusBar")
	local rows = {
		"Widgets: Cooldown:SetCooldownFromDurationObject " .. ns.Has(testCooldown.SetCooldownFromDurationObject)
			.. ", StatusBar:SetTimerDuration " .. ns.Has(testBar.SetTimerDuration)
			.. ", C_CurveUtil.CreateColorCurve " .. ns.Has(C_CurveUtil and C_CurveUtil.CreateColorCurve),
	}
	for _, combat in ipairs({ "out of combat", "in combat" }) do
		local result = results[combat]
		if result then
			rows[#rows + 1] = combat .. " (" .. result.reason .. ", " .. format("%.0f", GetTime() - result.time)
				.. " s ago):"
			for _, row in ipairs(result.rows) do
				rows[#rows + 1] = "  " .. row
			end
		else
			rows[#rows + 1] = combat .. ": not tested yet"
				.. (combat == "in combat" and " (target something with buffs, enter combat, then run /ptf probe)" or "")
		end
	end
	return rows
end

ns.RegisterFeature("Aura access test", function() end, Probe)
