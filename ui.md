# GuiLibrary

A single-file Roblox GUI library with Rayfield / Sirius-v2 style syntax. It builds a polished window (tabs, buttons, toggles, sliders, inputs, dropdowns, keybinds), a key-page **loader window**, notifications, themes, fonts, autosave, shared appearance settings, a startup splash, a user panel and a live info bar.

> It was written without being able to run Roblox. Test it in Studio or your executor first and report anything that misbehaves.

## Contents
- [Features](#features) · [Install](#install) · [Quick start](#quick-start)
- [CreateWindow](#createwindow) · [Window methods](#window-methods) · [Elements](#elements) · [Hotkeys](#hotkeys-for-buttons-and-toggles)
- [Loader window](#loader-window) · [Notifications](#notifications)
- [Themes](#themes) · [Fonts](#fonts) · [User panel](#user-panel) · [Anonymous mode](#anonymous-mode)
- [Settings page](#settings-page-gear) · [Shared settings](#shared-settings-same-in-every-script) · [Autosave](#autosave) · [Unload](#unload)
- [Splash screen](#splash-screen) · [Info bar](#info-bar) · [Resizing](#resizing-and-minimizing) · [Tuning](#tuning) · [Notes](#notes)

## Features
- Add tabs and items to the window from code, at any time
- Elements: label, button, toggle (with a repeating `Loop`), slider, input, dropdown, keybind
- Hotkeys for any button or toggle (right-click it, press a key)
- Resizable window (drag the bottom-right grip) that can also be minimized
- Rounded, slightly translucent window with a darker see-through backdrop, drifting sprinkles, and an animated glow and shine behind the window, the info bar and notifications
- Fade in/out for windows and notifications; squish, ripple and glow effects on buttons, toggles and sliders
- Loader window: profile card, status, info rows, script picker, big load button and an optional key page
- 8 themes (including Halloween, Christmas and Monochrome) and 8 font presets, switchable live
- Shared appearance settings: theme, font, toggle key, info bar, anti AFK and anonymous mode are remembered across every script
- Per-script autosave of every element
- Discord-style user panel with a Premium / Regular status and a theme-coloured shimmer for premium names
- Anonymous mode that hides your name and picture
- Anti AFK toggle and an **Unload Script** button that turns every feature off
- Draggable info bar (ping / FPS / time)
- Startup splash screen with your logo
- Always on top of other GUIs

## Install
**Option A: ModuleScript (Studio).** Put `GuiLibrary.lua` in a ModuleScript named `GuiLibrary` (for example in ReplicatedStorage), then from a LocalScript:
```lua
local Library = require(game.ReplicatedStorage:WaitForChild("GuiLibrary"))
```
**Option B: executor.** Save the file in your executor's workspace folder:
```lua
local Library = loadstring(readfile("GuiLibrary.lua"))()
```
or host it and load it with `loadstring(game:HttpGet("https://.../GuiLibrary.lua"))()`.

**Option C: one LocalScript.** Paste your own code at the bottom of the file, just above `return Library`.

See `Example.lua` for a complete working script.

## Quick start
```lua
local Window = Library:CreateWindow({ Name = "My Hub" })
local Tab = Window:CreateTab("Main")

Tab:CreateButton({ Name = "Hello", Callback = function() print("hi") end })
Tab:CreateToggle({ Name = "Spam", Loop = function() print("hi") end })
```

## CreateWindow
```lua
local Window = Library:CreateWindow({
	Name = "My Hub",                     -- title (shown uppercase)
	ToggleKey = Enum.KeyCode.RightShift, -- default RightShift
	Theme = "Dark",                      -- default theme; a theme saved in Settings wins
	InfoBar = true,                      -- ping / fps / time, top right
	Premium = nil,                       -- true / false forces the user panel's status (see User panel)
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "MyHub",
		FileName = "Config",
	},
	Splash = { Image = "rbxassetid://123", Duration = 4.5, Subtitle = "loading" }, -- or false
})
```
Every field is optional.

## Window methods
| Method | Description |
|---|---|
| `Window:CreateTab(name)` | Adds a tab and returns it |
| `Window:Toggle()` | Show / hide |
| `Window:SetVisible(bool)` | Show / hide with a fade |
| `Window:SetToggleKey(KeyCode)` | Change the show/hide key |
| `Window:SetInfoBar(bool)` | Show / hide the info bar |
| `Window:SetPremium(bool)` | Force the Premium / Regular status of the user panel |
| `Window:SaveNow()` | Write the per-script save file immediately |
| `Window:Unload()` | Same as `Library:Unload()` (see [Unload](#unload)) |
| `Window:Destroy()` | Remove just this window |
| `Window.Flags` | Table of every saved value, by flag name |
| `Window.SettingsTab` | The built-in settings tab |

The title-bar buttons are: gear (settings page), minimize, close. Closing destroys the window; use minimize or the toggle key to only hide it.

## Elements
Every element accepts an optional `Flag = "SaveName"`. Without one, the flag is `"<Tab name>/<Element name>"`. Flags are what the autosave stores, so keep names stable.

### Label
```lua
local label = Tab:CreateLabel("Some text")
label:Set("New text")
```

### Button
```lua
local b = Tab:CreateButton({
	Name = "Press me",
	Callback = function() end,
	Bind = Enum.KeyCode.H,   -- optional default hotkey
})
b:SetBind(Enum.KeyCode.J)    -- or SetBind(nil) to clear
b:Destroy()
```

### Toggle
```lua
local t = Tab:CreateToggle({
	Name = "Speed",
	CurrentValue = false,
	Callback = function(value) end,  -- fires on every change
	Loop = function() end,           -- optional: repeats while the toggle is ON
	Interval = 0.1,                  -- seconds between Loop calls (default 0.1)
	Flag = "Speed",
	Bind = Enum.KeyCode.X,           -- optional default hotkey
})
t:Set(true)        -- t:Set(true, true) changes it without firing Callback
t:Get()
t:SetBind(nil)
```
If the `Loop` function errors, the toggle switches itself off and prints a warning. A toggle restored as ON from a save starts its loop again.

### Slider
```lua
local s = Tab:CreateSlider({
	Name = "Walk speed",
	Range = { 16, 100 },
	Increment = 1,
	Suffix = " studs/s",
	CurrentValue = 16,
	Callback = function(value) end,
	Flag = "WalkSpeed",
})
s:Set(50)
```

### Input
```lua
local i = Tab:CreateInput({
	Name = "Player",
	PlaceholderText = "name...",
	RemoveTextAfterFocusLost = false,
	Callback = function(text) end,
})
i:Set("text")
```

### Dropdown
```lua
local d = Tab:CreateDropdown({
	Name = "Mode",
	Options = { "A", "B", "C" },
	CurrentOption = "A",
	Callback = function(option) end,
})
d:Set("B")
```

### Keybind
```lua
local k = Tab:CreateKeybind({
	Name = "Fly key",
	CurrentKeybind = Enum.KeyCode.F,
	Callback = function(key) end,  -- the key was pressed
	Changed = function(key) end,   -- the user rebound it
})
k:Set(Enum.KeyCode.G)
```
Clicking a keybind row waits for a key; Escape cancels.

## Hotkeys for buttons and toggles
Every button and toggle, including the ones in Settings, can have a hotkey:
- **Right-click** the element, then press a key. A small key tag appears on the row.
- **Escape** cancels, **Backspace / Delete** clears the hotkey.
- Hotkeys work while the window is hidden, but not while you are typing in a text box.
- They are saved with autosave (flag `<flag>/Bind`) and restored on start.
- In code: `Bind = Enum.KeyCode.X` in the options sets a default, and `element:SetBind(KeyCode or nil)` changes or clears it.

## Loader window
`Library:CreateLoader` builds a separate "hub loader" window: a profile card (avatar, display name, username), a status line, info rows, a script dropdown, a big load button, a Streamer Mode card and an optional key page. It uses the same themes, fonts, sprinkles, glow and splash as the main window. The loader is only the picker; your own code decides what happens in `OnLoad`.

```lua
local Loader = Library:CreateLoader({
	Name = "Scals Hub",
	Theme = "Monochrome",                -- default theme; a theme saved in Settings wins
	Accent = Color3.fromRGB(52, 199, 123), -- optional, defaults to the theme accent
	Splash = { Image = "rbxassetid://123", Duration = 3.5, Subtitle = "loader" }, -- optional
	Font = nil,                          -- optional font family; default follows the font preset
	Footer = "gg/v4nta",
	Status = { Text = "Working / Undetected", Color = Color3.fromRGB(52, 199, 123) },
	Info = { { "Last Updated", "6/11/26" }, { "Version", "V1.0.0" }, { "Type", "-" } },
	DropdownName = "Script",
	Options = { "Murder Mystery 2", "Universal" },
	CurrentOption = "Universal",
	ButtonText = "Load Script",
	StreamerMode = false,                -- default for anonymous mode (the saved choice wins)
	StartPage = "Key",                   -- "Key" | "Main" (default: "Key" when Key is set)

	OnLoad = function(option) end,       -- big button
	OnSelect = function(option) end,     -- dropdown changed
	OnRefresh = function() end,          -- refresh icon, top right
	OnStreamerMode = function(on) end,
	OnClose = function() end,
	OnShown = function() end,            -- fired once the loader is visible (after the splash)

	Key = {                              -- optional key page
		Note = "Press Get Key, then paste your key below.",
		Placeholder = "Paste your key here",
		GetKeyLink = "https://...",      -- copied by "Get Key"
		OnGetKey = function() end,       -- or fetch the link yourself when the button is pressed
		Check = function(key) return true end, -- return true, or false + a reason to show
		OnSuccess = function(key) end,   -- after a valid key
		OnResetKey = function() end,     -- "Change key" pressed twice: forget the saved key
	},
})
```

| Method | Description |
|---|---|
| `Loader:SetInfo(label, value)` | Change one of the info rows, for example `("Type", "Premium")` |
| `Loader:SetStatus(text, color)` | Change the status line and its dot colour |
| `Loader:SetOptions(list, current)` | Replace the dropdown options |
| `Loader:SetOption(option)` / `:GetOption()` | Select / read the current script |
| `Loader:SetButton(text)` | Change the big button's text (for example a countdown) |
| `Loader:SetStreamerMode(bool)` | Turn anonymous mode on or off |
| `Loader:ShowKey(message)` / `:ShowMain()` | Switch pages |
| `Loader:SetKeyStatus(text, isError)` | Message under the key box |
| `Loader:Close()` | Fade out (lets the next window play its splash again) |
| `Loader:Destroy()` | Remove immediately |

- **Splash handoff:** when a loader plays the splash it sets `getgenv().GuiLibrarySplashShown`, so the main window of the script it loads doesn't play it a second time.
- **Key services:** the library contains no key-service code. Your loader script validates the key and passes the result on (see [User panel](#user-panel)).

## Notifications
```lua
Library:Notify({ Title = "Done", Content = "Saved your settings", Duration = 4 })
```
Cards slide in with a fade, get the same glow and shine as the window, and always render above other GUIs.

## Themes
`Dark`, `Light`, `Ocean`, `Rose`, `Forest`, `Halloween` (deep purple with pumpkin orange), `Christmas` (pine green with festive red), `Monochrome` (black and white).
```lua
Library:SetTheme("Ocean")
print(Library.CurrentTheme)
```
Also available in Settings, and remembered across scripts. The glow, shine, sprinkles and the Premium name effect all follow the theme's accent colour.

## Fonts
Presets: `Default`, `Modern`, `Clean`, `Techno`, `Gothic`, `Elegant`, `Retro`, `Rounded`.
```lua
Library:SetFont("Gothic")
print(Library.CurrentFont)
```
Also available in Settings > Font, and remembered across scripts. Every preset fills four roles (title, heading, body, light); the info bar always stays monospaced so the numbers don't jitter. Wider fonts truncate long names with an ellipsis. To add your own, add an entry to `FontPresets` and `FontOrder` in the Fonts section of the library.

## User panel
A small Discord-style panel sits at the bottom left of the window: your avatar with a green online dot, your display name, and either **Premium** or **Regular** underneath. Premium names get an animated shimmer and glow built from the current theme's accent colour (it recolours when you change theme); the avatar gets an accent ring. In [anonymous mode](#anonymous-mode) the name and picture are hidden.

**How it knows who is premium:** the library has no key-service code. The loader that validates the key hands the result over through the executor environment, and the library only reads it:
```lua
local env = (typeof(getgenv) == "function" and getgenv()) or _G
env.GuiLibraryUser = { Premium = true, Tier = "Premium" } -- set by your loader after the key check
env.SCRIPT_KEY = key                                      -- the validated key (a Jnkie loader sets this already)
```
`Premium = true`, or a `Tier` containing the word "premium", shows Premium; anything else (or no loader) shows Regular. The panel re-checks once a second, so a key accepted after the window opened is picked up. Clear `env.GuiLibraryUser` (for example when the user changes key) and it goes back to Regular.

Override it with `Premium = true/false` in `CreateWindow`, or at runtime with `Window:SetPremium(true)`.

## Anonymous mode
Hides your name and picture: the main window's user panel shows "Anonymous" with a blank avatar, and the loader window shows its "HIDDEN" profile. Turn it on in Settings > Anonymous Mode or with the Streamer Mode card in the loader (both are the same switch). It is saved in the shared settings file, so it stays on in every script until you turn it off. In code: `Library:SetAnonymous(true)`, `Library.Anonymous`.

## Settings page (gear)
The gear opens a built-in page. It is always present and cannot be removed:

| Setting | What it does |
|---|---|
| Theme | Dropdown of all themes |
| Font | Dropdown of the font presets |
| Toggle Window | Keybind that shows / hides the window |
| Info Bar | Show / hide the ping, FPS and time bar |
| Anti AFK | When Roblox marks you idle (about 20 minutes without input) it sends a fake click so you are not kicked |
| Anonymous Mode | Hide your name and picture (see above) |
| Unload Script | Press twice within 3 seconds to turn everything off (see [Unload](#unload)) |

Below them, status lines show where the shared settings and the autosave file are stored (or that there is no file access).

## Shared settings (same in every script)
Theme, Font, the Toggle Window key, Info Bar, Anti AFK, Anonymous Mode and the info bar position are saved in one separate file, `GuiLibrary/GlobalSettings.json`, that every script using the library reads. Change them once and every other script opens with the same look.
- A saved choice beats the `Theme = "..."` a script passes to `CreateWindow` / `CreateLoader`; that option is only the default for a first run.
- Script-specific values (your toggles, sliders, hotkeys...) stay in each script's own autosave file, so scripts don't overwrite each other.
- `Library.GlobalSettingsFile = "MyFolder/File.json"` changes the path (set it before `CreateWindow`). Delete the file to reset the look.
- Needs executor file access, like autosave. Without it the settings still work but aren't remembered.

## Autosave
- Enabled with `ConfigurationSaving = { Enabled = true, FolderName, FileName }` (on by default).
- Saves to `<FolderName>/<FileName>.json` shortly after any change (debounced 0.4 s).
- On start, saved values are restored and each element's `Callback` is fired with the restored value.
- Needs an executor with `writefile`, `readfile`, `isfile` and `makefolder`. Without them, autosave switches itself off quietly and the Settings page says so.
- Studio and plain LocalScripts have no file access, so nothing is saved there.

## Unload
Settings > **Unload Script** (press it twice within 3 seconds) removes the whole GUI and turns every feature off:
1. every toggle is switched off, so loops stop and each toggle's `Callback(false)` runs to undo what it did;
2. functions registered with `Library:OnUnload(function() ... end)` run, so you can disconnect your own connections or restore anything a button changed;
3. all windows, the info bar and notifications are destroyed.

Saved states are not overwritten by an unload, so toggles that were on come back on next run. From code: `Library:Unload()` or `Window:Unload()`.
```lua
Library:OnUnload(function()
	if myConnection then myConnection:Disconnect() end
end)
```
A button's effect can't be undone automatically, so use `OnUnload` for anything a button changed in the game.

## Splash screen
Plays once on start, then the window fades in. Any key or click skips it after 0.8 s.
```lua
Splash = {
	Image = "rbxassetid://123456789", -- or a bare id, or a file name in the executor workspace
	Duration = 4.5,
	Subtitle = "loading",
}
```
`Splash = false` turns it off. With no image, the window name is shown in large letters instead. If the image can't load, the text version is shown and the window still opens. The same option works on `CreateLoader`.

**Using a logo:** upload your picture at Creator Hub > Images, wait for moderation, then use the resulting id. In an executor you can also drop the file in the workspace folder and set `Image = "logo.png"`. (`SCALS_logo.png` is a white-on-transparent version of the SCALS picture.)

## Info bar
Top-right bar with ping, FPS and the local time, with its own glow and shine. It stays visible when the window is hidden.
- Toggle it with `InfoBar = true/false`, `Window:SetInfoBar(bool)` or the Settings page.
- Drag it anywhere with the mouse or touch; right-click it to send it back to the top-right corner. Its position is remembered in the shared settings file.

## Resizing and minimizing
Drag the three-line grip in the bottom-right corner to resize (minimum 400x260, maximum 1000x700, set by `MinSize` / `MaxSize` in the library). The top-left corner stays put. The minimize button collapses the window to its title bar and restores the size you chose. Drag the title bar to move the window.

## Tuning
Constants at the top of `GuiLibrary.lua`:

| Name | Default | Meaning |
|---|---|---|
| `Alpha` | 0.06 | Window translucency |
| `BackdropAlpha` | 0.5 | Darkness of the screen behind the window (lower is darker) |
| `SprinkleCount` | 130 | Particles on the backdrop |
| `GlowEnabled` | true | Glow and shine behind the window, info bar and notifications |

## Notes
- The window and cards are CanvasGroups so they fade as one piece and keep their rounded corners; very large UI scale can soften text slightly.
- GUIs use a very high `DisplayOrder` so they stay above other ScreenGuis.
- Loops, animations and hotkeys run client-side only.
- Anti AFK relies on Roblox's `VirtualUser`; if a game or executor blocks it, a warning is printed.
