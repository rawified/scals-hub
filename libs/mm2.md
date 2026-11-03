# Murder Mystery 2 library

Coin farm, role ESP, kill all and an event log for Murder Mystery 2. No UI: call it from any script.

```lua
local REPO = "https://raw.githubusercontent.com/rawified/scals-hub/refs/heads/main/"
local MM2 = loadstring(game:HttpGet(REPO .. "libs/mm2.lua"))()
```

## Game

| Field / function | Description |
|---|---|
| `MM2.PlaceIds` | `{ 142823291 }`. Pass it as `Game = MM2.PlaceIds` on hub features |
| `MM2.inGame()` | `true` in MM2 (matches PlaceId or GameId) |

Every function below refuses to start outside MM2 and returns `false` (or `nil`) plus a reason.

## Coin farm

```lua
MM2.setFarm({ Speed = 80, FarmMode = "Clusters" })
MM2.farm(true)
```

| Function | Description |
|---|---|
| `MM2.farm(on)` | switch the farm on / off. Returns `true`, or `false, reason` |
| `MM2.setFarm(opts)` | change any of the settings below (the rest stay as they are) |
| `MM2.Farm` | the current settings (read them, change them with `setFarm`) |
| `MM2.isFarming()` | the farm is switched on |
| `MM2.isBagFull()` | the bag filled up this round |
| `MM2.isRoundActive()` | a round with coins is running for you |

| Setting | Default | Meaning |
|---|---|---|
| `Speed` | `60` | studs per second |
| `FarmMode` | `"Nearest"` | `"Nearest"` or `"Clusters"` (clears the biggest group of coins first) |
| `PositionMode` | `"Normal"` | `"Normal"` or `"Under Floor"` (lies under the floor, always noclips) |
| `ClusterRadius` | `30` | studs: coins this close together count as one group |
| `FloorDepth` | `1.5` | studs below the floor in Under Floor mode |
| `RetryAfter` | `4` | seconds before a coin you reached may be tried again |
| `StopWhenFull` | `true` | stop and reset when the bag is full; resumes next round |
| `Noclip` | `true` | noclip while farming |

How it works: it finds whichever map holds a `CoinContainer` (it changes every round) and re-reads the coins left before every hop. The round starts when the game fires `CoinsStarted`, and ends for you when you respawn, get teleported far from the coins or the map is removed. The bag counts as full when `CoinCollected` reports current ≥ max, or the bag GUI shows "Full". The game hooks are only set up the first time you switch the farm on.

Speeds above ~150 may get you flagged.

## Role ESP

Knife = Murderer (red), Gun = Sheriff (blue), neither = Innocent (green).

| Function | Description |
|---|---|
| `MM2.esp(on)` | highlights + name / role / distance labels through walls |
| `MM2.setEsp(opts)` | `Highlights` (true), `Labels` (true), `ShowInnocents` (true) |
| `MM2.getRole(player)` | `"Murderer"`, `"Sheriff"` or `"Innocent"` |
| `MM2.getMurderer()` / `MM2.getSheriff()` | the Player, or `nil` |
| `MM2.RoleColors` | `{ Murderer = Color3, Sheriff = Color3, Innocent = Color3 }` |

## Kill all

Only works when you're the murderer. Equips your knife, then pins every living player 2 studs in front of you (on your screen) and stabs until they die or time runs out.

```lua
local killed, reason = MM2.killAll({ PerTarget = 1.5 }) -- yields
if not killed then print(reason) end
```

| Function | Description |
|---|---|
| `MM2.killAll(opts)` | yields. `PerTarget` = max seconds per player (1.5). Returns how many died, or `nil, reason` |
| `MM2.stopKillAll()` | stops a running kill all |
| `MM2.isKilling()` | `true` while it runs |

## Event log

`MM2.logEvents(true)` prints every `Remotes.Gameplay` event to the console (F9) with its arguments, which is how to find e.g. the event the game fires when a round ends.

## Messages

The library doesn't show anything itself. Set `MM2.Notify = function(title, text) end` to get its messages ("Bag Full", "No map loaded yet..."), e.g. as UI notifications. Without it they're printed to F9.

## Cleanup

`MM2.destroy()` turns everything off, cancels the farm tween, removes the ESP and disconnects everything. Call it from your script's Unload.
