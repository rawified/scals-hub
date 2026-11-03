--[[
    Scals Hub - Universal library
    WalkSpeed, Infinite Jump, Fly, ESP and Aimbot that work in every game. No UI.

        local U = loadstring(game:HttpGet(REPO .. "libs/universal.lua"))()

    MOVEMENT
        U.walkSpeed(true / false)      U.setWalkSpeed(32)     -- re-applied every frame
        U.infiniteJump(true / false)

    FLY
        U.fly(true / false)
        U.setFly({ Mode = "Noclip" | "Platform", Speed = 50, VerticalSpeed = 30, ShowPlatform = true })
        -- Noclip: WASD flies where you look, Space up, Left Ctrl down, through everything
        -- Platform: walk on a part that follows you, Space / Left Ctrl raise / lower it

    ESP (players, optionally NPCs = models whose PrimaryPart is HumanoidRootPart)
        U.setEsp({
            Boxes = false, Names = true, Chams = false, ChamsFill = 0.5,
            TeamCheck = false, Color = "Team Color", IncludeNPCs = false,
        })
        U.EspColors                   -- { "Team Color", "White", "Red", "Green", "Blue", "Yellow", "Purple" }

    AIMBOT
        U.aimbot(true / false)
        U.setAimbot({
            Activation = "Hold Right Mouse" | "Always", Method = "Camera" | "Mouse",
            Part = "Head" | "Torso", UseFov = true, ShowFov = true, Fov = 120, Smoothing = 5,
            TeamCheck = true, WallCheck = false, IncludeNPCs = false,
        })
        U.getAimTarget()              -- the Player / NPC model it's locked on, or nil
        U.hasMouseMove()              -- the executor has mousemoverel (needed for Method = "Mouse")

    U.Settings / U.Fly / U.Esp / U.Aim -- current settings (change them with the set functions)
    U.destroy()                       -- turns everything off and disconnects
]]

local U = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local connections = {}
local function track(conn)
	table.insert(connections, conn)
	return conn
end

local function getHumanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function merge(into, opts, skip)
	for k, v in pairs(opts or {}) do
		if k ~= skip and into[k] ~= nil then into[k] = v end
	end
end

local Settings = { SpeedEnabled = false, WalkSpeed = 32, InfiniteJump = false }
local Fly = { Enabled = false, Mode = "Noclip", Speed = 50, VerticalSpeed = 30, ShowPlatform = true }
local Esp = {
	Boxes = false,
	Names = true,
	Chams = false,
	ChamsFill = 0.5, -- 0 = solid fill, 1 = outline only
	TeamCheck = false,
	Color = "Team Color",
	IncludeNPCs = false,
}
local Aim = {
	Enabled = false,
	Activation = "Hold Right Mouse",
	Method = "Camera",
	Part = "Head",
	UseFov = true,
	ShowFov = true,
	Fov = 120,
	Smoothing = 5,
	TeamCheck = true,
	WallCheck = false,
	IncludeNPCs = false,
}
U.Settings, U.Fly, U.Esp, U.Aim = Settings, Fly, Esp, Aim

