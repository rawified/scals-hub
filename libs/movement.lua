--[[
    Scals Hub - Movement library
    Tweening, teleporting, flying and noclip for your own character.

        local Move = loadstring(game:HttpGet(REPO .. "libs/movement.lua"))()

    TARGETS
    Anything that takes a "target" accepts: Vector3, CFrame, BasePart, Model, Player,
    a player's name (partial, case-insensitive), or an Attachment.

    TWEENING
        local t = Move.tweenTo(target, {
            Speed = 80,                  -- studs per second (default)    -- or Time = 2 (seconds)
            Offset = Vector3.new(0,3,0), -- added to the target position   (or a CFrame offset)
            Style = Enum.EasingStyle.Linear, Direction = Enum.EasingDirection.InOut,
            Noclip = true,               -- pass through walls while moving (default true)
            KeepRotation = false,        -- true = don't turn toward the target's rotation
            Flat = false,                -- true = stay at your current height
        })
        t:Wait()       -- yields until done; returns true if it finished, false if cancelled
        t:Cancel()
        t.Completed    -- bool
        Move.tweenPath({ p1, p2, p3 }, opts)   -- tweens through every point, returns a handle the same way
        Move.stopTween()                       -- cancels whatever is tweening

    TELEPORTING
        Move.teleport(target, { Offset = ..., KeepRotation = false })
        Move.teleportSteps(target, { StepSize = 20, Delay = 0.05, Offset = ... })  -- short hops (for anti-TP checks)
        Move.teleportBehind(target, distance)  -- behind a player / part, facing it
        Move.savePosition(name) / Move.loadPosition(name)

    FLY
        Move.fly(true, { Speed = 60, Mode = "Velocity" | "CFrame" })   -- WASD + Space / LeftCtrl
        Move.fly(false)
        Move.setFlySpeed(100)
        Move.isFlying()

    NOCLIP
        Move.noclip(true) / Move.noclip(false)
        Move.isNoclipping()

    OTHER
        Move.getCharacter(), Move.getRoot(), Move.getHumanoid()
        Move.getPosition(target) -> Vector3   Move.getCFrame(target) -> CFrame
        Move.findPlayer("partialName")
        Move.freeze(true / false)              -- anchors your root part
        Move.destroy()                          -- turns everything off and disconnects

    Fly and noclip survive respawning: they switch back on for the new character.
]]

local Move = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local connections = {}

local function track(c)
	table.insert(connections, c)
	return c
end

----------------------------------------------------------------------
-- Character helpers
----------------------------------------------------------------------
function Move.getCharacter()
	return player.Character
end

function Move.getRoot(char)
	char = char or player.Character
	return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

function Move.getHumanoid(char)
	char = char or player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

function Move.findPlayer(name)
	if typeof(name) == "Instance" and name:IsA("Player") then return name end
	name = tostring(name):lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == name or p.DisplayName:lower() == name then return p end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name then
			return p
		end
	end
	return nil
end

