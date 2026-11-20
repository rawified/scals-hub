--[[
    Scals Hub - Shooter library (PlaceId / GameId 78884249003161)
    An aimbot and recoil control tuned for this game's guns (K-433, GX-36, SK-556, RN-545, MX-65,
    BT-762). WalkSpeed, Fly and ESP come from libs/universal.lua. No UI.

        local S = loadstring(game:HttpGet(REPO .. "libs/shooter.lua"))()

    The aimbot always moves the mouse (mousemoverel): the game drives its own camera, so turning the
    camera directly gets overwritten. Without mousemoverel it does nothing (S.hasMouseMove() = false).

        S.aimbot(true / false)
        S.setAimbot({
            Activation = "Hold Right Mouse" | "Hold Left or Right Mouse" | "Always",
            Part = "Auto" | "Head" | "Torso",   -- Auto: chest when hip-fire spread would miss the head
            UseFov = true, ShowFov = true, Fov = 120, Smoothing = 4,
            TeamCheck = true, WallCheck = true, IncludeNPCs = false,
            Prediction = false,                  -- lead moving targets by your ping
            RecoilStrength = 0.8,                -- 0-1
        })
        S.recoilControl(true / false)            -- pulls the gun back down while you shoot
        S.getAimTarget()                         -- the Player / NPC it's locked on, or nil
        S.getWeapon()                            -- stats of the gun you're holding, or nil
        S.Weapons                                -- every gun: interval, mag, spread, aimFov, kick, damage
        S.hasMouseMove()
        S.Aim                                    -- current settings
        S.destroy()
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

local function merge(into, opts, skip)
	for k, v in pairs(opts or {}) do
		if k ~= skip and into[k] ~= nil then into[k] = v end
	end
end

local Aim = {
	Enabled = false,
	Activation = "Hold Right Mouse",
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
U.Aim = Aim

----------------------------------------------------------------------
-- Screen for the FOV circle
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
espGui.Name = "ScalsShooterAim"
espGui.IgnoreGuiInset = true
espGui.ResetOnSpawn = false
espGui.DisplayOrder = 10
espGui.Parent = hiddenParent or player:WaitForChild("PlayerGui")

----------------------------------------------------------------------
-- Targets: players, optionally NPCs (models whose PrimaryPart is HumanoidRootPart)
----------------------------------------------------------------------
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

local npcTracking = false
local function addNpcCandidate(inst)
	if inst.Name ~= "HumanoidRootPart" or not inst:IsA("BasePart") then return end
	local model = inst.Parent
	if not (model and model:IsA("Model")) or npcs[model] then return end
	if Players:GetPlayerFromCharacter(model) then return end
	npcs[model] = true
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
-- Aimbot: while the aim key is held, moves the mouse toward the target closest to the cursor,
-- and stays locked on it while it's still valid
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
	if not hasMouseMove then return end -- mouse only
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
				for model in pairs(npcs) do
					if model:IsDescendantOf(workspace) then consider(model) else npcs[model] = nil end
				end
			end
		end
	else
		lockedTarget = nil
	end

	if point then -- locked on: following the target also cancels the recoil
		local alpha = 1 - (1 - 1 / Aim.Smoothing) ^ (dt * 60) -- same feel at any frame rate
		local delta = (Vector2.new(sp.X, sp.Y) - mousePos) * alpha * zoomScale(cam)
		if delta.Magnitude > 0.3 then mousemoverel(delta.X, delta.Y) end
		return
	end

	-- Recoil Control: pull down by the gun's kick while you shoot
	if Aim.RecoilControl and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		and not UserInputService:GetFocusedTextBox() then
		local gun = getWeapon() or DEFAULT_GUN
		local kick = (aiming(cam, gun) and gun.aimKick or gun.hipKick).X -- degrees per shot
		local degrees = kick * Aim.RecoilStrength * dt / gun.interval
		local pixelsPerDegree = cam.ViewportSize.Y / cam.FieldOfView
		mousemoverel(0, degrees * pixelsPerDegree * zoomScale(cam))
	end
end
-- after the game's own camera code, so the target's screen position matches what you see
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
	Aim.Enabled = false
	Aim.RecoilControl = false
	pcall(function() RunService:UnbindFromRenderStep("ScalsShooterAim") end)
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	espGui:Destroy()
end

return U
