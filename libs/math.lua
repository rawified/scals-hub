--[[
    Scals Hub - Math library
    The math that keeps coming up in hub scripts: distances, screen projection, FOV checks,
    picking targets, prediction, smoothing, angles and random offsets.

        local M = loadstring(game:HttpGet(REPO .. "libs/math.lua"))()

    Anywhere a "point" is expected you can pass a Vector3, CFrame, BasePart, Model, Player or Attachment.

    NUMBERS
        M.clamp(x, min, max)       M.lerp(a, b, t)          M.inverseLerp(a, b, x)
        M.remap(x, inMin, inMax, outMin, outMax)            M.round(x, step)   -- step 0.5, 10, ...
        M.sign(x)                  M.approx(a, b, eps)      M.wrapAngle(deg)   -- -180..180
        M.format(n)                -- 1.2K / 3.4M

    POINTS & DISTANCE
        M.pos(point) -> Vector3
        M.dist(a, b)               M.flatDist(a, b)          -- ignores height
        M.myPos()                  M.distFromMe(point)
        M.direction(from, to)      -- unit Vector3
        M.within(a, b, range)

    SCREEN
        M.toScreen(point) -> Vector2, onScreen, depth
        M.screenCenter()           M.mousePos()
        M.screenDist(point, from)  -- pixels from the cursor (or `from`)
        M.inFov(point, radius, from)
        M.screenBox(model) -> topLeft Vector2, size Vector2, onScreen   -- 2D box around a model
        M.offScreenArrow(point, margin) -> Vector2 position, angle (radians)  -- edge indicator

    ANGLES
        M.angleBetween(dirA, dirB)          -- degrees
        M.angleTo(point, cframe)            -- degrees between where cframe looks and the point (default: camera)
        M.yawPitch(direction) -> yaw, pitch (radians)
        M.fromYawPitch(yaw, pitch) -> direction
        M.isBehind(point, cframe)
        M.lookAt(from, to)                  -- CFrame

    TARGETS
        M.closest(list, origin, opts)       -- by 3D distance. opts: GetPoint, MaxDistance, Filter
        M.closestToCursor(list, opts)       -- by pixels.      opts: GetPoint, Fov, Filter, From
        M.sortByDistance(list, origin, getPoint)
        M.players(opts)                     -- other players' characters. opts: TeamCheck, AliveOnly

    PREDICTION
        M.velocity(point)                   -- AssemblyLinearVelocity of the part / model root
        M.predict(point, time, velocity)    -- where it will be after `time` seconds
        M.intercept(shooterPos, targetPos, targetVel, projectileSpeed) -> aimPos, time  (nil if impossible)
        M.dropCompensation(from, to, projectileSpeed, gravity) -> aim point raised for bullet drop
        M.pingSeconds()                     -- your ping, for prediction

    SMOOTHING
        M.smoothAlpha(smoothing, dt)        -- frame-rate independent lerp alpha (1 = instant)
        M.damp(current, target, speed, dt)  -- numbers, Vector2, Vector3 or CFrame
        M.Spring.new(initial, speed, damper) -> spring:Update(target, dt) / spring.Position
        M.bezier(t, p0, p1, p2[, p3])       -- quadratic / cubic curve point

    RANDOM / HUMANIZING
        M.randomRange(min, max)
        M.randomInCircle(radius) -> Vector2  M.randomInSphere(radius) -> Vector3
        M.jitter(point, amount)             -- Vector3 with a small random offset

    RAYCASTS
        M.visible(point, ignore, origin)    -- nothing in the way (ignore = list of instances)
]]

local M = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StatsService = game:GetService("Stats")

local player = Players.LocalPlayer
local rng = Random.new()

local function cam()
	return workspace.CurrentCamera
end

----------------------------------------------------------------------
-- Numbers
----------------------------------------------------------------------
function M.clamp(x, lo, hi)
	return x < lo and lo or (x > hi and hi or x)
end

function M.lerp(a, b, t)
	if type(a) == "number" then return a + (b - a) * t end
	return a:Lerp(b, t) -- Vector2 / Vector3 / CFrame / Color3
end

function M.inverseLerp(a, b, x)
	if a == b then return 0 end
	return (x - a) / (b - a)
end

function M.remap(x, inMin, inMax, outMin, outMax, clampIt)
	local t = M.inverseLerp(inMin, inMax, x)
	if clampIt then t = M.clamp(t, 0, 1) end
	return outMin + (outMax - outMin) * t
