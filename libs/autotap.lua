--[[
    Scals Hub - Auto Tap library (the tapping game)
    Taps for you at a steady rate, never faster than the game accepts. No UI.

        local Tap = loadstring(game:HttpGet(REPO .. "libs/autotap.lua"))()

    How the game taps (from its TapController):
      TapService.TapRequested:FireServer({ Auto = false, ClientSequence = n, Source = source })
      - ClientSequence goes up by 1 on every tap
      - taps closer together than GameConfig.ClickFxInterval are thrown away
      - taps are ignored while MiningActive / AtDigsite / DiggingActive / ColosseumActive is set
      - the server answers every tap with TapService.TapResult

    GAME
        Tap.PlaceId = nil          -- set it if you know it (otherwise the game is found by its tap remote)
        Tap.inGame()               -- true in the tapping game; use as Game = Tap.inGame in the hub

    TAPPING
        Tap.auto(true / false)     -- returns false, reason outside the game
        Tap.set({ Rate = 10, Method = "Remote" | "Game Tap", Source = "button" })
        Tap.tap()                  -- one tap
        Tap.maxRate()              -- taps per second the game accepts
        Tap.hasGameTap()           -- the game's TapController was found ("Game Tap" method)
        Tap.Sources                -- { "button", "screen", "key_e", "rebirth_row" }
        Tap.stats()                -- sent, paidOut: taps per second over the last second
        Tap.Settings               -- current settings

    Tap.destroy()                  -- stops tapping and disconnects
]]

local Tap = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local connections = {}
local alive = true
local function track(conn)
	table.insert(connections, conn)
	return conn
end

Tap.PlaceId = nil
Tap.Sources = { "button", "screen", "key_e", "rebirth_row" }

local Settings = { Enabled = false, Rate = 10, Method = "Remote", Source = "button" }
Tap.Settings = Settings

-- the game's tap remotes (looked up when needed, so this never waits in other games)
local tapRemotes, TapRequested
local function getRemotes()
	if TapRequested and TapRequested.Parent then return TapRequested end
	local rs = ReplicatedStorage:FindFirstChild("RemoteServices")
	local svc = rs and rs:FindFirstChild("TapService")
	tapRemotes = svc and svc:FindFirstChild("RE")
	TapRequested = tapRemotes and tapRemotes:FindFirstChild("TapRequested")
	return TapRequested
end

function Tap.inGame()
	if Tap.PlaceId and game.PlaceId == Tap.PlaceId then return true end
	local rs = ReplicatedStorage:FindFirstChild("RemoteServices")
	return rs ~= nil and rs:FindFirstChild("TapService") ~= nil
end

-- game modules, read once in the game
local minInterval = 0.05
local TapController, TapResultState
local loaded = false
local sequence = 0
local sent, registered = 0, 0

local function ensureLoaded()
	if loaded or not Tap.inGame() then return end
	loaded = true
	pcall(function()
		local cfg = require(ReplicatedStorage.Shared.Core.GameConfig)
		if type(cfg.ClickFxInterval) == "number" then minInterval = cfg.ClickFxInterval end
	end)
	pcall(function()
		local controllers = ReplicatedStorage:FindFirstChild("Controllers")
		local mod = controllers and controllers:FindFirstChild("TapController", true)
		if mod then TapController = require(mod) end
	end)
	pcall(function()
		TapResultState = require(ReplicatedStorage.Shared.Core.TapResultState)
	end)
	-- start our sequence where the game's own counter is
	pcall(function()
		if TapController and TapController.GetManualTapCount then sequence = TapController:GetManualTapCount() end
	end)
	-- count the taps the server actually paid out (not the paid auto clicker's)
	getRemotes()
	local TapResult = tapRemotes and tapRemotes:FindFirstChild("TapResult")
	if TapResult then
		track(TapResult.OnClientEvent:Connect(function(payload)
			local isAuto = false
			if TapResultState then
				local ok, data = pcall(TapResultState.Expand, payload, {})
				isAuto = ok and type(data) == "table" and data.IsAuto == true
			end
			if not isAuto then registered += 1 end
		end))
	end
end

function Tap.maxRate()
	ensureLoaded()
	return math.max(math.floor(1 / minInterval), 1)
end

function Tap.hasGameTap()
	ensureLoaded()
	return TapController ~= nil and TapController.Tap ~= nil
end

-- same checks the game does before it sends a tap
local function tapsBlocked()
	return player:GetAttribute("MiningActive") == true
		or player:GetAttribute("AtDigsite") == true
		or player:GetAttribute("DiggingActive") == true
		or player:GetAttribute("ColosseumActive") == true
end

function Tap.tap()
	ensureLoaded()
	if tapsBlocked() then return false end
	if Settings.Method == "Game Tap" and TapController and TapController.Tap then
		TapController:Tap() -- the game's own code: real sequence number, sounds and effects
	else
		local remote = getRemotes()
		if not remote then return false end
		sequence += 1
		remote:FireServer({ Auto = false, ClientSequence = sequence, Source = Settings.Source })
	end
	sent += 1
	return true
end

-- every frame while on: steady rate, at most one tap per frame, no catch-up bursts after lag
local nextTapAt = 0
local stepConn
local function step()
	local now = os.clock()
	local interval = math.max(1 / Settings.Rate, minInterval)
	if nextTapAt < now - interval then nextTapAt = now end
	if now >= nextTapAt then
		Tap.tap()
		nextTapAt += interval
	end
end

function Tap.auto(on)
	on = on == true
	if on and not Tap.inGame() then return false, "Not in the tapping game." end
	Settings.Enabled = on
	if on then
		ensureLoaded()
		nextTapAt = 0
		if not stepConn then stepConn = track(RunService.Heartbeat:Connect(step)) end
	elseif stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
	return true
end

function Tap.set(opts)
	for k, v in pairs(opts or {}) do
		if k ~= "Enabled" and Settings[k] ~= nil then Settings[k] = v end
	end
end

-- taps per second over the last second
local lastSent, lastPaid, rateSent, ratePaid = 0, 0, 0, 0
task.spawn(function()
	while alive do
		task.wait(1)
		rateSent, ratePaid = sent - lastSent, registered - lastPaid
		lastSent, lastPaid = sent, registered
	end
end)
function Tap.stats()
	return rateSent, ratePaid
end

function Tap.destroy()
	alive = false
	Settings.Enabled = false
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	stepConn = nil
end

return Tap
