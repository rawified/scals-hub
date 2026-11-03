--[[
    Scals Hub - Murder Mystery 2 library
    Coin farm, role ESP, kill all and an event log for MM2. No UI: call it from any script.

        local MM2 = loadstring(game:HttpGet(REPO .. "libs/mm2.lua"))()

    GAME
        MM2.PlaceIds              -- { 142823291 }, use as Game = MM2.PlaceIds in the hub
        MM2.inGame()              -- true in MM2. Everything below does nothing outside MM2.

    COIN FARM
        MM2.farm(true / false)    -- returns false, reason when it can't start (not in MM2)
        MM2.setFarm({
            Speed = 60,               -- studs per second
            FarmMode = "Nearest",     -- "Nearest" | "Clusters" (biggest group of coins first)
            PositionMode = "Normal",  -- "Normal" | "Under Floor" (lie under the floor, always noclips)
            ClusterRadius = 30,       -- studs: coins this close together are one group
            FloorDepth = 1.5,         -- studs below the floor in Under Floor mode
            RetryAfter = 4,           -- seconds before a coin we reached may be tried again
            StopWhenFull = true,      -- stop + reset when the bag is full, resumes next round
            Noclip = true,            -- noclip while farming
        })
        MM2.Farm                  -- the current settings (read only, change them with setFarm)
        MM2.isFarming()           -- farm switched on
        MM2.isBagFull()  MM2.isRoundActive()

    ROLE ESP (Knife = Murderer, Gun = Sheriff, neither = Innocent)
        MM2.esp(true / false)
        MM2.setEsp({ Highlights = true, Labels = true, ShowInnocents = true })
        MM2.getRole(player)       -- "Murderer" | "Sheriff" | "Innocent"
        MM2.getMurderer()  MM2.getSheriff()   -- Player or nil
        MM2.RoleColors            -- { Murderer = Color3, Sheriff = Color3, Innocent = Color3 }

    KILL ALL (only when you're the murderer)
        MM2.killAll({ PerTarget = 1.5 })   -- yields; returns how many died, or nil, reason
        MM2.stopKillAll()  MM2.isKilling()

    EVENT LOG
        MM2.logEvents(true / false)   -- prints every Remotes.Gameplay event to F9

    MESSAGES
        MM2.Notify = function(title, text) end   -- e.g. "Bag Full"; prints to F9 when not set

    MM2.destroy()                 -- turns everything off and disconnects
]]

local MM2 = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local connections = {}
local alive = true

local function track(conn)
	table.insert(connections, conn)
	return conn
end

local function notify(title, text)
	if type(MM2.Notify) == "function" then
		task.spawn(MM2.Notify, title, text)
	else
		print(("[MM2] %s: %s"):format(title, text))
	end
end

local function getRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

MM2.PlaceIds = { 142823291 }

function MM2.inGame()
	for _, id in ipairs(MM2.PlaceIds) do
		if game.PlaceId == id or game.GameId == id then return true end
	end
	return false
end

----------------------------------------------------------------------
-- Coin farm
-- Finds whichever map holds a "CoinContainer" (the map changes every round). Before every
-- hop it re-reads the coins that are still there, then picks the next one by FarmMode.
----------------------------------------------------------------------
local Farm = {
	Enabled = false,
	Speed = 60,
	Noclip = true,
	FarmMode = "Nearest",
	PositionMode = "Normal",
	ClusterRadius = 30,
	FloorDepth = 1.5,
	RetryAfter = 4,
	StopWhenFull = true,
}
MM2.Farm = Farm

local Log = { Enabled = false }

local bagFull = false
-- Round ON when its coins spawn (CoinsStarted); OFF when it ends for us: we respawn, get
-- teleported away from the coins, or the map is removed.
local roundActive = false
local roundStartedAt = 0
local hasStartRemote = false

local function findCoinContainer()
	for _, child in ipairs(workspace:GetChildren()) do
		local container = child:FindFirstChild("CoinContainer")
		if container then return container end
	end
	return nil
end

local function getCoinPosition(coin)
	if coin:IsA("BasePart") then
		return coin.Position
	elseif coin:IsA("Model") then
		return coin:GetPivot().Position
	end
	return nil
end

-- a coin is only still there while it has its CoinVisual
local function isCoinAvailable(coin)
	return coin.Parent ~= nil and coin:FindFirstChild("CoinVisual") ~= nil
end

local reached = setmetatable({}, { __mode = "k" }) -- coin -> time we reached it

local function getAvailableCoins(container)
	local now = os.clock()
	local list = {}
	for _, coin in ipairs(container:GetChildren()) do
		if coin.Name == "Coin_Server" and isCoinAvailable(coin) then
			local t = reached[coin]
			if not t or now - t > Farm.RetryAfter then
				local pos = getCoinPosition(coin)
				if pos then table.insert(list, { coin = coin, pos = pos }) end
			end
		end
	end
	return list
end

local function nearestIn(list, fromPos, filter)
	local best, bestDist
	for _, c in ipairs(list) do
		if not filter or filter(c) then
			local d = (c.pos - fromPos).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = c, d
			end
		end
	end
	return best
end

local clusterCenter

local function pickCluster(list, fromPos)
	local r = Farm.ClusterRadius
	local bestCenter, bestCount, bestDist
	for _, a in ipairs(list) do
		local count = 0
		local sum = Vector3.zero
		for _, b in ipairs(list) do
			if (a.pos - b.pos).Magnitude <= r then
				count += 1
				sum += b.pos
			end
		end
		local center = sum / count
		local d = (center - fromPos).Magnitude
		if not bestCount or count > bestCount or (count == bestCount and d < bestDist) then
			bestCenter, bestCount, bestDist = center, count, d
		end
	end
	return bestCenter, bestCount
end

local function chooseTarget(list, fromPos)
	if #list == 0 then return nil end
	if Farm.FarmMode == "Clusters" then
		local r = Farm.ClusterRadius
		local inCluster = function(c)
			return clusterCenter and (c.pos - clusterCenter).Magnitude <= r
		end
		local target = clusterCenter and nearestIn(list, fromPos, inCluster)
		if not target then
			clusterCenter = pickCluster(list, fromPos)
			target = nearestIn(list, fromPos, inCluster)
		end
		return target
	end
	return nearestIn(list, fromPos)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function floorYBelow(pos, container)
	local ignore = { container }
	if player.Character then table.insert(ignore, player.Character) end
	rayParams.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -60, 0), rayParams)
	return result and result.Position.Y
