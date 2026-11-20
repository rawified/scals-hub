--[[
    Scals Hub - Shooter library (PlaceId / GameId 78884249003161)
    The Universal features (WalkSpeed, Infinite Jump, Fly, ESP) plus an aimbot tuned for this game's
    guns (K-433, GX-36, SK-556, RN-545, MX-65, BT-762). No UI.

        local S = loadstring(game:HttpGet(REPO .. "libs/shooter.lua"))()

    MOVEMENT / FLY / ESP: same as libs/universal.lua
        S.walkSpeed(on)  S.setWalkSpeed(32)  S.infiniteJump(on)
        S.fly(on)  S.setFly({ Mode, Speed, VerticalSpeed, ShowPlatform })
        S.setEsp({ Boxes, Names, Chams, ChamsFill, TeamCheck, Color, IncludeNPCs })   S.EspColors

    AIMBOT (what's different from Universal)
        - Method "Mouse" by default: the game drives its own camera, so camera aim gets overwritten.
          "Camera" still exists and now runs after the game's camera code.
        - Mouse moves are scaled by the zoom, so aiming down sights (FOV 20-44) doesn't overshoot.
        - The wall check ignores your gun model (it lives in the camera).
        - Part "Auto": head while aiming down sights, chest when your hip-fire spread would miss the head.
        - Recoil Control pulls the gun back down while you shoot (when nothing is locked).
        - Activation "Hold Right Mouse" (aiming), "Hold Left or Right Mouse" (also hip fire) or "Always".
        - Prediction: leads moving targets by your ping.

        S.aimbot(true / false)
        S.setAimbot({
            Activation = "Hold Right Mouse", Method = "Mouse", Part = "Auto" | "Head" | "Torso",
            UseFov = true, ShowFov = true, Fov = 120, Smoothing = 4,
            TeamCheck = true, WallCheck = true, IncludeNPCs = false,
            Prediction = false, RecoilControl = true, RecoilStrength = 0.8,  -- 0-1
        })
        S.recoilControl(true / false)
        S.getAimTarget()             -- the Player / NPC it's locked on, or nil
        S.getWeapon()                -- stats of the gun you're holding (from Weapons), or nil
        S.Weapons                    -- every gun: interval, mag, spread, aimFov, kick, damage
        S.hasMouseMove()

    S.destroy()                      -- turns everything off and disconnects
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
	Method = typeof(mousemoverel) == "function" and "Mouse" or "Camera",
	Part = "Auto",
	UseFov = true,
	ShowFov = true,
	Fov = 120,
	Smoothing = 4,
	TeamCheck = true,
	WallCheck = true,
	IncludeNPCs = false,
	Prediction = false,
	RecoilControl = false,
	RecoilStrength = 0.8,
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
espGui.Name = "ScalsShooterESP"
espGui.IgnoreGuiInset = true
espGui.ResetOnSpawn = false
espGui.DisplayOrder = 10
espGui.Parent = hiddenParent or player:WaitForChild("PlayerGui")

local chamsFolder = Instance.new("Folder")
chamsFolder.Name = "ScalsShooterChams"
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
-- Guns (from the game's weapon module). spread = degrees, aimFov = camera FOV while aiming down
-- sights, kick = camera kick per shot in degrees (X = up), damage = { from distance, damage }
----------------------------------------------------------------------
local V = Vector3.new
local Weapons = {
	K433 = { id = "K433", name = "K-433", interval = 0.08, mag = 30, aimFov = 38.3,
		spread = { hip = 1.6, aim = 0.08 }, aimKick = V(0.3, 0.4, 1.1), hipKick = V(0.9, 0.8, 1.3),
		damage = { { 0, 41.2 }, { 21.5, 34.3 }, { 75, 29.4 } } },
	GX36 = { id = "GX36", name = "GX-36", interval = 0.083, mag = 30, aimFov = 33.1,
		spread = { hip = 1.6, aim = 0.06 }, aimKick = V(0.3, 0.3, 1), hipKick = V(1, 0.6, 1.2),
		damage = { { 0, 41.2 }, { 21.5, 34.3 }, { 75, 29.4 } } },
	SK556 = { id = "SK556", name = "SK-556", interval = 0.106, mag = 30, aimFov = 19.7,
		spread = { hip = 1.6, aim = 0.05 }, aimKick = V(0.45, 0.2, 0.8), hipKick = V(1.3, 0.5, 1),
		damage = { { 0, 41.2 }, { 21.5, 34.3 }, { 75, 29.4 } } },
	RN545 = { id = "RN545", name = "RN-545", interval = 0.075, mag = 30, aimFov = 44,
		spread = { hip = 1.46, aim = 0.05 }, aimKick = V(0.25, 0.3, 1), hipKick = V(0.8, 0.7, 1.2),
		damage = { { 0, 41.2 }, { 16, 34.3 }, { 55, 29.4 } } },
	MX65 = { id = "MX65", name = "MX-65", interval = 0.0944, mag = 20, aimFov = 29.4,
		spread = { hip = 1.46, aim = 0.05 }, aimKick = V(0.35, 0.3, 0.9), hipKick = V(1.1, 0.6, 1.1),
		damage = { { 0, 51.5 }, { 21.5, 41.2 }, { 75, 34.3 } } },
	BT762 = { id = "BT762", name = "BT-762", interval = 0.0833, mag = 20, aimFov = 44,
		spread = { hip = 1.46, aim = 0.05 }, aimKick = V(0.5, 0.4, 1.1), hipKick = V(1.4, 0.7, 1.3),
		damage = { { 0, 51.5 }, { 30, 41.2 }, { 75, 34.3 } } },
}
U.Weapons = Weapons
local DEFAULT_GUN = { interval = 0.09, aimFov = 35, spread = { hip = 1.5, aim = 0.06 }, aimKick = V(0.35, 0.3, 1), hipKick = V(1.1, 0.6, 1.2) }

-- the gun you're holding: a Tool / model named after it (K433 or "K-433") in your character or in
-- the camera (where the gun you see is), or an attribute on you / your character
local function weaponKey(s) return (tostring(s):lower():gsub("[^%w]", "")) end
local byKey = {}
for id, w in pairs(Weapons) do
	byKey[weaponKey(id)] = w
	byKey[weaponKey(w.name)] = w
end
local function findWeaponIn(container, depth)
	if not container then return nil end
	for _, c in ipairs(container:GetChildren()) do
		local w = byKey[weaponKey(c.Name)]
		if w then return w end
		if depth > 1 and (c:IsA("Model") or c:IsA("Tool") or c:IsA("Folder")) then
			w = findWeaponIn(c, depth - 1)
			if w then return w end
		end
	end
	return nil
end
local function findWeaponAttribute(inst)
	if not inst then return nil end
	for _, name in ipairs({ "Weapon", "Equipped", "Gun", "CurrentWeapon", "Primary" }) do
		local v = inst:GetAttribute(name)
		if type(v) == "string" and byKey[weaponKey(v)] then return byKey[weaponKey(v)] end
	end
	return nil
end
local currentWeapon, lastWeaponCheck = nil, 0
local function getWeapon()
	local now = os.clock()
	if now - lastWeaponCheck > 0.25 then
		lastWeaponCheck = now
		local char = player.Character
		currentWeapon = findWeaponIn(char, 2) or findWeaponIn(workspace.CurrentCamera, 3)
			or findWeaponAttribute(char) or findWeaponAttribute(player)
	end
	return currentWeapon
end
function U.getWeapon() return getWeapon() end

----------------------------------------------------------------------
-- Aimbot: while the aim key is held, moves the mouse (or the camera) toward the target closest
-- to the cursor, and stays locked on it while it's still valid
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
local function torso(char, root)
	return partNamed(char, "UpperTorso") or partNamed(char, "Torso") or root
end
local function aiming(cam, gun)
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return true end
	return cam.FieldOfView <= (gun or DEFAULT_GUN).aimFov + 3 -- zoomed in
end
-- "Auto": the head unless your spread at that distance is wider than a head (hip fire far away)
local function aimPart(cam, char, root)
	if Aim.Part == "Torso" then return torso(char, root) end
	local head = partNamed(char, "Head")
	if Aim.Part == "Head" then return head or root end
	if not head then return torso(char, root) end
	local gun = getWeapon() or DEFAULT_GUN
	local spread = aiming(cam, gun) and gun.spread.aim or gun.spread.hip
	local dist = (head.Position - cam.CFrame.Position).Magnitude
	local radius = dist * math.tan(math.rad(spread))
	return radius > 0.7 and torso(char, root) or head
end
local function canSee(cam, part, char)
	if not Aim.WallCheck then return true end
	local ignore = { cam } -- your gun model lives in the camera; it would block every ray
	if player.Character then table.insert(ignore, player.Character) end
	aimRay.FilterDescendantsInstances = ignore
	local origin = cam.CFrame.Position
	local result = workspace:Raycast(origin, part.Position - origin, aimRay)
	return not result or result.Instance:IsDescendantOf(char)
end
local function isTeam(key)
	if not key:IsA("Player") then return false end
	if key.Team ~= nil and key.Team == player.Team then return true end
	local mine, theirs = player:GetAttribute("Team"), key:GetAttribute("Team") -- games with their own teams
	return mine ~= nil and mine == theirs
end
local function aimPoint(part, root)
	if not Aim.Prediction then return part.Position end
	local ping = 0.05
	pcall(function() ping = player:GetNetworkPing() end)
	return part.Position + root.AssemblyLinearVelocity * ping
end
local function screenDistance(key, cam, mousePos)
	if key == player then return nil end
	local char, root = targetInfo(key, Aim.IncludeNPCs)
	if not char then return nil end
	if Aim.TeamCheck and isTeam(key) then return nil end
	local part = aimPart(cam, char, root)
	if not part then return nil end
	local point = aimPoint(part, root)
	local sp, onScreen = cam:WorldToViewportPoint(point)
	if not onScreen then return nil end
	local d = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
	if Aim.UseFov and d > Aim.Fov then return nil end
	if not canSee(cam, part, char) then return nil end
	return d, point, sp
end
local function aimHeld()
	if Aim.Activation == "Always" then return true end
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return true end
	return Aim.Activation == "Hold Left or Right Mouse"
		and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
end
-- the game zooms in when aiming; the same mouse move turns further on screen, so move less
local function zoomScale(cam)
	return math.clamp(cam.FieldOfView / 70, 0.15, 1)
end

local lockedTarget
local function aimStep(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local mousePos = UserInputService:GetMouseLocation()
	fovCircle.Visible = Aim.Enabled and Aim.UseFov and Aim.ShowFov
	if fovCircle.Visible then
		fovCircle.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
		fovCircle.Size = UDim2.fromOffset(Aim.Fov * 2, Aim.Fov * 2)
	end
	local useMouse = Aim.Method == "Mouse" and hasMouseMove
	local point, sp
	if Aim.Enabled and aimHeld() then
		if lockedTarget then _, point, sp = screenDistance(lockedTarget, cam, mousePos) end
		if not point then
			lockedTarget = nil
			local best
			local function consider(key)
				local d, p, s = screenDistance(key, cam, mousePos)
				if d and (not best or d < best) then best, lockedTarget, point, sp = d, key, p, s end
			end
			for _, plr in ipairs(Players:GetPlayers()) do consider(plr) end
			if Aim.IncludeNPCs then
				for model in pairs(npcs) do consider(model) end
			end
		end
	else
		lockedTarget = nil
	end

	if point then -- locked on: following the target also cancels the recoil
		local alpha = 1 - (1 - 1 / Aim.Smoothing) ^ (dt * 60) -- same feel at any frame rate
		if useMouse then
			local delta = (Vector2.new(sp.X, sp.Y) - mousePos) * alpha * zoomScale(cam)
			if delta.Magnitude > 0.3 then mousemoverel(delta.X, delta.Y) end
		else
			local camPos = cam.CFrame.Position
			cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(camPos, point), alpha)
		end
		return
	end

	-- Recoil Control: pull down by the gun's kick while you shoot
	if Aim.RecoilControl and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		and not UserInputService:GetFocusedTextBox() then
		local gun = getWeapon() or DEFAULT_GUN
		local kick = (aiming(cam, gun) and gun.aimKick or gun.hipKick).X -- degrees per shot
		local degrees = kick * Aim.RecoilStrength * dt / gun.interval
		if useMouse then
			local pixelsPerDegree = cam.ViewportSize.Y / cam.FieldOfView
			mousemoverel(0, degrees * pixelsPerDegree * zoomScale(cam))
		else
			cam.CFrame *= CFrame.Angles(-math.rad(degrees), 0, 0)
		end
	end
end
-- after the game's own camera code, so camera aim isn't overwritten that frame
RunService:BindToRenderStep("ScalsShooterAim", Enum.RenderPriority.Last.Value + 50, aimStep)

function U.aimbot(on)
	Aim.Enabled = on == true
	if not Aim.Enabled then lockedTarget = nil end
end
function U.setAimbot(opts)
	merge(Aim, opts, "Enabled")
	Aim.Smoothing = math.max(1, tonumber(Aim.Smoothing) or 4)
	Aim.RecoilStrength = math.clamp(tonumber(Aim.RecoilStrength) or 0.8, 0, 1)
	if Aim.IncludeNPCs then startNpcTracking() end
end
function U.recoilControl(on)
	Aim.RecoilControl = on == true
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
	pcall(function() RunService:UnbindFromRenderStep("ScalsShooterAim") end)
	Aim.RecoilControl = false
	restoreSpeed()
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	espGui:Destroy()
	chamsFolder:Destroy()
end

return U
