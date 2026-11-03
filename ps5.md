# PS5 UI library

A Roblox UI that looks and moves like the PS5 home screen: a boot animation, game tiles along the top, a big title with a background for each tab, and the tab's features as cards underneath. It has the same element API as GuiLibrary, so a script can switch between the two.

```lua
local REPO = "https://raw.githubusercontent.com/rawified/scals-hub/refs/heads/main/"
local Library = loadstring(game:HttpGet(REPO .. "ps5.luau"))()
```

## Quick start

```lua
local Window = Library:CreateWindow({ Name = "Scals Hub" })

local Tab = Window:CreateTab("Universal", { Description = "Works in every game." })
Tab:CreateToggle({
	Name = "Infinite Jump",
	CurrentValue = false,
	Flag = "InfiniteJump",
	Callback = function(on) print("infinite jump", on) end,
})
Tab:CreateSlider({
	Name = "WalkSpeed",
	Range = { 16, 200 },
	Increment = 1,
	Suffix = "studs/s",
	CurrentValue = 16,
	Flag = "WalkSpeed",
	Callback = function(v) print(v) end,
})

Library:Notify({ Title = "Loaded", Content = "Press RightShift to hide the hub." })
```

## Window

```lua
local Window = Library:CreateWindow({
	Name = "Scals Hub",
	ToggleKey = Enum.KeyCode.RightShift,   -- shows / hides the window (can be changed in Settings)
	Accent = Color3.fromRGB(0, 112, 220),  -- toggles, sliders, notification icons
	Fullscreen = false,                    -- true = covers the whole screen like the real console
	Blur = true,                           -- blurs the game behind the window (windowed only)
	Scale = 1,                             -- largest size; it always shrinks to fit the screen
	StartHidden = false,                   -- true = build first, then Window:SetVisible(true)
	ConfigurationSaving = { Enabled = true, FolderName = "ScalsHub", FileName = "Settings" },
	Splash = {                             -- false = no boot animation
		Image = "rbxassetid://123",        -- logo (without one, the window name is shown)
		Duration = 3.2,                    -- particles + logo, in seconds
		Subtitle = "hub",
		Welcome = true,                    -- the "Welcome back" user screen after the logo
		WelcomeText = "Welcome back to Scals Hub",
		AutoContinue = 5,                  -- seconds before the welcome screen moves on by itself
	},
	Sounds = { Move = "rbxassetid://...", Select = "rbxassetid://...", Boot = "rbxassetid://...", Notify = "rbxassetid://..." },
	Premium = nil,                         -- true / false overrides getgenv().GuiLibraryUser
	PremiumText = "Get a premium key on our Discord.",
	QueueOnTeleport = REPO .. "hub.lua",   -- runs again in the new server after teleporting
	ChangeKey = function() end,            -- adds "Change Key" to the account menu + Settings
	SignOut = function() end,              -- adds "Sign Out" to the account menu
})
```