end

local LYING = CFrame.Angles(math.rad(90), 0, 0)

local function targetCFrame(pos, root, container)
	if Farm.PositionMode == "Under Floor" then
		local floorY = floorYBelow(pos, container) or (pos.Y - 3)
		local yaw = select(2, root.CFrame:ToOrientation())
		return CFrame.new(pos.X, floorY - Farm.FloorDepth, pos.Z) * CFrame.Angles(0, yaw, 0) * LYING
	end
	return CFrame.new(pos) * root.CFrame.Rotation
end

-- extra touch so the coin registers even when the body doesn't overlap it (Under Floor)
local function touchCoin(root, coin)
	if typeof(firetouchinterest) ~= "function" then return end
	local part = coin:IsA("BasePart") and coin or coin:FindFirstChildWhichIsA("BasePart", true)
	if part then
		pcall(function()
			firetouchinterest(root, part, 0)
			task.wait()
			firetouchinterest(root, part, 1)
		end)
	end
end

local currentTween

local function tweenToCoin(coin, pos, container)
	local root = getRoot()
	if not root then return false end
	local goal = targetCFrame(pos, root, container)
	local distance = (goal.Position - root.Position).Magnitude
	local duration = math.max(distance / Farm.Speed, 0.05)
	local tw = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = goal })
	currentTween = tw
	local finished = false
	local conn = tw.Completed:Connect(function(state)
		finished = (state == Enum.PlaybackState.Completed)
	end)
	tw:Play()
	while tw.PlaybackState == Enum.PlaybackState.Playing do
		if not Farm.Enabled or not roundActive or bagFull or not isCoinAvailable(coin) or not root.Parent then
			tw:Cancel()
			break
		end
		task.wait()
	end
	conn:Disconnect()
	if currentTween == tw then currentTween = nil end
	if finished and isCoinAvailable(coin) then touchCoin(root, coin) end
	return finished
end

local lastContainer

local function farmStep()
	local root = getRoot()
	local container = findCoinContainer()
	if container ~= lastContainer then
		reached = setmetatable({}, { __mode = "k" })
		clusterCenter = nil
		lastContainer = container
		if not container then
			roundActive = false
		elseif not hasStartRemote then
			bagFull = false
			roundStartedAt = os.clock()
			roundActive = true
		end
	end
	if bagFull or not roundActive or not (root and container) then
		task.wait(0.5)
		return
	end
	local target = chooseTarget(getAvailableCoins(container), root.Position)
	if not target then
		task.wait(0.3)
		return
	end
	if tweenToCoin(target.coin, target.pos, container) then
		reached[target.coin] = os.clock()
	end
