# Auto Tap library

Taps for you in the tapping game at a steady rate, never faster than the game accepts. No UI.

```lua
local REPO = "https://raw.githubusercontent.com/rawified/scals-hub/refs/heads/main/"
local Tap = loadstring(game:HttpGet(REPO .. "libs/autotap.lua"))()
```

## Game

| Field / function | Description |
|---|---|
| `Tap.PlaceId` | `nil` until you know it. Set it so `inGame` also matches the PlaceId |
| `Tap.inGame()` | `true` in the tapping game (found by its `RemoteServices.TapService`). Pass it as `Game = Tap.inGame` on hub features |

Nothing waits for the game's objects, so loading this in another game costs nothing.

## Tapping

```lua
Tap.set({ Rate = Tap.maxRate(), Method = "Game Tap" })
Tap.auto(true)
```

| Function | Description |
|---|---|
| `Tap.auto(on)` | auto tap on / off. Returns `true`, or `false, reason` outside the game |
| `Tap.set(opts)` | change any setting below |
| `Tap.tap()` | one tap. `false` when the game blocks taps right now |
| `Tap.maxRate()` | taps per second the game accepts (from `GameConfig.ClickFxInterval`) |
| `Tap.hasGameTap()` | the game's `TapController` was found, so `"Game Tap"` works |
| `Tap.stats()` | `sent, paidOut`: taps per second over the last second |
| `Tap.Sources` | `{ "button", "screen", "key_e", "rebirth_row" }` |
| `Tap.Settings` | the current settings |

| Setting | Default | Meaning |
|---|---|---|
| `Rate` | `10` | taps per second (capped by the game's minimum interval) |
| `Method` | `"Remote"` | `"Remote"` fires `TapRequested` directly. `"Game Tap"` goes through the game's own `TapController:Tap()` (real sequence number, sounds and effects) |
| `Source` | `"button"` | what the remote says the tap came from |

## How the game taps

From its `TapController`:

- `TapService.TapRequested:FireServer({ Auto = false, ClientSequence = n, Source = source })`
- `ClientSequence` goes up by 1 on every tap. The library starts at the game's own counter
- taps closer together than `GameConfig.ClickFxInterval` are thrown away, so at most one tap is sent per frame and it never bursts to catch up after lag
- taps are ignored while `MiningActive`, `AtDigsite`, `DiggingActive` or `ColosseumActive` is set on you; the library skips them too
- the server answers every tap with `TapService.TapResult`. `Tap.stats()` counts those answers (not the paid auto clicker's), so if "paid out" stays well below "sent", the server is rate-limiting you

## Cleanup

`Tap.destroy()` stops tapping and disconnects everything.
