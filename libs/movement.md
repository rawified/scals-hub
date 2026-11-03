# Movement library

Tweening, teleporting, flying and noclip for your own character.

```lua
local REPO = "https://raw.githubusercontent.com/rawified/scals-hub/refs/heads/main/"
local Move = loadstring(game:HttpGet(REPO .. "libs/movement.lua"))()
```

## Targets

Anything that takes a **target** accepts:

- `Vector3` (you keep your current rotation)
- `CFrame`
- `BasePart`
- `Model` (uses HumanoidRootPart, then PrimaryPart, then its pivot)
- `Player`
- a player's name, partial and case-insensitive (`"rob"` finds `Roblox`), matching Name or DisplayName
- `Attachment`

## Tweening

```lua
local t = Move.tweenTo(target, {
	Speed = 80,                     -- studs per second (default), or:
	Time = 2,                       -- seconds (overrides Speed)
	Offset = Vector3.new(0, 3, 0),  -- added to the target position (a CFrame offset also works)
	Style = Enum.EasingStyle.Linear,
	Direction = Enum.EasingDirection.InOut,
	Noclip = true,                  -- pass through walls while moving (default true)
	KeepRotation = false,           -- true = don't turn to the target's rotation
	Flat = false,                   -- true = stay at your current height
})

t:Wait()   -- yields; true if it finished, false if cancelled
t:Cancel()
```

| Function | Description |
|---|---|
| `Move.tweenTo(target, opts)` | tween to one target, returns a handle (doesn't yield) |
| `Move.tweenPath({ p1, p2, ... }, opts)` | tween through every point in order, same handle |
| `Move.stopTween()` | cancels whatever is tweening |
| `Move.isTweening()` | `true` while a tween runs |

Handle fields: `Completed`, `Cancelled`. Only one tween runs at a time; starting a new one cancels the old one. Dying or respawning cancels it too. While tweening, velocity is held at zero so gravity doesn't drag you down.

```lua
-- collect every coin in order
local coins = { workspace.Coin1, workspace.Coin2, workspace.Coin3 }
Move.tweenPath(coins, { Speed = 60, Offset = Vector3.new(0, 2, 0) }):Wait()
```

## Teleporting

| Function | Description |
|---|---|
| `Move.teleport(target, opts)` | instant teleport. opts: `Offset`, `KeepRotation`, `Flat`. Returns `true` on success |
| `Move.teleportSteps(target, opts)` | many short hops (yields). opts: `StepSize` (20), `Delay` (0.05 s), `Offset`, `KeepRotation` |
| `Move.teleportBehind(target, distance)` | stand `distance` studs (default 3) behind a player / part, facing it |
| `Move.savePosition(name)` | remembers where you stand (name defaults to `"default"`) |
| `Move.loadPosition(name, opts)` | teleports back to a saved position |
| `Move.freeze(on)` | anchors / unanchors your root part |

`teleportSteps` is for games that kick you for moving too far in one frame.

```lua
Move.savePosition("base")
Move.teleportBehind("enemyName", 4)
task.wait(2)
Move.loadPosition("base")
```

## Fly

```lua
Move.fly(true, { Speed = 60, Mode = "Velocity", Noclip = false })
Move.fly(false)
```

| Option | Default | Meaning |
|---|---|---|
| `Speed` | `60` | studs per second |
| `Mode` | `"Velocity"` | `"Velocity"` sets the root's velocity (smooth); `"CFrame"` moves the root directly (use it when the game resets your velocity) |
| `Noclip` | `false` | also noclip while flying |

Controls: WASD flies where the camera looks, Space goes up, Left Ctrl goes down, and the mobile thumbstick works too. Keys are ignored while you type in chat. Your character faces the camera direction.

Also: `Move.setFlySpeed(speed)`, `Move.isFlying()`. Fly pauses while a tween is running.

## Noclip

| Function | Description |
|---|---|
| `Move.noclip(on)` | turns collisions off for your character every physics step |
| `Move.isNoclipping()` | your noclip setting |

The parts it changed get their collisions back when it's turned off. Tweens and fly use their own temporary noclip, so they never switch off a noclip you turned on yourself.

## Helpers

| Function | Returns |
|---|---|
| `Move.getCharacter()` | your character |
| `Move.getRoot(char)` | HumanoidRootPart (or PrimaryPart) |
| `Move.getHumanoid(char)` | Humanoid |
| `Move.getCFrame(target)` | CFrame of any target, or `nil` |
| `Move.getPosition(target)` | Vector3 of any target, or `nil` |
| `Move.findPlayer(name)` | Player by exact, then partial, Name / DisplayName |

## Respawning and cleanup

Fly and noclip carry over to your new character after respawning. Tweens are cancelled.

`Move.destroy()` stops tweens, fly and noclip and disconnects everything. Call it from your script's Unload button.