end

local function resetCharacter()
	local hum = getHumanoid()
	if hum and hum.Health > 0 then
		hum.Health = 0
	elseif player.Character then
		player.Character:BreakJoints()
	end
end

local function onBagFull()
	if bagFull or not Farm.Enabled or not Farm.StopWhenFull then return end
	bagFull = true
	if currentTween then currentTween:Cancel() end
	notify("Bag Full", "Stopped farming and reset. Resumes next round.")
	task.wait(0.2)
	resetCharacter()
end

local function onNewRound()
	bagFull = false
	reached = setmetatable({}, { __mode = "k" })
	clusterCenter = nil
	roundStartedAt = os.clock()
	roundActive = true
end

local function endRound(reason)
	if not roundActive then return end
	roundActive = false
	clusterCenter = nil
	if currentTween then currentTween:Cancel() end
	if Log.Enabled then print("[MM2] round over for us:", reason) end
end

local function guiSaysFull()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return false end
	for _, gui in ipairs(pg:GetChildren()) do
		if gui:IsA("ScreenGui") then
			local container = gui:FindFirstChild("Container", true)
			if container then
				for _, frame in ipairs(container:GetChildren()) do
					if frame:IsA("Frame") and frame.Visible then
						local icon = frame:FindFirstChild("FullBagIcon", true)
						local label = frame:FindFirstChild("Full", true)
						if (icon and icon.Visible) or (label and label.Visible) then return true end
					end
				end
			end
		end
	end
	return false
end

local function farmingActive()
	return Farm.Enabled and roundActive and not bagFull and lastContainer ~= nil and lastContainer.Parent ~= nil
end

local function underFloor()
	return farmingActive() and Farm.PositionMode == "Under Floor"
end

-- Game hooks: set up once, the first time the farm is switched on
local hooked = false
local function ensureFarmHooks()
	if hooked then return end
	hooked = true

	-- bag full (CoinCollected: current >= max) and new rounds (CoinsStarted)
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
		local gameplay = remotes and remotes:WaitForChild("Gameplay", 10)
		if not gameplay then
			warn("[MM2] Remotes.Gameplay not found, using the bag GUI check only")
			return
		end
		local collected = gameplay:WaitForChild("CoinCollected", 10)
		if collected then
			track(collected.OnClientEvent:Connect(function(_coinType, currentAmount, maxAmount)
				local current, max = tonumber(currentAmount), tonumber(maxAmount)
				if current and max and current >= max then task.spawn(onBagFull) end
			end))
		end
		local started = gameplay:WaitForChild("CoinsStarted", 10)
		if started then
			hasStartRemote = true
			track(started.OnClientEvent:Connect(onNewRound))
		end
	end)

	-- backup: the bag GUI switching to "Full"
	task.spawn(function()
		local wasFull = false
		while alive do
			task.wait(0.5)
			local full = guiSaysFull()
			if full and not wasFull and Farm.Enabled and not bagFull then onBagFull() end
			wasFull = full
		end
	end)

	-- started mid-round: a map with coins on it counts as a running round
	local container = findCoinContainer()
	if container and #getAvailableCoins(container) > 0 then roundActive = true end

	track(player.CharacterAdded:Connect(function()
		if os.clock() - roundStartedAt > 5 then endRound("respawned") end
	end))

	-- teleported far from the coins (our own tweens move smoothly, a jump is the game)
	local lastRootPos
	track(RunService.Heartbeat:Connect(function()
		local root = getRoot()
		if not root then
			lastRootPos = nil
			return
		end
		local pos = root.Position
		if lastRootPos and roundActive and (pos - lastRootPos).Magnitude > 100 and os.clock() - roundStartedAt > 5 then
			local c = findCoinContainer()
			local nearest = c and nearestIn(getAvailableCoins(c), pos)
			if not nearest or (nearest.pos - pos).Magnitude > 300 then
				endRound("teleported away from the map")
			end
		end
		lastRootPos = pos
	end))

	-- noclip, no falling, and lying still while farming
	track(RunService.Stepped:Connect(function()
		if not (farmingActive() and (Farm.Noclip or underFloor())) then return end
		local char = player.Character
		if not char then return end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = false end
		end
	end))

	local platformStanding = false
	track(RunService.Heartbeat:Connect(function()
		if underFloor() then
			local hum = getHumanoid()
			if hum and not hum.PlatformStand then hum.PlatformStand = true end
			platformStanding = true
		elseif platformStanding then
			local hum = getHumanoid()
			if hum then hum.PlatformStand = false end
			platformStanding = false
		end
		if not farmingActive() then return end
		local root = getRoot()
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end))
end