----------------------------------------------------------------------
-- WalkSpeed (games reset it, so it's re-applied every frame; the game's own speed comes back
-- when it's switched off) and Infinite Jump
----------------------------------------------------------------------
local speedHum, defaultSpeed
local function restoreSpeed()
	if speedHum and speedHum.Parent and defaultSpeed then speedHum.WalkSpeed = defaultSpeed end
	speedHum, defaultSpeed = nil, nil
end

track(RunService.Heartbeat:Connect(function()
	if not Settings.SpeedEnabled then return end
	local hum = getHumanoid()
	if not hum then return end
	if hum ~= speedHum then speedHum, defaultSpeed = hum, hum.WalkSpeed end
	if hum.WalkSpeed ~= Settings.WalkSpeed then hum.WalkSpeed = Settings.WalkSpeed end
end))

function U.walkSpeed(on)
	Settings.SpeedEnabled = on == true
	if not Settings.SpeedEnabled then restoreSpeed() end
end
function U.setWalkSpeed(v)
	Settings.WalkSpeed = tonumber(v) or Settings.WalkSpeed
end

local lastJump = 0
track(UserInputService.JumpRequest:Connect(function()
	if not Settings.InfiniteJump then return end
	local now = os.clock()
	if now - lastJump < 0.1 then return end -- holding space would rocket you up
	lastJump = now
	local hum = getHumanoid()
	if hum and hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

function U.infiniteJump(on)
	Settings.InfiniteJump = on == true
end

----------------------------------------------------------------------
-- Fly
----------------------------------------------------------------------
local flyState = {} -- { root, hum, mode, collisions = { [part] = true }, platform, platformY, jumpOff }

local function stopFly()
	local s = flyState
	if s.platform then s.platform:Destroy() end
	for part in pairs(s.collisions or {}) do
		if part.Parent then part.CanCollide = true end
	end
	if s.hum and s.hum.Parent then
		s.hum.PlatformStand = false
		if s.jumpOff then s.hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end
	end
	flyState = {}
end

local function feetOffset(hum, root)
	if hum.RigType == Enum.HumanoidRigType.R15 then return hum.HipHeight + root.Size.Y / 2 end
	return 3
end

local function verticalInput()
	if UserInputService:GetFocusedTextBox() then return 0 end
	local v = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then v += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then v -= 1 end
	return v
end

local function noclipDirection(cam, hum)
	local dir = Vector3.zero
	if not UserInputService:GetFocusedTextBox() then
		local cf = cam.CFrame
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
	end
	if dir.Magnitude == 0 then dir = hum.MoveDirection end -- mobile thumbstick
	dir += Vector3.yAxis * verticalInput()
	return dir.Magnitude > 0 and dir.Unit or Vector3.zero
end

track(RunService.Stepped:Connect(function()
	local s = flyState
	if not (Fly.Enabled and s.mode == "Noclip" and s.root) then return end
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			s.collisions[part] = true
			part.CanCollide = false
		end
	end
end))

track(RunService.Heartbeat:Connect(function(dt)
	if not Fly.Enabled then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not (hum and root and cam and hum.Health > 0) then return end
	local s = flyState
	if s.root ~= root or s.mode ~= Fly.Mode then -- started, respawned, or the mode changed
		stopFly()
		s = { root = root, hum = hum, mode = Fly.Mode, collisions = {} }
		flyState = s
		if Fly.Mode == "Platform" then
			local p = Instance.new("Part")
			p.Name = "Part"
			p.Size = Vector3.new(6, 0.5, 6)
			p.Anchored = true
			p.CanCollide = true
			p.Material = Enum.Material.SmoothPlastic
			p.Color = Color3.fromRGB(240, 240, 240)
			p.Parent = workspace
			s.platform = p
			s.platformY = root.Position.Y - feetOffset(hum, root) - p.Size.Y / 2
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) -- Space raises the platform
			s.jumpOff = true
		end
	end
	if Fly.Mode == "Noclip" then
		hum.PlatformStand = true
		local pos = root.Position + noclipDirection(cam, hum) * Fly.Speed * dt
		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(pos, pos + flat)
		else
			root.CFrame = root.CFrame.Rotation + pos
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	else
		local dy = verticalInput() * Fly.VerticalSpeed * dt
		if dy ~= 0 then
			s.platformY += dy
			root.CFrame += Vector3.new(0, dy, 0)
		end
		s.platform.CFrame = CFrame.new(root.Position.X, s.platformY, root.Position.Z)
		s.platform.Transparency = Fly.ShowPlatform and 0.6 or 1
	end
end))

function U.fly(on)
	Fly.Enabled = on == true
	if not Fly.Enabled then stopFly() end
end
function U.setFly(opts)
	merge(Fly, opts, "Enabled") -- a running flight switches mode on the next frame
end

----------------------------------------------------------------------
-- ESP
----------------------------------------------------------------------
local hiddenParent
pcall(function()
	if typeof(gethui) == "function" then hiddenParent = gethui() end
end)
if not hiddenParent then
	pcall(function()
		local core = game:GetService("CoreGui")
		local probe = Instance.new("Folder")
		probe.Parent = core
		probe:Destroy()
		hiddenParent = core
	end)
end

local espGui = Instance.new("ScreenGui")
espGui.Name = "ScalsESP"
espGui.IgnoreGuiInset = true
espGui.ResetOnSpawn = false
espGui.DisplayOrder = 10
espGui.Parent = hiddenParent or player:WaitForChild("PlayerGui")

local chamsFolder = Instance.new("Folder")
chamsFolder.Name = "ScalsChams"
chamsFolder.Parent = hiddenParent or workspace

local Colors = {
	White = Color3.fromRGB(245, 245, 245),
	Red = Color3.fromRGB(255, 70, 70),
	Green = Color3.fromRGB(80, 230, 120),
	Blue = Color3.fromRGB(80, 150, 255),
	Yellow = Color3.fromRGB(255, 220, 70),
	Purple = Color3.fromRGB(180, 100, 255),
}
U.EspColors = { "Team Color", "White", "Red", "Green", "Blue", "Yellow", "Purple" }

local function espColor(key)
	if Esp.Color == "Team Color" then
		return key:IsA("Player") and key.Team and key.TeamColor.Color or Colors.White
	end
	return Colors[Esp.Color] or Colors.White
end

local function isTeammate(key)
	return Esp.TeamCheck and key:IsA("Player") and key.Team ~= nil and key.Team == player.Team
end

local npcs = {}
local function isNpc(model)
	local root = model.PrimaryPart
	return root ~= nil and root.Name == "HumanoidRootPart" and model:IsDescendantOf(workspace)
		and Players:GetPlayerFromCharacter(model) == nil
end

-- model, root part and display name of a live target, or nil
local function targetInfo(key, includeNpcs)
	if key:IsA("Player") then
		local char = key.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (root and hum and hum.Health > 0) then return nil end
		return char, root, key.DisplayName
	end
	if not (includeNpcs and isNpc(key)) then return nil end
	local hum = key:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then return nil end
	return key, key.PrimaryPart, key.Name
end

local esp = {}
local function createEsp(plr)
	if plr == player or esp[plr] then return end
	local box = Instance.new("Frame")
	box.Name = plr.Name
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	box.Visible = false
	box.Parent = espGui
	local outline = Instance.new("UIStroke") -- thick dark line under a thin colored one
	outline.Thickness = 3
	outline.Transparency = 0.4
	outline.Color = Color3.new(0, 0, 0)
	outline.Parent = box
	local inner = Instance.new("Frame")
	inner.Size = UDim2.fromScale(1, 1)
	inner.BackgroundTransparency = 1
	inner.BorderSizePixel = 0
	inner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Parent = inner
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, -3)
	label.Size = UDim2.fromOffset(200, 14)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.TextStrokeTransparency = 0.4
	label.Text = ""
	label.Parent = box
	local hl = Instance.new("Highlight")
	hl.Name = plr.Name
	hl.Enabled = false
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.OutlineTransparency = 0
	hl.Parent = chamsFolder
	esp[plr] = { box = box, stroke = stroke, label = label, highlight = hl }
end

local function removeEsp(plr)
	local e = esp[plr]
	if not e then return end
	e.box:Destroy()
	e.highlight:Destroy()
	esp[plr] = nil
end

for _, plr in ipairs(Players:GetPlayers()) do createEsp(plr) end
track(Players.PlayerAdded:Connect(createEsp))
track(Players.PlayerRemoving:Connect(removeEsp))

-- NPC tracking starts the first time ESP or aimbot NPCs are switched on
local npcTracking = false
local function addNpcCandidate(inst)
	if inst.Name ~= "HumanoidRootPart" or not inst:IsA("BasePart") then return end
	local model = inst.Parent
	if not (model and model:IsA("Model")) or npcs[model] then return end
	if Players:GetPlayerFromCharacter(model) then return end
	npcs[model] = true
	createEsp(model)
end
local function startNpcTracking()
	if npcTracking then return end
	npcTracking = true
	track(workspace.DescendantAdded:Connect(addNpcCandidate))
	task.spawn(function()
		for i, d in ipairs(workspace:GetDescendants()) do
			addNpcCandidate(d)
			if i % 5000 == 0 then task.wait() end -- don't freeze big maps
		end
	end)
end

local HEAD_OFFSET = Vector3.new(0, 2.6, 0)
local FEET_OFFSET = Vector3.new(0, 3.2, 0)

local function hide(e)
	e.box.Visible = false
	e.highlight.Enabled = false
end

track(RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local anyOn = Esp.Boxes or Esp.Chams
	local myChar = player.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	for key, e in pairs(esp) do
		if not key:IsA("Player") and not key:IsDescendantOf(workspace) then
			removeEsp(key)
			npcs[key] = nil
			continue
		end
		local char, root, name = targetInfo(key, Esp.IncludeNPCs)
		if not (anyOn and cam and char) or isTeammate(key) then
			hide(e)
			continue
		end
		local color = espColor(key)
		local hl = e.highlight
		if Esp.Chams then
			if hl.Adornee ~= char then hl.Adornee = char end
			hl.FillColor = color
			hl.OutlineColor = color
			hl.FillTransparency = Esp.ChamsFill
			hl.Enabled = true
		else
			hl.Enabled = false
		end
		local boxShown = false
		if Esp.Boxes then
			local pos = root.Position
			local top = cam:WorldToViewportPoint(pos + HEAD_OFFSET)
			local bottom = cam:WorldToViewportPoint(pos - FEET_OFFSET)
			if top.Z > 0 and bottom.Z > 0 then
				local h = math.max(bottom.Y - top.Y, 4)
				local w = h * 0.6
				local cx = (top.X + bottom.X) / 2
				e.box.Position = UDim2.fromOffset(cx - w / 2, top.Y)
				e.box.Size = UDim2.fromOffset(w, h)
				e.stroke.Color = color
				if Esp.Names then
					local dist = myRoot and math.floor((myRoot.Position - pos).Magnitude + 0.5)
					e.label.Text = dist and ("%s [%d]"):format(name, dist) or name
					e.label.TextColor3 = color
					e.label.Visible = true
				else
					e.label.Visible = false
				end
				boxShown = true
			end
		end
		e.box.Visible = boxShown
	end
end))