-- Any target -> CFrame (nil if it can't be resolved)
function Move.getCFrame(target)
	local t = typeof(target)
	if t == "CFrame" then return target end
	if t == "Vector3" then return CFrame.new(target) end
	if t == "string" then target = Move.findPlayer(target) t = typeof(target) end
	if t ~= "Instance" or not target then return nil end

	if target:IsA("Player") then
		local root = Move.getRoot(target.Character)
		return root and root.CFrame
	end
	if target:IsA("BasePart") then return target.CFrame end
	if target:IsA("Model") then
		local root = Move.getRoot(target)
		if root then return root.CFrame end
		local ok, cf = pcall(target.GetPivot, target)
		return ok and cf or nil
	end
	if target:IsA("Attachment") then return target.WorldCFrame end
	return nil
end

function Move.getPosition(target)
	local cf = Move.getCFrame(target)
	return cf and cf.Position
end

-- Where the root should end up for a target + opts
local function goalCFrame(root, target, opts)
	local cf = Move.getCFrame(target)
	if not cf then return nil end
	local offset = opts.Offset
	if typeof(offset) == "Vector3" then
		cf = cf + offset
	elseif typeof(offset) == "CFrame" then
		cf = cf * offset
	end
	if opts.Flat then
		cf = cf.Rotation + Vector3.new(cf.X, root.Position.Y, cf.Z)
	end
	-- plain positions have no useful rotation, so keep facing the way we face
	if opts.KeepRotation or typeof(target) == "Vector3" then
		cf = root.CFrame.Rotation + cf.Position
	end
	return cf
end

----------------------------------------------------------------------
-- Noclip
-- Collisions are switched off right before every physics step, and the
-- parts we touched are put back when it's turned off.
----------------------------------------------------------------------
local noclipState = { enabled = false, users = 0, changed = {} }

local function noclipStep()
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			noclipState.changed[part] = true
			part.CanCollide = false
		end
	end
end

local function restoreCollisions()
	for part in pairs(noclipState.changed) do
		if part.Parent then part.CanCollide = true end
	end
	table.clear(noclipState.changed)
end

local noclipConn
local function refreshNoclip()
	local want = noclipState.enabled or noclipState.users > 0
	if want and not noclipConn then
		noclipConn = RunService.Stepped:Connect(noclipStep)
	elseif not want and noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
		restoreCollisions()
	end
end

function Move.noclip(on)
	noclipState.enabled = on and true or false
	refreshNoclip()
end

function Move.isNoclipping()
	return noclipState.enabled
end

-- temporary noclip used by tweens / fly (doesn't touch the user's own setting)
local function pushNoclip() noclipState.users += 1 refreshNoclip() end
local function popNoclip() noclipState.users = math.max(noclipState.users - 1, 0) refreshNoclip() end

----------------------------------------------------------------------
-- Tweening
----------------------------------------------------------------------
local activeTween -- the handle currently running

local function newHandle()
	local h = { Completed = false, Cancelled = false, _done = Instance.new("BindableEvent") }
	function h:Wait()
		if not (self.Completed or self.Cancelled) then self._done.Event:Wait() end
		return self.Completed
	end
	function h:Cancel()
		if self.Completed or self.Cancelled then return end
		self.Cancelled = true
		if self._tween then self._tween:Cancel() end
		if self._finish then self._finish() end
	end
	return h
end

-- Runs one TweenService tween on the root, keeping velocity at 0 so gravity doesn't fight it
local function tweenRoot(handle, root, goal, opts)
	local hum = Move.getHumanoid()
	local dist = (goal.Position - root.Position).Magnitude
	local time = opts.Time or (dist / math.max(opts.Speed or 80, 1))

	local tween = TweenService:Create(root, TweenInfo.new(
		math.max(time, 0.03),
		opts.Style or Enum.EasingStyle.Linear,
		opts.Direction or Enum.EasingDirection.InOut
	), { CFrame = goal })
	handle._tween = tween

	local useNoclip = opts.Noclip ~= false
	if useNoclip then pushNoclip() end
	local hold = RunService.Heartbeat:Connect(function()
		if root.Parent then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
	if hum then hum.PlatformStand = true end

	local finished = Instance.new("BindableEvent")
	local cleaned = false
	local function cleanup()
		if cleaned then return end
		cleaned = true
		hold:Disconnect()
		if useNoclip then popNoclip() end
		if hum and hum.Parent then hum.PlatformStand = false end
		finished:Fire()
	end
	handle._finish = cleanup

	tween.Completed:Connect(cleanup)
	-- died / respawned mid-tween
	local diedConn = hum and hum.Died:Connect(function() handle:Cancel() end)
	tween:Play()
	if not cleaned then finished.Event:Wait() end
	if diedConn then diedConn:Disconnect() end
	finished:Destroy()
	return tween.PlaybackState == Enum.PlaybackState.Completed and not handle.Cancelled
end

-- Tweens through every point in order. Doesn't yield; use handle:Wait().
function Move.tweenPath(points, opts)
	opts = opts or {}
	if activeTween then activeTween:Cancel() end
	local handle = newHandle()
	activeTween = handle

	task.spawn(function()
		for _, target in ipairs(points) do
			if handle.Cancelled then break end
			local root = Move.getRoot()
			local goal = root and goalCFrame(root, target, opts)
			if not goal then handle:Cancel() break end
			if not tweenRoot(handle, root, goal, opts) then
				handle.Cancelled = true
				break
			end
		end
		if not handle.Cancelled then handle.Completed = true end
		if activeTween == handle then activeTween = nil end
		handle._done:Fire()
	end)
	return handle
end

function Move.tweenTo(target, opts)
	return Move.tweenPath({ target }, opts)
end

function Move.stopTween()
	if activeTween then activeTween:Cancel() end
end

function Move.isTweening()
	return activeTween ~= nil
end

----------------------------------------------------------------------
-- Teleporting
----------------------------------------------------------------------
function Move.teleport(target, opts)
	opts = opts or {}
	local root = Move.getRoot()
	local goal = root and goalCFrame(root, target, opts)
	if not goal then return false end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	-- PivotTo moves the whole character even if something is welded oddly
	local char = player.Character
	local delta = goal * root.CFrame:Inverse()
	char:PivotTo(delta * char:GetPivot())
	return true
end

-- Many short hops instead of one big jump (yields). opts: StepSize, Delay, Offset, KeepRotation
function Move.teleportSteps(target, opts)
	opts = opts or {}
	local root = Move.getRoot()
	local goal = root and goalCFrame(root, target, opts)
	if not goal then return false end
	local step = opts.StepSize or 20
	local start = root.Position
	local dist = (goal.Position - start).Magnitude
	local hops = math.max(math.ceil(dist / step), 1)
	for i = 1, hops do
		root = Move.getRoot()
		if not root then return false end
		local cf = root.CFrame.Rotation + start:Lerp(goal.Position, i / hops)
		if i == hops then cf = goal end
		Move.teleport(cf, { KeepRotation = false })
		task.wait(opts.Delay or 0.05)
	end
	return true
end

-- Stand `distance` studs behind a player / part, facing it
function Move.teleportBehind(target, distance)
	local cf = Move.getCFrame(target)
	if not cf then return false end
	local pos = cf.Position - cf.LookVector * (distance or 3)
	return Move.teleport(CFrame.lookAt(pos, cf.Position))
end

local saved = {}
function Move.savePosition(name)
	local root = Move.getRoot()
	if root then saved[name or "default"] = root.CFrame end
	return saved[name or "default"]
end

function Move.loadPosition(name, opts)
	local cf = saved[name or "default"]
	return cf and Move.teleport(cf, opts) or false
end

function Move.freeze(on)
	local root = Move.getRoot()
	if root then root.Anchored = on and true or false end
end

----------------------------------------------------------------------
-- Fly
-- "Velocity": sets the root's velocity (smooth, plays nicer with physics)
-- "CFrame"  : moves the root's CFrame directly (works when velocity is reset by the game)
----------------------------------------------------------------------
local flyState = { enabled = false, speed = 60, mode = "Velocity", noclip = false }
local flyConn

local function flyDirection(cam, hum)
	local dir = Vector3.zero
	if not UserInputService:GetFocusedTextBox() then
		local cf = cam.CFrame
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
	end
	if dir.Magnitude == 0 and hum then
		dir = hum.MoveDirection -- mobile thumbstick
	end
	return dir.Magnitude > 0 and dir.Unit or Vector3.zero
end

local function stopFlyLoop()
	if flyConn then flyConn:Disconnect() flyConn = nil end
	local hum = Move.getHumanoid()
	if hum then hum.PlatformStand = false end
	local root = Move.getRoot()
	if root then root.AssemblyLinearVelocity = Vector3.zero end
end

local function startFlyLoop()
	if flyConn then return end
	flyConn = RunService.Heartbeat:Connect(function(dt)
		local char = player.Character
		local hum = Move.getHumanoid(char)
		local root = Move.getRoot(char)
		local cam = workspace.CurrentCamera
		if not (hum and root and cam) or hum.Health <= 0 or activeTween then return end

		hum.PlatformStand = true
		local dir = flyDirection(cam, hum)
		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)

		if flyState.mode == "CFrame" then
			local pos = root.Position + dir * flyState.speed * dt
			root.CFrame = flat.Magnitude > 0.01 and CFrame.lookAt(pos, pos + flat) or (root.CFrame.Rotation + pos)
			root.AssemblyLinearVelocity = Vector3.zero
		else
			root.AssemblyLinearVelocity = dir * flyState.speed
			if flat.Magnitude > 0.01 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		end
		root.AssemblyAngularVelocity = Vector3.zero
	end)
end

-- opts: Speed, Mode ("Velocity" | "CFrame"), Noclip (true = also noclip while flying)
function Move.fly(on, opts)
	opts = opts or {}
	if opts.Speed then flyState.speed = opts.Speed end
	if opts.Mode then flyState.mode = opts.Mode end
	local wantNoclip = opts.Noclip == true

	if on and not flyState.enabled then
		flyState.enabled = true
		flyState.noclip = wantNoclip
		if wantNoclip then pushNoclip() end
		startFlyLoop()
	elseif not on and flyState.enabled then
		flyState.enabled = false
		if flyState.noclip then popNoclip() end
		flyState.noclip = false
		stopFlyLoop()
	end
end

function Move.setFlySpeed(speed)
	flyState.speed = speed
end

function Move.isFlying()
	return flyState.enabled
end

----------------------------------------------------------------------
-- Respawn: fly loop keeps running (it reads the new character every frame),
-- noclip reads player.Character every step, so both carry over automatically.
-- Tweens are cancelled because their root part is gone.
----------------------------------------------------------------------
track(player.CharacterAdded:Connect(function()
	Move.stopTween()
	table.clear(noclipState.changed)
end))

----------------------------------------------------------------------
-- Cleanup
----------------------------------------------------------------------
function Move.destroy()
	Move.stopTween()
	Move.fly(false)
	noclipState.enabled = false
	noclipState.users = 0
	refreshNoclip()
	for _, c in ipairs(connections) do c:Disconnect() end
	table.clear(connections)
end

return Move
