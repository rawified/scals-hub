# Math library

The math that keeps coming up in hub scripts: distances, screen projection, FOV checks, picking targets, prediction, smoothing, angles and random offsets.

```lua
local REPO = "https://raw.githubusercontent.com/rawified/scals-hub/refs/heads/main/"
local M = loadstring(game:HttpGet(REPO .. "libs/math.lua"))()
```

## Points

Anywhere a **point** is expected you can pass a `Vector3`, `CFrame`, `BasePart`, `Model`, `Player` or `Attachment`. Players and models use their HumanoidRootPart (or PrimaryPart).

## Numbers

| Function | Description |
|---|---|
| `M.clamp(x, min, max)` | keep `x` in range |
| `M.lerp(a, b, t)` | numbers, Vector2, Vector3, CFrame, Color3 |
| `M.inverseLerp(a, b, x)` | where `x` sits between `a` and `b` (0..1) |
| `M.remap(x, inMin, inMax, outMin, outMax, clamp)` | map one range onto another |
| `M.round(x, step)` | round to a step (`1`, `0.5`, `10`...) |
| `M.sign(x)` | `-1`, `0` or `1` |
| `M.approx(a, b, eps)` | nearly equal (default eps `1e-4`) |
| `M.wrapAngle(deg)` | wrap to -180..180 |
| `M.format(n)` | `1.2K`, `3.4M`, `5B`, `1T` |

## Distance

| Function | Returns |
|---|---|
| `M.pos(point)` | Vector3 (or `nil`) |
| `M.dist(a, b)` | distance (Vector2 works too); `math.huge` if a point is missing |
| `M.flatDist(a, b)` | distance ignoring height |
| `M.myPos()` | your root position |
| `M.distFromMe(point)` | distance from you |
| `M.direction(from, to)` | unit Vector3 |
| `M.within(a, b, range)` | `true` if closer than `range` |

## Screen

Screen positions are viewport pixels, the same as `UserInputService:GetMouseLocation()` and GUIs with `IgnoreGuiInset = true`.

| Function | Returns |
|---|---|
| `M.toScreen(point)` | `Vector2`, `onScreen`, `depth` |
| `M.screenCenter()` | middle of the screen |
| `M.mousePos()` | cursor position |
| `M.screenDist(point, from)` | pixels from the cursor (or `from`); `math.huge` if off-screen |
| `M.inFov(point, radius, from)` | inside a circle around the cursor |
| `M.screenBox(model)` | `topLeft`, `size`, `onScreen`: a 2D box from the model's bounding box (good for ESP) |
| `M.offScreenArrow(point, margin)` | position on the screen edge pointing at the point, and its angle in radians |

```lua
local topLeft, size, visible = M.screenBox(character)
if topLeft and visible then
	box.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
	box.Size = UDim2.fromOffset(size.X, size.Y)
end
```

## Angles

| Function | Returns |
|---|---|
| `M.angleBetween(dirA, dirB)` | degrees |
| `M.angleTo(point, cframe)` | degrees between where `cframe` looks (default: camera) and the point |
| `M.yawPitch(direction)` | `yaw`, `pitch` in radians |
| `M.fromYawPitch(yaw, pitch)` | direction Vector3 |
| `M.isBehind(point, cframe)` | point is behind the camera / cframe |
| `M.lookAt(from, to)` | CFrame |

## Targets

| Function | Returns |
|---|---|
| `M.closest(list, origin, opts)` | closest item by 3D distance, and its distance. opts: `GetPoint`, `MaxDistance`, `Filter` |
| `M.closestToCursor(list, opts)` | closest item on screen, and its pixel distance. opts: `GetPoint`, `Fov`, `Filter`, `From` |
| `M.sortByDistance(list, origin, getPoint)` | sorts `list` in place, nearest first |
| `M.players(opts)` | other players' characters. opts: `TeamCheck`, `AliveOnly` (default `true`) |

`GetPoint(item)` lets the list hold anything (e.g. return `item:FindFirstChild("Head")`). `origin` defaults to you.

```lua
local target = M.closestToCursor(M.players({ TeamCheck = true }), {
	Fov = 150,
	GetPoint = function(char) return char:FindFirstChild("Head") end,
	Filter = function(char) return M.visible(char) end,
})
```

## Prediction

| Function | Returns |
|---|---|
| `M.velocity(point)` | `AssemblyLinearVelocity` of the part or model root (zero for plain positions) |
| `M.predict(point, time, velocity)` | where it will be after `time` seconds |
| `M.intercept(shooterPos, targetPos, targetVel, projectileSpeed)` | aim position and travel time for a projectile to hit a moving target (no gravity), or `nil` if it can't catch it |
| `M.dropCompensation(from, to, projectileSpeed, gravity)` | aim point raised for bullet drop, and travel time (gravity defaults to `workspace.Gravity`) |
| `M.pingSeconds()` | your ping in seconds |

```lua
local head = target.Head
local aim = M.predict(head, M.pingSeconds())
local hit = M.intercept(camera.CFrame.Position, aim, M.velocity(head), 300) or aim
```

## Smoothing

| Function | Description |
|---|---|
| `M.smoothAlpha(smoothing, dt)` | lerp alpha that feels the same at any FPS. `1` = snap, higher = slower (same scale as the Smoothing slider in `player.lua`) |
| `M.damp(current, target, speed, dt)` | exponential approach for numbers, vectors or CFrames |
| `M.Spring.new(initial, speed, damper)` | spring for numbers / Vector2 / Vector3. `spring:Update(target, dt)` returns the new position; also `.Position`, `.Velocity`, `.Speed`, `.Damper` |
| `M.bezier(t, p0, p1, p2, p3)` | point on a quadratic (3 points) or cubic (4 points) curve |

```lua
camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(camera.CFrame.Position, aim), M.smoothAlpha(5, dt))
```

## Random / humanizing

| Function | Returns |
|---|---|
| `M.randomRange(min, max)` | random number |
| `M.randomInCircle(radius)` | random Vector2 inside a circle (evenly spread) |
| `M.randomInSphere(radius)` | random Vector3 inside a sphere |
| `M.jitter(point, amount)` | point plus a small random offset (default 0.5 studs) |

## Raycasts

`M.visible(point, ignore, origin)` is `true` when nothing blocks the line from `origin` (default: camera) to the point. Your character is always ignored, `ignore` adds more instances, and hitting the target's own model counts as visible.