end

function M.round(x, step)
	step = step or 1
	return math.floor(x / step + 0.5) * step
end

function M.sign(x)
	return x > 0 and 1 or (x < 0 and -1 or 0)
end

function M.approx(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-4)
end

function M.wrapAngle(deg)
	return (deg + 180) % 360 - 180
end

function M.format(n)
	local abs = math.abs(n)
	for _, s in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
		if abs >= s[1] then
			return (("%.1f"):format(n / s[1]):gsub("%.0$", "")) .. s[2]
		end
	end
	return tostring(M.round(n, 0.01))
end

----------------------------------------------------------------------
-- Points & distance
----------------------------------------------------------------------
local function rootOf(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

function M.pos(p)
	local t = typeof(p)
	if t == "Vector3" then return p end
	if t == "CFrame" then return p.Position end
	if t ~= "Instance" then return nil end
	if p:IsA("Player") then
		local root = p.Character and rootOf(p.Character)
		return root and root.Position
	end
	if p:IsA("BasePart") then return p.Position end
	if p:IsA("Model") then
		local root = rootOf(p)
		if root then return root.Position end
		local ok, cf = pcall(p.GetPivot, p)
		return ok and cf.Position or nil
	end
	if p:IsA("Attachment") then return p.WorldPosition end
	return nil
end

function M.dist(a, b)
	if typeof(a) == "Vector2" then return (a - b).Magnitude end
	local pa, pb = M.pos(a), M.pos(b)
	return (pa and pb) and (pa - pb).Magnitude or math.huge
end

function M.flatDist(a, b)
	local pa, pb = M.pos(a), M.pos(b)
	if not (pa and pb) then return math.huge end
	return Vector2.new(pa.X - pb.X, pa.Z - pb.Z).Magnitude
end

function M.myPos()
	return M.pos(player)
end

function M.distFromMe(p)
	local me = M.myPos()
	return me and M.dist(me, p) or math.huge
end

function M.direction(from, to)
	local d = M.pos(to) - M.pos(from)
	return d.Magnitude > 0 and d.Unit or Vector3.zero
end

function M.within(a, b, range)
	return M.dist(a, b) <= range
end

----------------------------------------------------------------------
-- Screen
----------------------------------------------------------------------
-- Vector2 in viewport pixels (matches GetMouseLocation and IgnoreGuiInset GUIs)
function M.toScreen(p)
	local pos = M.pos(p)
	local c = cam()
	if not (pos and c) then return Vector2.zero, false, 0 end
	local v, onScreen = c:WorldToViewportPoint(pos)
	return Vector2.new(v.X, v.Y), onScreen and v.Z > 0, v.Z
end

function M.screenCenter()
	local c = cam()
	return c and c.ViewportSize / 2 or Vector2.zero
end

function M.mousePos()
	return UserInputService:GetMouseLocation()
end

function M.screenDist(p, from)
	local sp, onScreen = M.toScreen(p)
	if not onScreen then return math.huge end
	return (sp - (from or M.mousePos())).Magnitude
end

function M.inFov(p, radius, from)
	return M.screenDist(p, from) <= radius
end

-- 2D box around a model from its bounding box corners
function M.screenBox(model)
	local ok, cf, size = pcall(model.GetBoundingBox, model)
	if not ok then return nil end
	local half = size / 2
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local anyVisible = false
	for _, x in ipairs({ -1, 1 }) do
		for _, y in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				local sp, onScreen, depth = M.toScreen(cf * Vector3.new(half.X * x, half.Y * y, half.Z * z))
				if depth > 0 then
					anyVisible = anyVisible or onScreen
					minX, minY = math.min(minX, sp.X), math.min(minY, sp.Y)
					maxX, maxY = math.max(maxX, sp.X), math.max(maxY, sp.Y)
				end
			end
		end
	end
	if minX == math.huge then return nil end
	return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY), anyVisible
end

-- Position on the screen edge pointing toward an off-screen point, plus its angle
function M.offScreenArrow(p, margin)
	margin = margin or 40
	local c = cam()
	local pos = M.pos(p)
	if not (c and pos) then return nil end
	local rel = c.CFrame:PointToObjectSpace(pos)
	local dir = Vector2.new(rel.X, -rel.Y)
	if dir.Magnitude == 0 then dir = Vector2.new(0, -1) end
	dir = dir.Unit
	local center = c.ViewportSize / 2
	local edge = center - Vector2.new(margin, margin)
	local scale = math.min(
		math.abs(dir.X) > 0 and edge.X / math.abs(dir.X) or math.huge,
		math.abs(dir.Y) > 0 and edge.Y / math.abs(dir.Y) or math.huge
	)
	return center + dir * scale, math.atan2(dir.Y, dir.X)
