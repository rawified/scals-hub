# GuiLibrary

A single-file Roblox GUI library with Rayfield / Sirius-v2 style syntax: tabs, buttons, toggles, sliders, inputs, dropdowns, keybinds, notifications, themes, fonts, autosave, a startup splash and a live info bar.

> Written without being able to run Roblox. Test it in Studio first and report anything that misbehaves.

## Contents
- [Install](#install) · [Quick start](#quick-start) · [CreateWindow](#createwindow) · [Window methods](#window-methods)
- [Elements](#elements) · [Notifications](#notifications) · [Themes](#themes) · [Fonts](#fonts)
- [Settings gear](#settings-gear) · [Autosave](#autosave) · [Splash screen](#splash-screen) · [Info bar](#info-bar)
- [Tuning](#tuning) · [Notes](#notes)

## Features
- Add tabs and items to the window from code, at any time
- Resizable window: drag the grip in the bottom-right corner (min 400x260, max 1000x700)
- Rounded, slightly translucent window, darker see-through backdrop with drifting sprinkles, animated glow and shine behind the window
- Fade in/out for the window and notifications; effects on buttons (squish and ripple), toggles and sliders
- Toggles that repeat a function while on (`Loop`)
- Hotkeys for any button or toggle (right-click it, press a key)
- Autosave of every element, theme, font, toggle key and info-bar choice
- 6 themes (including Monochrome), 8 font presets, both switchable live
- Info bar (ping / FPS / time) in the top-right corner with its own glow and shine
- Startup splash screen with your logo
- Always on top of other GUIs
- Settings gear next to minimize and close

## Install
**Option A: ModuleScript (recommended).** Put `GuiLibrary.lua` in a ModuleScript named `GuiLibrary` (for example in ReplicatedStorage), then from a LocalScript:
```lua
local Library = require(game.ReplicatedStorage:WaitForChild("GuiLibrary"))
```
**Option B: executor.** Save the file in your executor's workspace folder:
```lua
local Library = loadstring(readfile("GuiLibrary.lua"))()
```
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
	Theme = "Dark",                      -- Dark | Light | Ocean | Rose | Forest | Halloween | Christmas | Monochrome
	InfoBar = true,                      -- ping / fps / time, top right
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
| `Window:SaveNow()` | Write the save file immediately |
| `Window:Destroy()` | Remove the window |
| `Window.Flags` | Table of every saved value, by flag name |
| `Window.SettingsTab` | The built-in settings tab |

The title-bar buttons are: gear (settings), minimize, close.

## Elements
Every element accepts an optional `Flag = "SaveName"`. Without one, the flag is `"<Tab>/<Element name>"`. Flags are what the autosave stores, so keep names stable.

### Label
```lua
local label = Tab:CreateLabel("Some text")
label:Set("New text")
```

### Button
```lua
Tab:CreateButton({ Name = "Press me", Callback = function() end })
```

### Hotkeys for buttons and toggles
Every button and toggle (including the ones in Settings) can have a hotkey:
- **Right-click** the element, then press a key. A small key tag appears on the row.
- **Escape** cancels, **Backspace / Delete** clears the hotkey.
- Hotkeys work while the window is hidden, but not while you are typing in a text box.
- They are saved with autosave (flag `<flag>/Bind`) and restored on start.
- In code: `Bind = Enum.KeyCode.X` in the options sets a default, and `element:SetBind(Enum.KeyCode.X)` / `element:SetBind(nil)` changes or clears it.

### Toggle
```lua
local t = Tab:CreateToggle({
	Name = "Speed",
	CurrentValue = false,
	Callback = function(value) end,  -- fires on every change
	Loop = function() end,           -- optional: repeats while the toggle is ON
	Interval = 0.1,                  -- seconds between Loop calls (default 0.1)
	Flag = "Speed",
})
t:Set(true)        -- t:Set(true, true) changes it without firing Callback
t:Get()
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

## Notifications
```lua
Library:Notify({ Title = "Done", Content = "Saved your settings", Duration = 4 })
```
Cards slide in with a fade and always render above other GUIs.

## Themes
`Dark`, `Light`, `Ocean`, `Rose`, `Forest`, `Halloween` (deep purple with pumpkin orange), `Christmas` (pine green with festive red), `Monochrome` (black and white).
```lua
Library:SetTheme("Ocean")
print(Library.CurrentTheme)
```
Also available in Settings, and saved automatically.

## Fonts
Presets: `Default`, `Modern`, `Clean`, `Techno`, `Gothic`, `Elegant`, `Retro`, `Rounded`.
```lua
Library:SetFont("Gothic")
print(Library.CurrentFont)
```
Also available in Settings > Font, and saved automatically. Every preset fills four roles (title, heading, body, light); the info bar always stays monospaced so the numbers don't jitter. Wider fonts truncate long names with an ellipsis. To add your own, add an entry to `FontPresets` and `FontOrder` in the Fonts section of the library.

## User panel
A small Discord-style panel sits at the bottom left of the window: your avatar with a green online dot, your display name, and either **Premium** or **Regular** underneath. Premium names get an animated shimmer and glow built from the current theme's accent colour (it recolours when you change theme); the avatar gets an accent ring.

**How it knows who is premium:** the library has no key-service code in it. The loader that validates the key hands the result over through the executor environment, and the library only reads it:
```lua
local env = (typeof(getgenv) == "function" and getgenv()) or _G
env.GuiLibraryUser = { Premium = true, Tier = "Premium" } -- set by your loader after the key check
env.SCRIPT_KEY = key                                      -- the validated key (a Jnkie loader sets this already)
```
`Premium = true`, or a `Tier` containing the word "premium", shows Premium; anything else (or no loader) shows Regular. The panel re-checks once a second, so a key accepted after the window opened is picked up. Clear `env.GuiLibraryUser` (for example when the user changes key) and it goes back to Regular.

Override it with `Premium = true/false` in `CreateWindow`, or at runtime with `Window:SetPremium(true)`.

## Anonymous mode
Hides your name and picture: the main window's user panel shows "Anonymous" with a blank avatar, and the loader window shows its "HIDDEN" profile. Turn it on in Settings > Anonymous Mode or with the Streamer Mode card in the loader (both are the same switch). It is saved in the shared settings file, so it stays on in every script until you turn it off. In code: `Library:SetAnonymous(true)`, `Library.Anonymous`.

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

## Settings gear
The gear opens a built-in page with: Theme, Font, Toggle Window keybind, Info Bar toggle, Anti AFK toggle, Anonymous Mode toggle, Unload Script button (sends a fake click when Roblox marks you idle, so you are not kicked after ~20 minutes; saved like other settings) and an autosave status line. It is always present and cannot be removed.

## Shared settings (same in every script)
Theme, Font, the Toggle Window key, Info Bar and Anti AFK are saved in one separate file, `GuiLibrary/GlobalSettings.json`, that every script using the library reads. Change them once in the gear page and every other script opens with the same look.
- A saved choice beats the `Theme = "..."` a script passes to `CreateWindow` / `CreateLoader`; that option is only the default for a first run.
- Script-specific values (your toggles, sliders, hotkeys...) stay in each script's own autosave file, so scripts don't overwrite each other.
- `Library.GlobalSettingsFile = "MyFolder/File.json"` changes the path (set it before `CreateWindow`). Delete the file to reset the look.
- Needs executor file access, like autosave. Without it the settings still work but aren't remembered.

## Autosave
- Enabled with `ConfigurationSaving = { Enabled = true, FolderName, FileName }`.
- Saves to `<FolderName>/<FileName>.json` shortly after any change (debounced 0.4 s).
- On start, saved values are restored and each element's `Callback` is fired with the restored value.
- Needs an executor with `writefile`, `readfile`, `isfile` and `makefolder`. Without them, autosave switches itself off quietly and the Settings page says so.
- Studio and plain LocalScripts have no file access, so nothing is saved there.

## Splash screen
Plays once on start, then the window fades in. Any key or click skips it after 0.8 s.
```lua
Splash = {
	Image = "rbxassetid://123456789", -- or a bare id, or a file name in the executor workspace
	Duration = 4.5,
	Subtitle = "loading",
}
```
`Splash = false` turns it off. With no image, the window name is shown in large letters instead.

**Using the SCALS logo:** `SCALS_logo.png` is a white-on-transparent version of your picture. Upload it at Creator Hub > Images, wait for moderation, then use the resulting id. In an executor you can drop the file in the workspace folder and set `Image = "SCALS_logo.png"`. If the image can't load, the text version is shown and the window still opens.

## Info bar
Drag the bar anywhere with the mouse or touch; right-click it to send it back to the top-right corner. Its position is remembered in the shared settings file.

Top-right bar with ping, FPS and the local time, with its own glow and shine. Toggle it with `InfoBar = true/false`, `Window:SetInfoBar(bool)` or the Settings page. It stays visible when the window is hidden.

## Tuning
Constants at the top of `GuiLibrary.lua`:

| Name | Default | Meaning |
|---|---|---|
| `Alpha` | 0.06 | Window translucency |
| `BackdropAlpha` | 0.5 | Darkness of the screen behind the window (lower is darker) |
| `SprinkleCount` | 130 | Particles on the backdrop |
| `GlowEnabled` | true | Glow and shine behind the window and info bar |

## Notes
- The window and cards are CanvasGroups so they fade as one piece and keep their rounded corners; very large UI scale can soften text slightly.
- GUIs use a very high `DisplayOrder` so they stay above other ScreenGuis.
- Closing the window destroys it. Use minimize or the toggle key to just hide it.
- Loops and animations run client-side only.
