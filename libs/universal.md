# Universal library

WalkSpeed, Infinite Jump, Fly, ESP and Aimbot that work in every game. No UI.

```lua
local REPO = "https://raw.githubusercontent.com/rawified/scals-hub/refs/heads/main/"
local U = loadstring(game:HttpGet(REPO .. "libs/universal.lua"))()
```

## Movement

| Function | Description |
|---|---|
| `U.walkSpeed(on)` | custom WalkSpeed on / off. Re-applied every frame because games reset it; your game's own speed comes back when it's switched off |
| `U.setWalkSpeed(v)` | the speed to use (default `32`, Roblox's is 16) |
| `U.infiniteJump(on)` | jump again in mid-air (space or the mobile button) |

## Fly

```lua
U.setFly({ Mode = "Noclip", Speed = 80 })
U.fly(true)
```

| Function | Description |
|---|---|
| `U.fly(on)` | fly on / off |
| `U.setFly(opts)` | change any setting below; a running flight switches over on the next frame |

| Setting | Default | Meaning |
|---|---|---|
| `Mode` | `"Noclip"` | `"Noclip"`: float through everything, WASD flies where the camera looks, Space up, Left Ctrl down. `"Platform"`: walk on a part that follows you, Space / Left Ctrl raise or lower it |
| `Speed` | `50` | Noclip flying speed (studs/s) |
| `VerticalSpeed` | `30` | Platform up / down speed (studs/s). Sideways speed is your WalkSpeed |
| `ShowPlatform` | `true` | see-through platform, or fully invisible |

Keys are ignored while you type in chat. Fly carries over to your new character after respawning.

## ESP

```lua
U.setEsp({ Boxes = true, Chams = true, Color = "Red" })
```

| Setting | Default | Meaning |
|---|---|---|
| `Boxes` | `false` | 2D boxes around players |
| `Names` | `true` | name + distance above each box |
| `Chams` | `false` | highlight through walls (Roblox draws at most 31 at once) |
| `ChamsFill` | `0.5` | chams fill transparency, 0 = solid, 1 = outline only |
| `TeamCheck` | `false` | skip players on your team |
| `Color` | `"Team Color"` | one of `U.EspColors`: `"Team Color"`, `"White"`, `"Red"`, `"Green"`, `"Blue"`, `"Yellow"`, `"Purple"`. Team Color falls back to white for NPCs and games without teams |
| `IncludeNPCs` | `false` | also show NPCs: models in workspace whose PrimaryPart is HumanoidRootPart (not player characters) |

## Aimbot

While the aim key is held, it turns the camera (or moves the mouse) toward the target closest to your cursor, and stays locked on that target while it's still valid.

| Function | Description |
|---|---|
| `U.aimbot(on)` | aimbot on / off |
| `U.setAimbot(opts)` | change any setting below |
| `U.getAimTarget()` | the Player / NPC model it's locked on, or `nil` |
| `U.hasMouseMove()` | the executor has `mousemoverel` (needed for `Method = "Mouse"`) |

| Setting | Default | Meaning |
|---|---|---|
| `Activation` | `"Hold Right Mouse"` | or `"Always"` |
| `Method` | `"Camera"` | `"Mouse"` moves the real mouse instead; use it when the game has its own camera |
| `Part` | `"Head"` | or `"Torso"`. NPCs without one use their root part |
| `UseFov` | `true` | only targets inside the circle |
| `ShowFov` | `true` | draw the circle |
| `Fov` | `120` | circle radius in pixels |
| `Smoothing` | `5` | 1 = instant snap, higher = slower and more natural |
| `TeamCheck` | `true` | skip your team |
| `WallCheck` | `false` | only targets you can actually see |
| `IncludeNPCs` | `false` | also target NPC models |

## Settings and cleanup

`U.Settings`, `U.Fly`, `U.Esp` and `U.Aim` hold the current settings (change them with the set functions).

`U.destroy()` turns everything off, puts your WalkSpeed back, removes the ESP and the aimbot, and disconnects everything. Call it from your script's Unload.