local farmThread
function MM2.farm(on)
	on = on == true
	if on and not MM2.inGame() then return false, "Not in Murder Mystery 2." end
	Farm.Enabled = on
	clusterCenter = nil
	if on then
		ensureFarmHooks()
		if not findCoinContainer() then
			notify("Auto Collect", "No map loaded yet, waiting for the round to start.")
		end
		if not farmThread then
			farmThread = task.spawn(function()
				while alive and Farm.Enabled do
					local ok, err = pcall(farmStep)
					if not ok then
						warn("[MM2] farm error: " .. tostring(err))
						task.wait(1)
					end
					task.wait(0.05)
				end
				farmThread = nil
			end)
		end
	elseif currentTween then
		currentTween:Cancel()
	end
	return true
end

function MM2.setFarm(opts)
	for k, v in pairs(opts or {}) do
		if k ~= "Enabled" and Farm[k] ~= nil then Farm[k] = v end
	end
	clusterCenter = nil
end

function MM2.isFarming() return Farm.Enabled end
function MM2.isBagFull() return bagFull end
function MM2.isRoundActive() return roundActive end

----------------------------------------------------------------------
-- Role ESP
----------------------------------------------------------------------
local Esp = { Enabled = false, Highlights = true, Labels = true, ShowInnocents = true }
MM2.Esp = Esp
MM2.RoleColors = {
	Murderer = Color3.fromRGB(255, 60, 60),
	Sheriff = Color3.fromRGB(70, 150, 255),
	Innocent = Color3.fromRGB(80, 230, 120),
}

local function hasTool(plr, name)
	local bp = plr:FindFirstChildOfClass("Backpack")
	local char = plr.Character
	return (bp and bp:FindFirstChild(name)) or (char and char:FindFirstChild(name))
end

function MM2.getRole(plr)
	if hasTool(plr, "Knife") then return "Murderer" end
	if hasTool(plr, "Gun") then return "Sheriff" end
	return "Innocent"
end

local function findRole(role)
	for _, plr in ipairs(Players:GetPlayers()) do
		if MM2.getRole(plr) == role then return plr end
	end
	return nil
end
function MM2.getMurderer() return findRole("Murderer") end
function MM2.getSheriff() return findRole("Sheriff") end

local espFolder
local espObjects = {}

local function makeEsp(plr)
	if plr == player or espObjects[plr] then return end
	local hl = Instance.new("Highlight")
	hl.Enabled = false
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.FillTransparency = 0.6
	hl.OutlineTransparency = 0
	hl.Parent = espFolder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 20)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Enabled = false
	bb.Parent = espFolder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextStrokeTransparency = 0.3
	label.Parent = bb
	espObjects[plr] = { highlight = hl, billboard = bb, label = label }
end

local function removeEspFor(plr)
	local e = espObjects[plr]
	if not e then return end
	e.highlight:Destroy()
	e.billboard:Destroy()
	espObjects[plr] = nil
end

local function ensureEsp()
	if espFolder then return end
	-- hidden from the game: executor GUI folder, then CoreGui, then PlayerGui
	local parent
	pcall(function()
		if typeof(gethui) == "function" then parent = gethui() end
	end)
	if not parent then
		pcall(function()
			local core = game:GetService("CoreGui")
			local probe = Instance.new("Folder")
			probe.Parent = core
			probe:Destroy()
			parent = core
		end)
	end
	espFolder = Instance.new("Folder")
	espFolder.Name = "ScalsRoleESP"
	espFolder.Parent = parent or player:WaitForChild("PlayerGui")

	for _, plr in ipairs(Players:GetPlayers()) do makeEsp(plr) end
	track(Players.PlayerAdded:Connect(makeEsp))
	track(Players.PlayerRemoving:Connect(removeEspFor))

	-- roles only change a few times per round, so 5 checks a second is plenty
	task.spawn(function()
		while alive do
			local myRoot = getRoot()
			for plr, e in pairs(espObjects) do
				local char = plr.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local head = char and char:FindFirstChild("Head")
				local role = MM2.getRole(plr)
				local show = Esp.Enabled and char and hum and hum.Health > 0 and (Esp.ShowInnocents or role ~= "Innocent")
				if show then
					local color = MM2.RoleColors[role]
					e.highlight.Adornee = char
					e.highlight.FillColor = color
					e.highlight.OutlineColor = color
					e.highlight.Enabled = Esp.Highlights
					e.billboard.Adornee = head
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local dist = myRoot and hrp and math.floor((myRoot.Position - hrp.Position).Magnitude + 0.5)
					e.label.Text = dist and ("%s [%s] %dm"):format(plr.DisplayName, role, dist)
						or ("%s [%s]"):format(plr.DisplayName, role)
					e.label.TextColor3 = color
					e.billboard.Enabled = Esp.Labels and head ~= nil
				else
					e.highlight.Enabled = false
					e.billboard.Enabled = false
				end
			end
			task.wait(0.2)
		end
	end)
