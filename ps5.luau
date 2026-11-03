--[[
	PS5Library - a console home screen style UI for Scals Hub (same element API as GuiLibrary)

	local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/rawified/scals-hub/refs/heads/main/ps5.luau"))()

	WINDOW
		local Window = Library:CreateWindow({
			Name = "Scals Hub",
			ToggleKey = Enum.KeyCode.RightShift,
			Accent = Color3.fromRGB(0, 112, 220),   -- toggles, sliders, notifications
			Fullscreen = false,                     -- true = takes the whole screen (users can change it in Settings)
			Theme = "Cosmic Blue",                  -- default background theme (users can change it in Settings)
			Blur = true,                            -- blurs the game behind the window (windowed only)
			Scale = 1,                              -- max size; it always shrinks to fit the screen
			ConfigurationSaving = { Enabled = true, FolderName = "ScalsHub", FileName = "Settings" },
			Splash = {                              -- false = no boot animation
				Image = "rbxassetid://123",         -- logo; without one the window name is used
				Duration = 3.2,                     -- particles + logo part, in seconds
				Subtitle = "loader",
				Welcome = true,                     -- the "Welcome back" user screen after the logo
				WelcomeText = "Welcome back to Scals Hub",
				AutoContinue = 5,                   -- seconds before the welcome screen continues by itself
			},
			Sounds = { Move = "rbxassetid://...", Select = "rbxassetid://...", Boot = "rbxassetid://..." },
		})

	TABS = the game tiles in the row at the top. The selected tile grows, its name shows next to it,
	the background crossfades to that tab's colours / picture, and the page below swaps in.
		local Tab = Window:CreateTab("Murder Mystery 2", {
			Image = "rbxassetid://...",        -- tile picture (else initials on a colour made from the name)
			Background = "rbxassetid://...",   -- full-screen art behind the page (else an animated gradient)
			Title = "Murder Mystery 2",        -- big title on the page (defaults to the tab name)
			Description = "Auto farm, ESP and more",
			Section = "Items",                 -- heading over the first row of cards
			ButtonText = "Explore",            -- button under the title, scrolls down to the items
			PlaceId = 142823291,               -- adds a white Play button that teleports you to that game
			ForGame = { 142823291 },           -- which game this tile is for (ids or a function), used to
			                                   -- put it first and open on it when you're in that game.
			                                   -- Defaults to Game / PlaceId. Tiles without any = universal:
			                                   -- order is your game, universal tiles, then other games.
			                                   -- ("Rejoin" when you're already in it)
			Premium = true,                    -- only premium users can use anything on this tab
		})
		Window:CreateTab("Name", "rbxassetid://123") also works (just an image).

	PREMIUM: put Premium = true on a tab, a toggle or a button. For everyone else the tile gets a gold
	lock, the cards are dimmed with a "PREMIUM" tag, and clicks / hotkeys only show a notification.
	A locked toggle never runs (even if it was saved as on), and switches off if premium is lost.
	Who is premium: getgenv().GuiLibraryUser = { Premium = true } (set by the loader after the key
	check), or Premium = true/false in CreateWindow, or Window:SetPremium(bool). Window:IsPremium().
	CreateWindow({ PremiumText = "Get a premium key on our Discord." }) changes the notification text.

	TELEPORT: CreateWindow({ QueueOnTeleport = "https://raw.githubusercontent.com/.../loader.lua" }) downloads
	and runs that script again in the new server (needs queue_on_teleport, e.g. Volt's queueonteleport),
	so the hub comes back. It waits for the game to load and retries the download a few times.
	Lua code instead of a URL also works. In the new server, getgenv().ScalsGet(url) returns the
	downloaded script as a function, with the same retries.

	ITEMS = the cards under each tab (the "community" row). Every element is a card and every one
	accepts an optional Flag = "SaveName" and Description = "small text under the name".
		Tab:CreateSection("Combat")           -- new heading + new row of cards
		Tab:CreateButton({Name, Callback})
		Tab:CreateToggle({Name, CurrentValue, Callback(value), Loop = function() end, Interval = 0.1})
		Tab:CreateSlider({Name, Range = {min, max}, Increment, Suffix, CurrentValue, Callback(value)})
		Tab:CreateInput({Name, PlaceholderText, RemoveTextAfterFocusLost, Callback(text)})
		Tab:CreateDropdown({Name, Options, CurrentOption, Callback(option)})  -- opens a menu over the screen
		Tab:CreateKeybind({Name, CurrentKeybind, Callback(key), Changed(key)})
		Tab:CreateLabel("text")

	HOTKEYS: right-click a button or toggle card, then press a key (Escape cancels, Backspace clears),
	or pass Bind = Enum.KeyCode.X. element:SetBind(KeyCode or nil).

	NAVIGATION: click the tiles, or Left / Right arrows (gamepad: D-pad, L1 / R1) while the window is open.
	Mouse wheel / the white button scrolls down to the cards; the tile row fades out like on the console.

	LOADER: Library:CreateLoader({...}) - console-style sign-in (user screen -> key screen -> script tiles),
	same options and methods as GuiLibrary's CreateLoader. Full list above the function, near the end.

	ACCOUNT MENU: click your picture (top right): Change Key, Hide my info, Sign Out, Unload.
	CreateWindow({ ChangeKey = function() end, SignOut = function() end }) adds those two entries.
	Your name shows next to your picture; premium users get a gold shimmer + glow on it.

	SETTINGS: not a tile. "Settings" next to "Games" (top left) opens the console-style Settings screen:
	System, Screen and Video (Full Screen, Window Size, Blur, Motion), Themes, Account, Saved Data, Unload.
	Escape / Backspace goes back. Window:OpenSettings() / :CloseSettings() / :SelectTab("Settings").

	THEMES: Game Colours, Cosmic Blue, Slate, Midnight, Aurora, Ocean, Forest, Sunset, Crimson, Sakura,
	Gold, Synthwave, Mono. Each mixes light rays, particle waves, stars, aurora, petals and a horizon grid.
	Window:SetTheme("Aurora") / Window:SetFullscreen(bool). Library.Themes lists them.

	Window:SetVisible(bool) / :Toggle() / :SetToggleKey(KeyCode) / :SelectTab(name) / :Destroy()
	Library:Notify({Title, Content, Duration, Icon = "rbxassetid://...", Prefix = "🏆"})
	Library:Unload() / Library:OnUnload(fn) / Library:SetAnonymous(bool)

	Shared with every script that uses this library (Settings, saved in GuiLibrary/PS5Settings.json):
	toggle key, sounds, Anti AFK, full screen, window size, blur, background motion, theme, Anonymous mode.
	Premium badge on the avatar: reads getgenv().GuiLibraryUser = { Premium = true } like GuiLibrary.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Library = {}
Library.FontFamily = "rbxasset://fonts/families/BuilderSans.json"
Library.Accent = Color3.fromRGB(0, 112, 220)
Library.Sounds = {
	Move = "rbxasset://sounds/electronicpingshort.wav",
	Select = "rbxasset://sounds/electronicpingshort.wav",
	Boot = nil,
	Notify = "rbxasset://sounds/electronicpingshort.wav",
}

----------------------------------------------------------------------
-- Look
----------------------------------------------------------------------
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local Col = {
	Sub = Color3.fromRGB(222, 232, 248),
	Dim = Color3.fromRGB(176, 192, 220),
	Card = Color3.fromRGB(255, 255, 255),      -- cards are frosted glass: white at high transparency
	CardHover = Color3.fromRGB(255, 255, 255),
	Panel = Color3.fromRGB(34, 52, 92),        -- dialogs
	Ps = Color3.fromRGB(30, 31, 36),           -- PS5 charcoal: notifications + option menus
	PsText = Color3.fromRGB(168, 170, 178),    -- PS5 grey subtitle text
	Track = Color3.fromRGB(120, 140, 175),
	Gold = Color3.fromRGB(255, 196, 64),
	Error = Color3.fromRGB(240, 95, 95),
}

-- Background themes (Settings > Themes). Weights (0-1) pick how much of each background detail shows.
--	Game: each tile's own colours. C1 / C2: light / dark colour. Glow: rays, particles, stars.
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local Themes = {
	{ Name = "Game Colours", Game = true, Rays = 0.6, Waves = 0.7, Stars = 0.35, Aurora = 0.35, Orbs = 1 },
	{ Name = "Cosmic Blue", C1 = rgb(90, 150, 255), C2 = rgb(10, 30, 92), Glow = rgb(150, 195, 255), Rays = 0.7, Waves = 1, Stars = 0.5, Aurora = 0.4, Orbs = 0.8 },
	{ Name = "Slate", C1 = rgb(120, 128, 146), C2 = rgb(16, 20, 30), Glow = rgb(236, 230, 218), Rays = 1, Waves = 0.35, Stars = 0.2, Aurora = 0, Orbs = 0.3 },
	{ Name = "Midnight", C1 = rgb(64, 74, 120), C2 = rgb(5, 7, 18), Glow = rgb(180, 190, 240), Rays = 0.3, Waves = 0.45, Stars = 1, Aurora = 0.25, Orbs = 0.4 },
	{ Name = "Aurora", C1 = rgb(70, 230, 170), C2 = rgb(5, 26, 46), Glow = rgb(130, 255, 205), Rays = 0.2, Waves = 0.5, Stars = 0.85, Aurora = 1, Orbs = 0.35 },
	{ Name = "Ocean", C1 = rgb(60, 210, 240), C2 = rgb(4, 30, 72), Glow = rgb(165, 240, 255), Rays = 0.85, Waves = 1, Stars = 0.2, Aurora = 0.4, Orbs = 0.7 },
	{ Name = "Forest", C1 = rgb(115, 200, 110), C2 = rgb(7, 32, 18), Glow = rgb(210, 255, 175), Rays = 0.95, Waves = 0.35, Stars = 0.3, Aurora = 0.3, Orbs = 0.6, Petals = 0.5 },
	{ Name = "Sunset", C1 = rgb(255, 150, 90), C2 = rgb(88, 20, 70), Glow = rgb(255, 205, 150), Rays = 0.9, Waves = 0.7, Stars = 0.2, Aurora = 0.5, Orbs = 0.8 },
	{ Name = "Crimson", C1 = rgb(240, 70, 82), C2 = rgb(38, 4, 12), Glow = rgb(255, 150, 150), Rays = 0.6, Waves = 0.85, Stars = 0.3, Aurora = 0.3, Orbs = 0.9 },
	{ Name = "Sakura", C1 = rgb(255, 150, 210), C2 = rgb(70, 20, 82), Glow = rgb(255, 205, 236), Rays = 0.5, Waves = 0.6, Stars = 0.4, Aurora = 0.6, Orbs = 0.8, Petals = 1 },
	{ Name = "Gold", C1 = rgb(255, 200, 90), C2 = rgb(30, 20, 6), Glow = rgb(255, 222, 155), Rays = 0.85, Waves = 0.6, Stars = 0.6, Aurora = 0.2, Orbs = 0.7 },
	{ Name = "Synthwave", C1 = rgb(255, 80, 200), C2 = rgb(20, 6, 52), Glow = rgb(110, 230, 255), Rays = 0.25, Waves = 0.8, Stars = 0.9, Aurora = 0.6, Orbs = 0.5, Grid = 1 },
	{ Name = "Mono", C1 = rgb(180, 180, 186), C2 = rgb(14, 14, 16), Glow = rgb(255, 255, 255), Rays = 0.6, Waves = 0.6, Stars = 0.4, Aurora = 0, Orbs = 0.5 },
}
Library.Themes = Themes
local function themeByName(n)
	for _, t in ipairs(Themes) do
		if t.Name == n then return t end
	end
	return nil
end

local BASE_W, BASE_H = 1000, 562 -- design size (16:9); scaled to fit the screen
local PAD = 48                   -- left / right margin
local TILE, TILE_BIG, TILE_GAP = 64, 100, 14
local ROW_Y = 66                 -- top of the tile row
local PAGE_TOP = 188             -- where a page's content starts
local HERO_H = 196               -- big title area
local CARD_W, CARD_H, CARD_GAP = 210, 124, 14
local CARD_ALPHA, CARD_ALPHA_HOVER = 0.84, 0.72 -- glass transparency (lower = more solid)

local ck, nk = ColorSequenceKeypoint.new, NumberSequenceKeypoint.new
local CENTER = Vector2.new(0.5, 0.5)

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function create(class, props)
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(p, r)
	return create("UICorner", { CornerRadius = UDim.new(0, r or 12), Parent = p })
end

local function round(p)
	return create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = p })
end

local function stroke(p, color, thickness, transparency)
	return create("UIStroke", {
		Color = color or WHITE,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = p,
	})
end

local function tween(inst, props, time, style, dir)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function font(weight)
	return Font.new(Library.FontFamily, weight or Enum.FontWeight.Regular)
end

local function text(parent, props)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or WHITE
	props.FontFace = props.FontFace or font(Enum.FontWeight.Regular)
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.Parent = parent
	return create("TextLabel", props)
end

local function fire(cb, ...)
	if cb then
		task.spawn(cb, ...)
	end
end

local function env()
	return (typeof(getgenv) == "function" and getgenv()) or _G
end

local function num(v)
	local n = Instance.new("NumberValue")
	n.Value = v
	return n
end

local function estimateWidth(str, size)
	return #str * size * 0.5
end

local function textWidth(str, size, weight)
	local ok, w = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = str
		params.Font = font(weight)
		params.Size = size
		params.Width = 4000
		return TextService:GetTextBoundsAsync(params).X
	end)
	if ok and type(w) == "number" and w > 0 then
		return w
	end
	return #str * size * 0.52
end

-- A colour pair made from a name, so every tab gets its own tile / background colour
local function colorsFor(name)
	local h = 7
	for i = 1, #name do
		h = (h * 31 + string.byte(name, i)) % 3600
	end
	local hue = h / 3600
	return Color3.fromHSV(hue, 0.55, 0.95), Color3.fromHSV((hue + 0.07) % 1, 0.75, 0.62)
end

local function initials(name)
	local out = ""
	for word in string.gmatch(name, "%w+") do
		out ..= string.upper(string.sub(word, 1, 1))
		if #out >= 2 then break end
	end
	return out ~= "" and out or "?"
end

local function resolveImage(img)
	if type(img) == "number" then
		return "rbxassetid://" .. tostring(img)
	end
	if type(img) ~= "string" or img == "" then
		return nil
	end
	if img:find("^rbxassetid://") or img:find("^rbxasset://") or img:find("^rbxthumb://") then
		return img
	end
	if tonumber(img) then
		return "rbxassetid://" .. img
	end
	if type(isfile) == "function" and type(getcustomasset) == "function" then
		local ok, asset = pcall(function()
			if isfile(img) then
				return getcustomasset(img)
			end
		end)
		if ok and asset then
			return asset
		end
	end
	return nil
end

-- Game check for Game = ... options: a PlaceId, a list of PlaceIds / GameIds, or a function
-- returning true when you're in that game (handy when you don't know the PlaceId).
local function gameMatches(spec)
	if spec == nil then return true end
	if type(spec) == "function" then
		local ok, r = pcall(spec)
		return ok and r == true
	end
	if type(spec) == "number" then spec = { spec } end
	if type(spec) == "table" then
		for _, id in ipairs(spec) do
			if id == game.PlaceId or id == game.GameId then return true end
		end
		return false
	end
	return true
end
Library.InGame = gameMatches

-- Soft glow behind something: stacked rounded frames (no image assets needed)
local function softGlow(parent, radius, color, layers, step)
	local list = {}
	for i = 1, layers do
		local pad = i * step
		local f = create("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, pad * 2, 1, pad * 2),
			BackgroundColor3 = color,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = parent,
		})
		corner(f, radius + pad)
		list[i] = { frame = f, alpha = 0.18 / i }
	end
	return list
end
local function glowTo(list, k, time)
	for _, l in ipairs(list) do
		tween(l.frame, { BackgroundTransparency = 1 - l.alpha * k }, time or 0.25)
	end
end
local function glowSet(list, k)
	for _, l in ipairs(list) do
		l.frame.BackgroundTransparency = 1 - l.alpha * k
	end
end

-- ">" made of two lines (rot = 90 for a down arrow)
local function chevron(parent, size, color, rot)
	local box = create("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Rotation = rot or 0,
		Parent = parent,
	})
	local len = size * 0.5 + 2
	local angle = math.deg(math.atan2(0.3, 0.4))
	for i, y in ipairs({ 0.35, 0.65 }) do
		local ln = create("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromOffset(len, 2),
			Rotation = i == 1 and angle or -angle,
			BackgroundColor3 = color or WHITE,
			BorderSizePixel = 0,
			Parent = box,
		})
		round(ln)
	end
	return box
end

-- Gear drawn from frames, sized by scale so it grows with the tile
local function gear(parent, color, holeColor)
	local box = create("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	for i = 0, 7 do
		local a = math.rad(i * 45)
		create("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5 + math.sin(a) * 0.4, 0.5 - math.cos(a) * 0.4),
			Size = UDim2.fromScale(0.2, 0.26),
			Rotation = i * 45,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = box,
		})
	end
	local ring = create("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = box,
	})
	round(ring)
	local hole = create("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.34, 0.34),
		BackgroundColor3 = holeColor,
		BorderSizePixel = 0,
		Parent = box,
	})
	round(hole)
	return box
end

local function closeGlyph(parent, size, color)
	local box = create("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local lines = {}
	for _, r in ipairs({ 45, -45 }) do
		local ln = create("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1.25, 0, 0, 2),
			Rotation = r,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = box,
		})
		round(ln)
		table.insert(lines, ln)
	end
	return lines
end

-- Small padlock: shackle (outlined arch) + body
local function padlock(parent, size, color, order)
	local box = create("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	local shackle = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.58, 0.62),
		BackgroundTransparency = 1,
		Parent = box,
	})
	corner(shackle, math.floor(size * 0.3))
	stroke(shackle, color, math.max(1.5, size / 8), 0)
	local body = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(0.86, 0.56),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = box,
	})
	corner(body, math.max(2, math.floor(size / 7)))
	return box
end

----------------------------------------------------------------------
-- Sounds
----------------------------------------------------------------------
local lastMove = 0
local function sfx(kind)
	if Library.SoundsEnabled == false then return end
	local id = Library.Sounds[kind]
	if not id then return end
	if kind == "Move" then
		if os.clock() - lastMove < 0.05 then return end -- don't machine-gun while sweeping the mouse
		lastMove = os.clock()
	end
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = kind == "Move" and 0.12 or 0.3
		s.PlaybackSpeed = kind == "Move" and 1.6 or (kind == "Notify" and 0.8 or 1.15)
		s.Parent = SoundService
		s:Play()
		task.delay(4, function()
			s:Destroy()
		end)
	end)
end

----------------------------------------------------------------------
-- Shared settings (every script using this library)
----------------------------------------------------------------------
Library.GlobalSettingsFile = "GuiLibrary/PS5Settings.json"
local globalSettings = {}
local globalFiles = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
if globalFiles then
	pcall(function()
		if isfile(Library.GlobalSettingsFile) then
			local data = HttpService:JSONDecode(readfile(Library.GlobalSettingsFile))
			if type(data) == "table" then
				globalSettings = data
			end
		end
	end)
end
local globalPending = false
local unloadingAll = false
local function saveGlobal(key, value)
	if unloadingAll then return end
	globalSettings[key] = value
	if not globalFiles or globalPending then return end
	globalPending = true
	task.delay(0.4, function()
		globalPending = false
		pcall(function()
			local path = Library.GlobalSettingsFile
			local dir = path:match("^(.*)/[^/]+$")
			if dir and type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(dir) then
				makefolder(dir)
			end
			writefile(path, HttpService:JSONEncode(globalSettings))
		end)
	end)
end
Library.SoundsEnabled = globalSettings.Sounds ~= false
Library.Motion = globalSettings.Motion ~= false
Library.Anonymous = globalSettings.Anonymous == true

local anonListeners = {}
function Library:OnAnonymous(owner, fn)
	table.insert(anonListeners, { owner = owner, fn = fn })
end
function Library:SetAnonymous(v)
	v = v == true
	if unloadingAll or v == Library.Anonymous then return end
	Library.Anonymous = v
	saveGlobal("Anonymous", v)
	for i = #anonListeners, 1, -1 do
		local l = anonListeners[i]
		if l.owner:IsDescendantOf(game) then
			l.fn(v)
		else
			table.remove(anonListeners, i)
		end
	end
end

local windows = {}
local unloadHooks = {}
function Library:OnUnload(fn)
	if type(fn) == "function" then
		table.insert(unloadHooks, fn)
	end
end

local listeningForKey = false -- a card is waiting for a key press

local function detectPremium()
	local u = env().GuiLibraryUser
	if type(u) ~= "table" then return false end
	if u.Premium == true then return true end
	return type(u.Tier) == "string" and string.find(string.lower(u.Tier), "premium", 1, true) ~= nil
end

----------------------------------------------------------------------
-- Notifications (top right, slide in from the side)
----------------------------------------------------------------------
local notifyGui, notifyHolder
local notifyOrder = 0