function U.setEsp(opts)
	merge(Esp, opts)
	if Esp.IncludeNPCs then startNpcTracking() end
end

----------------------------------------------------------------------
-- Aimbot: while the aim key is held, turns the camera (or moves the mouse) toward the target
-- closest to the cursor, and stays locked on it while it's still valid
----------------------------------------------------------------------
local fovCircle = Instance.new("Frame")
fovCircle.Name = "FovCircle"
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.BackgroundTransparency = 1
fovCircle.Visible = false
fovCircle.Parent = espGui
local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle
local fovStroke = Instance.new("UIStroke")
fovStroke.Thickness = 1.5
fovStroke.Transparency = 0.3
fovStroke.Color = Color3.new(1, 1, 1)
fovStroke.Parent = fovCircle

local aimRay = RaycastParams.new()
aimRay.FilterType = Enum.RaycastFilterType.Exclude
local hasMouseMove = typeof(mousemoverel) == "function"
function U.hasMouseMove() return hasMouseMove end

local function partNamed(model, n)
	local p = model:FindFirstChild(n)
	return p and p:IsA("BasePart") and p or nil
end
local function aimPart(char, root)
	if Aim.Part == "Head" then return partNamed(char, "Head") or root end
	return partNamed(char, "UpperTorso") or partNamed(char, "Torso") or root