| Method | Description |
|---|---|
| `Window:CreateTab(name, opts)` | adds a game tile, see [Tabs](#tabs) |
| `Window:SetVisible(bool)` / `Window:Toggle()` | shows / hides the window |
| `Window:SetToggleKey(KeyCode)` | changes the show / hide key |
| `Window:SelectTab(name)` | opens a tab by name (`"Settings"` works too) |
| `Window:SetPremium(bool)` / `Window:IsPremium()` | sets / reads premium for this window |
| `Window:SaveNow()` | writes the config file right away (it also saves by itself) |
| `Window:Destroy()` | removes the window |

With `ConfigurationSaving` on, every element that has a `Flag` is saved to `FolderName/FileName.json` and restored the next time the script runs.

## Tabs

Tabs are the game tiles in the row at the top. The selected tile grows and shows its name, the background crossfades to that tab's colours or picture, and its page slides in below.

```lua
local Tab = Window:CreateTab("Murder Mystery 2", {
	Image = "rbxassetid://...",       -- tile picture (else initials on a colour made from the name)
	Background = "rbxassetid://...",  -- full-screen art behind the page (else an animated gradient)
	Title = "Murder Mystery 2",       -- big title on the page (defaults to the tab name)
	Description = "Auto farm, ESP and more",
	Section = "Farming",              -- heading over the first row of cards
	ButtonText = "Explore",           -- button under the title; scrolls down to the cards
	PlaceId = 142823291,              -- adds a Play button that teleports to that game ("Rejoin" when you're in it)
	ForGame = { 142823291 },          -- which game the tile belongs to (only for ordering, locks nothing)
	Game = nil,                       -- locks every card on this tab outside that game
	GameName = "MM2",                 -- name shown on "ONLY IN ..." tags (defaults to Title / name)
	Premium = false,                  -- true = only premium users can use this tab
})

Window:CreateTab("Name", "rbxassetid://123") -- short form: just a tile image
```

**Tile order:** the tile for the game you're in comes first and opens automatically. Universal tiles (no `ForGame`, `Game` or `PlaceId`) come next, then tiles for other games, and Settings is always last. `ForGame` falls back to `Game`, then `PlaceId`.

**Navigation:** click the tiles, or use the Left / Right arrows (on a gamepad, the D-pad or L1 / R1). The mouse wheel or the white button scrolls down to the cards, and the tile row fades out like it does on the console.

## Elements (cards)

Each element is a card on the tab's page. Every element accepts these optional fields:

| Field | Meaning |
|---|---|
| `Flag = "SaveName"` | saves the value with ConfigurationSaving |
| `Description = "..."` | small text under the name |
| `Game = spec` | only usable in that game, see [Game locks](#game-locks) |
| `GameName = "..."` | name shown on the "ONLY IN ..." tag |
| `Premium = true` | only usable by premium users |

### Section

```lua
Tab:CreateSection("Combat") -- new heading + new row of cards
```

### Button

```lua
local Button = Tab:CreateButton({
	Name = "Kill All",
	Bind = Enum.KeyCode.K, -- optional hotkey
	Callback = function() end,
})
Button:SetBind(Enum.KeyCode.J) -- nil removes the hotkey
Button:Destroy()
```

### Toggle

```lua
local Toggle = Tab:CreateToggle({
	Name = "Auto Farm",
	CurrentValue = false,
	Flag = "AutoFarm",
	Callback = function(on) end,
	Loop = function() end,  -- optional: runs every Interval seconds while it's on
	Interval = 0.1,
})
Toggle:Set(true)        -- Toggle:Set(true, true) = without running the callback
Toggle:Get()
Toggle:SetBind(Enum.KeyCode.F)
```

If `Loop` errors, the toggle switches itself off and the error is printed in F9.

### Slider

```lua
local Slider = Tab:CreateSlider({
	Name = "Speed",
	Range = { 0, 100 },
	Increment = 1,
	Suffix = "studs/s",
	CurrentValue = 50,
	Flag = "Speed",
	Callback = function(v) end,
})
Slider:Set(75) / Slider:Get()
```

### Input

```lua
local Input = Tab:CreateInput({
	Name = "Target",
	PlaceholderText = "Player name",
	RemoveTextAfterFocusLost = false, -- true = clears after Enter (and isn't saved)
	Flag = "Target",
	Callback = function(text) end,
})
Input:Set("someone")
```

### Dropdown

Clicking the card opens the PS5 options sheet. It slides in from the right, each option has a radio circle, and the current choice is filled in.

```lua
local Dropdown = Tab:CreateDropdown({
	Name = "Mode",
	Options = { "Nearest", "Clusters" },
	CurrentOption = "Nearest",
	Flag = "Mode",
	Callback = function(option) end,
})
Dropdown:Set("Clusters") / Dropdown:Get()
Dropdown:Refresh({ "A", "B", "C" }, "B") -- new options (+ optional current one)
```

### Keybind

```lua
local Keybind = Tab:CreateKeybind({
	Name = "Kill All Hotkey",
	CurrentKeybind = Enum.KeyCode.K,
	Flag = "KillKey",
	Callback = function(key) end,  -- the key was pressed
	Changed = function(key) end,   -- the user picked a new key
})
Keybind:Set(Enum.KeyCode.L)
```

### Label

```lua
local Label = Tab:CreateLabel("Speeds above 150 may get you flagged.")
Label:Set("new text")
```

### Container

A full-width empty panel for custom UI, such as the Outfit Editor's item grids.

```lua
local frame = Tab:CreateContainer(300) -- height in pixels; parent your own instances to it
```

### Hotkeys on cards

Right-click a button or toggle card, then press a key. Escape cancels and Backspace clears the key. You can also pass `Bind = Enum.KeyCode.X`.

## Game locks

`Game` takes a **game spec**:

- a PlaceId: `142823291`
- a list of PlaceIds / GameIds: `{ 142823291, 335132309 }`
- a function that returns `true` when you're in the game: `function() return workspace:FindFirstChild("TapRemote") ~= nil end`

Outside that game, the card is dimmed with an "ONLY IN <GAME>" tag and clicking it only shows a notification. Locked toggles never run, even if they were saved as on, and startup callbacks are skipped. Locks are checked again every second.

`Library.InGame(spec)` runs the same check yourself.

## Premium

Put `Premium = true` on a tab or an element. For everyone else, the tile gets a gold lock, the cards get a "PREMIUM" tag, and clicks and hotkeys only show `PremiumText`. A locked toggle never runs, and it switches off if premium is lost.

Whether a user is premium comes from, in order:

1. `Premium = true / false` in CreateWindow, or `Window:SetPremium(bool)`.
2. `getgenv().GuiLibraryUser = { Premium = true, Tier = "Premium" }`, which the hub sets after the key check. A `Tier` containing "premium" also counts.

Premium users get a ★ badge on their picture.

## Notifications

```lua
Library:Notify({
	Title = "1 down, lots more to go!",
	Content = "Trophy earned!",       -- grey line under the title (optional)
	Duration = 4,
	Icon = "rbxassetid://...",        -- square picture on the left (else the accent colour with "!")
	Prefix = "🏆",                    -- put in front of the title
})
```

Notifications look like the console's: a dark charcoal pill that drops in at the top right. New ones push older ones down.

## Account menu

Click your picture (top right) to get:

- **Change Key**: only when `ChangeKey` is passed.
- **Hide my info / Show my info**: anonymous mode, which hides your name and picture.
- **Sign Out**: only when `SignOut` is passed.
- **Unload**

## Settings tile

Every window gets a Settings tile with the toggle key, sounds, background motion, blur, Anti AFK, anonymous mode, Change Key and Unload. These settings are shared by every script that uses the library and are saved in `GuiLibrary/PS5Settings.json`.

## Teleporting

The tab's Play button teleports to its `PlaceId`. With `QueueOnTeleport` set, the script runs again in the new server, so the hub comes back. This needs your executor's `queue_on_teleport`; Volt calls it `queueonteleport`, and both work.

- `QueueOnTeleport` can be a URL or Lua code.
- It waits for the game to load, then retries the download a few times.
- In the new server, `getgenv().ScalsGet(url)` downloads a script and returns it as a function, with the same retries.

## Loader (sign-in)

A console-style sign-in: the boot animation, then the "Welcome back" user screen, then the key screen, then either a home screen with your scripts or straight into the hub.

```lua
local Loader = Library:CreateLoader({
	Name = "Scals Hub",
	Footer = "gg/v4nta",
	Status = { Text = "Working / Undetected", Color = Color3.fromRGB(52, 199, 123) },
	Info = { { "Version", "1.0" } },
	Splash = { Image = "rbxassetid://...", Duration = 3.5, Subtitle = "hub" },
	LoginText = "Choose your user to sign in",
	StartScreen = nil,       -- "key" = skip the user screen (e.g. for Change Key)
	StartPage = "Key",       -- "Main" = the saved key is fine, signing in skips the key screen
	Home = true,             -- false = signing in finishes right away (OnLoad) with no home screen
	Options = { "Murder Mystery 2", "Universal" }, CurrentOption = "Universal", ButtonText = "Load",
	Fullscreen = false,
	OnLoad = function(option) end,   -- signed in / Load pressed
	OnClose = function() end,
	OnSelect = function(option) end, OnRefresh = function() end, OnShown = function() end,
	OnStreamerMode = function(on) end,
	Key = {
		Note = "Press Get Key, finish the steps, then paste your key here.",
		GetKeyLink = "https://...",      -- or OnGetKey = function() end
		Check = function(key) return true end, -- return ok, reason
		OnSuccess = function(key) end,
		OnResetKey = function() end,
	},
})
```

| Method | Description |
|---|---|
| `Loader:SetKeyStatus(text, isError)` | message under the key box |
| `Loader:ShowKey(message)` / `Loader:ShowMain()` | switch screens |
| `Loader:SetStatus(text, color)` / `Loader:SetInfo(label, value)` | the status and info chips |
| `Loader:SetOptions(list, current)` / `Loader:SetOption(o)` / `Loader:GetOption()` | script tiles on the home screen |
| `Loader:SetButton(text)` / `Loader:SetStreamerMode(bool)` | |
| `Loader:Close()` / `Loader:Destroy()` | |

## Unloading

| Function | Description |
|---|---|
| `Library:Unload()` | switches every feature off and removes all windows and notifications |
| `Library:OnUnload(fn)` | runs `fn` when unloading (call your libs' `destroy` here) |
| `Library:SetAnonymous(bool)` | turns anonymous mode on / off |

```lua
Library:OnUnload(function()
	MM2.destroy()
	Universal.destroy()
end)
```