function Library:Notify(o)
	o = o or {}
	if not notifyGui or not notifyGui.Parent then
		notifyGui = create("ScreenGui", {
			Name = "PS5Notifications",
			DisplayOrder = 2147483600,
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		})
		notifyHolder = create("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -20, 0, 20),
			Size = UDim2.new(0, 380, 1, -40),
			BackgroundTransparency = 1,
			Parent = notifyGui,
		})
		create("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = notifyHolder })
	end
	notifyOrder -= 1
	local duration = o.Duration or 4
	local H = 64

	-- The slot opens up first so older notifications slide down instead of jumping
	local slot = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = notifyOrder,
		Parent = notifyHolder,
	})
	-- PS5 style: dark charcoal pill, square icon, bold title, grey subtitle
	local card = create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, H),
		Position = UDim2.fromOffset(0, -18),
		GroupTransparency = 1,
		BackgroundColor3 = Col.Ps,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Parent = slot,
	})
	corner(card, 14)
	local edge = create("Frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		Parent = card,
	})
	corner(edge, 13)
	stroke(edge, WHITE, 1, 0.93)

	local icon = create("Frame", {
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = card,
	})
	corner(icon, 6)
	stroke(icon, WHITE, 1, 0.8)
	local iconImage = resolveImage(o.Icon)
	if iconImage then
		icon.BackgroundColor3 = Col.Ps:Lerp(BLACK, 0.4)
		local img = create("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = iconImage,
			ScaleType = Enum.ScaleType.Crop,
			Parent = icon,
		})
		corner(img, 6)
	else
		create("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new(Library.Accent:Lerp(WHITE, 0.25), Library.Accent:Lerp(BLACK, 0.35)),
			Parent = icon,
		})
		text(icon, {
			Size = UDim2.fromScale(1, 1),
			Text = "!",
			FontFace = font(Enum.FontWeight.Bold),
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
	local hasContent = o.Content ~= nil and tostring(o.Content) ~= ""
	local title = tostring(o.Title or "Notification")
	if o.Prefix then title = tostring(o.Prefix) .. " " .. title end -- e.g. Prefix = "🏆"
	text(card, {
		Position = UDim2.fromOffset(68, hasContent and 11 or 0),
		Size = UDim2.new(1, -82, 0, hasContent and 22 or H),
		Text = title,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	if hasContent then
		text(card, {
			Position = UDim2.fromOffset(68, 33),
			Size = UDim2.new(1, -82, 0, 20),
			Text = tostring(o.Content),
			TextSize = 13,
			TextColor3 = Col.PsText,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end

	-- drops in from above and fades in, like the console
	tween(slot, { Size = UDim2.new(1, 0, 0, H + 8) }, 0.25)
	tween(card, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, 0.4)
	sfx("Notify")

	task.delay(duration, function()
		if not slot.Parent then return end
		tween(card, { Position = UDim2.fromOffset(0, -12), GroupTransparency = 1 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.28)
		local t = tween(slot, { Size = UDim2.new(1, 0, 0, 0) }, 0.25)
		t.Completed:Wait()
		slot:Destroy()
	end)
end

function Library:Unload()
	if unloadingAll then return end
	unloadingAll = true
	for _, w in ipairs(windows) do
		pcall(w._StopFeatures, w)
	end
	for _, fn in ipairs(unloadHooks) do
		pcall(fn)
	end
	task.wait()
	for i = #windows, 1, -1 do
		pcall(windows[i].Destroy, windows[i])
	end
	table.clear(windows)
	table.clear(unloadHooks)
	if notifyGui then
		pcall(function() notifyGui:Destroy() end)
		notifyGui = nil
	end
	env().ScalsLoaderRunning = nil
	unloadingAll = false
end

----------------------------------------------------------------------
-- Boot animation
-- 1. black, a cloud of light specks swirls in and pulls together
-- 2. light streak + bloom flash, the logo appears, the specks burst outward
-- 3. "Welcome back" screen: blue gradient, floating specks, your avatar with a pulsing ring
-- 4. any key / click (or after AutoContinue seconds): zoom into the home screen
----------------------------------------------------------------------
local function playSplash(opts, windowName, onReveal)
	local revealed = false
	local function reveal()
		if not revealed then
			revealed = true
			onReveal()
		end
	end

	local image = resolveImage(opts.Image)
	local logoTime = math.max(opts.Duration or 3.2, 1.6)
	local showWelcome = opts.Welcome ~= false
	local autoContinue = opts.AutoContinue or 5
	local player = Players.LocalPlayer

	local gui
	local conns = {}
	local active = {} -- running tweens, cancelled on skip
	local function tw(inst, props, time, style, dir)
		local t = tween(inst, props, time, style, dir)
		table.insert(active, t)
		return t
	end

	task.spawn(function()
		local ok, err = pcall(function()
			local rand = math.random
			local lightBlue = Color3.fromRGB(150, 200, 255)

			gui = create("ScreenGui", {
				Name = "PS5Boot",
				ResetOnSpawn = false,
				IgnoreGuiInset = true,
				DisplayOrder = 2147483647,
				ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
				Parent = player:WaitForChild("PlayerGui"),
			})
			local root = create("CanvasGroup", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = BLACK,
				BorderSizePixel = 0,
				Parent = gui,
			})

			-- values the per-frame loop reads
			local spread = num(1.7)  -- how far the specks are from the centre
			local spin = num(1)      -- how fast they orbit
			local amount = num(0)    -- how visible they are
			local bloom = num(0)     -- centre light

			-- Welcome background (fades in later)
			local wbg = create("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = root,
			})
			create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ck(0, Color3.fromRGB(86, 156, 240)),
					ck(0.55, Color3.fromRGB(34, 96, 196)),
					ck(1, Color3.fromRGB(14, 46, 120)),
				}),
				Parent = wbg,
			})

			-- Specks
			local layer = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })
			local parts = {}
			for i = 1, 170 do
				local s = rand(2, 5)
				if rand() < 0.08 then s = rand(6, 11) end
				local f = create("Frame", {
					AnchorPoint = CENTER,
					Size = UDim2.fromOffset(s, s),
					BackgroundColor3 = rand() < 0.55 and WHITE or lightBlue,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = layer,
				})
				round(f)
				parts[i] = {
					f = f,
					a = rand() * math.pi * 2,
					r = 0.3 + rand() * 0.95,
					speed = (0.06 + rand() * 0.2) * (rand() < 0.5 and -1 or 1),
					alpha = 0.25 + rand() * 0.65,
					tw = 1 + rand() * 3,
					ph = rand() * 6.28,
					rise = 0.003 + rand() * 0.012,
					dy = 0,
				}
			end

			-- Bloom (centre light) + horizontal light streak
			local bloomLayers = {}
			for i = 1, 9 do
				local f = create("Frame", {
					AnchorPoint = CENTER,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.06 + i * 0.075, 0.06 + i * 0.075),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,
					BackgroundColor3 = i <= 3 and WHITE or lightBlue,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = root,
				})
				round(f)
				bloomLayers[i] = { f = f, alpha = 0.3 * (1 - (i - 1) / 9) }
			end
			local streak = create("Frame", {
				AnchorPoint = CENTER,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, 0, 0, 2),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				Parent = root,
			})
			create("UIGradient", {
				Transparency = NumberSequence.new({ nk(0, 1), nk(0.35, 0.3), nk(0.5, 0), nk(0.65, 0.3), nk(1, 1) }),
				Parent = streak,
			})

			-- Logo
			local logoBox = create("Frame", {
				AnchorPoint = CENTER,
				Position = UDim2.fromScale(0.5, 0.48),
				Size = image and UDim2.fromScale(0.34, 0.34) or UDim2.fromScale(0.7, 0.13),
				SizeConstraint = image and Enum.SizeConstraint.RelativeYY or Enum.SizeConstraint.RelativeXY,
				BackgroundTransparency = 1,
				Parent = root,
			})
			local logoScale = create("UIScale", { Scale = 0.88, Parent = logoBox })
			local logo
			if image then
				logo = create("ImageLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = image,
					ScaleType = Enum.ScaleType.Fit,
					ImageTransparency = 1,
					Parent = logoBox,
				})
			else
				logo = create("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = windowName,
					FontFace = font(Enum.FontWeight.Bold),
					TextScaled = true,
					TextColor3 = WHITE,
					TextTransparency = 1,
					Parent = logoBox,
				})
			end
			local logoProp = image and "ImageTransparency" or "TextTransparency"
			local shine = create("UIGradient", {
				Rotation = 15,
				Offset = Vector2.new(-1, 0),
				Color = ColorSequence.new({ ck(0, WHITE), ck(0.45, WHITE), ck(0.5, lightBlue), ck(0.55, WHITE), ck(1, WHITE) }),
				Parent = logo,
			})
			local sub
			if opts.Subtitle then
				sub = text(root, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.58),
					Size = UDim2.new(0.6, 0, 0, 22),
					Text = string.upper(opts.Subtitle),
					TextSize = 16,
					TextColor3 = Col.Sub,
					TextTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			end

			-- Welcome screen
			local welcome = create("CanvasGroup", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				GroupTransparency = 1,
				Parent = root,
			})
			text(welcome, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.16),
				Size = UDim2.new(0.8, 0, 0, 40),
				Text = opts.WelcomeText or ("Welcome back to " .. windowName),
				FontFace = font(Enum.FontWeight.Light),
				TextSize = 34,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			local avatarWrap = create("Frame", {
				AnchorPoint = CENTER,
				Position = UDim2.fromScale(0.5, 0.47),
				Size = UDim2.fromScale(0.22, 0.22),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundTransparency = 1,
				Parent = welcome,
			})
			local avatarScale = create("UIScale", { Scale = 0.9, Parent = avatarWrap })
			local avatarGlow = softGlow(avatarWrap, 999, WHITE, 6, 5)
			local avatar = create("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Col.Card,
				BorderSizePixel = 0,
				Image = "",
				Parent = avatarWrap,
			})
			round(avatar)
			local ringHolder = create("Frame", {
				AnchorPoint = CENTER,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 14, 1, 14),
				BackgroundTransparency = 1,
				Parent = avatarWrap,
			})
			round(ringHolder)
			local ring = stroke(ringHolder, WHITE, 3, 0)
			local anon = Library.Anonymous
			text(welcome, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.62),
				Size = UDim2.new(0.6, 0, 0, 30),
				Text = anon and "Player" or (player.DisplayName ~= "" and player.DisplayName or player.Name),
				FontFace = font(Enum.FontWeight.SemiBold),
				TextSize = 26,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			local premium = detectPremium()
			text(welcome, {
				AnchorPoint = Vector2.new(0.5, 0),
				Size = UDim2.new(0.6, 0, 0, 22),
				Position = UDim2.new(0.5, 0, 0.62, 34),
				Text = premium and "★ Premium" or "",
				TextSize = 15,
				TextColor3 = Col.Gold,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			local hint = text(welcome, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.9),
				Size = UDim2.new(0.8, 0, 0, 22),
				Text = "Press any key or click to continue",
				TextSize = 17,
				TextColor3 = Col.Sub,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			local clock = text(welcome, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -40, 0, 28),
				Size = UDim2.fromOffset(120, 24),
				Text = os.date("%H:%M"),
				FontFace = font(Enum.FontWeight.Medium),
				TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			if not anon then
				task.spawn(function()
					local okThumb, img = pcall(function()
						return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
					end)
					if okThumb and img and avatar.Parent then
						avatar.Image = img
					end
				end)
			end

			-- Per frame
			local t0 = os.clock()
			local state = "intro"
			local skipped, continued = false, false
			local welcomeAt = 0
			table.insert(conns, RunService.RenderStepped:Connect(function(dt)
				local t = os.clock() - t0
				local cam = workspace.CurrentCamera
				local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
				local aspect = vp.X / math.max(vp.Y, 1)
				local R, sp, am = spread.Value, spin.Value, amount.Value
				for _, p in ipairs(parts) do
					p.a += p.speed * sp * dt
					if state ~= "intro" then
						p.dy += p.rise * dt
						if p.dy > 0.6 then p.dy -= 1.2 end
					end
					local r = p.r * R
					local x = 0.5 + math.cos(p.a) * r * 0.5
					local y = 0.5 + math.sin(p.a) * r * 0.5 * aspect * 0.55 - p.dy
					p.f.Position = UDim2.fromScale(x, y)
					local twinkle = 0.55 + 0.45 * math.sin(t * p.tw + p.ph)
					p.f.BackgroundTransparency = 1 - p.alpha * twinkle * am
				end
				local b = bloom.Value
				local pulse = 0.9 + 0.1 * math.sin(t * 3)
				for _, l in ipairs(bloomLayers) do
					l.f.BackgroundTransparency = math.clamp(1 - l.alpha * b * pulse, 0, 1)
				end
				if state == "welcome" then
					local wt = os.clock() - welcomeAt
					ring.Transparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(wt * 2.6))
					glowSet(avatarGlow, 0.5 + 0.3 * math.sin(wt * 2.6))
					hint.TextTransparency = 0.15 + 0.45 * (0.5 + 0.5 * math.sin(wt * 2))
					clock.Text = os.date("%H:%M")
				end
			end))

			table.insert(conns, UserInputService.InputBegan:Connect(function(input)
				local ut = input.UserInputType
				local isPress = ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch
					or ut == Enum.UserInputType.Keyboard or ut == Enum.UserInputType.Gamepad1
				if not isPress then return end
				if state == "intro" and os.clock() - t0 > 0.5 then
					skipped = true
				elseif state == "welcome" and os.clock() - welcomeAt > 0.4 then
					continued = true
				end
			end))

			local function pause(sec)
				local s = os.clock()
				while os.clock() - s < sec and not skipped do
					task.wait()
				end
			end

			-- 1. specks swirl in and pull together
			tw(amount, { Value = 1 }, 0.9, Enum.EasingStyle.Quad)
			tw(spread, { Value = 0.2 }, logoTime * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			tw(spin, { Value = 3.2 }, logoTime * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			pause(logoTime * 0.42)
			tw(streak, { Size = UDim2.new(0.85, 0, 0, 2) }, 0.5, Enum.EasingStyle.Quint)
			pause(logoTime * 0.13)

			-- 2. flash, logo, burst
			if not skipped then
				sfx("Boot")
				bloom.Value = 1.6
				tw(bloom, { Value = 0.35 }, 1.1, Enum.EasingStyle.Quad)
				tw(spread, { Value = 1.5 }, 1.4, Enum.EasingStyle.Quint)
				tw(spin, { Value = 0.3 }, 1.6, Enum.EasingStyle.Quad)
				tw(streak, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 1) }, 0.9, Enum.EasingStyle.Quad)
				tw(logo, { [logoProp] = 0 }, 0.7, Enum.EasingStyle.Quad)
				tw(logoScale, { Scale = 1 }, 1.6, Enum.EasingStyle.Quint)
				if sub then tw(sub, { TextTransparency = 0.2 }, 0.8) end
				pause(0.6)
				tw(shine, { Offset = Vector2.new(1, 0) }, 1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
				pause(math.max(logoTime * 0.45, 0.9))
			end

			if skipped then
				for _, t in ipairs(active) do t:Cancel() end
				spread.Value, spin.Value, amount.Value, bloom.Value = 1.5, 0.3, 1, 0
				streak.Visible = false
			end
			table.clear(active)

			-- 3. welcome screen
			if showWelcome then
				tween(logo, { [logoProp] = 1 }, 0.4)
				if sub then tween(sub, { TextTransparency = 1 }, 0.4) end
				tween(bloom, { Value = 0 }, 0.6)
				tween(wbg, { BackgroundTransparency = 0 }, 0.9, Enum.EasingStyle.Quad)
				tween(amount, { Value = 0.55 }, 0.9)
				tween(welcome, { GroupTransparency = 0 }, 0.7, Enum.EasingStyle.Quad)
				tween(avatarScale, { Scale = 1 }, 0.9, Enum.EasingStyle.Back)
				welcomeAt = os.clock()
				state = "welcome"
				local deadline = os.clock() + autoContinue + 0.7
				while not continued and os.clock() < deadline do
					task.wait()
				end
				sfx("Select")
				ring.Transparency = 0
				tween(avatarScale, { Scale = 1.12 }, 0.35, Enum.EasingStyle.Back)
				task.wait(0.25)
			else
				state = "out"
				tween(logoScale, { Scale = 1.15 }, 0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			end

			-- 4. out, the home screen zooms in underneath
			state = "out"
			reveal()
			tween(root, { GroupTransparency = 1 }, 0.6, Enum.EasingStyle.Quad)
			task.wait(0.65)
		end)

		for _, c in ipairs(conns) do c:Disconnect() end
		if gui then gui:Destroy() end
		reveal() -- the window always shows, even if the animation broke
		if not ok then
			warn("[PS5Library] Boot animation failed: " .. tostring(err))
		end
	end)
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
function Library:CreateWindow(settings)
	settings = settings or {}
	if settings.Accent then Library.Accent = settings.Accent end
	if type(settings.Sounds) == "table" then
		for k, v in pairs(settings.Sounds) do
			Library.Sounds[k] = v
		end
	end
	local accent = Library.Accent
	local player = Players.LocalPlayer
	local windowName = settings.Name or "Hub"
	-- Full Screen and Theme can be changed in Settings; the saved choice wins over the script's default
	local fullscreen = settings.Fullscreen == true
	if type(globalSettings.Fullscreen) == "boolean" then fullscreen = globalSettings.Fullscreen end
	local blurWanted = settings.Blur ~= false
	local currentTheme = themeByName(globalSettings.Theme) or themeByName(settings.Theme) or Themes[1]
	local SIZES = { Small = 0.8, Medium = 0.9, Large = 1 }
	local windowSize = SIZES[globalSettings.WindowSize] and globalSettings.WindowSize or "Large"

	local Window = {}
	local visible = false
	local splashActive = false
	local toggleKey = settings.ToggleKey or Enum.KeyCode.RightShift
	local conns = {}
	local function track(c)
		table.insert(conns, c)
		return c
	end

	------------------------------------------------------------------
	-- Autosave (same format as GuiLibrary, so a script can switch libraries and keep its settings)
	------------------------------------------------------------------
	local cfg = settings.ConfigurationSaving or {}
	local saveEnabled = cfg.Enabled ~= false
	local hasFiles = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
	local canSave = saveEnabled and hasFiles
	local folder = cfg.FolderName or (windowName:gsub("[^%w_%- ]", ""))
	if folder == "" then folder = "GuiLibrary" end
	local filePath = folder .. "/" .. (cfg.FileName or "Settings") .. ".json"

	local flags = {}
	if canSave then
		pcall(function()
			if isfile(filePath) then
				local data = HttpService:JSONDecode(readfile(filePath))
				if type(data) == "table" then flags = data end
			end
		end)
	end
	for k, v in pairs(globalSettings) do
		flags["__global_" .. k] = v
	end
	Window.Flags = flags

	local savePending = false
	local function flush()
		if not canSave then return end
		pcall(function()
			if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(folder) then
				makefolder(folder)
			end
			local own = {}
			for k, v in pairs(flags) do
				if string.sub(k, 1, 9) ~= "__global_" then own[k] = v end
			end
			writefile(filePath, HttpService:JSONEncode(own))
		end)
	end
	local function changed(flag, value)
		if unloadingAll then return end
		if flags[flag] == value then return end
		flags[flag] = value
		if string.sub(flag, 1, 9) == "__global_" then
			saveGlobal(string.sub(flag, 10), value)
			return
		end
		if canSave and not savePending then
			savePending = true
			task.delay(0.4, function()
				savePending = false
				flush()
			end)
		end
	end
	function Window:SaveNow()
		flush()
	end

	------------------------------------------------------------------
	-- Root
	------------------------------------------------------------------
	local gui = create("ScreenGui", {
		Name = windowName,
		DisplayOrder = 2147483000,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local dim = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	})
	local holder = create("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(BASE_W, BASE_H),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local uiScale = create("UIScale", { Parent = holder })
	local outerGlow = softGlow(holder, 20, accent:Lerp(WHITE, 0.3), 6, 6)
	local screen = create("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(30, 60, 120),
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = holder,
	})
	local screenCorner = corner(screen, fullscreen and 0 or 18)

	local blur
	if blurWanted then
		blur = Instance.new("BlurEffect")
		blur.Name = "PS5LibraryBlur"
		blur.Size = 0
		blur.Enabled = globalSettings.Blur ~= false
		blur.Parent = Lighting
	end

	------------------------------------------------------------------
	-- Background: two layers that crossfade when the tab changes
	------------------------------------------------------------------
	local bg = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = screen })
	local function makeBgLayer()
		local layer = create("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			Parent = bg,
		})
		-- gradient on its own frame (on the CanvasGroup itself it would tint the picture + lights too)
		local base = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Parent = layer,
		})
		local grad = create("UIGradient", { Rotation = 25, Parent = base })
		local img = create("ImageLabel", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.04, 1.04),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Crop,
			Image = "",
			Visible = false,
			Parent = layer,
		})
		local zoom = create("UIScale", { Parent = img })
		local blobs = {}
		for i = 1, 2 do
			local blob = create("Frame", {
				AnchorPoint = CENTER,
				Size = UDim2.fromScale(i == 1 and 0.95 or 0.7, i == 1 and 0.95 or 0.7),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundTransparency = 1,
				Parent = layer,
			})
			local rings = {}
			for j = 1, 7 do
				local f = create("Frame", {
					AnchorPoint = CENTER,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(j / 7, j / 7),
					BackgroundColor3 = WHITE,
					BackgroundTransparency = 0.94,
					BorderSizePixel = 0,
					Parent = blob,
				})
				round(f)
				rings[j] = f
			end
			blobs[i] = { frame = blob, rings = rings, ph = i * 2.3 }
		end
		return { layer = layer, grad = grad, img = img, zoom = zoom, blobs = blobs }
	end
	local bgLayers = { makeBgLayer(), makeBgLayer() }
	local bgFront = 1

	------------------------------------------------------------------
	-- Background detail, tinted by the theme: light rays, particle waves, stars, aurora,
	-- petals and a horizon grid. Each theme says how much of each one shows.
	------------------------------------------------------------------
	local detail = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = screen })
	local function group()
		return create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = detail })
	end
	local fx = { w = {} } -- w = current weights

	-- aurora: wide soft bands across the top
	fx.auroraGroup = group()
	fx.aurora = {}
	for i = 1, 3 do
		local band = create("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.18 + i * 0.09),
			Size = UDim2.new(1.7, 0, 0.2 + i * 0.03, 0),
			Rotation = -12 + i * 5,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = fx.auroraGroup,
		})
		local g = create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ nk(0, 1), nk(0.45, 0.25), nk(0.55, 0.25), nk(1, 1) }),
			Parent = band,
		})
		fx.aurora[i] = { f = band, g = g, a = 0.16 - i * 0.03, ph = i * 2.1, y = 0.18 + i * 0.09, rot = -12 + i * 5 }
	end

	-- stars: tiny twinkling dots, mostly in the top half
	fx.starGroup = group()
	fx.stars = {}
	for i = 1, 70 do
		local sz = (i % 7 == 0) and 3 or ((i % 3 == 0) and 2 or 1)
		local f = create("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(math.random(), math.random() ^ 1.6 * 0.85),
			Size = UDim2.fromOffset(sz, sz),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = fx.starGroup,
		})
		round(f)
		fx.stars[i] = { f = f, a = 0.25 + math.random() * 0.55, tw = 0.5 + math.random() * 2.2, ph = math.random() * 6.28 }
	end

	-- light rays from the top left (like the console's Settings screen)
	fx.rayGroup = group()
	fx.rays = {}
	for i = 1, 8 do
		local thick = 24 + ((i * 37) % 5) * 22
		local ray = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.04, 0, -0.14, 0),
			Size = UDim2.fromOffset(1700, thick),
			Rotation = 16 + i * 6.5,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = fx.rayGroup,
		})
		local fade = NumberSequence.new({ nk(0, 0.1), nk(0.3, 0.55), nk(0.75, 0.92), nk(1, 1) })
		create("UIGradient", { Transparency = fade, Parent = ray })
		local core = create("Frame", { -- brighter middle, so the edges look soft
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(1, 0.35),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = ray,
		})
		create("UIGradient", { Transparency = fade, Parent = core })
		fx.rays[i] = { f = ray, core = core, rot = 16 + i * 6.5, a = 0.03 + (i % 3) * 0.018, ph = i * 1.37 }
	end

	-- particle waves: strands of dots on moving sine curves (the console's signature waves)
	fx.waveGroup = group()
	fx.strands = {}
	local DOTS = 46
	for k = 1, 4 do
		local dots = {}
		for j = 1, DOTS do
			local sz = (j % 4 == 0) and 4 or ((j % 2 == 0) and 3 or 2)
			local f = create("Frame", {
				AnchorPoint = CENTER,
				Size = UDim2.fromOffset(sz, sz),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = fx.waveGroup,
			})
			round(f)
			dots[j] = f
		end
		fx.strands[k] = { dots = dots, y = 0.6 + k * 0.04, amp = 0.045 + k * 0.012, freq = 4.6 + k * 0.7, speed = 0.22 + k * 0.05, ph = k * 0.9 }
	end

	-- petals: falling, spinning (Sakura / Forest)
	fx.petalGroup = group()
	fx.petals = {}
	for i = 1, 18 do
		local f = create("Frame", {
			AnchorPoint = CENTER,
			Size = UDim2.fromOffset(7 + (i % 3) * 2, 5 + (i % 2) * 2),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = fx.petalGroup,
		})
		corner(f, 4)
		fx.petals[i] = { f = f, x = math.random(), y = math.random(), vy = 0.025 + math.random() * 0.03, vx = 0.01 + math.random() * 0.015, spin = 30 + math.random() * 90, ph = math.random() * 6.28, a = 0.35 + math.random() * 0.35 }
	end

	-- horizon grid + sun (Synthwave): rebuilt when the window width changes
	fx.gridGroup = group()
	fx.gridLines, fx.gridRows = {}, {}
	local HORIZON = 0.64
	local function buildGrid()
		for _, c in ipairs(fx.gridGroup:GetChildren()) do c:Destroy() end
		table.clear(fx.gridLines)
		table.clear(fx.gridRows)
		local W, H = holder.Size.X.Offset, BASE_H
		local hy = H * HORIZON
		fx.sun = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.78),
			Position = UDim2.new(0.5, 0, HORIZON, 0),
			Size = UDim2.fromOffset(170, 170),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = fx.gridGroup,
		})
		round(fx.sun)
		fx.sunGrad = create("UIGradient", { Rotation = 90, Parent = fx.sun })
		fx.horizon = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, HORIZON, 0),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = fx.gridGroup,
		})
		create("UIGradient", { Transparency = NumberSequence.new({ nk(0, 1), nk(0.5, 0), nk(1, 1) }), Parent = fx.horizon })
		for i = -11, 11 do
			local bx = W / 2 + i * W * 0.1
			local dx, dy = bx - W / 2, H - hy
			local len = math.sqrt(dx * dx + dy * dy)
			local f = create("Frame", {
				AnchorPoint = CENTER,
				Position = UDim2.fromOffset(W / 2 + dx / 2, hy + dy / 2),
				Size = UDim2.fromOffset(len, 1),
				Rotation = math.deg(math.atan2(dy, dx)),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = fx.gridGroup,
			})
			create("UIGradient", { Transparency = NumberSequence.new({ nk(0, 1), nk(1, 0) }), Parent = f })
			table.insert(fx.gridLines, f)
		end
		for k = 1, 9 do
			local f = create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = fx.gridGroup,
			})
			table.insert(fx.gridRows, { f = f, p = (k - 1) / 9 })
		end
		fx.gridBuilt = true
		if fx.paint then fx.paint() end
	end

	-- colours + weights for the current theme (glow = rays / particles colour)
	local function themeColors(e)
		if currentTheme.Game and e then
			return e.c1, e.c2, e.c1:Lerp(WHITE, 0.55)
		end
		return currentTheme.C1 or Color3.fromRGB(90, 150, 255), currentTheme.C2 or Color3.fromRGB(10, 30, 90), currentTheme.Glow or WHITE
	end
	local boostRays = 0 -- the Settings screen turns the rays up
	fx.paint = function(e)
		e = e or fx.lastEntry
		fx.lastEntry = e
		local c1, c2, glow = themeColors(e)
		local th = currentTheme
		fx.w.Rays = math.max(th.Rays or 0, boostRays)
		fx.w.Waves, fx.w.Stars, fx.w.Aurora = th.Waves or 0, th.Stars or 0, th.Aurora or 0
		fx.w.Petals, fx.w.Grid = th.Petals or 0, th.Grid or 0
		fx.rayGroup.Visible = fx.w.Rays > 0
		fx.waveGroup.Visible = fx.w.Waves > 0
		fx.starGroup.Visible = fx.w.Stars > 0
		fx.auroraGroup.Visible = fx.w.Aurora > 0
		fx.petalGroup.Visible = fx.w.Petals > 0
		fx.gridGroup.Visible = fx.w.Grid > 0
		for _, r in ipairs(fx.rays) do
			r.f.BackgroundColor3 = glow
			r.core.BackgroundColor3 = glow:Lerp(WHITE, 0.4)
			r.f.BackgroundTransparency = 1 - r.a * fx.w.Rays
			r.core.BackgroundTransparency = 1 - r.a * 1.2 * fx.w.Rays
		end
		for _, st in ipairs(fx.strands) do
			for _, d in ipairs(st.dots) do d.BackgroundColor3 = glow end
		end
		for _, st in ipairs(fx.stars) do st.f.BackgroundColor3 = glow:Lerp(WHITE, 0.6) end
		for i, b in ipairs(fx.aurora) do
			b.f.BackgroundColor3 = WHITE
			b.g.Color = ColorSequence.new({
				ck(0, c1), ck(0.5, i == 2 and glow or c1:Lerp(glow, 0.5)), ck(1, c1),
			})
			b.f.BackgroundTransparency = 1 - b.a * fx.w.Aurora
		end
		for _, pt in ipairs(fx.petals) do
			pt.f.BackgroundColor3 = glow
			pt.f.BackgroundTransparency = 1 - pt.a * fx.w.Petals
		end
		if fx.gridBuilt then
			fx.sun.BackgroundTransparency = 1 - 0.85 * fx.w.Grid
			fx.sunGrad.Color = ColorSequence.new({ ck(0, Color3.fromRGB(255, 220, 120)), ck(1, c1) })
			fx.sunGrad.Transparency = NumberSequence.new({ nk(0, 0), nk(0.75, 0.15), nk(1, 1) })
			fx.horizon.BackgroundColor3 = glow
			fx.horizon.BackgroundTransparency = 1 - 0.8 * fx.w.Grid
			for _, l in ipairs(fx.gridLines) do
				l.BackgroundColor3 = c1
				l.BackgroundTransparency = 1 - 0.55 * fx.w.Grid
			end
			for _, r in ipairs(fx.gridRows) do r.f.BackgroundColor3 = c1 end
		end
		-- the ring blobs live in the background layers
		for _, L in ipairs(bgLayers) do
			for _, b in ipairs(L.blobs) do
				for _, r in ipairs(b.rings) do
					r.BackgroundTransparency = 1 - 0.06 * (th.Orbs or 1)
				end
			end
		end
	end
	-- moves everything (t = seconds); also run once so it looks right with Background Motion off
	fx.update = function(t, dt)
		local W = fx.w
		if W.Rays > 0 then
			for _, r in ipairs(fx.rays) do
				r.f.Rotation = r.rot + math.sin(t * 0.11 + r.ph) * 2.2
				local pulse = 0.75 + 0.25 * math.sin(t * 0.35 + r.ph)
				r.f.BackgroundTransparency = 1 - r.a * W.Rays * pulse
				r.core.BackgroundTransparency = 1 - r.a * 1.2 * W.Rays * pulse
			end
		end
		if W.Waves > 0 then
			for _, st in ipairs(fx.strands) do
				for j, d in ipairs(st.dots) do
					local x = (j - 1) / (DOTS - 1)
					local y = st.y + math.sin(x * st.freq + t * st.speed + st.ph) * st.amp + math.sin(x * 2.3 - t * 0.17 + st.ph) * 0.03
					d.Position = UDim2.fromScale(x * 1.04 - 0.02, y)
					local edge = math.sin(math.pi * x)
					d.BackgroundTransparency = 1 - W.Waves * 0.6 * edge * (0.55 + 0.45 * math.sin(t * 1.1 + j * 0.45 + st.ph))
				end
			end
		end
		if W.Stars > 0 then
			for _, st in ipairs(fx.stars) do
				st.f.BackgroundTransparency = 1 - W.Stars * st.a * (0.45 + 0.55 * math.sin(t * st.tw + st.ph) ^ 2)
			end
		end
		if W.Aurora > 0 then
			for _, b in ipairs(fx.aurora) do
				b.f.Position = UDim2.fromScale(0.5 + math.sin(t * 0.05 + b.ph) * 0.08, b.y + math.sin(t * 0.08 + b.ph) * 0.03)
				b.f.Rotation = b.rot + math.sin(t * 0.06 + b.ph) * 3
				b.g.Offset = Vector2.new(0, math.sin(t * 0.2 + b.ph) * 0.12)
			end
		end
		if W.Petals > 0 then
			for _, pt in ipairs(fx.petals) do
				pt.y += pt.vy * dt
				pt.x += pt.vx * dt
				if pt.y > 1.05 then pt.y = -0.05; pt.x = math.random() * 0.9 - 0.2 end
				if pt.x > 1.05 then pt.x = -0.05 end
				pt.f.Position = UDim2.fromScale(pt.x + math.sin(t * 0.8 + pt.ph) * 0.015, pt.y)
				pt.f.Rotation = (t * pt.spin + pt.ph * 57) % 360
			end
		end
		if W.Grid > 0 and fx.gridBuilt then
			for _, r in ipairs(fx.gridRows) do
				local p = (r.p + t * 0.06) % 1
				r.f.Position = UDim2.new(0, 0, HORIZON + (1 - HORIZON) * p * p, 0)
				r.f.BackgroundTransparency = 1 - 0.6 * W.Grid * math.min(1, p * 2.5)
			end
		end
	end

	local function setBackground(e, instant)
		local nextI = 3 - bgFront
		local A, B = bgLayers[bgFront], bgLayers[nextI]
		local c1, c2 = themeColors(e)
		B.grad.Color = ColorSequence.new({
			ck(0, c2:Lerp(c1, 0.45)),
			ck(0.55, c2),
			ck(1, c2:Lerp(BLACK, 0.45)),
		})
		B.img.Image = e.background or ""
		B.img.Visible = e.background ~= nil
		for _, b in ipairs(B.blobs) do
			b.frame.Visible = e.background == nil
			for _, r in ipairs(b.rings) do
				r.BackgroundColor3 = c1
			end
		end
		B.layer.ZIndex = 2
		A.layer.ZIndex = 1
		B.zoom.Scale = 1.08
		tween(B.zoom, { Scale = 1 }, 1.4)
		if instant then
			B.layer.GroupTransparency = 0
		else
			B.layer.GroupTransparency = 1
			tween(B.layer, { GroupTransparency = 0 }, 0.6, Enum.EasingStyle.Quad)
		end
		bgFront = nextI
		fx.paint(e)
		fx.update(os.clock(), 0)
	end

	-- Shading so text stays readable on any picture
	local function shade(rotation, seq, props)
		props = props or {}
		local f = create("Frame", {
			Size = props.Size or UDim2.fromScale(1, 1),
			BackgroundColor3 = BLACK,
			BorderSizePixel = 0,
			Parent = screen,
		})
		create("UIGradient", { Rotation = rotation, Transparency = NumberSequence.new(seq), Parent = f })
		return f
	end
	shade(0, { nk(0, 0.7), nk(0.6, 0.95), nk(1, 1) })
	shade(90, { nk(0, 1), nk(0.6, 0.92), nk(1, 0.6) })
	shade(90, { nk(0, 0.75), nk(1, 1) }, { Size = UDim2.new(1, 0, 0, 120) })
	local scrollDim = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = screen,
	})

	-- Floating specks (bokeh)
	local bokeh = {}
	local bokehLayer = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = screen })
	for i = 1, 22 do
		local s = math.random(3, 9)
		local f = create("Frame", {
			AnchorPoint = CENTER,
			Size = UDim2.fromOffset(s, s),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = bokehLayer,
		})
		round(f)
		bokeh[i] = {
			f = f,
			x = math.random(),
			y = math.random(),
			speed = 0.006 + math.random() * 0.018,
			alpha = 0.08 + math.random() * 0.22,
			tw = 0.6 + math.random() * 1.6,
			ph = math.random() * 6.28,
		}
	end

	------------------------------------------------------------------
	-- Pages container + top shade that appears when you scroll down
	------------------------------------------------------------------
	local pagesHolder = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = screen })
	local topScrollShade = create("Frame", {
		Size = UDim2.new(1, 0, 0, 100),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = screen,
	})
	create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ nk(0, 0.3), nk(0.6, 0.6), nk(1, 1) }),
		Parent = topScrollShade,
	})

	------------------------------------------------------------------
	-- Top bar: "Games  Settings" on the left, avatar / clock / close on the right
	------------------------------------------------------------------
	local topBar = create("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = screen,
	})
	local nav = create("Frame", {
		Position = UDim2.fromOffset(PAD, 16),
		Size = UDim2.new(0.5, 0, 0, 28),
		BackgroundTransparency = 1,
		Parent = topBar,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 28),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = nav,
	})
	local function navButton(label, order)
		local b = create("TextButton", {
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = label,
			FontFace = font(Enum.FontWeight.Bold),
			TextSize = 21,
			TextColor3 = WHITE,
			LayoutOrder = order,
			Parent = nav,
		})
		return b
	end
	local navGames = navButton("Games", 1)
	local navSettings = navButton("Settings", 2)

	local right = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD + 8, 0, 12),
		Size = UDim2.new(0.5, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = topBar,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 18),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = right,
	})
	-- your name, left of your picture. Premium: gold shimmer + glow
	local nameLabel = text(right, {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		FontFace = font(Enum.FontWeight.SemiBold),
		TextSize = 17,
		LayoutOrder = 0,
	})
	local nameShine = create("UIGradient", {
		Color = ColorSequence.new({
			ck(0, Color3.fromRGB(255, 196, 70)),
			ck(0.42, Color3.fromRGB(255, 226, 140)),
			ck(0.5, Color3.fromRGB(255, 252, 235)),
			ck(0.58, Color3.fromRGB(255, 226, 140)),
			ck(1, Color3.fromRGB(255, 196, 70)),
		}),
		Enabled = false,
		Parent = nameLabel,
	})
	local nameGlow = create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.fromRGB(255, 190, 60),
		Thickness = 1.2,
		Transparency = 0.7,
		Enabled = false,
		Parent = nameLabel,
	})
	local avatarWrap = create("Frame", {
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = right,
	})
	local avatar = create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Col.Card,
		BorderSizePixel = 0,
		Image = "",
		Parent = avatarWrap,
	})
	round(avatar)
	local avatarRing = stroke(avatar, WHITE, 1.5, 0.6)
	-- click your picture: account menu (Change Key / Hide my info / Sign Out / Unload)
	local accountHit = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 3,
		Parent = avatarWrap,
	})
	local accountScale = create("UIScale", { Parent = avatarWrap })
	accountHit.MouseEnter:Connect(function()
		sfx("Move")
		tween(avatarRing, { Transparency = 0, Thickness = 2 }, 0.15)
		tween(accountScale, { Scale = 1.1 }, 0.2)
	end)
	accountHit.MouseLeave:Connect(function()
		tween(avatarRing, { Transparency = 0.6, Thickness = 1.5 }, 0.15)
		tween(accountScale, { Scale = 1 }, 0.2)
	end)
	local badge = create("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.new(1, -3, 1, -3),
		Size = UDim2.fromOffset(15, 15),
		BackgroundColor3 = Col.Gold,
		BorderSizePixel = 0,
		Visible = false,
		Parent = avatarWrap,
	})
	round(badge)
	stroke(badge, Color3.fromRGB(10, 12, 20), 2, 0)
	text(badge, {
		Size = UDim2.fromScale(1, 1),
		Text = "★",
		TextSize = 10,
		TextColor3 = Color3.fromRGB(40, 28, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local clock = text(right, {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = os.date("%H:%M"),
		FontFace = font(Enum.FontWeight.Medium),
		TextSize = 19,
		LayoutOrder = 2,
	})
	local closeBtn = create("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = 3,
		Parent = right,
	})
	round(closeBtn)
	local closeLines = closeGlyph(closeBtn, 12, Col.Sub)
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, { BackgroundTransparency = 0.85 }, 0.15)
		for _, l in ipairs(closeLines) do tween(l, { BackgroundColor3 = WHITE }, 0.15) end
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, { BackgroundTransparency = 1 }, 0.15)
		for _, l in ipairs(closeLines) do tween(l, { BackgroundColor3 = Col.Sub }, 0.15) end
	end)

	local avatarThumb = ""
	local isPremium -- set below
	local function paintName()
		local shownName = Library.Anonymous and "Player" or (player.DisplayName ~= "" and player.DisplayName or player.Name)
		nameLabel.Text = isPremium and ("★ " .. shownName) or shownName
		nameShine.Enabled = isPremium == true
		nameGlow.Enabled = isPremium == true
	end
	local function applyAnonymous()
		avatar.Image = Library.Anonymous and "" or avatarThumb
		paintName()
	end
	Library:OnAnonymous(avatar, applyAnonymous)
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and img and avatar.Parent then
			avatarThumb = img
			applyAnonymous()
		end
	end)
	local premiumLocked = type(settings.Premium) == "boolean"
	if premiumLocked then isPremium = settings.Premium else isPremium = detectPremium() end
	badge.Visible = isPremium
	paintName()
	-- everything that is locked to premium re-checks itself when this changes
	local premiumListeners = {}
	local function onPremium(fn)
		table.insert(premiumListeners, fn)
	end
	local function setPremiumState(v)
		v = v == true
		if v == isPremium then return end
		isPremium = v
		badge.Visible = v
		paintName()
		for _, fn in ipairs(premiumListeners) do
			task.spawn(fn, v)
		end
	end
	function Window:SetPremium(v)
		premiumLocked = true
		setPremiumState(v)
	end
	function Window:IsPremium()
		return isPremium
	end

	------------------------------------------------------------------
	-- Teleport (Play button)
	------------------------------------------------------------------
	local TeleportService = game:GetService("TeleportService")
	-- Executors name this differently, and some only put it in getgenv(), so look everywhere
	local function findQueueOnTeleport()
		local places = { getfenv and getfenv(0) or {}, env() }
		local names = { "queue_on_teleport", "queueonteleport", "queueteleport", "queue_teleport" }
		for _, tbl in ipairs(places) do
			for _, n in ipairs(names) do
				local ok, f = pcall(function() return tbl[n] end)
				if ok and type(f) == "function" then return f, n end
			end
			for _, ns in ipairs({ "syn", "fluxus", "volt", "Volt" }) do
				local ok, lib = pcall(function() return tbl[ns] end)
				if ok and type(lib) == "table" then
					for _, n in ipairs(names) do
						if type(lib[n]) == "function" then return lib[n], ns .. "." .. n end
					end
				end
			end
		end
		return nil
	end
	Window.QueueOnTeleportFunction = function()
		local _, n = findQueueOnTeleport()
		return n
	end

	local teleportReset -- set while a teleport is in progress: puts the button back and says why
	local function teleportTo(placeId, button, label)
		if teleportReset then return end
		local original = button.Text
		local reset
		reset = function(msg)
			if teleportReset ~= reset then return end
			teleportReset = nil
			if button.Parent then button.Text = original end
			if msg then
				Library:Notify({ Title = "Teleport failed", Content = tostring(msg), Duration = 5 })
			end
		end
		teleportReset = reset
		button.Text = "Teleporting..."
		Library:Notify({ Title = "Teleporting", Content = "Joining " .. label .. "...", Duration = 4 })
		if type(settings.QueueOnTeleport) == "string" then
			local q, qName = findQueueOnTeleport()
			if q then
				-- Queued code runs as soon as the new server starts, before the game has loaded,
				-- so it has to wait for the game + LocalPlayer itself or the loader errors silently.
				-- It also shows Roblox toasts in the new server ("reloading" / the error), so a failure is visible
				-- without opening F9, and clears the "already running" flag: executors like Volt keep getgenv()
				-- between servers, so a leftover flag would make the loader quit straight away.
				local code = table.concat({
					"if not game:IsLoaded() then game.Loaded:Wait() end",
					"local Players = game:GetService('Players')",
					"while not Players.LocalPlayer do task.wait() end",
					"Players.LocalPlayer:WaitForChild('PlayerGui')",
					"task.wait(1)",
					"local function toast(t, m) pcall(function() game:GetService('StarterGui'):SetCore('SendNotification', { Title = t, Text = m, Duration = 6 }) end) end",
					"toast(" .. string.format("%q", windowName) .. ", 'Reloading after teleport...')",
					"local g = (getgenv and getgenv()) or _G",
					"g.ScalsLoaderRunning = nil",
					"g.GuiLibrarySplashShown = nil",
					-- Right after a teleport, HttpGet can return nothing / an error page for a few seconds,
					-- so downloads are retried. getgenv().ScalsGet(url) is left for scripts to use too.
					"local function get(url)",
					"  local last = 'no response'",
					"  for i = 1, 8 do",
					"    local ok, src = pcall(function() return game:HttpGet(url) end)",
					"    if ok and type(src) == 'string' and #src > 0 then",
					"      local fn, err = loadstring(src)",
					"      if fn then return fn end",
					"      last = 'not a script: ' .. tostring(err) .. ' (got: ' .. src:sub(1, 40):gsub('%s+', ' ') .. ')'",
					"    else",
					"      last = ok and 'empty response' or tostring(src)",
					"    end",
					"    task.wait(math.min(i, 3))",
					"  end",
					"  error('download failed: ' .. url .. ' - ' .. last, 0)",
					"end",
					"g.ScalsGet = get",
					"local source = " .. string.format("%q", settings.QueueOnTeleport),
					"local ok, err = pcall(function()",
					"  if source:match('^https?://') then",
					"    get(source)()",
					"  else",
					"    local fn, compileErr = loadstring(source)",
					"    if not fn then error(compileErr, 0) end",
					"    fn()",
					"  end",
					"end)",
					"if not ok then toast('Reload failed', tostring(err)); warn('[PS5Library] reload after teleport: ' .. tostring(err)) end",
				}, "\n")
				-- only one copy, even after several Play presses / a failed teleport
				local clear = (type(clearqueueonteleport) == "function" and clearqueueonteleport)
					or (type(env().clearqueueonteleport) == "function" and env().clearqueueonteleport)
				if clear then pcall(clear) end
				local queued, qErr = pcall(q, code)
				if queued then
					print("[PS5Library] Queued the reload with " .. qName)
				end
				if not queued then
					warn("[PS5Library] " .. qName .. " failed: " .. tostring(qErr))
				end
			else
				warn("[PS5Library] No queue_on_teleport in this executor; the hub won't reload after teleporting.")
				Library:Notify({
					Title = "Hub won't reload",
					Content = "Your executor can't queue scripts across teleports. Put the loader in its autoexec folder.",
					Duration = 6,
				})
			end
		end
		local ok, err = pcall(function()
			TeleportService:Teleport(placeId, player)
		end)
		if not ok then
			reset(err)
			return
		end
		task.delay(20, function() reset("Timed out, try again.") end)
	end
	track(TeleportService.TeleportInitFailed:Connect(function(plr, _, msg)
		if plr ~= player or not teleportReset then return end
		teleportReset((msg and msg ~= "") and msg or "Roblox couldn't start the teleport.")
	end))

	-- Locked thing pressed: little shake + a (rate limited) notification
	local lastDenied = 0
	local function denied(target, title, content)
		sfx("Select")
		if target then
			task.spawn(function()
				for _, x in ipairs({ 9, -7, 5, -3, 0 }) do
					target.Position = UDim2.new(0.5, x, 0.5, 0)
					task.wait(0.035)
				end
			end)
		end
		if os.clock() - lastDenied > 2 then
			lastDenied = os.clock()
			Library:Notify({
				Title = title or "Premium only",
				Content = content or settings.PremiumText or "Get a premium key to unlock this.",
				Duration = 3,
			})
		end
	end

	------------------------------------------------------------------
	-- Tile row (the games)
	------------------------------------------------------------------
	local row = create("CanvasGroup", {
		Position = UDim2.fromOffset(0, ROW_Y - 14),
		Size = UDim2.new(1, 0, 0, TILE_BIG + 28),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = screen,
	})
	local tileName = text(row, {
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.fromOffset(300, TILE_BIG),
		Text = "",
		FontFace = font(Enum.FontWeight.SemiBold),
		TextSize = 20,
		TextTransparency = 1,
	})

	------------------------------------------------------------------
	-- Menu (dropdowns open this over the whole screen)
	------------------------------------------------------------------
	local modal = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
		Parent = screen,
	})
	local scrim = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = modal,
	})
	-- PS5 options sheet: dark panel on the right, full height, slides in from the side
	local SHEET_W = 360
	local panel = create("CanvasGroup", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 40, 0.5, 0),
		Size = UDim2.new(0, SHEET_W, 1, -24),
		BackgroundColor3 = Col.Ps,
		BackgroundTransparency = 0.03,
		GroupTransparency = 1,
		BorderSizePixel = 0,
		Parent = modal,
	})
	corner(panel, 16)
	local panelEdge = create("Frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	corner(panelEdge, 15)
	stroke(panelEdge, WHITE, 1, 0.92)
	local panelScale = create("UIScale", { Parent = panel })
	local panelTitle = text(panel, {
		Position = UDim2.fromOffset(24, 20),
		Size = UDim2.new(1, -48, 0, 24),
		Text = "",
		FontFace = font(Enum.FontWeight.SemiBold),
		TextSize = 18,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	create("Frame", { -- thin divider under the title
		Position = UDim2.fromOffset(24, 56),
		Size = UDim2.new(1, -48, 0, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Parent = panel,
	})
	local panelList = create("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 66),
		Size = UDim2.new(1, -24, 1, -78),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = WHITE,
		ScrollBarImageTransparency = 0.6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panelList })
	create("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 4), PaddingTop = UDim.new(0, 2), Parent = panelList })

	local menuOpen, menuToken = false, 0
	local function closeMenu()
		if not menuOpen then return end
		menuOpen = false
		menuToken += 1
		local mine = menuToken
		tween(modal, { BackgroundTransparency = 1 }, 0.2)
		tween(panel, { GroupTransparency = 1, Position = UDim2.new(1, 40, 0.5, 0) }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.24, function()
			if mine == menuToken then modal.Visible = false end
		end)
	end
	local function openMenu(title, options, current, onPick)
		menuToken += 1
		menuOpen = true
		for _, c in ipairs(panelList:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		panelTitle.Text = title
		local radio = current ~= nil -- a choice list gets radio circles; an action list (account menu) doesn't
		for i, opt in ipairs(options) do
			local isCurrent = radio and tostring(opt) == tostring(current)
			local b = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 46),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = i,
				Parent = panelList,
			})
			corner(b, 10)
			local glow = stroke(b, WHITE, 2, 1) -- the console's soft focus outline
			local lbl = text(b, {
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(1, radio and -60 or -32, 1, 0),
				Text = tostring(opt),
				FontFace = font(isCurrent and Enum.FontWeight.SemiBold or Enum.FontWeight.Medium),
				TextSize = 16,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			local ring, fill
			if radio then
				ring = create("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -16, 0.5, 0),
					Size = UDim2.fromOffset(20, 20),
					BackgroundTransparency = 1,
					Parent = b,
				})
				round(ring)
				local ringStroke = stroke(ring, WHITE, 2, isCurrent and 0 or 0.45)
				fill = create("Frame", {
					AnchorPoint = CENTER,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(10, 10),
					BackgroundColor3 = WHITE,
					BackgroundTransparency = isCurrent and 0 or 1,
					BorderSizePixel = 0,
					Parent = ring,
				})
				round(fill)
				b.MouseEnter:Connect(function()
					tween(ringStroke, { Color = BLACK, Transparency = isCurrent and 0 or 0.4 }, 0.12)
					tween(fill, { BackgroundColor3 = BLACK }, 0.12)
				end)
				b.MouseLeave:Connect(function()
					tween(ringStroke, { Color = WHITE, Transparency = isCurrent and 0 or 0.45 }, 0.12)
					tween(fill, { BackgroundColor3 = WHITE }, 0.12)
				end)
			end
			b.MouseEnter:Connect(function()
				sfx("Move")
				tween(b, { BackgroundTransparency = 0 }, 0.12)
				tween(glow, { Transparency = 0.6 }, 0.12)
				tween(lbl, { TextColor3 = BLACK }, 0.12)
			end)
			b.MouseLeave:Connect(function()
				tween(b, { BackgroundTransparency = 1 }, 0.12)
				tween(glow, { Transparency = 1 }, 0.12)
				tween(lbl, { TextColor3 = WHITE }, 0.12)
			end)
			b.MouseButton1Click:Connect(function()
				sfx("Select")
				closeMenu()
				onPick(opt)
			end)
		end
		-- scroll so the current choice is in view
		panelList.CanvasPosition = Vector2.zero
		if radio then
			for i, opt in ipairs(options) do
				if tostring(opt) == tostring(current) then
					task.defer(function()
						panelList.CanvasPosition = Vector2.new(0, math.max(0, (i - 1) * 48 - 96))
					end)
					break
				end
			end
		end
		modal.Visible = true
		modal.BackgroundTransparency = 1
		panel.GroupTransparency = 1
		panel.Position = UDim2.new(1, 40, 0.5, 0)
		panelScale.Scale = 1
		tween(modal, { BackgroundTransparency = 0.55 }, 0.25)
		tween(panel, { GroupTransparency = 0, Position = UDim2.new(1, -12, 0.5, 0) }, 0.35)
	end
	scrim.MouseButton1Click:Connect(closeMenu)

	-- Account menu (your picture, top right). Sign Out only shows when the script passes SignOut.
	accountHit.MouseButton1Click:Connect(function()
		sfx("Select")
		local actions, labels = {}, {}
		local function add(label, fn)
			table.insert(labels, label)
			actions[label] = fn
		end
		if type(settings.ChangeKey) == "function" then add("Change Key", settings.ChangeKey) end
		add(Library.Anonymous and "Show my info" or "Hide my info", function()
			Library:SetAnonymous(not Library.Anonymous)
		end)
		if type(settings.SignOut) == "function" then add("Sign Out", settings.SignOut) end
		add("Unload", function() Library:Unload() end)
		local who = Library.Anonymous and "Player" or (player.DisplayName ~= "" and player.DisplayName or player.Name)
		openMenu(who .. (isPremium and "  ★" or ""), labels, nil, function(label)
			local fn = actions[label]
			if fn then task.spawn(fn) end
		end)
	end)

	------------------------------------------------------------------
	-- Tabs: selection, tile layout, page swap
	------------------------------------------------------------------
	local tiles = {}  -- every tab in row order
	local selected, lastNormal
	local settingsOpen = false -- the Settings screen (not a tile: "Settings" next to "Games")
	local openSettings, closeSettings, settingsBack -- defined with the Settings screen

	local function indexOf(e)
		return table.find(tiles, e) or 0
	end

	local function layoutTiles(animated)
		if not selected then return end
		local s = indexOf(selected)
		local prevVisible = math.min(s - 1, 2)
		local xSel = PAD + prevVisible * (TILE + TILE_GAP)
		local nameW = selected.nameW
		local afterName = xSel + TILE_BIG + 18 + nameW + 28
		for i, e in ipairs(tiles) do
			local x, size
			if i < s then
				x = xSel - (s - i) * (TILE + TILE_GAP)
				size = TILE
			elseif i == s then
				x = xSel
				size = TILE_BIG
			else
				x = afterName + (i - s - 1) * (TILE + TILE_GAP)
				size = TILE
			end
			local props = { Position = UDim2.fromOffset(x, 14), Size = UDim2.fromOffset(size, size) }
			local focused = i == s
			if animated then
				tween(e.tile, props, 0.4)
				tween(e.tileDim, { BackgroundTransparency = focused and 1 or 0.6 }, 0.25)
				tween(e.ringStroke, { Transparency = focused and 0 or 1 }, 0.25)
			else
				e.tile.Position = props.Position
				e.tile.Size = props.Size
				e.tileDim.BackgroundTransparency = focused and 1 or 0.6
				e.ringStroke.Transparency = focused and 0 or 1
			end
		end
		tileName.Text = selected.name
		tileName.Size = UDim2.fromOffset(nameW + 10, TILE_BIG)
		local namePos = UDim2.fromOffset(xSel + TILE_BIG + 18, 14)
		if animated then
			tileName.TextTransparency = 1
			tileName.Position = namePos + UDim2.fromOffset(18, 0)
			tween(tileName, { TextTransparency = 0, Position = namePos }, 0.45)
		else
			tileName.Position = namePos
			tileName.TextTransparency = 0
		end
	end

	local function updateScrollFx()
		if settingsOpen then return end
		local y = selected and selected.page.CanvasPosition.Y or 0
		local k = math.clamp(y / 150, 0, 1)
		row.GroupTransparency = k
		row.Position = UDim2.fromOffset(0, ROW_Y - 14 - k * 34)
		row.Visible = k < 0.98
		scrollDim.BackgroundTransparency = 1 - 0.2 * k
		topScrollShade.BackgroundTransparency = 1 - 0.6 * k
	end

	local function paintNav()
		local onSettings = settingsOpen
		tween(navGames, { TextColor3 = onSettings and Col.Dim or WHITE }, 0.2)
		tween(navSettings, { TextColor3 = onSettings and WHITE or Col.Dim }, 0.2)
	end

	local pageToken = 0
	local function selectTab(e, quiet)
		if not e then return end
		if settingsOpen then closeSettings(true) end
		if selected == e then return end
		closeMenu()
		local prev = selected
		local dir = (prev and indexOf(prev) > indexOf(e)) and -1 or 1
		selected = e
		if not e.internal then lastNormal = e end
		pageToken += 1
		local mine = pageToken

		layoutTiles(prev ~= nil)
		setBackground(e, prev == nil)
		paintNav()

		if prev then
			local pw = prev.wrap
			tween(pw, { GroupTransparency = 1, Position = UDim2.fromOffset(-50 * dir, 0) }, 0.22, Enum.EasingStyle.Quad)
			task.delay(0.24, function()
				if mine == pageToken and selected ~= prev then pw.Visible = false end
			end)
		end
		e.wrap.Visible = true
		e.wrap.GroupTransparency = 1
		e.wrap.Position = UDim2.fromOffset(60 * dir, 0)
		e.page.CanvasPosition = Vector2.zero
		tween(e.wrap, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.5)
		e.intro()
		updateScrollFx()
		if not quiet then sfx("Move") end
	end

	local function step(delta)
		if not selected or #tiles == 0 then return end
		local i = math.clamp(indexOf(selected) + delta, 1, #tiles)
		selectTab(tiles[i])
	end

	navGames.MouseButton1Click:Connect(function()
		if settingsOpen then
			sfx("Select")
			closeSettings()
		end
	end)

	------------------------------------------------------------------
	-- Show / hide
	------------------------------------------------------------------
	local shown = num(0)
	local baseScale = 1
	local function viewport()
		local cam = workspace.CurrentCamera
		return cam and cam.ViewportSize or Vector2.new(1920, 1080)
	end
	local function applyShown()
		local v = shown.Value
		uiScale.Scale = baseScale * (1.045 - 0.045 * v)
		screen.GroupTransparency = 1 - v
		dim.BackgroundTransparency = 1 - (fullscreen and 0 or 0.25) * v
		glowSet(outerGlow, fullscreen and 0 or v * 0.6)
		if blur then blur.Size = fullscreen and 0 or 14 * v end
	end
	local function layoutHolder()
		local vp = viewport()
		if fullscreen then
			baseScale = vp.Y / BASE_H
			holder.Size = UDim2.fromOffset(math.ceil(vp.X / baseScale), BASE_H)
			holder.Position = UDim2.fromScale(0.5, 0.5)
		else
			holder.Size = UDim2.fromOffset(BASE_W, BASE_H)
			local maxScale = (settings.Scale or 1) * (SIZES[windowSize] or 1)
			baseScale = math.min(maxScale, (vp.X - 40) / BASE_W, (vp.Y - 40) / BASE_H)
		end
		applyShown()
		if not fx.gridBuilt or fx.gridWidth ~= holder.Size.X.Offset then
			fx.gridWidth = holder.Size.X.Offset
			buildGrid()
		end
	end
	-- Settings > Screen and Video
	local function setFullscreen(v)
		fullscreen = v == true
		screenCorner.CornerRadius = UDim.new(0, fullscreen and 0 or 18)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		layoutHolder()
		if selected then layoutTiles(false) end
	end
	local function setWindowSize(name)
		if not SIZES[name] then return end
		windowSize = name
		holder.Position = UDim2.fromScale(0.5, 0.5)
		layoutHolder()
	end
	shown.Changed:Connect(applyShown)
	layoutHolder()
	if workspace.CurrentCamera then
		track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutHolder))
	end

	local shownTween
	function Window:SetVisible(v)
		v = v == true
		if v == visible then return end
		visible = v
		if shownTween then shownTween:Cancel() end
		if v then
			holder.Visible = true
			dim.Visible = true
			shownTween = tween(shown, { Value = 1 }, 0.6, Enum.EasingStyle.Quint)
			if selected then selected.intro() end
		else
			closeMenu()
			shownTween = tween(shown, { Value = 0 }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			shownTween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not visible then
					holder.Visible = false
					dim.Visible = false
				end
			end)
		end
	end
	function Window:Toggle()
		Window:SetVisible(not visible)
	end
	function Window:SetToggleKey(key)
		toggleKey = key
		changed("__global_ToggleKey", key.Name)
	end
	function Window:Destroy()
		if gui.Parent then gui:Destroy() end
	end
	function Window:Unload()
		Library:Unload()
	end
	closeBtn.MouseButton1Click:Connect(function()
		sfx("Select")
		Window:SetVisible(false)
		Library:Notify({
			Title = windowName,
			Content = "Hidden. Press " .. toggleKey.Name .. " to open it again.",
			Duration = 3,
		})
	end)

	local allToggles = {}
	function Window._StopFeatures()
		for _, t in ipairs(allToggles) do
			pcall(t.Set, t, false)
		end
	end
	table.insert(windows, Window)

	-- Drag the window by the top bar (not in fullscreen)
	local dragging, dragStart, startPos
	topBar.InputBegan:Connect(function(input)
		if fullscreen then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, input.Position, holder.Position
		end
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	-- Keys: toggle key, hotkeys on cards, arrows / gamepad to move between tiles, Escape closes menus
	local keyBinds = {}
	track(UserInputService.InputBegan:Connect(function(input, processed)
		if listeningForKey or splashActive then return end
		local kc = input.KeyCode
		if menuOpen and (kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.Backspace or kc == Enum.KeyCode.ButtonB) then
			closeMenu()
			return
		end
		if processed then return end
		if kc == toggleKey then
			Window:Toggle()
			return
		end
		if visible and settingsOpen and not menuOpen and not UserInputService:GetFocusedTextBox()
			and (kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.Backspace or kc == Enum.KeyCode.ButtonB) then
			settingsBack()
			return
		end
		if visible and not settingsOpen and not menuOpen and not UserInputService:GetFocusedTextBox() then
			if kc == Enum.KeyCode.Left or kc == Enum.KeyCode.DPadLeft or kc == Enum.KeyCode.ButtonL1 then
				step(-1)
			elseif kc == Enum.KeyCode.Right or kc == Enum.KeyCode.DPadRight or kc == Enum.KeyCode.ButtonR1 then
				step(1)
			end
		end
		if kc ~= Enum.KeyCode.Unknown then
			for i = #keyBinds, 1, -1 do
				local b = keyBinds[i]
				if not b.inst:IsDescendantOf(game) then
					table.remove(keyBinds, i)
				elseif b.key == kc then
					task.spawn(b.action)
				end
			end
		end
	end))

	local settingsFx -- the Settings screen's own light rays (set below)
	-- Per frame: background drift, bokeh, clock, premium check
	local t0 = os.clock()
	local lastSecond = 0
	track(RunService.RenderStepped:Connect(function(dt)
		if shown.Value <= 0 then return end
		local t = os.clock() - t0
		if Library.Motion then
			local L = bgLayers[bgFront]
			L.grad.Rotation = 25 + math.sin(t * 0.12) * 12
			L.blobs[1].frame.Position = UDim2.fromScale(0.78 + math.sin(t * 0.13 + L.blobs[1].ph) * 0.08, 0.32 + math.cos(t * 0.11) * 0.1)
			L.blobs[2].frame.Position = UDim2.fromScale(0.3 + math.sin(t * 0.09 + L.blobs[2].ph) * 0.1, 0.85 + math.cos(t * 0.15) * 0.08)
			L.img.Position = UDim2.new(0.5, math.sin(t * 0.07) * 10, 0.5, math.cos(t * 0.06) * 6)
			fx.update(t, dt)
			if settingsFx then settingsFx(t) end
			for _, b in ipairs(bokeh) do
				b.y -= b.speed * dt
				if b.y < -0.05 then
					b.y = 1.05
					b.x = math.random()
				end
				b.f.Position = UDim2.fromScale(b.x + math.sin(t * 0.3 + b.ph) * 0.01, b.y)
				b.f.BackgroundTransparency = 1 - b.alpha * (0.5 + 0.5 * math.sin(t * b.tw + b.ph))
			end
		else
			for _, b in ipairs(bokeh) do
				b.f.BackgroundTransparency = 1
			end
		end
		if isPremium then -- the shine sweeps across your name every few seconds
			local p = (t * 0.35) % 1.6
			nameShine.Offset = Vector2.new(p * 2.4 - 1.2 - 0.6, 0)
			nameGlow.Transparency = 0.6 + 0.25 * math.sin(t * 2)
		end
		if t - lastSecond > 1 then
			lastSecond = t
			clock.Text = os.date("%H:%M")
			if not premiumLocked then
				setPremiumState(detectPremium())
			end
			for _, fn in ipairs(premiumListeners) do
				task.spawn(fn, isPremium)
			end
		end
	end))

	gui.Destroying:Connect(function()
		for _, c in ipairs(conns) do c:Disconnect() end
		if blur then blur:Destroy() end
		local i = table.find(windows, Window)
		if i then table.remove(windows, i) end
	end)

	------------------------------------------------------------------
	-- CreateTab
	------------------------------------------------------------------
	local settingsEntry
	local pickedGame = false
	function Window:CreateTab(name, opts, _internal)
		if type(opts) == "string" or type(opts) == "number" then
			opts = { Image = opts }
		end
		opts = opts or {}
		local Tab = {}
		local c1, c2 = colorsFor(name)
		if _internal then
			c1, c2 = Color3.fromRGB(150, 156, 172), Color3.fromRGB(40, 44, 56)
		end

		local e = {
			name = name,
			internal = _internal == true,
			c1 = c1,
			c2 = c2,
			background = resolveImage(opts.Background),
			nameW = estimateWidth(name, 20),
			cards = {},
			premium = opts.Premium == true,
			-- Game = true uses this tab's PlaceId
			gameSpec = (opts.Game == true) and tonumber(opts.PlaceId) or opts.Game,
			gameName = opts.GameName or opts.Title or name,
		}
		-- which game an element is for: its own Game (true = this tab's PlaceId), else the tab's
		local function specFor(o)
			local s = o and o.Game
			if s == true then s = tonumber(opts.PlaceId) end
			if s == nil then s = e.gameSpec end
			return s
		end
		-- "game" when you're not in the element's game, "premium" when it needs premium, else nil
		local function lockReason(o)
			local spec = specFor(o)
			if spec ~= nil and not gameMatches(spec) then return "game" end
			if (e.premium or (o and o.Premium == true)) and not isPremium then return "premium" end
			return nil
		end
		-- true when this thing needs premium and the user doesn't have it
		local function isLocked(o)
			return (e.premium or (o and o.Premium == true)) and not isPremium
		end

		-- Tile
		local tile = create("TextButton", {
			Position = UDim2.fromOffset(BASE_W + 100, 14),
			Size = UDim2.fromOffset(TILE, TILE),
			BackgroundColor3 = WHITE,
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			Parent = row,
		})
		corner(tile, 12)
		create("UIGradient", { Rotation = 45, Color = ColorSequence.new(c1, c2), Parent = tile })
		local tileImage = resolveImage(opts.Image)
		if _internal then
			gear(tile, WHITE, c1:Lerp(c2, 0.5))
		elseif tileImage then
			local img = create("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = tileImage,
				ScaleType = Enum.ScaleType.Crop,
				Parent = tile,
			})
			corner(img, 12)
		else
			local lbl = text(tile, {
				Size = UDim2.fromScale(1, 1),
				Text = initials(name),
				FontFace = font(Enum.FontWeight.Bold),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			create("UIPadding", {
				PaddingTop = UDim.new(0.24, 0), PaddingBottom = UDim.new(0.24, 0),
				PaddingLeft = UDim.new(0.14, 0), PaddingRight = UDim.new(0.14, 0),
				Parent = lbl,
			})
		end
		local tileDim = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Parent = tile,
		})
		corner(tileDim, 12)
		local ring = create("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 10, 1, 10),
			BackgroundTransparency = 1,
			Parent = tile,
		})
		corner(ring, 16)
		e.ringStroke = stroke(ring, WHITE, 2.5, 1)
		e.tile, e.tileDim = tile, tileDim
		if e.premium then
			-- gold lock in the corner of the tile while it's locked
			local lockBadge = create("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -5, 0, 5),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = Col.Gold,
				BorderSizePixel = 0,
				Parent = tile,
			})
			round(lockBadge)
			stroke(lockBadge, Color3.fromRGB(10, 12, 20), 1.5, 0)
			local lockIcon = padlock(lockBadge, 10, Color3.fromRGB(40, 28, 0))
			lockIcon.AnchorPoint = CENTER
			lockIcon.Position = UDim2.fromScale(0.5, 0.5)
			local function refresh() lockBadge.Visible = isLocked() end
			refresh()
			onPremium(refresh)
		end
		local tileScale = create("UIScale", { Parent = tile })
		tile.MouseEnter:Connect(function()
			if selected ~= e then
				tween(tileDim, { BackgroundTransparency = 0.1 }, 0.15)
				tween(tileScale, { Scale = 1.06 }, 0.2)
			end
		end)
		tile.MouseLeave:Connect(function()
			tween(tileDim, { BackgroundTransparency = selected == e and 1 or 0.6 }, 0.15)
			tween(tileScale, { Scale = 1 }, 0.2)
		end)
		tile.MouseButton1Down:Connect(function()
			tween(tileScale, { Scale = 0.95 }, 0.08)
		end)
		tile.MouseButton1Up:Connect(function()
			tween(tileScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
		end)
		tile.MouseButton1Click:Connect(function()
			tween(tileScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
			selectTab(e)
		end)

		-- Tile order: the game you're in, then universal tiles, then other games, Settings last.
		-- Which game a tile is for: ForGame (doesn't lock anything), else Game, else PlaceId.
		local tileSpec = opts.ForGame
		if tileSpec == nil and opts.Game ~= nil and opts.Game ~= true then tileSpec = opts.Game end
		if tileSpec == nil then tileSpec = tonumber(opts.PlaceId) end
		e.thisGame = tileSpec ~= nil and gameMatches(tileSpec)
		if _internal then
			e.rank = 4
		elseif e.thisGame then
			e.rank = 1
		elseif tileSpec == nil then
			e.rank = 2 -- universal
		else
			e.rank = 3
		end
		local at = #tiles + 1
		for i, other in ipairs(tiles) do
			if other.rank > e.rank then
				at = i
				break
			end
		end
		table.insert(tiles, at, e)
		task.spawn(function()
			local w = textWidth(name, 20, Enum.FontWeight.SemiBold) -- exact width (may yield)
			if w ~= e.nameW then
				e.nameW = w
				if selected then layoutTiles(true) end
			end
		end)

		-- Page
		local wrap = create("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Visible = false,
			Parent = pagesHolder,
		})
		local page = create("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = WHITE,
			ScrollBarImageTransparency = 0.7,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Parent = wrap,
		})
		create("UIPadding", {
			PaddingTop = UDim.new(0, PAGE_TOP),
			PaddingLeft = UDim.new(0, PAD - 8),
			PaddingRight = UDim.new(0, PAD - 8),
			PaddingBottom = UDim.new(0, 36),
			Parent = page,
		})
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
		e.wrap, e.page = wrap, page
		page:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if selected == e then updateScrollFx() end
		end)

		-- Hero: big title, description, white button + item count
		local hero = create("Frame", {
			Size = UDim2.new(1, 0, 0, HERO_H),
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Parent = page,
		})
		local heroTitle = text(hero, {
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 60),
			Text = opts.Title or name,
			FontFace = font(Enum.FontWeight.Bold),
			TextSize = 52,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local heroSub = text(hero, {
			Position = UDim2.fromOffset(10, 66),
			Size = UDim2.new(0.62, 0, 0, 40),
			Text = opts.Description or "",
			TextSize = 16,
			TextColor3 = Col.Sub,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local heroButtons = create("Frame", {
			Position = UDim2.fromOffset(8, 118),
			Size = UDim2.new(1, -16, 0, 46),
			BackgroundTransparency = 1,
			Parent = hero,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = heroButtons,
		})
		-- primary = white (like the console's Play), otherwise dark and turns white when hovered
		local function heroButton(label, primary, order, width)
			local slot = create("Frame", {
				Size = UDim2.fromOffset(width, 46),
				BackgroundTransparency = 1,
				LayoutOrder = order,
				Parent = heroButtons,
			})
			local glow = softGlow(slot, 12, WHITE, 4, 4)
			local b = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = primary and 0 or 0.8,
				AutoButtonColor = false,
				Text = label,
				FontFace = font(Enum.FontWeight.SemiBold),
				TextSize = 18,
				TextColor3 = primary and BLACK or WHITE,
				Parent = slot,
			})
			corner(b, 12)
			if not primary then stroke(b, WHITE, 1, 0.8) end
			local sc = create("UIScale", { Parent = slot })
			b.MouseEnter:Connect(function()
				sfx("Move")
				tween(sc, { Scale = 1.05 }, 0.25)
				glowTo(glow, 1)
				if not primary then
					tween(b, { BackgroundColor3 = WHITE, BackgroundTransparency = 0, TextColor3 = BLACK }, 0.15)
				end
			end)
			b.MouseLeave:Connect(function()
				tween(sc, { Scale = 1 }, 0.25)
				glowTo(glow, 0)
				if not primary then
					tween(b, { BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, TextColor3 = WHITE }, 0.15)
				end
			end)
			local function pop()
				sfx("Select")
				tween(sc, { Scale = 0.96 }, 0.08)
				task.delay(0.08, function() tween(sc, { Scale = 1.05 }, 0.3, Enum.EasingStyle.Back) end)
			end
			return b, pop
		end

		-- Play: teleports to the tab's game (Rejoin when you're already there)
		local placeId = tonumber(opts.PlaceId)
		if placeId then
			local playBtn, playPop = heroButton(game.PlaceId == placeId and "Rejoin" or "Play", true, 1, 150)
			playBtn.MouseButton1Click:Connect(function()
				playPop()
				teleportTo(placeId, playBtn, opts.Title or name)
			end)
		end
		local exploreBtn, explorePop = heroButton(opts.ButtonText or "Explore", placeId == nil, 2, 150)
		exploreBtn.MouseButton1Click:Connect(function()
			explorePop()
			tween(page, { CanvasPosition = Vector2.new(0, HERO_H - 4) }, 0.7)
		end)
		if e.premium then
			local premiumChip = create("Frame", {
				Size = UDim2.fromOffset(0, 46),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Col.Gold,
				BackgroundTransparency = 0.82,
				LayoutOrder = 4,
				Parent = heroButtons,
			})
			corner(premiumChip, 12)
			stroke(premiumChip, Col.Gold, 1, 0.4)
			create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = premiumChip })
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = premiumChip,
			})
			local chipLock = padlock(premiumChip, 14, Col.Gold, 1)
			local chipText = text(premiumChip, {
				Size = UDim2.fromOffset(0, 46),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = "",
				FontFace = font(Enum.FontWeight.SemiBold),
				TextSize = 15,
				TextColor3 = Col.Gold,
				LayoutOrder = 2,
			})
			local function refresh()
				local locked = isLocked()
				chipLock.Visible = locked
				chipText.Text = locked and "Premium only" or "★ Premium"
			end
			refresh()
			onPremium(refresh)
		end
		local countChip = create("TextLabel", {
			LayoutOrder = 3,
			Size = UDim2.fromOffset(0, 46),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.82,
			Text = "0 items",
			FontFace = font(Enum.FontWeight.Medium),
			TextSize = 15,
			TextColor3 = Col.Sub,
			Parent = heroButtons,
		})
		corner(countChip, 12)
		stroke(countChip, WHITE, 1, 0.85)
		create("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = countChip })

		local order = 0
		local itemCount = 0
		local currentGrid
		local function nextOrder()
			order += 1
			return order
		end
		local function newSection(title)
			local header
			if title then
				header = text(page, {
					Size = UDim2.new(1, 0, 0, 30),
					Text = title,
					FontFace = font(Enum.FontWeight.SemiBold),
					TextSize = 20,
					LayoutOrder = nextOrder(),
				})
				create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = header })
			end
			local grid = create("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			create("UIGridLayout", {
				CellSize = UDim2.fromOffset(CARD_W, CARD_H),
				CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = grid,
			})
			create("UIPadding", {
				PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 18),
				PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
				Parent = grid,
			})
			currentGrid = grid
			return header
		end

		-- A full-width glass panel for your own UI (lists, grids, previews). Cards made after it
		-- continue in a new row below. Returns the Frame to put things in.
		local madeGrid = false
		function Tab:CreateContainer(height)
			if not madeGrid then newSection(opts.Section or "Items") end
			madeGrid = true
			local wrapper = create("Frame", {
				Size = UDim2.new(1, 0, 0, (height or 300) + 16),
				BackgroundTransparency = 1,
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			local panelFrame = create("Frame", {
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(1, -16, 1, -16),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = CARD_ALPHA,
				BorderSizePixel = 0,
				Parent = wrapper,
			})
			corner(panelFrame, 14)
			stroke(panelFrame, WHITE, 1, 0.75)
			currentGrid = nil
			itemCount += 1
			countChip.Text = itemCount == 1 and "1 item" or (itemCount .. " items")
			return panelFrame
		end

		function Tab:CreateSection(title)
			madeGrid = true
			local header = newSection(title or "Section")
			return { Set = function(_, t) header.Text = t end }
		end

		-- Intro: title slides in, cards rise in one after another
		function e.intro()
			heroTitle.Position = UDim2.fromOffset(40, 4)
			heroTitle.TextTransparency = 1
			tween(heroTitle, { Position = UDim2.fromOffset(8, 4), TextTransparency = 0 }, 0.6)
			heroSub.TextTransparency = 1
			task.delay(0.06, function() tween(heroSub, { TextTransparency = 0 }, 0.5) end)
			heroButtons.Position = UDim2.fromOffset(8, 132)
			tween(heroButtons, { Position = UDim2.fromOffset(8, 118) }, 0.6)
			for i, c in ipairs(e.cards) do
				c.holder.Position = UDim2.new(0.5, 0, 0.5, 22)
				c.scale.Scale = 0.94
				local d = math.min(0.08 + i * 0.035, 0.5)
				task.delay(d, function()
					tween(c.holder, { Position = UDim2.fromScale(0.5, 0.5) }, 0.5)
					tween(c.scale, { Scale = c.isFocused() and 1.05 or 1 }, 0.5)
				end)
			end
		end

		------------------------------------------------------------------
		-- Card (every element is one)
		------------------------------------------------------------------
		local function flagOf(o, fallback)
			return o.Flag or (name .. "/" .. (o.Name or fallback))
		end

		local function newCard(o, kind)
			if not currentGrid then
				newSection(not madeGrid and (opts.Section or "Items") or nil)
				madeGrid = true
			end
			itemCount += 1
			countChip.Text = itemCount == 1 and "1 item" or (itemCount .. " items")

			local slot = create("Frame", { BackgroundTransparency = 1, LayoutOrder = itemCount, Parent = currentGrid })
			local cardHolder = create("Frame", {
				AnchorPoint = CENTER,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Parent = slot,
			})
			local scale = create("UIScale", { Parent = cardHolder })
			local glow = softGlow(cardHolder, 14, WHITE, 4, 4)
			local face = create("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Col.Card,
				BackgroundTransparency = CARD_ALPHA,
				BorderSizePixel = 0,
				Parent = cardHolder,
			})
			corner(face, 14)
			stroke(face, WHITE, 1, 0.75)
			local ringFrame = create("Frame", {
				AnchorPoint = CENTER,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 8, 1, 8),
				BackgroundTransparency = 1,
				Parent = cardHolder,
			})
			corner(ringFrame, 18)
			local ringStroke = stroke(ringFrame, WHITE, 2.5, 1)

			-- click area first, so text boxes / bars added later sit on top of it
			local hit = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				Parent = face,
			})
			local title = text(face, {
				Position = UDim2.fromOffset(16, 14),
				Size = UDim2.new(1, -32, 0, 20),
				Text = o.Name or kind,
				FontFace = font(Enum.FontWeight.SemiBold),
				TextSize = 16,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			if o.Description then
				text(face, {
					Position = UDim2.fromOffset(16, 36),
					Size = UDim2.new(1, -32, 0, 32),
					Text = o.Description,
					TextSize = 13,
					TextColor3 = Col.Dim,
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
			end

			local focused = false
			local held = false -- e.g. slider being dragged: stay focused
			local function setFocus(v)
				if held and not v then return end
				if focused == v then return end
				focused = v
				tween(scale, { Scale = v and 1.05 or 1 }, 0.28)
				tween(ringStroke, { Transparency = v and 0 or 1 }, 0.18)
				tween(face, {
					BackgroundColor3 = v and Col.CardHover or Col.Card,
					BackgroundTransparency = v and CARD_ALPHA_HOVER or CARD_ALPHA,
				}, 0.2)
				glowTo(glow, v and 1 or 0, 0.28)
				if v then sfx("Move") end
			end
			cardHolder.MouseEnter:Connect(function() setFocus(true) end)
			cardHolder.MouseLeave:Connect(function() setFocus(false) end)

			local function press()
				local flash = create("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = WHITE,
					BackgroundTransparency = 0.75,
					BorderSizePixel = 0,
					Parent = face,
				})
				corner(flash, 14)
				tween(flash, { BackgroundTransparency = 1 }, 0.35)
				task.delay(0.4, function() flash:Destroy() end)
				tween(scale, { Scale = 0.97 }, 0.07)
				task.delay(0.07, function()
					tween(scale, { Scale = focused and 1.05 or 1 }, 0.35, Enum.EasingStyle.Back)
				end)
			end

			local card = {
				slot = slot,
				holder = cardHolder,
				scale = scale,
				face = face,
				hit = hit,
				title = title,
				press = press,
				isFocused = function() return focused end,
				hold = function(v)
					held = v
					if not v then
						-- re-check: the mouse may have left while dragging
						local m = UserInputService:GetMouseLocation()
						local p, s = cardHolder.AbsolutePosition, cardHolder.AbsoluteSize
						local inside = m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
						if not inside then setFocus(false) end
					end
				end,
			}
			-- Lock: dims the card, adds a tag (gold PREMIUM / blue ONLY IN <game>) and swallows every
			-- click on it (ZIndex 10, so it sits above whatever the element adds to the card afterwards)
			card.locked = function() return lockReason(o) ~= nil end
			if e.premium or o.Premium == true or specFor(o) ~= nil then
				local gameName = o.GameName or e.gameName
				local lockLayer = create("TextButton", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = BLACK,
					BackgroundTransparency = 0.6,
					AutoButtonColor = false,
					Text = "",
					ZIndex = 10,
					Parent = face,
				})
				corner(lockLayer, 14)
				local tag = create("Frame", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -12, 0, 12),
					Size = UDim2.fromOffset(0, 22),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = Col.Gold,
					BorderSizePixel = 0,
					Parent = lockLayer,
				})
				corner(tag, 6)
				create("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 8), Parent = tag })
				create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 5),
					SortOrder = Enum.SortOrder.LayoutOrder,
					Parent = tag,
				})
				local tagLock = padlock(tag, 10, Color3.fromRGB(40, 28, 0), 1)
				local tagText = text(tag, {
					Size = UDim2.fromOffset(0, 22),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = "PREMIUM",
					FontFace = font(Enum.FontWeight.Bold),
					TextSize = 11,
					TextColor3 = Color3.fromRGB(40, 28, 0),
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = 2,
				})
				create("UISizeConstraint", { MaxSize = Vector2.new(CARD_W - 40, 22), Parent = tag })
				local function press()
					if lockReason(o) == "game" then
						denied(cardHolder, "Only in " .. gameName,
							"This only works in " .. gameName .. ". Use Play on its tile to go there.")
					else
						denied(cardHolder)
					end
				end
				lockLayer.MouseButton1Click:Connect(press)
				lockLayer.MouseButton2Click:Connect(press)
				card.denied = press
				local function refresh()
					local reason = lockReason(o)
					lockLayer.Visible = reason ~= nil
					if reason == "game" then
						tag.BackgroundColor3 = WHITE
						tagLock.Visible = false
						tagText.Text = "ONLY IN " .. string.upper(gameName)
						tagText.TextColor3 = Color3.fromRGB(20, 40, 90)
					elseif reason == "premium" then
						tag.BackgroundColor3 = Col.Gold
						tagLock.Visible = true
						tagText.Text = "PREMIUM"
						tagText.TextColor3 = Color3.fromRGB(40, 28, 0)
					end
				end
				refresh()
				onPremium(refresh) -- also re-run every second (a Game = function() check can change)
			end
			table.insert(e.cards, card)
			return card
		end

		-- Hotkey chip in the card's top-right corner (right-click to set)
		local function attachBind(o, flag, card, action)
			local bindFlag = flag .. "/Bind"
			local key = Enum.KeyCode.Unknown
			if type(flags[bindFlag]) == "string" then
				if flags[bindFlag] ~= "" then
					local ok, saved = pcall(function() return Enum.KeyCode[flags[bindFlag]] end)
					if ok and saved then key = saved end
				end
			elseif typeof(o.Bind) == "EnumItem" then
				key = o.Bind
			end
			local chip = create("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 12),
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = BLACK,
				BackgroundTransparency = 0.65,
				Text = key.Name,
				FontFace = font(Enum.FontWeight.SemiBold),
				TextSize = 12,
				TextColor3 = Col.Sub,
				Visible = key ~= Enum.KeyCode.Unknown,
				Parent = card.face,
			})
			corner(chip, 6)
			create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = chip })
			local function fitTitle()
				card.title.Size = UDim2.new(1, chip.Visible and -110 or -32, 0, 20)
			end
			fitTitle()

			local function guarded()
				if card.locked() then
					if card.denied then card.denied() else denied(card.holder) end
					return
				end
				action()
			end
			local entry = { key = key, action = guarded, inst = chip }
			table.insert(keyBinds, entry)
			local function setKey(k)
				key = k or Enum.KeyCode.Unknown
				entry.key = key
				chip.Text = key.Name
				chip.Visible = key ~= Enum.KeyCode.Unknown
				fitTitle()
				changed(bindFlag, key == Enum.KeyCode.Unknown and "" or key.Name)
			end
			card.hit.MouseButton2Click:Connect(function()
				if listeningForKey then return end
				listeningForKey = true
				chip.Text = "Press a key..."
				chip.Visible = true
				local conn
				conn = UserInputService.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
					conn:Disconnect()
					task.defer(function() listeningForKey = false end)
					if input.KeyCode == Enum.KeyCode.Escape then
						setKey(key)
					elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
						setKey(nil)
					else
						setKey(input.KeyCode)
					end
				end)
			end)
			return { Set = setKey }
		end

		-- small round "go" chip, bottom right of button cards
		local function goChip(parent)
			local c = create("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -14, 1, -14),
				Size = UDim2.fromOffset(30, 30),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.85,
				BorderSizePixel = 0,
				Parent = parent,
			})
			round(c)
			chevron(c, 12, WHITE)
			return c
		end

		-- Label ------------------------------------------------------
		function Tab:CreateLabel(str)
			local card = newCard({ Name = "" }, "Label")
			card.title.Visible = false
			local l = text(card.face, {
				Position = UDim2.fromOffset(16, 14),
				Size = UDim2.new(1, -32, 1, -28),
				Text = tostring(str),
				TextSize = 15,
				TextColor3 = Col.Sub,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			return { Set = function(_, t) l.Text = tostring(t) end }
		end

		-- Button -----------------------------------------------------
		function Tab:CreateButton(o)
			local card = newCard(o, "Button")
			local chip = goChip(card.face)
			local function run()
				card.press()
				sfx("Select")
				tween(chip, { BackgroundTransparency = 0.3 }, 0.08)
				task.delay(0.1, function() tween(chip, { BackgroundTransparency = 0.85 }, 0.4) end)
				fire(o.Callback)
			end
			card.hit.MouseButton1Click:Connect(run)
			local Button = { Destroy = function() card.slot:Destroy() end }
			local bind = attachBind(o, flagOf(o, "Button"), card, run)
			Button.SetBind = function(_, k) bind.Set(k) end
			return Button
		end

		-- Toggle -----------------------------------------------------
		function Tab:CreateToggle(o)
			local flag = flagOf(o, "Toggle")
			local value
			if flags[flag] ~= nil then
				value = flags[flag] == true
			else
				value = o.CurrentValue == true
			end
			local loopId = 0
			local interval = o.Interval or 0.1

			local card = newCard(o, "Toggle")
			local state = text(card.face, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 16, 1, -16),
				Size = UDim2.fromOffset(80, 20),
				Text = "",
				FontFace = font(Enum.FontWeight.Medium),
				TextSize = 14,
				TextColor3 = Col.Sub,
			})
			local track_ = create("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -14, 1, -14),
				Size = UDim2.fromOffset(48, 26),
				BackgroundColor3 = Col.Track,
				BorderSizePixel = 0,
				Parent = card.face,
			})
			round(track_)
			local knob = create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 3, 0.5, 0),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				Parent = track_,
			})
			round(knob)

			local function paint(animated)
				local pos = UDim2.new(0, value and 25 or 3, 0.5, 0)
				local color = value and accent or Col.Track
				state.Text = value and "On" or "Off"
				state.TextColor3 = value and WHITE or Col.Sub
				if animated then
					tween(track_, { BackgroundColor3 = color }, 0.2)
					-- knob stretches toward where it's going, then settles
					tween(knob, { Size = UDim2.fromOffset(26, 20), Position = UDim2.new(0, value and 13 or 3, 0.5, 0) }, 0.1)
					task.delay(0.1, function()
						tween(knob, { Size = UDim2.fromOffset(20, 20), Position = pos }, 0.3, Enum.EasingStyle.Back)
					end)
				else
					track_.BackgroundColor3 = color
					knob.Position = pos
				end
			end

			local Toggle = {}
			table.insert(allToggles, Toggle)
			local function startLoop()
				if type(o.Loop) ~= "function" then return end
				loopId += 1
				local mine = loopId
				task.spawn(function()
					while value and mine == loopId and card.slot:IsDescendantOf(game) do
						local ok, err = pcall(o.Loop)
						if not ok then
							warn(string.format("[PS5Library] Loop error in '%s': %s (toggle switched off)", o.Name or "Toggle", tostring(err)))
							if mine == loopId then Toggle:Set(false) end
							break
						end
						task.wait(interval)
					end
				end)
			end
			function Toggle:Set(v, silent)
				v = v == true
				if v == value then return end
				if v and card.locked() then return end -- premium-only: can't be switched on
				value = v
				paint(true)
				changed(flag, v)
				if v then startLoop() else loopId += 1 end
				if not silent then fire(o.Callback, v) end
			end
			function Toggle:Get()
				return value
			end
			local function flip()
				card.press()
				sfx("Select")
				Toggle:Set(not value)
			end
			card.hit.MouseButton1Click:Connect(flip)
			local bind = attachBind(o, flag, card, flip)
			Toggle.SetBind = function(_, k) bind.Set(k) end
			-- saved as on but locked now: show it off and don't run it (the saved value is kept)
			if value and card.locked() then value = false end
			onPremium(function()
				if value and card.locked() then Toggle:Set(false) end
			end)
			paint(false)
			if value then
				task.defer(function()
					if value then
						fire(o.Callback, true)
						startLoop()
					end
				end)
			end
			return Toggle
		end

		-- Slider -----------------------------------------------------
		function Tab:CreateSlider(o)
			local flag = flagOf(o, "Slider")
			local min, max = o.Range and o.Range[1] or 0, o.Range and o.Range[2] or 100
			local inc = o.Increment or 1
			local fromSave = type(flags[flag]) == "number"
			local value = fromSave and flags[flag] or (o.CurrentValue or min)

			local card = newCard(o, "Slider")
			card.title.Size = UDim2.new(1, -100, 0, 20)
			local valueLabel = text(card.face, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -16, 0, 12),
				Size = UDim2.fromOffset(84, 24),
				Text = "",
				FontFace = font(Enum.FontWeight.Bold),
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			local area = create("TextButton", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 10, 1, -8),
				Size = UDim2.new(1, -20, 0, 30),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				Parent = card.face,
			})
			local bar = create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.new(1, -16, 0, 4),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.78,
				BorderSizePixel = 0,
				Parent = area,
			})
			round(bar)
			local fill = create("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				Parent = bar,
			})
			round(fill)
			local knobHalo = create("Frame", {
				AnchorPoint = CENTER,
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = fill,
			})
			round(knobHalo)
			local knob = create("Frame", {
				AnchorPoint = CENTER,
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				Parent = fill,
			})
			round(knob)

			local Slider = {}
			local function render(v, instant)
				v = math.clamp(math.floor(v / inc + 0.5) * inc, min, max)
				local moved = v ~= value
				value = v
				local size = UDim2.fromScale(max > min and (v - min) / (max - min) or 0, 1)
				if instant then fill.Size = size else tween(fill, { Size = size }, 0.08) end
				valueLabel.Text = tostring(math.round(v * 100) / 100) .. (o.Suffix and (" " .. o.Suffix) or "")
				if moved and not instant then
					valueLabel.TextSize = 21
					tween(valueLabel, { TextSize = 18 }, 0.2)
				end
				return v
			end
			function Slider:Set(v, silent)
				v = render(v)
				changed(flag, v)
				if not silent then fire(o.Callback, v) end
			end
			function Slider:Get()
				return value
			end
			local sliding = false
			local function fromX(x)
				local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
				local before = value
				Slider:Set(min + (max - min) * rel)
				if value ~= before then sfx("Move") end
			end
			local cardConns = {}
			table.insert(cardConns, area.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					sliding = true
					card.hold(true)
					tween(knob, { Size = UDim2.fromOffset(20, 20) }, 0.18, Enum.EasingStyle.Back)
					tween(knobHalo, { Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 0.8 }, 0.2)
					fromX(input.Position.X)
				end
			end))
			table.insert(cardConns, UserInputService.InputChanged:Connect(function(input)
				if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					fromX(input.Position.X)
				end
			end))
			table.insert(cardConns, UserInputService.InputEnded:Connect(function(input)
				if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
					sliding = false
					tween(knob, { Size = UDim2.fromOffset(16, 16) }, 0.18)
					tween(knobHalo, { Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1 }, 0.2)
					card.hold(false)
				end
			end))
			card.slot.Destroying:Connect(function()
				for _, c in ipairs(cardConns) do c:Disconnect() end
			end)
			render(value, true)
			if fromSave then
				task.defer(function() if not card.locked() then fire(o.Callback, value) end end)
			end
			return Slider
		end

		-- Input ------------------------------------------------------
		function Tab:CreateInput(o)
			local flag = flagOf(o, "Input")
			local fromSave = type(flags[flag]) == "string" and flags[flag] ~= ""
			local card = newCard(o, "Input")
			local boxFrame = create("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 14, 1, -14),
				Size = UDim2.new(1, -28, 0, 34),
				BackgroundColor3 = BLACK,
				BackgroundTransparency = 0.7,
				BorderSizePixel = 0,
				Parent = card.face,
			})
			corner(boxFrame, 9)
			local boxStroke = stroke(boxFrame, WHITE, 1, 0.85)
			local box = create("TextBox", {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -24, 1, 0),
				BackgroundTransparency = 1,
				Text = fromSave and flags[flag] or "",
				PlaceholderText = o.PlaceholderText or "Type here",
				PlaceholderColor3 = Col.Dim,
				ClearTextOnFocus = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				FontFace = font(Enum.FontWeight.Regular),
				TextSize = 14,
				TextColor3 = WHITE,
				Parent = boxFrame,
			})
			card.hit.MouseButton1Click:Connect(function() box:CaptureFocus() end)
			box.Focused:Connect(function()
				card.hold(true)
				tween(boxStroke, { Transparency = 0, Color = accent:Lerp(WHITE, 0.3) }, 0.15)
			end)
			box.FocusLost:Connect(function()
				card.hold(false)
				tween(boxStroke, { Transparency = 0.85, Color = WHITE }, 0.15)
				if not o.RemoveTextAfterFocusLost then changed(flag, box.Text) end
				fire(o.Callback, box.Text)
				if o.RemoveTextAfterFocusLost then box.Text = "" end
			end)
			if fromSave then
				task.defer(function() if not card.locked() then fire(o.Callback, box.Text) end end)
			end
			return {
				Set = function(_, t)
					box.Text = tostring(t)
					if not o.RemoveTextAfterFocusLost then changed(flag, box.Text) end
				end,
			}
		end

		-- Dropdown (opens the menu over the screen) -------------------
		function Tab:CreateDropdown(o)
			local flag = flagOf(o, "Dropdown")
			local options = o.Options or {}
			local current = o.CurrentOption
			if type(current) == "table" then current = current[1] end
			if current == nil then current = options[1] end
			local fromSave = false
			if flags[flag] ~= nil then
				for _, opt in ipairs(options) do
					if tostring(opt) == tostring(flags[flag]) then
						current = opt
						fromSave = true
						break
					end
				end
			end

			local card = newCard(o, "Dropdown")
			local valueLabel = text(card.face, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 16, 1, -18),
				Size = UDim2.new(1, -64, 0, 20),
				Text = tostring(current or "-"),
				FontFace = font(Enum.FontWeight.SemiBold),
				TextSize = 16,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			local arrowChip = create("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -14, 1, -14),
				Size = UDim2.fromOffset(30, 30),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.85,
				BorderSizePixel = 0,
				Parent = card.face,
			})
			round(arrowChip)
			chevron(arrowChip, 12, WHITE, 90)

			local Dropdown = {}
			function Dropdown:Set(v, silent)
				current = v
				valueLabel.Text = tostring(v)
				changed(flag, v)
				if not silent then fire(o.Callback, v) end
			end
			function Dropdown:Get()
				return current
			end
			function Dropdown:Refresh(newOptions, cur)
				options = newOptions or {}
				if cur ~= nil then
					Dropdown:Set(cur, true)
				end
			end
			card.hit.MouseButton1Click:Connect(function()
				card.press()
				sfx("Select")
				openMenu(o.Name or "Choose", options, current, function(opt)
					Dropdown:Set(opt)
				end)
			end)
			if fromSave then
				task.defer(function() if not card.locked() then fire(o.Callback, current) end end)
			end
			return Dropdown
		end

		-- Keybind ----------------------------------------------------
		function Tab:CreateKeybind(o)
			local flag = flagOf(o, "Keybind")
			local key = o.CurrentKeybind or Enum.KeyCode.Unknown
			local fromSave = false
			if type(flags[flag]) == "string" then
				local ok, saved = pcall(function() return Enum.KeyCode[flags[flag]] end)
				if ok and saved then
					key = saved
					fromSave = true
				end
			end
			local card = newCard(o, "Keybind")
			local keyChip = create("TextLabel", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 14, 1, -14),
				Size = UDim2.fromOffset(0, 30),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.85,
				Text = key.Name,
				FontFace = font(Enum.FontWeight.SemiBold),
				TextSize = 14,
				TextColor3 = WHITE,
				Parent = card.face,
			})
			corner(keyChip, 8)
			create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = keyChip })

			local Keybind = {}
			function Keybind:Set(k, silent)
				key = k
				keyChip.Text = k.Name
				changed(flag, k.Name)
				if not silent then fire(o.Changed, k) end
			end
			card.hit.MouseButton1Click:Connect(function()
				if listeningForKey then return end
				card.press()
				listeningForKey = true
				keyChip.Text = "Press a key..."
				tween(keyChip, { BackgroundTransparency = 0.6 }, 0.15)
				local conn
				conn = UserInputService.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
					conn:Disconnect()
					task.defer(function() listeningForKey = false end)
					tween(keyChip, { BackgroundTransparency = 0.85 }, 0.15)
					if input.KeyCode == Enum.KeyCode.Escape then
						keyChip.Text = key.Name
					else
						sfx("Select")
						Keybind:Set(input.KeyCode)
					end
				end)
			end)
			local pressConn = UserInputService.InputBegan:Connect(function(input, processed)
				if processed or listeningForKey or card.locked() then return end
				if key ~= Enum.KeyCode.Unknown and input.KeyCode == key then
					fire(o.Callback, key)
				end
			end)
			card.slot.Destroying:Connect(function() pressConn:Disconnect() end)
			if fromSave then
				task.defer(function() if not card.locked() then fire(o.Changed, key) end end)
			end
			return Keybind
		end

		Tab._entry = e
		-- open on the first tile (the game you're in, or else a universal one)
		if e.thisGame and not pickedGame then
			pickedGame = true
			selectTab(e, true)
		elseif not pickedGame and tiles[1] and not tiles[1].internal and selected ~= tiles[1] then
			selectTab(tiles[1], true)
		elseif selected then
			layoutTiles(false)
		end
		return Tab
	end

	function Window:SelectTab(name)
		if name == "Settings" then
			openSettings()
			return
		end
		for _, e in ipairs(tiles) do
			if e.name == name then
				selectTab(e)
				return
			end
		end
	end

	------------------------------------------------------------------
	-- Settings screen (console style): "Settings" next to "Games" at the top left opens it.
	-- A list of categories with icons; clicking one opens its options in the same list.
	-- Everything here is shared by every script that uses this library.
	------------------------------------------------------------------
	local setView = create("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = screen,
	})
	local setDark = create("Frame", { -- dark slate over the theme, like the console
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(14, 18, 28),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Parent = setView,
	})
	create("UIGradient", {
		Rotation = 35,
		Transparency = NumberSequence.new({ nk(0, 0.35), nk(0.5, 0.05), nk(1, 0) }),
		Parent = setDark,
	})
	-- warm light rays from the top left corner
	local setRays = {}
	for i = 1, 6 do
		local ray = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.12, 0, -0.2, 0),
			Size = UDim2.fromOffset(1500, 40 + (i % 3) * 45),
			Rotation = 28 + i * 7,
			BackgroundColor3 = Color3.fromRGB(240, 232, 218),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = setView,
		})
		create("UIGradient", { Transparency = NumberSequence.new({ nk(0, 0.15), nk(0.4, 0.6), nk(1, 1) }), Parent = ray })
		setRays[i] = { f = ray, rot = 28 + i * 7, a = 0.045 + (i % 2) * 0.03, ph = i * 1.9 }
	end
	local setGlow = create("Frame", { -- soft light where the rays come from
		AnchorPoint = CENTER,
		Position = UDim2.new(0.14, 0, -0.12, 0),
		Size = UDim2.fromOffset(520, 520),
		BackgroundColor3 = Color3.fromRGB(240, 232, 218),
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Parent = setView,
	})
	round(setGlow)
	create("UIGradient", {
		Transparency = NumberSequence.new({ nk(0, 1), nk(0.5, 0.2), nk(1, 1) }),
		Parent = setGlow,
	})
	settingsFx = function(t)
		if not settingsOpen then return end
		for _, r in ipairs(setRays) do
			r.f.Rotation = r.rot + math.sin(t * 0.09 + r.ph) * 1.8
			r.f.BackgroundTransparency = 1 - r.a * (0.7 + 0.3 * math.sin(t * 0.3 + r.ph))
		end
	end
	for _, r in ipairs(setRays) do r.f.BackgroundTransparency = 1 - r.a end

	-- title (with a back arrow inside a category)
	local setBackBtn = create("TextButton", {
		Position = UDim2.fromOffset(PAD - 6, 62),
		Size = UDim2.fromOffset(28, 34),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = setView,
	})
	chevron(setBackBtn, 16, WHITE, 180)
	local setTitle = text(setView, {
		Position = UDim2.fromOffset(PAD, 62),
		Size = UDim2.new(0.5, 0, 0, 34),
		Text = "Settings",
		FontFace = font(Enum.FontWeight.Medium),
		TextSize = 26,
	})
	local LIST_W = 560
	local listGroup = create("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 20, 0, 108),
		Size = UDim2.new(0, LIST_W + 44, 1, -124),
		BackgroundTransparency = 1,
		Parent = setView,
	})
	local setList = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = WHITE,
		ScrollBarImageTransparency = 0.45,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = listGroup,
	})
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = setList })
	create("UIPadding", { PaddingRight = UDim.new(0, 44), PaddingBottom = UDim.new(0, 20), Parent = setList })

	-- line icons drawn with frames (recoloured when a row is focused)
	local function ring(parent, size, thick, pos)
		local f = create("Frame", {
			AnchorPoint = CENTER,
			Position = pos or UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Parent = parent,
		})
		round(f)
		stroke(f, WHITE, thick or 2, 0)
		return f
	end
	local function bar(parent, w, h, x, y, rot, r)
		local f = create("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.new(0.5, x or 0, 0.5, y or 0),
			Size = UDim2.fromOffset(w, h),
			Rotation = rot or 0,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Parent = parent,
		})
		if r then corner(f, r) end
		return f
	end
	local Icons = {
		System = function(box)
			ring(box, 12, 2)
			for i = 0, 5 do
				local a = math.rad(i * 60)
				bar(box, 4, 4, math.sin(a) * 8, -math.cos(a) * 8, i * 60, 1)
			end
		end,
		Screen = function(box)
			local f = bar(box, 20, 13, 0, -2, 0, 3)
			f.BackgroundTransparency = 1
			stroke(f, WHITE, 2, 0)
			bar(box, 10, 2, 0, 8, 0, 1)
		end,
		Themes = function(box)
			ring(box, 19, 2)
			for i, p in ipairs({ { -3, -3 }, { 3, -3 }, { 0, 3 } }) do
				local d = bar(box, 4, 4, p[1], p[2])
				round(d)
			end
		end,
		Account = function(box)
			local head = bar(box, 8, 8, 0, -5)
			round(head)
			bar(box, 16, 7, 0, 6, 0, 4)
		end,
		Data = function(box)
			for i = -1, 1 do bar(box, 18, 3, 0, i * 6, 0, 2) end
		end,
		Power = function(box)
			ring(box, 16, 2, UDim2.new(0.5, 0, 0.5, 1))
			bar(box, 2, 9, 0, -5, 0, 1)
		end,
	}
	local function recolor(box, c)
		for _, d in ipairs(box:GetDescendants()) do
			if d:IsA("UIStroke") then
				d.Color = c
			elseif d:IsA("Frame") and (d.BackgroundTransparency or 0) < 1 then
				d.BackgroundColor3 = c
			end
		end
	end

	-- one list row. o = { Name, Desc, Icon, Swatch = {c1, c2}, Kind = "switch" | "value" | "radio" | nil,
	--                     Get = fn, OnClick = fn(row), Danger = bool }
	local rows, rowOrder = {}, 0
	local DARK = Color3.fromRGB(20, 22, 28)
	local function makeRow(o)
		rowOrder += 1
		local h = o.Desc and 60 or 48
		local r = create("TextButton", {
			Size = UDim2.new(1, 0, 0, h),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = rowOrder,
			Parent = setList,
		})
		local hl = create("Frame", {
			Position = UDim2.fromOffset(4, 3),
			Size = UDim2.new(1, -8, 1, -6),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = r,
		})
		corner(hl, 10)
		local hlGlow = stroke(hl, WHITE, 3, 1)
		create("Frame", { -- divider
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 16, 1, 0),
			Size = UDim2.new(1, -32, 0, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			Parent = r,
		})
		local x = 20
		local iconBox
		if o.Icon or o.Swatch then
			iconBox = create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 20, 0.5, 0),
				Size = UDim2.fromOffset(24, 24),
				BackgroundTransparency = 1,
				Parent = r,
			})
			if o.Swatch then
				local sw = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = iconBox })
				round(sw)
				create("UIGradient", { Rotation = 45, Color = ColorSequence.new(o.Swatch[1], o.Swatch[2]), Parent = sw })
				stroke(sw, WHITE, 1, 0.6)
			else
				o.Icon(iconBox)
			end
			x = 58
		end
		local label = text(r, {
			Position = UDim2.fromOffset(x, o.Desc and 9 or 0),
			Size = UDim2.new(1, -x - 170, 0, o.Desc and 24 or h),
			Text = o.Name,
			FontFace = font(Enum.FontWeight.Medium),
			TextSize = 17,
			TextColor3 = o.Danger and Color3.fromRGB(255, 140, 140) or WHITE,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local desc
		if o.Desc then
			desc = text(r, {
				Position = UDim2.fromOffset(x, 33),
				Size = UDim2.new(1, -x - 170, 0, 18),
				Text = o.Desc,
				TextSize = 13,
				TextColor3 = Col.PsText,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		end
		local row = { inst = r, o = o, focused = false }
		local value, track, knob, radioRing, radioFill
		if o.Kind == "value" then
			value = text(r, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -22, 0.5, 0),
				Size = UDim2.fromOffset(160, 22),
				Text = "",
				TextSize = 15,
				TextColor3 = Col.PsText,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		elseif o.Kind == "switch" then
			track = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -22, 0.5, 0),
				Size = UDim2.fromOffset(44, 24),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				Parent = r,
			})
			round(track)
			knob = create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 3, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				Parent = track,
			})
			round(knob)
		elseif o.Kind == "radio" then
			radioRing = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -24, 0.5, 0),
				Size = UDim2.fromOffset(20, 20),
				BackgroundTransparency = 1,
				Parent = r,
			})
			round(radioRing)
			radioRing = stroke(radioRing, WHITE, 2, 0)
			radioFill = create("Frame", {
				AnchorPoint = CENTER,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				Parent = radioRing.Parent,
			})
			round(radioFill)
		end
		function row.paint(animated)
			local f = row.focused
			local fg = f and BLACK or (o.Danger and Color3.fromRGB(255, 140, 140) or WHITE)
			local t = animated and 0.12 or 0
			local function set(inst, props)
				if t > 0 then tween(inst, props, t) else for k, v in pairs(props) do inst[k] = v end end
			end
			set(hl, { BackgroundTransparency = f and 0 or 1 })
			set(hlGlow, { Transparency = f and 0.6 or 1 })
			set(label, { TextColor3 = fg })
			if desc then set(desc, { TextColor3 = f and Color3.fromRGB(70, 74, 84) or Col.PsText }) end
			if iconBox and o.Icon then recolor(iconBox, f and BLACK or WHITE) end
			local v = o.Get and o.Get()
			if value then
				value.Text = tostring(v or "")
				set(value, { TextColor3 = f and Color3.fromRGB(70, 74, 84) or Col.PsText })
			elseif track then
				set(track, {
					BackgroundColor3 = v and accent or (f and DARK or WHITE),
					BackgroundTransparency = v and 0 or (f and 0.75 or 0.7),
				})
				set(knob, { Position = UDim2.new(0, v and 23 or 3, 0.5, 0) })
			elseif radioRing then
				set(radioRing, { Color = f and BLACK or WHITE, Transparency = v and 0 or 0.4 })
				set(radioFill, { BackgroundColor3 = f and BLACK or WHITE, BackgroundTransparency = v and 0 or 1 })
			end
		end
		r.MouseEnter:Connect(function()
			sfx("Move")
			row.focused = true
			row.paint(true)
		end)
		r.MouseLeave:Connect(function()
			row.focused = false
			row.paint(true)
		end)
		r.MouseButton1Click:Connect(function()
			if not o.OnClick then return end
			sfx("Select")
			o.OnClick(row)
			for _, other in ipairs(rows) do other.paint(true) end
		end)
		table.insert(rows, row)
		row.paint(false)
		return row
	end
	local function clearRows()
		for _, row in ipairs(rows) do row.inst:Destroy() end
		table.clear(rows)
		rowOrder = 0
		setList.CanvasPosition = Vector2.zero
	end

	-- the settings themselves (saved for every script: GuiLibrary/PS5Settings.json)
	local function saveSetting(key, v) changed("__global_" .. key, v) end
	if type(globalSettings.ToggleKey) == "string" then
		local ok, kc = pcall(function() return Enum.KeyCode[globalSettings.ToggleKey] end)
		if ok and kc then toggleKey = kc end
	end
	local antiAfkConn
	local function setAntiAfk(v)
		if antiAfkConn then
			antiAfkConn:Disconnect()
			antiAfkConn = nil
		end
		if v then
			antiAfkConn = player.Idled:Connect(function()
				pcall(function()
					local vu = game:GetService("VirtualUser")
					vu:CaptureController()
					vu:ClickButton2(Vector2.new(0, 0))
				end)
			end)
			track(antiAfkConn)
		end
	end
	setAntiAfk(globalSettings.AntiAfk == true)
	local function setTheme(th)
		currentTheme = th
		saveSetting("Theme", th.Name)
		if selected then setBackground(selected, false) else fx.paint(nil) end
	end
	function Window:SetTheme(nameOrTheme)
		local th = type(nameOrTheme) == "table" and nameOrTheme or themeByName(nameOrTheme)
		if th then setTheme(th) end
	end
	function Window:SetFullscreen(v)
		saveSetting("Fullscreen", v == true)
		setFullscreen(v)
	end

	-- a key row: click, then press a key (Escape cancels)
	local function keyRow(name, desc, get, set)
		local listening = false
		local row
		row = makeRow({
			Name = name, Desc = desc, Kind = "value",
			Get = function() return listening and "Press a key..." or get().Name end,
			OnClick = function()
				if listening or listeningForKey then return end
				listening = true
				listeningForKey = true
				local conn
				conn = UserInputService.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
					conn:Disconnect()
					listening = false
					if input.KeyCode ~= Enum.KeyCode.Escape then set(input.KeyCode) end
					task.defer(function() listeningForKey = false end)
					if row.inst.Parent then row.paint(true) end
				end)
			end,
		})
		return row
	end
	local function choiceRow(name, desc, options, get, set)
		return makeRow({
			Name = name, Desc = desc, Kind = "value", Get = get,
			OnClick = function(row)
				openMenu(name, options, get(), function(v)
					set(v)
					if row.inst.Parent then row.paint(true) end
				end)
			end,
		})
	end
	local function switchRow(name, desc, get, set)
		return makeRow({
			Name = name, Desc = desc, Kind = "switch", Get = get,
			OnClick = function() set(not get()) end,
		})
	end

	local unloadArmed = 0
	local Categories = {
		{ Name = "System", Icon = Icons.System, Build = function()
			keyRow("Toggle UI", "Shows / hides this window", function() return toggleKey end, function(k)
				Window:SetToggleKey(k)
			end)
			switchRow("Sounds", "Clicks when you move around", function() return Library.SoundsEnabled end, function(v)
				Library.SoundsEnabled = v
				saveSetting("Sounds", v)
			end)
			switchRow("Anti AFK", "Stops the idle kick", function() return antiAfkConn ~= nil end, function(v)
				setAntiAfk(v)
				saveSetting("AntiAfk", v)
			end)
		end },
		{ Name = "Screen and Video", Icon = Icons.Screen, Build = function()
			switchRow("Full Screen", "Covers the whole screen, like the console", function() return fullscreen end, function(v)
				Window:SetFullscreen(v)
			end)
			choiceRow("Window Size", "When not in full screen", { "Small", "Medium", "Large" }, function() return windowSize end, function(v)
				setWindowSize(v)
				saveSetting("WindowSize", v)
			end)
			if blur then
				switchRow("Blur Game", "Blurs the game behind the window", function() return blur.Enabled end, function(v)
					blur.Enabled = v
					saveSetting("Blur", v)
				end)
			end
			switchRow("Background Motion", "Light rays, waves and particles move", function() return Library.Motion end, function(v)
				Library.Motion = v
				saveSetting("Motion", v)
			end)
		end },
		{ Name = "Themes", Icon = Icons.Themes, Build = function()
			for _, th in ipairs(Themes) do
				local sw = th.Game and { Color3.fromRGB(255, 120, 120), Color3.fromRGB(90, 120, 255) } or { th.C1, th.C2 }
				makeRow({
					Name = th.Name,
					Desc = th.Game and "Every game tile gets its own colours" or nil,
					Swatch = sw,
					Kind = "radio",
					Get = function() return currentTheme == th end,
					OnClick = function() if currentTheme ~= th then setTheme(th) end end,
				})
			end
		end },
		{ Name = "Account", Icon = Icons.Account, Build = function()
			makeRow({ Name = "Signed in as", Kind = "value", Get = function()
				return Library.Anonymous and "Player" or (player.DisplayName ~= "" and player.DisplayName or player.Name)
			end })
			makeRow({ Name = "Membership", Kind = "value", Get = function()
				local u = env().GuiLibraryUser
				local tier = type(u) == "table" and u.Tier
				if isPremium then return "★ " .. tostring(tier or "Premium") end
				return tier and tostring(tier) or "Free"
			end })
			switchRow("Anonymous Mode", "Hides your picture and name", function() return Library.Anonymous end, function(v)
				Library:SetAnonymous(v)
			end)
			if type(settings.ChangeKey) == "function" then
				makeRow({ Name = "Change Key", Desc = "Sign in again with a different key", OnClick = function()
					closeSettings(true)
					task.spawn(settings.ChangeKey)
				end })
			end
			if type(settings.SignOut) == "function" then
				makeRow({ Name = "Sign Out", OnClick = function()
					closeSettings(true)
					task.spawn(settings.SignOut)
				end })
			end
		end },
		{ Name = "Saved Data", Icon = Icons.Data, Build = function()
			makeRow({ Name = "This script", Desc = canSave and filePath or (saveEnabled and "No file access here" or "Autosave is off"), Kind = "value",
				Get = function() return canSave and "Autosave on" or "Not saved" end })
			makeRow({ Name = "Shared settings", Desc = globalFiles and Library.GlobalSettingsFile or "No file access here", Kind = "value",
				Get = function() return globalFiles and "Saved" or "Not saved" end })
			if canSave then
				makeRow({ Name = "Save Now", OnClick = function()
					flush()
					Library:Notify({ Title = "Saved", Content = filePath, Duration = 2 })
				end })
			end
		end },
		{ Name = "Unload Script", Icon = Icons.Power, Danger = true, Click = function()
			if os.clock() - unloadArmed < 3 then
				Library:Unload()
			else
				unloadArmed = os.clock()
				Library:Notify({ Title = "Unload Script", Content = "Click again within 3 seconds to unload.", Duration = 3 })
			end
		end },
	}

	local currentCat
	local listToken = 0
	local function showList(cat, dir)
		listToken += 1
		local mine = listToken
		currentCat = cat
		local function fill()
			clearRows()
			if cat then
				cat.Build()
			else
				for _, c in ipairs(Categories) do
					makeRow({ Name = c.Name, Icon = c.Icon, Danger = c.Danger, OnClick = function()
						if c.Click then c.Click() else showList(c, 1) end
					end })
				end
			end
			setTitle.Text = cat and cat.Name or "Settings"
			setTitle.Position = UDim2.fromOffset(cat and PAD + 26 or PAD, 62)
			setBackBtn.Visible = cat ~= nil
		end
		if not dir then
			fill()
			listGroup.GroupTransparency = 0
			listGroup.Position = UDim2.new(0.5, 20, 0, 108)
			return
		end
		tween(listGroup, { GroupTransparency = 1, Position = UDim2.new(0.5, 20 - 40 * dir, 0, 108) }, 0.15, Enum.EasingStyle.Quad)
		task.delay(0.15, function()
			if mine ~= listToken then return end
			fill()
			listGroup.Position = UDim2.new(0.5, 20 + 40 * dir, 0, 108)
			tween(listGroup, { GroupTransparency = 0, Position = UDim2.new(0.5, 20, 0, 108) }, 0.35)
		end)
	end
	setBackBtn.MouseButton1Click:Connect(function()
		sfx("Select")
		showList(nil, -1)
	end)

	local setToken = 0
	openSettings = function()
		if settingsOpen then return end
		closeMenu()
		settingsOpen = true
		setToken += 1
		paintNav()
		showList(nil)
		-- the game tiles and the page step aside
		tween(row, { GroupTransparency = 1 }, 0.2)
		if selected then
			tween(selected.wrap, { GroupTransparency = 1, Position = UDim2.fromOffset(0, 30) }, 0.25, Enum.EasingStyle.Quad)
		end
		tween(scrollDim, { BackgroundTransparency = 1 }, 0.2)
		tween(topScrollShade, { BackgroundTransparency = 1 }, 0.2)
		local mine = setToken
		task.delay(0.25, function()
			if mine ~= setToken then return end
			row.Visible = false
			if selected then selected.wrap.Visible = false end
		end)
		boostRays = 0.6
		fx.paint()
		setView.Visible = true
		setView.GroupTransparency = 1
		listGroup.Position = UDim2.new(0.5, 20, 0, 140)
		tween(setView, { GroupTransparency = 0 }, 0.4)
		tween(listGroup, { Position = UDim2.new(0.5, 20, 0, 108) }, 0.5)
	end
	closeSettings = function(instant)
		if not settingsOpen then return end
		settingsOpen = false
		setToken += 1
		local mine = setToken
		paintNav()
		boostRays = 0
		fx.paint()
		tween(setView, { GroupTransparency = 1 }, instant and 0.15 or 0.25)
		task.delay(instant and 0.15 or 0.25, function()
			if mine == setToken then setView.Visible = false end
		end)
		row.Visible = true
		row.GroupTransparency = 1
		updateScrollFx()
		local k = row.GroupTransparency
		row.GroupTransparency = 1
		tween(row, { GroupTransparency = k }, 0.35)
		if selected and not instant then
			selected.wrap.Visible = true
			selected.wrap.Position = UDim2.fromOffset(0, 30)
			tween(selected.wrap, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.45)
			selected.intro()
		elseif selected then
			selected.wrap.Visible = true
			selected.wrap.GroupTransparency = 0
			selected.wrap.Position = UDim2.fromOffset(0, 0)
		end
	end
	-- Escape / Backspace: out of a category, then back to the games
	settingsBack = function()
		if currentCat then
			sfx("Select")
			showList(nil, -1)
		else
			closeSettings()
		end
	end
	navSettings.MouseButton1Click:Connect(function()
		sfx("Select")
		if settingsOpen then settingsBack() else openSettings() end
	end)
	for _, b in ipairs({ navGames, navSettings }) do
		b.MouseEnter:Connect(function() sfx("Move") end)
	end
	function Window:OpenSettings() openSettings() end
	function Window:CloseSettings() closeSettings() end

	-- no game tabs at all: open on Settings
	task.defer(function()
		if not selected then
			openSettings()
		end
	end)

	-- Boot animation, then the home screen zooms in
	local splashOpts = settings.Splash
	local g = env()
	if g.GuiLibrarySplashShown then
		g.GuiLibrarySplashShown = nil
		splashOpts = false
	end
	if settings.StartHidden then
		-- shown later with Window:SetVisible(true) (e.g. after signing in)
	elseif splashOpts == false then
		Window:SetVisible(true)
	else
		splashActive = true
		playSplash(type(splashOpts) == "table" and splashOpts or {}, windowName, function()
			splashActive = false
			Window:SetVisible(true)
		end)
	end

	return Window