end
local function canSee(cam, part, char)
	if not Aim.WallCheck then return true end
	local myChar = player.Character
	aimRay.FilterDescendantsInstances = myChar and { myChar } or {}
	local origin = cam.CFrame.Position
	local result = workspace:Raycast(origin, part.Position - origin, aimRay)
	return not result or result.Instance:IsDescendantOf(char)
end
local function screenDistance(key, cam, mousePos)
	if key == player then return nil end
	local char, root = targetInfo(key, Aim.IncludeNPCs)
	if not char then return nil end
	if Aim.TeamCheck and key:IsA("Player") and key.Team ~= nil and key.Team == player.Team then return nil end
	local part = aimPart(char, root)
	if not part then return nil end
	local sp, onScreen = cam:WorldToViewportPoint(part.Position)
	if not onScreen then return nil end
	local d = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
	if Aim.UseFov and d > Aim.Fov then return nil end
	if not canSee(cam, part, char) then return nil end
	return d, part, sp
end
local function aimHeld()
	if Aim.Activation == "Always" then return true end
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

local lockedTarget
-- right after Roblox's camera update, so our aim isn't overwritten that frame
RunService:BindToRenderStep("ScalsAimbot", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local mousePos = UserInputService:GetMouseLocation()
	fovCircle.Visible = Aim.Enabled and Aim.UseFov and Aim.ShowFov
	if fovCircle.Visible then
		fovCircle.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
		fovCircle.Size = UDim2.fromOffset(Aim.Fov * 2, Aim.Fov * 2)
	end
	if not (Aim.Enabled and aimHeld()) then
		lockedTarget = nil
		return
	end
	local _, part, sp
	if lockedTarget then _, part, sp = screenDistance(lockedTarget, cam, mousePos) end
	if not part then
		lockedTarget = nil
		local best
		local function consider(key)
			local d, p, s = screenDistance(key, cam, mousePos)
			if d and (not best or d < best) then best, lockedTarget, part, sp = d, key, p, s end
		end
		for _, plr in ipairs(Players:GetPlayers()) do consider(plr) end
		if Aim.IncludeNPCs then
			for model in pairs(npcs) do consider(model) end
		end
	end
	if not part then return end
	local alpha = 1 - (1 - 1 / Aim.Smoothing) ^ (dt * 60) -- same feel at any frame rate
	if Aim.Method == "Mouse" and hasMouseMove then
		local delta = (Vector2.new(sp.X, sp.Y) - mousePos) * alpha
		mousemoverel(delta.X, delta.Y)
	else
		local camPos = cam.CFrame.Position
		cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(camPos, part.Position), alpha)
	end
end)

function U.aimbot(on)
	Aim.Enabled = on == true
	if not Aim.Enabled then lockedTarget = nil end
end
function U.setAimbot(opts)
	merge(Aim, opts, "Enabled")
	if Aim.IncludeNPCs then startNpcTracking() end
end
function U.getAimTarget()
	return lockedTarget
end

----------------------------------------------------------------------
function U.destroy()
	Settings.SpeedEnabled = false
	Settings.InfiniteJump = false
	Aim.Enabled = false
	Fly.Enabled = false
	stopFly()
	pcall(function() RunService:UnbindFromRenderStep("ScalsAimbot") end)
	restoreSpeed()
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	espGui:Destroy()
	chamsFolder:Destroy()
end

return U