end

----------------------------------------------------------------------
-- Angles
----------------------------------------------------------------------
function M.angleBetween(a, b)
	if a.Magnitude == 0 or b.Magnitude == 0 then return 0 end
	return math.deg(math.acos(M.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

function M.angleTo(p, cframe)
	cframe = cframe or (cam() and cam().CFrame)
	local pos = M.pos(p)
	if not (cframe and pos) then return 180 end
	return M.angleBetween(cframe.LookVector, pos - cframe.Position)
end

function M.yawPitch(dir)
	dir = dir.Unit
	return math.atan2(-dir.X, -dir.Z), math.asin(M.clamp(dir.Y, -1, 1))
end

function M.fromYawPitch(yaw, pitch)
	local cp = math.cos(pitch)
	return Vector3.new(-math.sin(yaw) * cp, math.sin(pitch), -math.cos(yaw) * cp)
end

function M.isBehind(p, cframe)
	cframe = cframe or (cam() and cam().CFrame)
	local pos = M.pos(p)
	return pos ~= nil and cframe.LookVector:Dot(pos - cframe.Position) < 0
end

function M.lookAt(from, to)
	return CFrame.lookAt(M.pos(from), M.pos(to))
end

----------------------------------------------------------------------
-- Targets
----------------------------------------------------------------------
-- opts.GetPoint(item) -> point (default: the item itself), opts.Filter(item) -> bool
function M.closest(list, origin, opts)
	opts = opts or {}
	origin = M.pos(origin or player)
	if not origin then return nil end
	local best, bestDist = nil, opts.MaxDistance or math.huge
	for _, item in ipairs(list) do
		if not opts.Filter or opts.Filter(item) then
			local p = M.pos(opts.GetPoint and opts.GetPoint(item) or item)
			if p then
				local d = (p - origin).Magnitude
				if d < bestDist then best, bestDist = item, d end
			end
		end
	end
	return best, best and bestDist or nil
end

-- opts: GetPoint, Filter, Fov (pixels), From (Vector2, default mouse)
function M.closestToCursor(list, opts)
	opts = opts or {}
	local from = opts.From or M.mousePos()
	local best, bestDist = nil, opts.Fov or math.huge
	for _, item in ipairs(list) do
		if not opts.Filter or opts.Filter(item) then
			local d = M.screenDist(opts.GetPoint and opts.GetPoint(item) or item, from)
			if d < bestDist then best, bestDist = item, d end
		end
	end
	return best, best and bestDist or nil
end

function M.sortByDistance(list, origin, getPoint)
	origin = M.pos(origin or player)
	local dists = {}
	for _, item in ipairs(list) do
		local p = M.pos(getPoint and getPoint(item) or item)
		dists[item] = (p and origin) and (p - origin).Magnitude or math.huge
	end
	table.sort(list, function(a, b) return dists[a] < dists[b] end)
	return list
end

-- Other players' characters. opts.TeamCheck skips your team, opts.AliveOnly (default true)
function M.players(opts)
	opts = opts or {}
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			local alive = hum and hum.Health > 0
			local sameTeam = opts.TeamCheck and p.Team ~= nil and p.Team == player.Team
			if (alive or opts.AliveOnly == false) and not sameTeam and rootOf(p.Character) then
				table.insert(out, p.Character)
			end
		end
	end
	return out
end

----------------------------------------------------------------------
-- Prediction
----------------------------------------------------------------------
function M.velocity(p)
	if typeof(p) ~= "Instance" then return Vector3.zero end
	local part = p
	if p:IsA("Player") then part = p.Character and rootOf(p.Character) end
	if part and part:IsA("Model") then part = rootOf(part) end
	return (part and part:IsA("BasePart")) and part.AssemblyLinearVelocity or Vector3.zero
end

function M.predict(p, time, velocity)
	return M.pos(p) + (velocity or M.velocity(p)) * time
end

-- Where to aim so a projectile of `speed` meets a target moving at `targetVel` (no gravity)
function M.intercept(shooterPos, targetPos, targetVel, speed)
	local d = targetPos - shooterPos
	local a = targetVel:Dot(targetVel) - speed * speed
	local b = 2 * d:Dot(targetVel)
	local c = d:Dot(d)
	local t
	if math.abs(a) < 1e-6 then
		if math.abs(b) < 1e-6 then return nil end
		t = -c / b
	else
		local disc = b * b - 4 * a * c
		if disc < 0 then return nil end
		local s = math.sqrt(disc)
		local t1, t2 = (-b - s) / (2 * a), (-b + s) / (2 * a)
		t = (t1 > 0 and t2 > 0) and math.min(t1, t2) or math.max(t1, t2)
	end
	if t <= 0 then return nil end
	return targetPos + targetVel * t, t
end

-- Raises the aim point so a projectile affected by gravity lands on `to`
function M.dropCompensation(from, to, speed, gravity)
	gravity = gravity or workspace.Gravity
	local t = (to - from).Magnitude / speed
	return to + Vector3.new(0, 0.5 * gravity * t * t, 0), t
end

function M.pingSeconds()
	local ok, ms = pcall(function()
		return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and ms then return ms / 1000 end
	local ok2, s = pcall(player.GetNetworkPing, player)
	return ok2 and s or 0
end

----------------------------------------------------------------------
-- Smoothing
----------------------------------------------------------------------
-- 1 = snap, higher = slower; same feel at any FPS
function M.smoothAlpha(smoothing, dt)
	smoothing = math.max(smoothing, 1)
	return 1 - (1 - 1 / smoothing) ^ ((dt or 1 / 60) * 60)
end

-- Exponential approach: speed ~ how many "halvings" per second-ish
function M.damp(current, target, speed, dt)
	local t = 1 - math.exp(-speed * dt)
	return M.lerp(current, target, t)
end

local Spring = {}
Spring.__index = Spring
M.Spring = Spring

-- Works with numbers, Vector2 and Vector3
function Spring.new(initial, speed, damper)
	local zero = type(initial) == "number" and 0 or initial * 0
	return setmetatable({
		Position = initial, Velocity = zero, Speed = speed or 10, Damper = damper or 1,
	}, Spring)
end

function Spring:Update(target, dt)
	-- semi-implicit Euler, split into small steps so it stays stable at low FPS
	local steps = math.max(math.ceil(dt / (1 / 120)), 1)
	local h = dt / steps
	local k = self.Speed * self.Speed
	local c = 2 * self.Damper * self.Speed
	for _ = 1, steps do
		local accel = (target - self.Position) * k - self.Velocity * c
		self.Velocity = self.Velocity + accel * h
		self.Position = self.Position + self.Velocity * h
	end
	return self.Position
end

function M.bezier(t, p0, p1, p2, p3)
	local u = 1 - t
	if p3 == nil then
		return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
	end
	return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
end

----------------------------------------------------------------------
-- Random / humanizing
----------------------------------------------------------------------
function M.randomRange(lo, hi)
	return rng:NextNumber(lo, hi)
end

function M.randomInCircle(radius)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = math.sqrt(rng:NextNumber()) * radius
	return Vector2.new(math.cos(a) * r, math.sin(a) * r)
end

function M.randomInSphere(radius)
	return rng:NextUnitVector() * (rng:NextNumber() ^ (1 / 3)) * radius
end

function M.jitter(p, amount)
	return M.pos(p) + M.randomInSphere(amount or 0.5)
end

----------------------------------------------------------------------
-- Raycasts
----------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- True when nothing blocks the line from origin (default: camera) to the point.
-- Hits on the target's own model count as visible.
function M.visible(p, ignore, origin)
	local pos = M.pos(p)
	origin = origin and M.pos(origin) or (cam() and cam().CFrame.Position)
	if not (pos and origin) then return false end
	local list = { player.Character }
	for _, v in ipairs(ignore or {}) do table.insert(list, v) end
	rayParams.FilterDescendantsInstances = list
	local hit = workspace:Raycast(origin, pos - origin, rayParams)
	if not hit then return true end
	if typeof(p) == "Instance" then
		local model = p:IsA("Player") and p.Character or (p:IsA("Model") and p) or p:FindFirstAncestorOfClass("Model")
		if model and hit.Instance:IsDescendantOf(model) then return true end
		if hit.Instance == p then return true end
	end
	return false
end

return M