end

----------------------------------------------------------------------
-- Loader: console-style sign-in
--	1. boot animation (optional, same as the window's)
--	2. "Welcome back" user screen - click your user to sign in
--	3. key screen (the passcode step) - Get Key / Sign In; skipped when a saved key already passed
--	4. home: your scripts as game tiles, info chips, big Load button, Change Key
--
-- Same options and methods as GuiLibrary's CreateLoader, so a loader can switch library:
--	Library:CreateLoader({
--		Name, Footer, Status = { Text, Color }, Info = { {label, value}, ... },
--		Options = { "Murder Mystery 2", "Universal" }, CurrentOption, ButtonText,
--		StartPage = "Key" | "Main",       -- where signing in goes ("Main" = saved key is fine)
--		Splash = { Image, Duration, Subtitle },
--		LoginText = "Choose your user to sign in",
--		Fullscreen = false,
--		OnLoad(option), OnSelect(option), OnRefresh(), OnClose(), OnShown(), OnStreamerMode(on),
--		Key = { Note, GetKeyLink, Check(key) -> ok, reason, OnGetKey(), OnSuccess(key), OnResetKey() },
--	})
--	Loader:SetInfo(label, value) / :SetStatus(text, color) / :SetOptions(list, current) / :SetOption(o)
--	Loader:GetOption() / :SetButton(text) / :SetStreamerMode(bool) / :ShowKey(message) / :ShowMain()
--	Loader:SetKeyStatus(text, isError) / :Close() / :Destroy()
----------------------------------------------------------------------

-- Pill button: primary = white with black text; secondary = dark, turns white when hovered
local function makePill(parent, label, primary, width, order)
	local slot = create("Frame", {
		Size = UDim2.fromOffset(width, 46),
		BackgroundTransparency = 1,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	local glow = softGlow(slot, 12, WHITE, 4, 4)
	local b = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = primary and 0 or 0.8,
		AutoButtonColor = false,
		Text = label,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextSize = 17,
		TextColor3 = primary and BLACK or WHITE,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = slot,
	})
	corner(b, 12)
	if not primary then stroke(b, WHITE, 1, 0.8) end
	local sc = create("UIScale", { Parent = slot })
	b.MouseEnter:Connect(function()
		sfx("Move")
		tween(sc, { Scale = 1.05 }, 0.25)
		glowTo(glow, 1)
		if not primary then
			tween(b, { BackgroundColor3 = WHITE, BackgroundTransparency = 0, TextColor3 = BLACK }, 0.15)
		end
	end)
	b.MouseLeave:Connect(function()
		tween(sc, { Scale = 1 }, 0.25)
		glowTo(glow, 0)
		if not primary then
			tween(b, { BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, TextColor3 = WHITE }, 0.15)
		end
	end)
	local function pop()
		sfx("Select")
		tween(sc, { Scale = 0.96 }, 0.08)
		task.delay(0.08, function() tween(sc, { Scale = 1.05 }, 0.3, Enum.EasingStyle.Back) end)
	end
	return b, pop, slot
end

function Library:CreateLoader(settings)
	settings = settings or {}
	if settings.Accent then Library.Accent = settings.Accent end
	if type(settings.Sounds) == "table" then
		for k, v in pairs(settings.Sounds) do
			Library.Sounds[k] = v
		end
	end
	local accent = Library.Accent
	local player = Players.LocalPlayer
	local hubName = settings.Name or "Hub"
	local kcfg = settings.Key or {}
	local hasKeyPage = settings.Key ~= nil
	local fullscreen = settings.Fullscreen == true
	-- where clicking your user goes: "Main" when a saved key already passed, else the key screen
	local afterLogin = settings.StartPage or (hasKeyPage and "Key" or "Main")

	local Loader = {}
	local conns = {}
	local function track(c)
		table.insert(conns, c)
		return c
	end

	------------------------------------------------------------------
	-- Root
	------------------------------------------------------------------
	local gui = create("ScreenGui", {
		Name = hubName .. "Loader",
		DisplayOrder = 2147483000,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Loader.Gui = gui
	local dim = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
	local holder = create("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(BASE_W, BASE_H),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local uiScale = create("UIScale", { Parent = holder })
	local outerGlow = softGlow(holder, 20, accent:Lerp(WHITE, 0.3), 6, 6)
	local screen = create("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(34, 96, 196),
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = holder,
	})
	corner(screen, fullscreen and 0 or 18)
	-- The gradient lives on its own frame: a UIGradient directly on a CanvasGroup tints
	-- EVERYTHING inside it (text, avatar...), which made the whole screen dark.
	local bgFrame = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = screen,
	})
	local bgGrad = create("UIGradient", {
		Rotation = 100,
		Color = ColorSequence.new({
			ck(0, Color3.fromRGB(86, 156, 240)),
			ck(0.5, Color3.fromRGB(34, 96, 196)),
			ck(1, Color3.fromRGB(14, 46, 120)),
		}),
		Parent = bgFrame,
	})

	-- soft light blobs + floating specks
	local blobs = {}
	for i = 1, 2 do
		local blob = create("Frame", {
			AnchorPoint = CENTER,
			Size = UDim2.fromScale(i == 1 and 1 or 0.7, i == 1 and 1 or 0.7),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			Parent = screen,
		})
		for j = 1, 7 do
			local f = create("Frame", {
				AnchorPoint = CENTER,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(j / 7, j / 7),
				BackgroundColor3 = Color3.fromRGB(200, 228, 255),
				BackgroundTransparency = 0.93,
				BorderSizePixel = 0,
				Parent = blob,
			})
			round(f)
		end
		blobs[i] = { frame = blob, ph = i * 2.1 }
	end
	local bokeh = {}
	for i = 1, 34 do
		local s = math.random(2, 7)
		local f = create("Frame", {
			AnchorPoint = CENTER,
			Size = UDim2.fromOffset(s, s),
			BackgroundColor3 = math.random() < 0.6 and WHITE or Color3.fromRGB(150, 200, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = screen,
		})
		round(f)
		bokeh[i] = {
			f = f,
			x = math.random(),
			y = math.random(),
			speed = 0.006 + math.random() * 0.02,
			alpha = 0.1 + math.random() * 0.35,
			tw = 0.6 + math.random() * 1.8,
			ph = math.random() * 6.28,
		}
	end

	------------------------------------------------------------------
	-- Top bar: name + status on the left, avatar (home only) / clock / close on the right
	------------------------------------------------------------------
	local topLeft = create("Frame", {
		Position = UDim2.fromOffset(PAD, 18),
		Size = UDim2.new(0.6, 0, 0, 26),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = screen,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = topLeft,
	})
	text(topLeft, {
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = hubName,
		FontFace = font(Enum.FontWeight.Bold),
		TextSize = 20,
		LayoutOrder = 1,
	})
	local statusDot = create("Frame", {
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		Parent = topLeft,
	})
	round(statusDot)
	local statusText = text(topLeft, {
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		TextSize = 14,
		TextColor3 = Col.Sub,
		LayoutOrder = 3,
	})
	function Loader:SetStatus(t, color)
		statusText.Text = t or ""
		statusDot.BackgroundColor3 = color or accent
		statusDot.Visible = (t or "") ~= ""
	end
	local st = settings.Status or {}
	Loader:SetStatus(st.Text or "Working", st.Color)

	local topRight = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD + 8, 0, 12),
		Size = UDim2.new(0.4, 0, 0, 36),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = screen,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 18),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = topRight,
	})
	local accountBtn = create("TextButton", {
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Col.Card,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		LayoutOrder = 1,
		Parent = topRight,
	})
	round(accountBtn)
	local accountRing = stroke(accountBtn, WHITE, 1.5, 0.6)
	local accountImg = create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		Parent = accountBtn,
	})
	round(accountImg)
	local clock = text(topRight, {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = os.date("%H:%M"),
		FontFace = font(Enum.FontWeight.Medium),
		TextSize = 19,
		LayoutOrder = 2,
	})
	local closeBtn = create("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = 3,
		Parent = topRight,
	})
	round(closeBtn)
	local closeLines = closeGlyph(closeBtn, 12, Col.Sub)
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, { BackgroundTransparency = 0.85 }, 0.15)
		for _, l in ipairs(closeLines) do tween(l, { BackgroundColor3 = WHITE }, 0.15) end
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, { BackgroundTransparency = 1 }, 0.15)
		for _, l in ipairs(closeLines) do tween(l, { BackgroundColor3 = Col.Sub }, 0.15) end
	end)
	accountBtn.MouseEnter:Connect(function() tween(accountRing, { Transparency = 0 }, 0.15) end)
	accountBtn.MouseLeave:Connect(function() tween(accountRing, { Transparency = 0.6 }, 0.15) end)

	if settings.Footer and settings.Footer ~= "" then
		text(screen, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, PAD, 1, -18),
			Size = UDim2.fromOffset(400, 18),
			Text = settings.Footer,
			TextSize = 13,
			TextColor3 = Col.Dim,
			ZIndex = 5,
		})
	end

	------------------------------------------------------------------
	-- Your user (name + picture, hidden in streamer / anonymous mode)
	------------------------------------------------------------------
	local streamer = Library.Anonymous or settings.StreamerMode == true
	local thumb = ""
	local avatars, names = {}, {}
	local function displayName()
		if streamer then return "Player" end
		return player.DisplayName ~= "" and player.DisplayName or player.Name
	end
	local function applyUser()
		for _, a in ipairs(avatars) do a.Image = streamer and "" or thumb end
		for _, n in ipairs(names) do n.Text = displayName() end
		accountImg.Image = streamer and "" or thumb
	end
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)
		if ok and img and gui.Parent then
			thumb = img
			applyUser()
		end
	end)

	------------------------------------------------------------------
	-- Pages (crossfade + slight zoom, like the console)
	------------------------------------------------------------------
	local pages = {}
	local currentName
	local function makePage(name)
		local group = create("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Visible = false,
			ZIndex = 2,
			Parent = screen,
		})
		local sc = create("UIScale", { Parent = group })
		local p = { group = group, scale = sc }
		pages[name] = p
		return p
	end

	-- Dialog: title, text, and a list of choices (hovered one turns white)
	local modal = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
		Parent = screen,
	})
	local scrim = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = modal,
	})
	local panel = create("CanvasGroup", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(400, 260),
		BackgroundColor3 = Col.Panel,
		BackgroundTransparency = 0.02,
		GroupTransparency = 1,
		BorderSizePixel = 0,
		Parent = modal,
	})
	corner(panel, 18)
	local panelScale = create("UIScale", { Parent = panel })
	local panelTitle = text(panel, {
		Position = UDim2.fromOffset(24, 18),
		Size = UDim2.new(1, -48, 0, 26),
		Text = "",
		FontFace = font(Enum.FontWeight.Bold),
		TextSize = 20,
	})
	local panelBody = text(panel, {
		Position = UDim2.fromOffset(24, 50),
		Size = UDim2.new(1, -48, 0, 40),
		Text = "",
		TextSize = 14,
		TextColor3 = Col.Sub,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local panelList = create("Frame", {
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = panel,
	})
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panelList })

	local dialogOpen, dialogToken = false, 0
	local function closeDialog()
		if not dialogOpen then return end
		dialogOpen = false
		dialogToken += 1
		local mine = dialogToken
		tween(modal, { BackgroundTransparency = 1 }, 0.2)
		tween(panel, { GroupTransparency = 1 }, 0.18)
		tween(panelScale, { Scale = 0.95 }, 0.2)
		task.delay(0.22, function()
			if mine == dialogToken then modal.Visible = false end
		end)
	end
	-- choices = { { "Label", function() end, danger = true }, ... }
	local function openDialog(title, body, choices)
		dialogToken += 1
		dialogOpen = true
		for _, c in ipairs(panelList:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		panelTitle.Text = title
		panelBody.Text = body or ""
		panelBody.Visible = body ~= nil
		local top = body and 98 or 58
		panelList.Position = UDim2.fromOffset(12, top)
		panel.Size = UDim2.fromOffset(400, top + #choices * 44 + 12)
		for i, ch in ipairs(choices) do
			local b = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = i,
				Parent = panelList,
			})
			corner(b, 10)
			local baseColor = ch.danger and Col.Error or WHITE
			local lbl = text(b, {
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(1, -32, 1, 0),
				Text = ch[1],
				FontFace = font(Enum.FontWeight.Medium),
				TextSize = 16,
				TextColor3 = baseColor,
			})
			b.MouseEnter:Connect(function()
				sfx("Move")
				tween(b, { BackgroundTransparency = 0 }, 0.12)
				tween(lbl, { TextColor3 = BLACK }, 0.12)
			end)
			b.MouseLeave:Connect(function()
				tween(b, { BackgroundTransparency = 1 }, 0.12)
				tween(lbl, { TextColor3 = baseColor }, 0.12)
			end)
			b.MouseButton1Click:Connect(function()
				sfx("Select")
				closeDialog()
				if ch[2] then task.spawn(ch[2]) end
			end)
		end
		modal.Visible = true
		modal.BackgroundTransparency = 1
		panel.GroupTransparency = 1
		panelScale.Scale = 1.06
		tween(modal, { BackgroundTransparency = 0.65 }, 0.25)
		tween(panel, { GroupTransparency = 0 }, 0.3)
		tween(panelScale, { Scale = 1 }, 0.35)
	end
	scrim.MouseButton1Click:Connect(closeDialog)

	local shownOnce = false
	local finished = false
	local shown -- made further down (show / hide)
	local function showPage(name)
		if name == "main" and settings.Home == false then
			-- no script picker: signing in finishes the loader and hands over to your hub
			if finished then return end
			finished = true
			sfx("Select")
			fire(settings.OnLoad)
			local tw = tween(shown, { Value = 0 }, 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tw.Completed:Connect(function() Loader:Destroy() end)
			return
		end
		local p = pages[name]
		if not p or currentName == name then return end
		closeDialog()
		local old = currentName and pages[currentName]
		currentName = name
		if old then
			tween(old.scale, { Scale = 0.97 }, 0.25)
			tween(old.group, { GroupTransparency = 1 }, 0.22, Enum.EasingStyle.Quad)
			task.delay(0.24, function()
				if pages[currentName] ~= old then old.group.Visible = false end
			end)
		end
		p.group.Visible = true
		p.group.GroupTransparency = 1
		p.scale.Scale = 1.03
		tween(p.group, { GroupTransparency = 0 }, 0.45)
		tween(p.scale, { Scale = 1 }, 0.5)
		accountBtn.Visible = name == "main"
		if p.onShow then p.onShow() end
		if name == "main" and not shownOnce then
			shownOnce = true
			fire(settings.OnShown) -- after signing in (the loader starts its auto-load countdown here)
		end
	end

	local function shake(target, base)
		task.spawn(function()
			for _, x in ipairs({ 10, -8, 6, -4, 2, 0 }) do
				target.Position = base + UDim2.fromOffset(x, 0)
				task.wait(0.035)
			end
		end)
	end

	------------------------------------------------------------------
	-- 1. User screen
	------------------------------------------------------------------
	local userPage = makePage("user")
	text(userPage.group, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.new(0.9, 0, 0, 42),
		Text = "Welcome back to " .. hubName,
		FontFace = font(Enum.FontWeight.Light),
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	text(userPage.group, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.new(0.9, 0, 0, 22),
		Text = settings.LoginText or "Choose your user to sign in",
		TextSize = 17,
		TextColor3 = Col.Sub,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local userWrap = create("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.new(0.5, 0, 0, 290),
		Size = UDim2.fromOffset(150, 150),
		BackgroundTransparency = 1,
		Parent = userPage.group,
	})
	local userScale = create("UIScale", { Parent = userWrap })
	local userGlow = softGlow(userWrap, 999, WHITE, 6, 5)
	local userAvatar = create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Col.Card,
		BorderSizePixel = 0,
		Image = "",
		Parent = userWrap,
	})
	round(userAvatar)
	table.insert(avatars, userAvatar)
	local userRingHolder = create("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 14, 1, 14),
		BackgroundTransparency = 1,
		Parent = userWrap,
	})
	round(userRingHolder)
	local userRing = stroke(userRingHolder, WHITE, 3, 0.6)
	local userHit = create("TextButton", {
		Size = UDim2.new(1, 20, 1, 80),
		Position = UDim2.fromOffset(-10, -10),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = userWrap,
	})
	local userName = text(userPage.group, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 384),
		Size = UDim2.new(0.6, 0, 0, 30),
		Text = "",
		FontFace = font(Enum.FontWeight.SemiBold),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	table.insert(names, userName)
	local userSub = text(userPage.group, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 416),
		Size = UDim2.new(0.6, 0, 0, 20),
		Text = "",
		TextSize = 15,
		TextColor3 = Col.Sub,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local function paintUserSub()
		if detectPremium() then
			userSub.Text = "★ Premium"
			userSub.TextColor3 = Col.Gold
		elseif afterLogin == "Main" then
			userSub.Text = "Key saved - you'll sign in straight away"
			userSub.TextColor3 = Col.Sub
		else
			userSub.Text = "You'll need a key to sign in"
			userSub.TextColor3 = Col.Sub
		end
	end

	-- streamer mode switch at the bottom
	local hideRow = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -44),
		Size = UDim2.fromOffset(200, 46),
		BackgroundTransparency = 1,
		Parent = userPage.group,
	})
	local hideBtn, hidePop = makePill(hideRow, "", false, 200)
	local function paintHide()
		hideBtn.Text = streamer and "Show my info" or "Hide my info"
	end

	local userHover = false
	userHit.MouseEnter:Connect(function()
		userHover = true
		sfx("Move")
		tween(userScale, { Scale = 1.06 }, 0.3)
		tween(userRing, { Transparency = 0 }, 0.2)
		glowTo(userGlow, 0.9, 0.3)
	end)
	userHit.MouseLeave:Connect(function()
		userHover = false
		tween(userScale, { Scale = 1 }, 0.3)
		tween(userRing, { Transparency = 0.6 }, 0.2)
		glowTo(userGlow, 0, 0.3)
	end)

	local signing = false
	local function signIn()
		if signing or currentName ~= "user" then return end
		signing = true
		sfx("Select")
		tween(userScale, { Scale = 1.14 }, 0.3, Enum.EasingStyle.Back)
		userRing.Transparency = 0
		glowTo(userGlow, 1.4, 0.2)
		local direct = afterLogin == "Main"
		if direct then
			userSub.Text = "Signing in..."
			userSub.TextColor3 = WHITE
		end
		task.delay(direct and 0.9 or 0.35, function()
			signing = false
			tween(userScale, { Scale = userHover and 1.06 or 1 }, 0.3)
			showPage(afterLogin == "Main" and "main" or "key")
		end)
	end
	userHit.MouseButton1Click:Connect(signIn)
	userPage.onShow = function()
		paintUserSub()
		userScale.Scale = 0.9
		tween(userScale, { Scale = userHover and 1.06 or 1 }, 0.6, Enum.EasingStyle.Back)
	end

	------------------------------------------------------------------
	-- 2. Key screen (the passcode step)
	------------------------------------------------------------------
	local keyPage = makePage("key")
	local backBtn = create("TextButton", {
		Position = UDim2.fromOffset(PAD - 8, 70),
		Size = UDim2.fromOffset(96, 34),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = keyPage.group,
	})
	corner(backBtn, 10)
	local backIcon = create("Frame", {
		Position = UDim2.fromOffset(8, 7),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Parent = backBtn,
	})
	chevron(backIcon, 12, WHITE, 180)
	local backLabel = text(backBtn, {
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -36, 1, 0),
		Text = "Back",
		FontFace = font(Enum.FontWeight.Medium),
		TextSize = 16,
	})
	backBtn.MouseEnter:Connect(function()
		tween(backBtn, { BackgroundTransparency = 0.88 }, 0.15)
	end)
	backBtn.MouseLeave:Connect(function()
		tween(backBtn, { BackgroundTransparency = 1 }, 0.15)
	end)
	backBtn.MouseButton1Click:Connect(function()
		sfx("Select")
		showPage("user")
	end)
	local keyAvatarWrap = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(84, 84),
		BackgroundTransparency = 1,
		Parent = keyPage.group,
	})
	local keyAvatar = create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Col.Card,
		BorderSizePixel = 0,
		Image = "",
		Parent = keyAvatarWrap,
	})
	round(keyAvatar)
	stroke(keyAvatar, WHITE, 2, 0.3)
	table.insert(avatars, keyAvatar)
	local keyName = text(keyPage.group, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 166),
		Size = UDim2.new(0.6, 0, 0, 24),
		Text = "",
		FontFace = font(Enum.FontWeight.SemiBold),
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	table.insert(names, keyName)
	text(keyPage.group, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 214),
		Size = UDim2.new(0.8, 0, 0, 34),
		Text = kcfg.Title or "Enter your key",
		FontFace = font(Enum.FontWeight.Light),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	text(keyPage.group, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 252),
		Size = UDim2.new(0.8, 0, 0, 20),
		Text = kcfg.Note or "Press Get Key, finish the steps, then paste your key here.",
		TextSize = 15,
		TextColor3 = Col.Sub,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local fieldPos = UDim2.new(0.5, -220, 0, 292)
	local fieldSlot = create("Frame", {
		Position = fieldPos,
		Size = UDim2.fromOffset(440, 54),
		BackgroundTransparency = 1,
		Parent = keyPage.group,
	})
	local fieldGlow = softGlow(fieldSlot, 14, WHITE, 4, 4)
	local field = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Parent = fieldSlot,
	})
	corner(field, 14)
	local fieldStroke = stroke(field, WHITE, 1.5, 0.75)
	local keyBox = create("TextBox", {
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -36, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = kcfg.Placeholder or "Paste your key",
		PlaceholderColor3 = Col.Dim,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = font(Enum.FontWeight.Medium),
		TextSize = 17,
		TextColor3 = WHITE,
		Parent = field,
	})
	local keyStatus = text(keyPage.group, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 356),
		Size = UDim2.new(0.8, 0, 0, 20),
		Text = "",
		TextSize = 14,
		TextColor3 = Col.Sub,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	function Loader:SetKeyStatus(t, isError)
		keyStatus.Text = t or ""
		keyStatus.TextColor3 = isError and Col.Error or Col.Sub
	end
	local keyButtons = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 394),
		Size = UDim2.fromOffset(354, 46),
		BackgroundTransparency = 1,
		Parent = keyPage.group,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = keyButtons,
	})
	local getKeyBtn, getKeyPop = makePill(keyButtons, kcfg.GetKeyText or "Get Key", false, 170, 1)
	local checkBtn, checkPop = makePill(keyButtons, kcfg.CheckText or "Sign In", true, 170, 2)

	keyBox.Focused:Connect(function()
		tween(fieldStroke, { Transparency = 0 }, 0.15)
		glowTo(fieldGlow, 0.8, 0.2)
	end)

	local checking = false
	local function checkNow()
		if checking then return end
		local key = keyBox.Text:match("^%s*(.-)%s*$")
		if key == "" then
			Loader:SetKeyStatus("Enter a key first.", true)
			shake(fieldSlot, fieldPos)
			return
		end
		local function success()
			Loader:SetKeyStatus("")
			afterLogin = "Main"
			showPage("main")
			fire(kcfg.OnSuccess, key)
		end
		if not kcfg.Check then
			success()
			return
		end
		checking = true
		checkBtn.Text = "Checking..."
		task.spawn(function()
			local ok, valid, reason = pcall(kcfg.Check, key)
			checking = false
			if not gui.Parent then return end
			checkBtn.Text = kcfg.CheckText or "Sign In"
			if ok and valid then
				success()
			else
				Loader:SetKeyStatus(ok and (reason or "Invalid key.") or ("Error: " .. tostring(valid)), true)
				shake(fieldSlot, fieldPos)
				sfx("Select")
			end
		end)
	end
	keyBox.FocusLost:Connect(function(enterPressed)
		tween(fieldStroke, { Transparency = 0.75 }, 0.15)
		glowTo(fieldGlow, 0, 0.2)
		if enterPressed then checkNow() end
	end)
	checkBtn.MouseButton1Click:Connect(function()
		checkPop()
		checkNow()
	end)
	getKeyBtn.MouseButton1Click:Connect(function()
		getKeyPop()
		local link = kcfg.GetKeyLink
		if link then
			if typeof(setclipboard) == "function" then
				pcall(setclipboard, link)
				Loader:SetKeyStatus("Key link copied, open it in your browser.")
			else
				Loader:SetKeyStatus(link)
			end
		end
		fire(kcfg.OnGetKey)
	end)
	keyPage.onShow = function()
		task.delay(0.3, function()
			if currentName == "key" and keyBox.Text == "" then
				pcall(function() keyBox:CaptureFocus() end)
			end
		end)
	end

	------------------------------------------------------------------
	-- 3. Home: scripts as tiles, info chips, Load + Change Key
	------------------------------------------------------------------
	local mainPage = makePage("main")
	local row = create("Frame", {
		Position = UDim2.fromOffset(0, ROW_Y - 14),
		Size = UDim2.new(1, 0, 0, TILE_BIG + 28),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = mainPage.group,
	})
	local tileName = text(row, {
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.fromOffset(300, TILE_BIG),
		Text = "",
		FontFace = font(Enum.FontWeight.SemiBold),
		TextSize = 20,
	})
	local heroTitle = text(mainPage.group, {
		Position = UDim2.fromOffset(PAD, PAGE_TOP + 4),
		Size = UDim2.new(1, -PAD * 2, 0, 58),
		Text = "",
		FontFace = font(Enum.FontWeight.Bold),
		TextSize = 50,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local infoRow = create("Frame", {
		Position = UDim2.fromOffset(PAD, PAGE_TOP + 70),
		Size = UDim2.new(1, -PAD * 2, 0, 34),
		BackgroundTransparency = 1,
		Parent = mainPage.group,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = infoRow,
	})
	local infoValues = {}
	for i, rowInfo in ipairs(settings.Info or {}) do
		local chip = create("Frame", {
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.82,
			LayoutOrder = i,
			Parent = infoRow,
		})
		corner(chip, 10)
		stroke(chip, WHITE, 1, 0.88)
		create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = chip })
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = chip,
		})
		text(chip, {
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = string.upper(tostring(rowInfo[1])),
			FontFace = font(Enum.FontWeight.Medium),
			TextSize = 11,
			TextColor3 = Col.Dim,
			LayoutOrder = 1,
		})
		infoValues[rowInfo[1]] = text(chip, {
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = tostring(rowInfo[2]),
			FontFace = font(Enum.FontWeight.SemiBold),
			TextSize = 14,
			LayoutOrder = 2,
		})
	end
	function Loader:SetInfo(label, value)
		local l = infoValues[label]
		if l then l.Text = tostring(value) end
	end

	local mainButtons = create("Frame", {
		Position = UDim2.fromOffset(PAD, PAGE_TOP + 124),
		Size = UDim2.new(1, -PAD * 2, 0, 46),
		BackgroundTransparency = 1,
		Parent = mainPage.group,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = mainButtons,
	})
	local loadBtn, loadPop, loadSlot = makePill(mainButtons, "", true, 220, 1)
	function Loader:SetButton(t)
		loadBtn.Text = tostring(t)
		loadSlot.Size = UDim2.fromOffset(math.clamp(estimateWidth(loadBtn.Text, 17) + 60, 200, 420), 46)
	end
	Loader:SetButton(settings.ButtonText or "Load Script")

	-- Change Key: asks first, then forgets the key and opens the key screen
	local function changeKey()
		openDialog("Change key?", "Your saved key will be removed and you'll need to enter a new one.", {
			{ "Change Key", function()
				keyBox.Text = ""
				afterLogin = "Key"
				Loader:SetKeyStatus("Key removed. Enter a new one.")
				showPage("key")
				fire(kcfg.OnResetKey)
			end, danger = true },
			{ "Cancel" },
		})
	end
	if hasKeyPage then
		local changeBtn, changePop = makePill(mainButtons, "Change Key", false, 160, 2)
		changeBtn.MouseButton1Click:Connect(function()
			changePop()
			changeKey()
		end)
	end

	local function applyStreamer()
		applyUser()
		paintHide()
	end
	local function setStreamer(v, quiet)
		streamer = v == true
		Library:SetAnonymous(streamer)
		applyStreamer()
		if not quiet then fire(settings.OnStreamerMode, streamer) end
	end
	function Loader:SetStreamerMode(v)
		setStreamer(v, true)
	end
	hideBtn.MouseButton1Click:Connect(function()
		hidePop()
		setStreamer(not streamer)
	end)

	accountBtn.MouseButton1Click:Connect(function()
		sfx("Select")
		local choices = {}
		if hasKeyPage then table.insert(choices, { "Change Key", changeKey }) end
		table.insert(choices, { streamer and "Show my info" or "Hide my info", function() setStreamer(not streamer) end })
		if settings.OnRefresh then
			table.insert(choices, { "Detect this game", function() fire(settings.OnRefresh) end })
		end
		table.insert(choices, { "Switch user", function() showPage("user") end })
		table.insert(choices, { "Cancel" })
		openDialog(displayName(), detectPremium() and "★ Premium" or nil, choices)
	end)

	-- Script tiles (same look and movement as the hub's game row)
	local options = settings.Options or {}
	local current = settings.CurrentOption or options[1]
	local tiles = {}
	local function layoutTiles(animated)
		local s = 1
		for i, t in ipairs(tiles) do
			if t.option == current then s = i end
		end
		local sel = tiles[s]
		if not sel then
			tileName.Text = ""
			heroTitle.Text = tostring(current or "")
			return
		end
		local prevVisible = math.min(s - 1, 2)
		local xSel = PAD + prevVisible * (TILE + TILE_GAP)
		local nameW = estimateWidth(sel.label, 20)
		local afterName = xSel + TILE_BIG + 18 + nameW + 28
		for i, t in ipairs(tiles) do
			local x, size
			if i < s then
				x, size = xSel - (s - i) * (TILE + TILE_GAP), TILE
			elseif i == s then
				x, size = xSel, TILE_BIG
			else
				x, size = afterName + (i - s - 1) * (TILE + TILE_GAP), TILE
			end
			local props = { Position = UDim2.fromOffset(x, 14), Size = UDim2.fromOffset(size, size) }
			local focused = i == s
			if animated then
				tween(t.tile, props, 0.4)
				tween(t.dim, { BackgroundTransparency = focused and 1 or 0.6 }, 0.25)
				tween(t.ring, { Transparency = focused and 0 or 1 }, 0.25)
			else
				t.tile.Position, t.tile.Size = props.Position, props.Size
				t.dim.BackgroundTransparency = focused and 1 or 0.6
				t.ring.Transparency = focused and 0 or 1
			end
		end
		tileName.Text = sel.label
		tileName.Size = UDim2.fromOffset(nameW + 10, TILE_BIG)
		local namePos = UDim2.fromOffset(xSel + TILE_BIG + 18, 14)
		heroTitle.Text = sel.label
		if animated then
			tileName.TextTransparency = 1
			tileName.Position = namePos + UDim2.fromOffset(18, 0)
			tween(tileName, { TextTransparency = 0, Position = namePos }, 0.45)
			heroTitle.TextTransparency = 1
			heroTitle.Position = UDim2.fromOffset(PAD + 30, PAGE_TOP + 4)
			tween(heroTitle, { TextTransparency = 0, Position = UDim2.fromOffset(PAD, PAGE_TOP + 4) }, 0.55)
		else
			tileName.Position = namePos
		end
	end
	local function choose(opt, userPicked)
		if opt == current then return end
		current = opt
		layoutTiles(true)
		if userPicked then
			sfx("Move")
			fire(settings.OnSelect, opt)
		end
	end
	local function buildTiles()
		for _, t in ipairs(tiles) do t.tile:Destroy() end
		tiles = {}
		for _, opt in ipairs(options) do
			local label = tostring(opt)
			local c1, c2 = colorsFor(label)
			local tile = create("TextButton", {
				Position = UDim2.fromOffset(BASE_W + 100, 14),
				Size = UDim2.fromOffset(TILE, TILE),
				BackgroundColor3 = WHITE,
				AutoButtonColor = false,
				Text = "",
				BorderSizePixel = 0,
				Parent = row,
			})
			corner(tile, 12)
			create("UIGradient", { Rotation = 45, Color = ColorSequence.new(c1, c2), Parent = tile })
			local lbl = text(tile, {
				Size = UDim2.fromScale(1, 1),
				Text = initials(label),
				FontFace = font(Enum.FontWeight.Bold),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			create("UIPadding", {
				PaddingTop = UDim.new(0.24, 0), PaddingBottom = UDim.new(0.24, 0),
				PaddingLeft = UDim.new(0.14, 0), PaddingRight = UDim.new(0.14, 0),
				Parent = lbl,
			})
			local dimFrame = create("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = BLACK,
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				Parent = tile,
			})
			corner(dimFrame, 12)
			local ringFrame = create("Frame", {
				AnchorPoint = CENTER,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 10, 1, 10),
				BackgroundTransparency = 1,
				Parent = tile,
			})
			corner(ringFrame, 16)
			local ring = stroke(ringFrame, WHITE, 2.5, 1)
			local sc = create("UIScale", { Parent = tile })
			local t = { tile = tile, dim = dimFrame, ring = ring, option = opt, label = label }
			tile.MouseEnter:Connect(function()
				if current ~= opt then
					tween(dimFrame, { BackgroundTransparency = 0.1 }, 0.15)
					tween(sc, { Scale = 1.06 }, 0.2)
				end
			end)
			tile.MouseLeave:Connect(function()
				tween(dimFrame, { BackgroundTransparency = current == opt and 1 or 0.6 }, 0.15)
				tween(sc, { Scale = 1 }, 0.2)
			end)
			tile.MouseButton1Click:Connect(function()
				tween(sc, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
				choose(opt, true)
			end)
			table.insert(tiles, t)
		end
		layoutTiles(false)
	end
	buildTiles()

	function Loader:SetOptions(list, cur)
		options = list or {}
		current = cur or options[1]
		buildTiles()
	end
	function Loader:SetOption(opt)
		if opt == current then return end
		current = opt
		layoutTiles(true)
	end
	function Loader:GetOption()
		return current
	end

	loadBtn.MouseButton1Click:Connect(function()
		loadPop()
		fire(settings.OnLoad, current)
	end)
	mainPage.onShow = function()
		heroTitle.TextTransparency = 1
		heroTitle.Position = UDim2.fromOffset(PAD + 30, PAGE_TOP + 4)
		tween(heroTitle, { TextTransparency = 0, Position = UDim2.fromOffset(PAD, PAGE_TOP + 4) }, 0.6)
		mainButtons.Position = UDim2.fromOffset(PAD, PAGE_TOP + 140)
		tween(mainButtons, { Position = UDim2.fromOffset(PAD, PAGE_TOP + 124) }, 0.6)
	end

	function Loader:ShowMain()
		afterLogin = "Main"
		paintUserSub()
		if currentName ~= "user" then showPage("main") end
	end
	function Loader:ShowKey(message)
		afterLogin = "Key"
		paintUserSub()
		if message then Loader:SetKeyStatus(message, true) end
		if currentName ~= "user" then showPage("key") end
	end

	applyStreamer()

	------------------------------------------------------------------
	-- Keys: Enter signs in, Left / Right pick a script, Escape goes back / closes the dialog
	------------------------------------------------------------------
	track(UserInputService.InputBegan:Connect(function(input, processed)
		local kc = input.KeyCode
		if dialogOpen and (kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.ButtonB) then
			closeDialog()
			return
		end
		if processed or UserInputService:GetFocusedTextBox() then return end
		if currentName == "user" and (kc == Enum.KeyCode.Return or kc == Enum.KeyCode.ButtonA) then
			signIn()
		elseif currentName == "key" and (kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.ButtonB) then
			showPage("user")
		elseif currentName == "main" and not dialogOpen and #tiles > 0 then
			local i = 1
			for n, t in ipairs(tiles) do
				if t.option == current then i = n end
			end
			if kc == Enum.KeyCode.Left or kc == Enum.KeyCode.DPadLeft then
				choose(tiles[math.max(i - 1, 1)].option, true)
			elseif kc == Enum.KeyCode.Right or kc == Enum.KeyCode.DPadRight then
				choose(tiles[math.min(i + 1, #tiles)].option, true)
			end
		end
	end))

	------------------------------------------------------------------
	-- Show / hide, per-frame motion
	------------------------------------------------------------------
	shown = num(0)
	local baseScale = 1
	local function applyShown()
		local v = shown.Value
		uiScale.Scale = baseScale * (1.045 - 0.045 * v)
		screen.GroupTransparency = 1 - v
		dim.BackgroundTransparency = 1 - (fullscreen and 0 or 0.25) * v
		glowSet(outerGlow, fullscreen and 0 or v * 0.6)
	end
	local function layoutHolder()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		if fullscreen then
			baseScale = vp.Y / BASE_H
			holder.Size = UDim2.fromOffset(math.ceil(vp.X / baseScale), BASE_H)
		else
			baseScale = math.min(settings.Scale or 1, (vp.X - 40) / BASE_W, (vp.Y - 40) / BASE_H)
		end
		applyShown()
	end
	shown.Changed:Connect(applyShown)
	layoutHolder()
	if workspace.CurrentCamera then
		track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutHolder))
	end

	local t0 = os.clock()
	local lastSecond = 0
	track(RunService.RenderStepped:Connect(function(dt)
		if shown.Value <= 0 then return end
		local t = os.clock() - t0
		bgGrad.Rotation = 100 + math.sin(t * 0.1) * 10
		blobs[1].frame.Position = UDim2.fromScale(0.76 + math.sin(t * 0.13 + blobs[1].ph) * 0.08, 0.3 + math.cos(t * 0.11) * 0.1)
		blobs[2].frame.Position = UDim2.fromScale(0.24 + math.sin(t * 0.09 + blobs[2].ph) * 0.1, 0.82 + math.cos(t * 0.15) * 0.08)
		for _, b in ipairs(bokeh) do
			b.y -= b.speed * dt
			if b.y < -0.05 then
				b.y = 1.05
				b.x = math.random()
			end
			b.f.Position = UDim2.fromScale(b.x + math.sin(t * 0.3 + b.ph) * 0.01, b.y)
			b.f.BackgroundTransparency = 1 - b.alpha * (0.5 + 0.5 * math.sin(t * b.tw + b.ph))
		end
		-- the user ring breathes while it waits for you
		if currentName == "user" and not userHover and not signing then
			userRing.Transparency = 0.35 + 0.3 * (0.5 + 0.5 * math.sin(t * 2.4))
			glowSet(userGlow, 0.25 + 0.25 * math.sin(t * 2.4))
		end
		if t - lastSecond > 1 then
			lastSecond = t
			clock.Text = os.date("%H:%M")
		end
	end))

	function Loader:Destroy()
		if gui.Parent then gui:Destroy() end
	end
	function Loader:Close()
		-- closed without loading anything: the next window may play its own boot animation again
		env().GuiLibrarySplashShown = nil
		local tw = tween(shown, { Value = 0 }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw.Completed:Connect(function() Loader:Destroy() end)
	end
	closeBtn.MouseButton1Click:Connect(function()
		sfx("Select")
		Loader:Close()
		fire(settings.OnClose)
	end)
	gui.Destroying:Connect(function()
		for _, c in ipairs(conns) do c:Disconnect() end
		shown:Destroy()
	end)

	-- Start on the user screen (or StartScreen = "key"): boot animation first (if asked), then zoom in
	showPage(settings.StartScreen == "key" and hasKeyPage and "key" or "user")
	local function reveal()
		if gui.Parent then
			tween(shown, { Value = 1 }, 0.6, Enum.EasingStyle.Quint)
		end
	end
	if type(settings.Splash) == "table" then
		env().GuiLibrarySplashShown = true -- the script the loader starts skips its own boot animation
		local opts = {}
		for k, v in pairs(settings.Splash) do opts[k] = v end
		opts.Welcome = false -- this sign-in screen is the welcome screen
		playSplash(opts, hubName, reveal)
	else
		reveal()
	end

	return Loader
end

return Library