end

function MM2.esp(on)
	on = on == true
	if on and not MM2.inGame() then return false, "Not in Murder Mystery 2." end
	Esp.Enabled = on
	if on then ensureEsp() end
	return true
end

function MM2.setEsp(opts)
	for k, v in pairs(opts or {}) do
		if k ~= "Enabled" and Esp[k] ~= nil then Esp[k] = v end
	end
end

----------------------------------------------------------------------
-- Kill all: pins each player 2 studs in front of you (on your screen) and stabs
----------------------------------------------------------------------
local Kill = { PerTarget = 1.5, Running = false }

local function myKnife()
	local char = player.Character
	local bp = player:FindFirstChildOfClass("Backpack")
	return (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife"))
end

local function stab(knife, targetRoot)
	knife:Activate()
	local handle = knife:FindFirstChild("Handle")
	if handle and typeof(firetouchinterest) == "function" then
		pcall(function()
			firetouchinterest(handle, targetRoot, 0)
			firetouchinterest(handle, targetRoot, 1)
		end)
	end
end

function MM2.killAll(opts)
	if not MM2.inGame() then return nil, "Not in Murder Mystery 2." end
	if Kill.Running then return nil, "Already running." end
	local perTarget = (opts and opts.PerTarget) or Kill.PerTarget
	local knife = myKnife()
	if not knife then return nil, "You don't have the knife, you're not the murderer." end
	local hum, root = getHumanoid(), getRoot()
	if not (hum and root and hum.Health > 0) then return nil, "You're dead." end
	Kill.Running = true
	if knife.Parent ~= player.Character then
		hum:EquipTool(knife)
		task.wait(0.15)
	end
	local killed = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if not Kill.Running or not alive then break end
		if plr ~= player then
			local char = plr.Character
			local thum = char and char:FindFirstChildOfClass("Humanoid")
			local troot = char and char:FindFirstChild("HumanoidRootPart")
			if thum and troot and thum.Health > 0 then
				local deadline = os.clock() + perTarget
				local lastStab = 0
				while thum.Parent and thum.Health > 0 and os.clock() < deadline and Kill.Running do
					root = getRoot()
					if not root or knife.Parent ~= player.Character then break end
					troot.CFrame = root.CFrame * CFrame.new(0, 0, -2)
					troot.AssemblyLinearVelocity = Vector3.zero
					if os.clock() - lastStab > 0.1 then
						lastStab = os.clock()
						stab(knife, troot)
					end
					RunService.Heartbeat:Wait()
				end
				if thum.Health <= 0 then killed += 1 end
			end
		end
	end
	Kill.Running = false
	return killed
end

function MM2.stopKillAll() Kill.Running = false end
function MM2.isKilling() return Kill.Running end

----------------------------------------------------------------------
-- Event log: prints every Remotes.Gameplay event (to find e.g. the round-end event)
----------------------------------------------------------------------
local loggerHooked = false
function MM2.logEvents(on)
	Log.Enabled = on == true
	if not Log.Enabled or loggerHooked then return end
	loggerHooked = true
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
		if not remotes then return end
		local function hook(obj)
			if obj:IsA("RemoteEvent") then
				track(obj.OnClientEvent:Connect(function(...)
					if not Log.Enabled then return end
					local args = {}
					for i, v in ipairs({ ... }) do args[i] = tostring(v) end
					print(("[MM2] %s  (%s)"):format(obj:GetFullName(), table.concat(args, ", ")))
				end))
			end
		end
		for _, obj in ipairs(remotes:GetDescendants()) do hook(obj) end
		track(remotes.DescendantAdded:Connect(hook))
	end)
end

----------------------------------------------------------------------
function MM2.destroy()
	alive = false
	Farm.Enabled = false
	Esp.Enabled = false
	Kill.Running = false
	Log.Enabled = false
	if currentTween then currentTween:Cancel() end
	local hum = getHumanoid()
	if hum and hum.PlatformStand then hum.PlatformStand = false end
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	if espFolder then espFolder:Destroy() end
end

return MM2
