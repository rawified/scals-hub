--[[
	Rayfield/Sirius-style GUI library (self-contained)
	Put this in a ModuleScript named GuiLibrary and require() it (see Example.lua),
	or paste your own code at the bottom, above `return Library`, to use it as one LocalScript.

	WINDOW
		Library:CreateWindow({
			Name = "My Hub",
			ToggleKey = Enum.KeyCode.RightShift,
			Theme = "Dark",                -- Dark | Light | Ocean | Rose | Forest | Monochrome
			InfoBar = true,                -- ping / fps / time bar, top right
			ConfigurationSaving = {        -- autosave (on by default)
				Enabled = true,
				FolderName = "MyHub",
				FileName = "Settings",
			},
		})
		Window:CreateTab("Name")
		Window:Toggle() / :SetVisible(bool) / :SetToggleKey(KeyCode) / :SetInfoBar(bool)

	SPLASH SCREEN (plays on start, any key or click skips it)
		Library:CreateWindow({ ..., Splash = { Image = "rbxassetid://123", Duration = 4.5, Subtitle = "..." } })
		Splash = false turns it off. Image can also be a file name in your executor's workspace
		folder. With no image, the window name is shown in big letters instead.

	ELEMENTS (every one accepts an optional Flag = "SaveName")
		Tab:CreateButton({Name, Callback})
		Tab:CreateToggle({Name, CurrentValue, Callback(value), Loop = function() end, Interval = 0.1})
		Tab:CreateSlider({Name, Range = {min, max}, Increment, Suffix, CurrentValue, Callback(value)})
		Tab:CreateInput({Name, PlaceholderText, RemoveTextAfterFocusLost, Callback(text)})
		Tab:CreateDropdown({Name, Options, CurrentOption, Callback(option)})
		Tab:CreateKeybind({Name, CurrentKeybind, Callback(key), Changed(key)})
		Tab:CreateLabel("text")

	Toggle Loop: while the toggle is ON, Loop runs over and over (every Interval seconds,
	default 0.1) until it is switched OFF. Callback still fires once per change.

	AUTOSAVE: every element's value is saved to a JSON file whenever it changes and is
	restored (callbacks included) the next time the script runs. Without a Flag, the save
	key is "<Tab name>/<Element name>". Saving needs file access (writefile/readfile);
	where that doesn't exist, the Settings tab says so and everything else keeps working.

	Library:SetTheme(name) / Library:Notify({Title, Content, Duration})
	Library:SetFont("Default" | "Modern" | "Clean" | "Techno" | "Gothic" | "Elegant" | "Retro" | "Rounded")
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local Library = {}

----------------------------------------------------------------------
-- Look & feel (tweak these)
----------------------------------------------------------------------
local Alpha = 0.06           -- window see-through amount (0 = solid)
local BackdropAlpha = 0.5    -- dark screen behind the window (1 = invisible)
local SprinkleCount = 130     -- floating specks on the background (0 = off)
local GlowEnabled = true     -- soft accent glow + moving shine behind the window

----------------------------------------------------------------------
-- Fonts
----------------------------------------------------------------------
-- Pick one in Settings > Font, or call Library:SetFont("Gothic").
-- Each preset fills four roles; add your own presets below if you like.
local function font(name, fallback)
	local ok, f = pcall(function() return Enum.Font[name] end)
	return (ok and f) or fallback
end
local function preset(title, heading, body, light)
	return {
		Title = font(title, Enum.Font.GothamBold),
		Heading = font(heading, Enum.Font.GothamBold),
		Body = font(body, Enum.Font.GothamMedium),
		Light = font(light, Enum.Font.Gotham),
	}
end
local FontPresets = {
	Default = preset("Oswald", "GothamBold", "GothamMedium", "Gotham"),
	Modern = preset("GothamBold", "GothamBold", "GothamMedium", "Gotham"),
	Clean = preset("BuilderSansExtraBold", "BuilderSansBold", "BuilderSansMedium", "BuilderSans"),
	Techno = preset("Michroma", "Jura", "Jura", "Jura"),
	Gothic = preset("GrenzeGotisch", "Oswald", "GothamMedium", "Gotham"),
	Elegant = preset("Merriweather", "GothamBold", "Nunito", "Nunito"),
	Retro = preset("Arcade", "Code", "Code", "Code"),
	Rounded = preset("FredokaOne", "Nunito", "Nunito", "Nunito"),
}
local FontOrder = { "Default", "Modern", "Clean", "Techno", "Gothic", "Elegant", "Retro", "Rounded" }

-- Title = window/notification titles, Heading = values and buttons, Body = labels and tabs,
-- Light = inputs and dropdown options, Mono = info bar (stays monospaced so it doesn't jitter)
local Fonts = { Mono = Enum.Font.RobotoMono }
for k, v in pairs(FontPresets.Default) do
	Fonts[k] = v
end
Library.CurrentFont = "Default"

local fontBound = {} -- { instance, role }
local function bindFont(inst, role)
	inst.Font = Fonts[role]
	table.insert(fontBound, { inst, role })
end

function Library:SetFont(name)
	local p = FontPresets[name]
	if not p then return end
	for k, v in pairs(p) do
		Fonts[k] = v
	end
	Library.CurrentFont = name
	for i = #fontBound, 1, -1 do
		local b = fontBound[i]
		if b[1]:IsDescendantOf(game) then
			b[1].Font = Fonts[b[2]]
		else
			table.remove(fontBound, i)
		end
	end
end

----------------------------------------------------------------------
-- Themes
----------------------------------------------------------------------
local Themes = {
	Dark = {
		Background = Color3.fromRGB(25, 25, 30),
		Topbar = Color3.fromRGB(35, 35, 42),
		Element = Color3.fromRGB(40, 40, 48),
		ElementHover = Color3.fromRGB(54, 54, 64),
		Accent = Color3.fromRGB(90, 120, 255),
		Text = Color3.fromRGB(240, 240, 245),
		SubText = Color3.fromRGB(160, 160, 170),
		Stroke = Color3.fromRGB(66, 66, 78),
	},
	Light = {
		Background = Color3.fromRGB(240, 240, 245),
		Topbar = Color3.fromRGB(225, 225, 232),
		Element = Color3.fromRGB(255, 255, 255),
		ElementHover = Color3.fromRGB(235, 235, 243),
		Accent = Color3.fromRGB(70, 100, 240),
		Text = Color3.fromRGB(30, 30, 38),
		SubText = Color3.fromRGB(105, 105, 120),
		Stroke = Color3.fromRGB(208, 208, 218),
	},
	Ocean = {
		Background = Color3.fromRGB(12, 25, 38),
		Topbar = Color3.fromRGB(18, 38, 58),
		Element = Color3.fromRGB(24, 48, 72),
		ElementHover = Color3.fromRGB(34, 64, 94),
		Accent = Color3.fromRGB(0, 170, 220),
		Text = Color3.fromRGB(230, 244, 252),
		SubText = Color3.fromRGB(140, 170, 190),
		Stroke = Color3.fromRGB(44, 82, 118),
	},
	Rose = {
		Background = Color3.fromRGB(32, 20, 26),
		Topbar = Color3.fromRGB(46, 28, 36),
		Element = Color3.fromRGB(56, 34, 44),
		ElementHover = Color3.fromRGB(74, 46, 58),
		Accent = Color3.fromRGB(235, 90, 140),
		Text = Color3.fromRGB(250, 235, 240),
		SubText = Color3.fromRGB(190, 150, 165),
		Stroke = Color3.fromRGB(100, 62, 80),
	},
	Forest = {
		Background = Color3.fromRGB(18, 28, 22),
		Topbar = Color3.fromRGB(26, 40, 32),
		Element = Color3.fromRGB(32, 50, 40),
		ElementHover = Color3.fromRGB(44, 68, 54),
		Accent = Color3.fromRGB(70, 200, 120),
		Text = Color3.fromRGB(232, 248, 238),
		SubText = Color3.fromRGB(150, 180, 162),
		Stroke = Color3.fromRGB(60, 94, 74),
	},
	Monochrome = {
		Background = Color3.fromRGB(12, 12, 12),
		Topbar = Color3.fromRGB(20, 20, 20),
		Element = Color3.fromRGB(27, 27, 27),
		ElementHover = Color3.fromRGB(42, 42, 42),
		Accent = Color3.fromRGB(240, 240, 240),
		Text = Color3.fromRGB(245, 245, 245),
		SubText = Color3.fromRGB(135, 135, 135),
		Stroke = Color3.fromRGB(62, 62, 62),
		Knob = Color3.fromRGB(12, 12, 12), -- dark knob on the white "on" track
	},
}
local ThemeOrder = { "Dark", "Light", "Ocean", "Rose", "Forest", "Monochrome" }

for _, t in pairs(Themes) do
	t.Knob = t.Knob or Color3.new(1, 1, 1)
end

local Theme = {}
for k, v in pairs(Themes.Dark) do
	Theme[k] = v
end
Library.CurrentTheme = "Dark"

-- Live theme registry
local bound = {}     -- { instance, property, themeKey }
local listeners = {} -- { owner = instance, fn = function }

local function bind(inst, prop, key)
	inst[prop] = Theme[key]
	table.insert(bound, { inst, prop, key })
end

local function onTheme(owner, fn)
	table.insert(listeners, { owner = owner, fn = fn })
end

function Library:SetTheme(name)
	local t = Themes[name]
	if not t then return end
	for k, v in pairs(t) do
		Theme[k] = v
	end
	Library.CurrentTheme = name

	for i = #bound, 1, -1 do
		local b = bound[i]
		if b[1]:IsDescendantOf(game) then
			b[1][b[2]] = Theme[b[3]]
		else
			table.remove(bound, i)
		end
	end
	for i = #listeners, 1, -1 do
		local l = listeners[i]
		if l.owner:IsDescendantOf(game) then
			l.fn()
		else
			table.remove(listeners, i)
		end
	end
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
-- props.Bind = { Property = "ThemeKey" } keeps that property in sync with the theme.
local function create(class, props)
	local inst = Instance.new(class)
	local parent = props.Parent
	local binds = props.Bind
	local fontRole = props.FontRole
	props.Parent = nil
	props.Bind = nil
	props.FontRole = nil
	for k, v in pairs(props) do
		inst[k] = v
	end
	if binds then
		for prop, key in pairs(binds) do
			bind(inst, prop, key)
		end
	end
	if fontRole then
		bindFont(inst, fontRole)
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

-- 1px inner border. Drawn as an inset frame whose stroke lands on the outermost pixel row,
-- so it also works inside CanvasGroups (which would clip a stroke drawn outside).
-- Never parent this to something that has a layout object.
local function hairline(parent, radius, transparency)
	local f = create("Frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	corner(f, math.max(radius - 1, 0))
	create("UIStroke", {
		Thickness = 1,
		Transparency = transparency or 0.45,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Bind = { Color = "Stroke" },
		Parent = f,
	})
	return f
end

local function tween(inst, props, time, style, dir)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function hover(button, target)
	button.MouseEnter:Connect(function() tween(target, { BackgroundColor3 = Theme.ElementHover }) end)
	button.MouseLeave:Connect(function() tween(target, { BackgroundColor3 = Theme.Element }) end)
end

local function fire(callback, ...)
	if callback then
		task.spawn(callback, ...)
	end
end

local function newElement(page, height)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, height or 34),
		BackgroundTransparency = Alpha,
		BorderSizePixel = 0,
		Bind = { BackgroundColor3 = "Element" },
		Parent = page,
	})
	corner(frame, 10)
	hairline(frame, 10)
	return frame
end

local function label(parent, text, size, colorKey, align)
	return create("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		FontRole = "Body",
		TextSize = size or 14,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Bind = { TextColor3 = colorKey or "Text" },
		Parent = parent,
	})
end

-- Where the pointer is inside a container (falls back to the center on touch devices)
local function pointerIn(container)
	local size = container.AbsoluteSize
	if UserInputService.MouseEnabled then
		local rel = UserInputService:GetMouseLocation() - container.AbsolutePosition
		return Vector2.new(math.clamp(rel.X, 0, size.X), math.clamp(rel.Y, 0, size.Y))
	end
	return size / 2
end

-- Expanding circle that fades out; the container (a CanvasGroup) clips it to its rounded shape
local function ripple(container, rel)
	local d = math.max(container.AbsoluteSize.X, container.AbsoluteSize.Y) * 2.4
	local circle = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(rel.X, rel.Y),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = container,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = circle })
	tween(circle, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 }, 0.55)
	task.delay(0.6, function()
		circle:Destroy()
	end)
end

local function getPing()
	local ok, v = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and type(v) == "number" then
		return v
	end
	local ok2, p = pcall(function()
		return Players.LocalPlayer:GetNetworkPing() * 2000
	end)
	return ok2 and p or 0
end

-- True while any keybind button is waiting for a key, so other key handlers stay quiet.
local listeningForKey = false

----------------------------------------------------------------------
-- Notifications (slide + fade in, fade out)
----------------------------------------------------------------------
local notifyGui, notifyHolder

function Library:Notify(settings)
	settings = settings or {}
	if not notifyGui or not notifyGui.Parent then
		notifyGui = create("ScreenGui", {
			Name = "Notifications",
			DisplayOrder = 2147483100,
			ResetOnSpawn = false,
			Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		})
		notifyHolder = create("Frame", {
			Size = UDim2.new(0, 260, 1, -20),
			Position = UDim2.new(1, -270, 0, 10),
			BackgroundTransparency = 1,
			Parent = notifyGui,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Parent = notifyHolder,
		})
	end

	-- The wrapper holds the layout slot; the card inside is what slides and fades
	local wrapper = create("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = 1,
		Parent = notifyHolder,
	})
	local card = create("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(40, 0),
		GroupTransparency = 1,
		BackgroundTransparency = Alpha,
		BorderSizePixel = 0,
		Bind = { BackgroundColor3 = "Topbar" },
		Parent = wrapper,
	})
	corner(card, 12)
	hairline(card, 12)

	local stripe = create("Frame", {
		Size = UDim2.new(0, 3, 1, -18),
		Position = UDim2.fromOffset(8, 9),
		BorderSizePixel = 0,
		Bind = { BackgroundColor3 = "Accent" },
		Parent = card,
	})
	corner(stripe, 2)

	local title = label(card, string.upper(settings.Title or "Notification"), 16)
	title.Size = UDim2.new(1, -30, 0, 22)
	title.Position = UDim2.fromOffset(20, 5)
	bindFont(title, "Title")
	local body = label(card, settings.Content or "", 12, "SubText")
	body.Size = UDim2.new(1, -30, 0, 26)
	body.Position = UDim2.fromOffset(20, 28)
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top

	tween(card, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, 0.4, Enum.EasingStyle.Quint)

	task.delay(settings.Duration or 4, function()
		if not wrapper.Parent then return end
		local t = tween(card, { Position = UDim2.fromOffset(40, 0), GroupTransparency = 1 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		t.Completed:Connect(function()
			wrapper:Destroy()
		end)
	end)
end

----------------------------------------------------------------------
-- Splash screen
----------------------------------------------------------------------
-- Accepts "rbxassetid://123", a bare asset id, or a file name in the executor's workspace
-- folder (needs getcustomasset). Returns nil when nothing usable is given.
local function resolveImage(img)
	if type(img) == "number" then
		return "rbxassetid://" .. tostring(img)
	end
	if type(img) ~= "string" or img == "" then
		return nil
	end
	if img:find("^rbxassetid://") or img:find("^rbxasset://") then
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

local function playSplash(opts, windowName, onReveal)
	local revealed = false
	local function reveal()
		if not revealed then
			revealed = true
			onReveal()
		end
	end

	local image = resolveImage(opts.Image or Library.SplashImage)
	local duration = math.max(opts.Duration or 4.5, 2.5)
	local logoName = string.upper(windowName or "Window")

	local gui, loopConn, skipConn
	local function cleanup()
		if loopConn then
			loopConn:Disconnect()
			loopConn = nil
		end
		if skipConn then
			skipConn:Disconnect()
			skipConn = nil
		end
		if gui then
			gui:Destroy()
			gui = nil
		end
	end

	task.defer(function()
		local ok, err = pcall(function()
			local accent = Theme.Accent
			local accentLight = accent:Lerp(Color3.new(1, 1, 1), 0.55)
			local white = Color3.new(1, 1, 1)
			local rand = math.random
			local kp = NumberSequenceKeypoint.new

			gui = create("ScreenGui", {
				Name = "Splash",
				ResetOnSpawn = false,
				IgnoreGuiInset = true,
				DisplayOrder = 2147483647,
				ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
				Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
			})
			local root = create("CanvasGroup", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				Parent = gui,
			})

			-- Animated values (tweened, read every frame)
			local function num(v)
				local n = Instance.new("NumberValue")
				n.Value = v
				return n
			end
			local function tnum(n, target, time, style, dir)
				return tween(n, { Value = target }, time, style, dir)
			end
			local logoAmt, glowAmt, partAmt, glitch, prog = num(0), num(0), num(0), num(0), num(0)

			----------------------------------------------------------
			-- Frame lines (grow out from the center)
			----------------------------------------------------------
			local function accentLine(y)
				local line = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, y),
					Size = UDim2.new(0, 0, 0, 1),
					BackgroundColor3 = accent,
					BorderSizePixel = 0,
					Parent = root,
				})
				create("UIGradient", {
					Transparency = NumberSequence.new({ kp(0, 1), kp(0.2, 0.15), kp(0.8, 0.15), kp(1, 1) }),
					Parent = line,
				})
				return line
			end
			local lineTop, lineBottom = accentLine(0.1), accentLine(0.9)

			----------------------------------------------------------
			-- Rising embers + horizontal speed streaks
			----------------------------------------------------------
			local particleLayer = create("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Parent = root,
			})
			local particles = {}
			for i = 1, 110 do
				local size = rand(2, 6)
				local fr = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(size, size),
					BackgroundColor3 = (i % 3 == 0) and accent or white,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = particleLayer,
				})
				create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fr })
				particles[i] = {
					frame = fr,
					x = rand(),
					y = rand(),
					speed = 0.02 + rand() * 0.09,
					drift = 0.3 + rand() * 0.9,
					phase = rand() * math.pi * 2,
					twinkle = 1 + rand() * 2.5,
					alpha = 0.35 + rand() * 0.55,
				}
			end

			local streakLayer = create("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Parent = root,
			})
			local streaks = {}
			for i = 1, 14 do
				local dirn = (i % 2 == 0) and 1 or -1
				local fr = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(rand(90, 280), rand(1, 2)),
					BackgroundColor3 = (i % 3 == 0) and accent or white,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = streakLayer,
				})
				create("UIGradient", {
					Transparency = NumberSequence.new({ kp(0, 1), kp(0.5, 0), kp(1, 1) }),
					Parent = fr,
				})
				streaks[i] = {
					frame = fr,
					x = rand(),
					y = 0.05 + rand() * 0.9,
					speed = (0.25 + rand() * 0.7) * dirn,
					alpha = 0.25 + rand() * 0.4,
				}
			end

			----------------------------------------------------------
			-- Stage: glow, spinning rings and the logo
			----------------------------------------------------------
			local stage = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.46),
				Size = UDim2.fromScale(0.6, 0.6),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundTransparency = 1,
				Parent = root,
			})

			local glow = {}
			for i = 1, 8 do
				local s = 0.28 + i * 0.09
				local fr = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(s, s),
					BackgroundColor3 = accent,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = stage,
				})
				create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fr })
				glow[i] = { frame = fr, base = 0.915 + i * 0.0105 }
			end

			local rings = {}
			local function ring(scale, thickness, speed)
				local fr = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(scale, scale),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = stage,
				})
				create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fr })
				local stroke = create("UIStroke", {
					Thickness = thickness,
					Color = accent,
					Transparency = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Parent = fr,
				})
				local grad = create("UIGradient", {
					Transparency = NumberSequence.new({
						kp(0, 0), kp(0.2, 0), kp(0.28, 1), kp(0.5, 1),
						kp(0.58, 0), kp(0.75, 0), kp(0.83, 1), kp(1, 1),
					}),
					Parent = stroke,
				})
				table.insert(rings, { stroke = stroke, grad = grad, speed = speed })
			end
			ring(0.98, 2, 70)
			ring(0.84, 1, -45)

			-- Logo: the picture if one was given, otherwise the window name in big letters
			local logoBox = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = image and UDim2.fromScale(0.86, 0.86) or UDim2.fromScale(1.6, 0.34),
				BackgroundTransparency = 1,
				Parent = stage,
			})
			local logoScale = create("UIScale", { Scale = 1.12, Parent = logoBox })

			local colorProp = image and "ImageColor3" or "TextColor3"
			local function piece(color)
				local obj
				if image then
					obj = create("ImageLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = image,
						ScaleType = Enum.ScaleType.Fit,
						ImageColor3 = color,
						ImageTransparency = 1,
						Parent = logoBox,
					})
				else
					obj = create("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = logoName,
						FontRole = "Title",
						TextScaled = true,
						TextColor3 = color,
						TextTransparency = 1,
						Parent = logoBox,
					})
				end
				return obj
			end
			local function setT(obj, a)
				if image then
					obj.ImageTransparency = a
				else
					obj.TextTransparency = a
				end
			end

			local ghostR = piece(Color3.fromRGB(255, 45, 70))
			local ghostC = piece(Color3.fromRGB(40, 230, 255))
			local logo = piece(Color3.fromRGB(205, 205, 212))
			local shinePiece = piece(white)
			local shineGrad = create("UIGradient", {
				Rotation = 20,
				Offset = Vector2.new(-1, 0),
				Transparency = NumberSequence.new({ kp(0, 1), kp(0.4, 1), kp(0.5, 0), kp(0.6, 1), kp(1, 1) }),
				Parent = shinePiece,
			})
			setT(shinePiece, 0)

			if opts.Subtitle then
				local sub = create("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.92),
					Size = UDim2.fromScale(1, 0.06),
					BackgroundTransparency = 1,
					Text = string.upper(opts.Subtitle),
					FontRole = "Title",
					TextScaled = true,
					TextColor3 = accentLight,
					TextTransparency = 1,
					Parent = stage,
				})
				task.delay(1.4, function()
					tween(sub, { TextTransparency = 0.15 }, 0.6)
				end)
			end

			----------------------------------------------------------
			-- Scanline sweep
			----------------------------------------------------------
			local scan = create("Frame", {
				Size = UDim2.new(1, 0, 0, 2),
				Position = UDim2.fromScale(0, -0.05),
				BackgroundColor3 = accentLight,
				BorderSizePixel = 0,
				Visible = false,
				Parent = root,
			})
			create("UIGradient", {
				Transparency = NumberSequence.new({ kp(0, 1), kp(0.15, 0), kp(0.85, 0), kp(1, 1) }),
				Parent = scan,
			})
			local trail = create("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Size = UDim2.new(1, 0, 0, 120),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				Parent = scan,
			})
			create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({ kp(0, 1), kp(1, 0.8) }),
				Parent = trail,
			})

			----------------------------------------------------------
			-- Progress bar + status text
			----------------------------------------------------------
			local trackW = 0.32
			local track = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.865),
				Size = UDim2.new(trackW, 0, 0, 3),
				BackgroundColor3 = Color3.fromRGB(40, 40, 44),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = root,
			})
			create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
			local fill = create("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = white,
				BorderSizePixel = 0,
				Parent = track,
			})
			create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
			create("UIGradient", { Color = ColorSequence.new(accent, accentLight), Parent = fill })

			local statusLabel = create("TextLabel", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0.5 - trackW / 2, 0.85),
				Size = UDim2.new(trackW * 0.7, 0, 0, 18),
				BackgroundTransparency = 1,
				FontRole = "Body",
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(150, 150, 160),
				TextTransparency = 1,
				Text = "INITIALIZING",
				Parent = root,
			})
			local percent = create("TextLabel", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(0.5 + trackW / 2, 0.85),
				Size = UDim2.new(trackW * 0.3, 0, 0, 18),
				BackgroundTransparency = 1,
				FontRole = "Heading",
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = white,
				TextTransparency = 1,
				Text = "0%",
				Parent = root,
			})
			local skipHint = create("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.95),
				Size = UDim2.new(0.4, 0, 0, 14),
				BackgroundTransparency = 1,
				FontRole = "Body",
				TextSize = 11,
				TextColor3 = Color3.fromRGB(120, 120, 130),
				TextTransparency = 1,
				Text = "PRESS ANY KEY TO SKIP",
				Parent = root,
			})

			local steps = {
				{ 0, "INITIALIZING" },
				{ 0.2, "LOADING MODULES" },
				{ 0.45, "APPLYING SETTINGS" },
				{ 0.7, "BUILDING INTERFACE" },
				{ 0.95, "READY" },
			}
			prog.Changed:Connect(function(v)
				fill.Size = UDim2.fromScale(v, 1)
				percent.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
				local msg = steps[1][2]
				for _, s in ipairs(steps) do
					if v >= s[1] then msg = s[2] end
				end
				statusLabel.Text = msg
			end)

			-- Full-screen flash (last = on top)
			local flash = create("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = accent,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = root,
			})

			----------------------------------------------------------
			-- Per-frame animation
			----------------------------------------------------------
			local t0 = os.clock()
			loopConn = RunService.Heartbeat:Connect(function(dt)
				local t = os.clock() - t0

				local pa = partAmt.Value
				for _, p in ipairs(particles) do
					p.y -= p.speed * dt
					if p.y < -0.03 then
						p.y = 1.03
						p.x = rand()
					end
					p.frame.Position = UDim2.fromScale(p.x + math.sin(t * p.drift + p.phase) * 0.012, p.y)
					local tw = 0.5 + 0.5 * math.sin(t * p.twinkle + p.phase)
					p.frame.BackgroundTransparency = 1 - p.alpha * (0.3 + 0.7 * tw) * pa
				end
				for _, s in ipairs(streaks) do
					s.x += s.speed * dt
					if s.speed > 0 and s.x > 1.3 then
						s.x = -0.3
						s.y = 0.05 + rand() * 0.9
					elseif s.speed < 0 and s.x < -0.3 then
						s.x = 1.3
						s.y = 0.05 + rand() * 0.9
					end
					s.frame.Position = UDim2.fromScale(s.x, s.y)
					s.frame.BackgroundTransparency = 1 - s.alpha * pa
				end

				local ga = glowAmt.Value
				local pulse = 0.85 + 0.15 * math.sin(t * 2.2)
				for _, g in ipairs(glow) do
					g.frame.BackgroundTransparency = math.clamp(1 - (1 - g.base) * ga * pulse, 0, 1)
				end
				for _, r in ipairs(rings) do
					r.grad.Rotation = (t * r.speed) % 360
				end

				-- Logo reveal with a glitch: RGB-split ghosts, shake and flicker that settle down
				local rv, gl = logoAmt.Value, glitch.Value
				local jitter = gl * 14
				ghostR.Position = UDim2.fromOffset((rand() * 2 - 1) * jitter, (rand() * 2 - 1) * jitter * 0.4)
				ghostC.Position = UDim2.fromOffset((rand() * 2 - 1) * jitter, (rand() * 2 - 1) * jitter * 0.4)
				logoBox.Position = UDim2.new(0.5, (rand() * 2 - 1) * gl * 6, 0.5, (rand() * 2 - 1) * gl * 3)
				local flicker = (rand() < gl * 0.55) and rand() * 0.9 or 0
				setT(logo, math.clamp((1 - rv) + flicker * gl, 0, 1))
				local ghostT = (rand() < 0.25) and 1 or (1 - 0.7 * gl * rv)
				setT(ghostR, ghostT)
				setT(ghostC, ghostT)
			end)

			----------------------------------------------------------
			-- Timeline
			----------------------------------------------------------
			local skipped = false
			skipConn = UserInputService.InputBegan:Connect(function(input)
				if os.clock() - t0 < 0.8 then return end
				local ut = input.UserInputType
				if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch or ut == Enum.UserInputType.Keyboard then
					skipped = true
				end
			end)
			local function pause(sec)
				local s = os.clock()
				while os.clock() - s < sec and not skipped do
					task.wait()
				end
			end

			-- Progress runs in its own thread, in uneven bursts
			local span = math.max(duration - 1.9, 1.2)
			local progDone = false
			task.spawn(function()
				pause(0.45)
				local targets = { 0.17, 0.4, 0.58, 0.83, 1 }
				local weights = { 0.12, 0.3, 0.16, 0.28, 0.14 }
				for i, target in ipairs(targets) do
					local dur = skipped and 0.12 or span * weights[i]
					tnum(prog, target, dur, Enum.EasingStyle.Quad)
					pause(dur + (i < #targets and rand() * 0.1 or 0))
				end
				tnum(prog, 1, 0.1)
				progDone = true
			end)

			-- Intro: lines grow, embers and glow fade up, rings appear
			tween(lineTop, { Size = UDim2.new(0.86, 0, 0, 1) }, 0.9, Enum.EasingStyle.Quint)
			tween(lineBottom, { Size = UDim2.new(0.86, 0, 0, 1) }, 0.9, Enum.EasingStyle.Quint)
			tnum(partAmt, 1, 1.4)
			tnum(glowAmt, 1, 1.6)
			for _, r in ipairs(rings) do
				tween(r.stroke, { Transparency = 0.25 }, 1.0)
			end
			tween(track, { BackgroundTransparency = 0 }, 0.6)
			tween(statusLabel, { TextTransparency = 0 }, 0.6)
			tween(percent, { TextTransparency = 0 }, 0.6)
			pause(0.4)

			-- Logo glitches in and settles
			glitch.Value = 1
			tnum(logoAmt, 1, 0.9, Enum.EasingStyle.Linear)
			tnum(glitch, 0, 1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(logoScale, { Scale = 1 }, 1.2, Enum.EasingStyle.Quint)
			tween(skipHint, { TextTransparency = 0.5 }, 0.8)
			pause(1.0)

			-- Shine sweep over the logo + a scanline down the screen
			scan.Visible = true
			tween(scan, { Position = UDim2.fromScale(0, 1.05) }, 1.1, Enum.EasingStyle.Sine)
			tween(shineGrad, { Offset = Vector2.new(1, 0) }, 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			flash.BackgroundColor3 = accent
			flash.BackgroundTransparency = 0.88
			tween(flash, { BackgroundTransparency = 1 }, 0.5)

			-- Wait for the progress bar (with a safety net so the window can never get stuck behind this)
			local deadline = os.clock() + duration + 3
			while not progDone and not skipped and os.clock() < deadline do
				task.wait()
			end

			-- Ready: the logo ignites
			tween(logo, { [colorProp] = white }, 0.3)
			tnum(glowAmt, 2.2, 0.18, Enum.EasingStyle.Quad)
			for _, r in ipairs(rings) do
				tween(r.stroke, { Transparency = 0 }, 0.18)
			end
			pause(0.2)
			tnum(glowAmt, 1, 0.7)
			pause(0.3)

			-- Outro: flash, logo pushes toward the camera, everything fades; the window fades in underneath
			reveal()
			flash.BackgroundColor3 = white
			flash.BackgroundTransparency = 0.5
			tween(flash, { BackgroundTransparency = 1 }, 0.55)
			tween(logoScale, { Scale = 1.18 }, 0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			tween(lineTop, { Size = UDim2.new(0, 0, 0, 1) }, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			tween(lineBottom, { Size = UDim2.new(0, 0, 0, 1) }, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			tween(root, { GroupTransparency = 1 }, 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.8)
		end)

		cleanup()
		reveal() -- also covers the failure path: the window always shows up
		if not ok then
			warn("[GuiLibrary] Splash screen failed: " .. tostring(err))
		end
	end)
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
function Library:CreateWindow(settings)
	settings = settings or {}
	if settings.Theme then
		Library:SetTheme(settings.Theme)
	end

	local Window = {}
	local tabs = {}
	local selectedTab
	local tabCount = 0
	local toggleKey = settings.ToggleKey or Enum.KeyCode.RightShift
	local visible = false
	local splashActive = false
	local toggleBind

	------------------------------------------------------------------
	-- Autosave
	------------------------------------------------------------------
	local cfg = settings.ConfigurationSaving or {}
	local saveEnabled = cfg.Enabled ~= false
	local hasFiles = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
	local canSave = saveEnabled and hasFiles
	local folder = cfg.FolderName or ((settings.Name or "GuiLibrary"):gsub("[^%w_%- ]", ""))
	if folder == "" then folder = "GuiLibrary" end
	local filePath = folder .. "/" .. (cfg.FileName or "Settings") .. ".json"

	local flags = {}
	if canSave then
		pcall(function()
			if isfile(filePath) then
				local data = HttpService:JSONDecode(readfile(filePath))
				if type(data) == "table" then
					flags = data
				end
			end
		end)
	end
	Window.Flags = flags

	local savePending = false
	local function flush()
		if not canSave then return end
		pcall(function()
			if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(folder) then
				makefolder(folder)
			end
			writefile(filePath, HttpService:JSONEncode(flags))
		end)
	end
	local function changed(flag, value)
		if flags[flag] == value then return end
		flags[flag] = value
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
	-- GUI root
	------------------------------------------------------------------
	local gui = create("ScreenGui", {
		Name = settings.Name or "Window",
		DisplayOrder = 2147483000,
		OnTopOfCoreBlur = true,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	-- Very see-through screen behind the window
	local backdrop = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	})

	-- Sprinkles floating on the background
	local sprinkleHolder = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
		Parent = gui,
	})
	local sprinkles = {}
	for i = 1, SprinkleCount do
		local size = math.random(2, 6)
		local fr = create("Frame", {
			Size = UDim2.fromOffset(size, size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = sprinkleHolder,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fr })
		table.insert(sprinkles, {
			frame = fr,
			x = math.random(),
			y = math.random(),
			speed = 0.008 + math.random() * 0.03,
			drift = 0.3 + math.random() * 0.7,
			phase = math.random() * math.pi * 2,
			twinkle = 0.8 + math.random() * 1.8,
			alpha = 0.35 + math.random() * 0.5,
			accent = i % 2 == 0,
		})
	end

	local fullSize = UDim2.fromOffset(560, 370)

	-- Holder = the thing that moves/resizes. Glow, shine and the window all live inside it.
	local holder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = fullSize,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local popScale = create("UIScale", { Scale = 0.9, Parent = holder })

	-- Soft glow behind something (stacked rounded frames, no image assets needed)
	-- plus a "shine": a bright spot that travels around its edge.
	local function makeGlow(parent, step, radius, phase)
		local store = { layers = {}, phase = phase }
		if not GlowEnabled then return store end
		for i = 1, 7 do
			local pad = i * step
			local fr = create("Frame", {
				Size = UDim2.new(1, pad * 2, 1, pad * 2),
				Position = UDim2.fromOffset(-pad, -pad),
				BackgroundColor3 = Theme.Accent,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = parent,
			})
			corner(fr, radius + pad)
			table.insert(store.layers, { frame = fr, base = 0.90 + i * 0.013 })
		end
		local shine = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = parent,
		})
		corner(shine, radius)
		store.stroke = create("UIStroke", {
			Thickness = 2,
			Color = Color3.new(1, 1, 1),
			Transparency = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = shine,
		})
		store.gradient = create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(0.7, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = store.stroke,
		})
		return store
	end
	-- k = how visible the whole effect is (0..1), t = time
	local function animateGlow(store, k, t)
		local pulse = 0.8 + 0.2 * math.sin(t * 1.6 + store.phase)
		for _, l in ipairs(store.layers) do
			l.frame.BackgroundTransparency = 1 - (1 - l.base) * k * pulse
		end
		if store.stroke then
			store.stroke.Transparency = 1 - 0.85 * k
			store.gradient.Rotation = (t * 80 + store.phase * 60) % 360
		end
	end
	local function recolorGlow(store)
		for _, l in ipairs(store.layers) do
			l.frame.BackgroundColor3 = Theme.Accent
		end
		if store.gradient then
			store.gradient.Color = ColorSequence.new(Theme.Accent, Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.65))
		end
	end

	local winGlow = makeGlow(holder, 6, 14, 0)

	-- The window itself. A CanvasGroup lets the whole thing fade in one go.
	local main = create("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = Alpha,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Bind = { BackgroundColor3 = "Background" },
		Parent = holder,
	})
	corner(main, 14)

	----------------------------------------------------------------
	-- Info bar (fps / ping / time), top right - with its own glow + shine
	----------------------------------------------------------------
	local infoOn = false
	local infoHolder = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 18),
		Size = UDim2.fromOffset(120, 28),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local infoGlow = makeGlow(infoHolder, 3, 14, 1.5)
	local infoBar = create("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 1,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Bind = { BackgroundColor3 = "Background" },
		Parent = infoHolder,
	})
	corner(infoBar, 14)
	local infoLabel = create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Fonts.Mono,
		TextSize = 13,
		RichText = true,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Bind = { TextColor3 = "Text" },
		Parent = infoBar,
	})
	hairline(infoBar, 14)

	-- Recolor the effects whenever the theme changes
	local function recolor()
		recolorGlow(winGlow)
		recolorGlow(infoGlow)
		for _, s in ipairs(sprinkles) do
			s.frame.BackgroundColor3 = s.accent and Theme.Accent or Color3.new(1, 1, 1)
		end
	end
	onTheme(backdrop, recolor)
	recolor()

	local lastFps = 60
	local barWidth = 0
	local function refreshInfo(fps)
		lastFps = fps or lastFps
		local sub, txt = Theme.SubText:ToHex(), Theme.Text:ToHex()
		infoLabel.Text = string.format(
			'<font color="#%s">FPS</font> <font color="#%s">%3d</font>   <font color="#%s">PING</font> <font color="#%s">%3d</font><font color="#%s">ms</font>   <font color="#%s">%s</font>',
			sub, txt, math.clamp(math.floor(lastFps + 0.5), 0, 999),
			sub, txt, math.clamp(math.floor(getPing() + 0.5), 0, 999),
			sub, txt, os.date("%H:%M")
		)
		-- Only ever grows, so the bar doesn't jitter as numbers change
		local w = math.ceil(infoLabel.TextBounds.X) + 30
		if w > barWidth then
			barWidth = w
			infoHolder.Size = UDim2.fromOffset(w, 28)
		end
	end
	onTheme(infoBar, function() refreshInfo() end)

	local infoFade = Instance.new("NumberValue") -- 0 = hidden, 1 = shown
	infoFade.Value = 0
	infoFade.Changed:Connect(function(v)
		infoBar.GroupTransparency = 1 - v
	end)

	local infoFrames, infoAcc = 0, 0
	local infoConn = RunService.Heartbeat:Connect(function(dt)
		if not infoOn then return end
		infoFrames += 1
		infoAcc += dt
		if infoAcc >= 0.5 then
			local fps = infoFrames / infoAcc
			infoFrames, infoAcc = 0, 0
			refreshInfo(fps)
		end
	end)

	function Window:SetInfoBar(v)
		v = v == true
		if v == infoOn then return end
		infoOn = v
		if v then
			infoHolder.Visible = true
			refreshInfo()
			tween(infoFade, { Value = 1 }, 0.4)
		else
			local t = tween(infoFade, { Value = 0 }, 0.3)
			t.Completed:Connect(function()
				if not infoOn then infoHolder.Visible = false end
			end)
		end
	end

	----------------------------------------------------------------
	-- Fade in / out (one 0..1 value drives everything)
	----------------------------------------------------------------
	local fade = Instance.new("NumberValue")
	fade.Value = 0
	local fadeTween

	local function apply(v)
		main.GroupTransparency = 1 - v
		popScale.Scale = 0.9 + 0.1 * v
		backdrop.BackgroundTransparency = 1 - (1 - BackdropAlpha) * v
	end
	fade.Changed:Connect(apply)
	apply(0)

	local function fadeTo(target, time, onDone)
		if fadeTween then fadeTween:Cancel() end
		local fadingIn = target == 1
		fadeTween = TweenService:Create(
			fade,
			TweenInfo.new(
				time,
				fadingIn and Enum.EasingStyle.Quint or Enum.EasingStyle.Quad,
				fadingIn and Enum.EasingDirection.Out or Enum.EasingDirection.In
			),
			{ Value = target }
		)
		fadeTween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and onDone then
				onDone()
			end
		end)
		fadeTween:Play()
	end

	-- Per-frame animation: glows + shines, sprinkle drift + twinkle, element animators
	local animators = {} -- per-element animations (slider shimmer, etc.)
	local startTime = os.clock()
	local winShown, infoShown = false, false
	local frameConn = RunService.Heartbeat:Connect(function(dt)
		local f, inf = fade.Value, infoFade.Value
		if f <= 0 and inf <= 0 and not winShown and not infoShown then return end
		local t = os.clock() - startTime

		if f > 0 or winShown then
			animateGlow(winGlow, f, t)
			winShown = f > 0
			if f > 0 then
				for _, s in ipairs(sprinkles) do
					s.y -= s.speed * dt
					if s.y < -0.03 then
						s.y = 1.03
						s.x = math.random()
					end
					local px = s.x + math.sin(t * s.drift + s.phase) * 0.01
					s.frame.Position = UDim2.fromScale(px, s.y)
					local tw = 0.5 + 0.5 * math.sin(t * s.twinkle + s.phase)
					s.frame.BackgroundTransparency = 1 - s.alpha * (0.3 + 0.7 * tw) * f
				end

				for i = #animators, 1, -1 do
					local a = animators[i]
					if a.inst:IsDescendantOf(game) then
						a.fn(t)
					else
						table.remove(animators, i)
					end
				end
			end
		end

		if inf > 0 or infoShown then
			animateGlow(infoGlow, inf, t)
			infoShown = inf > 0
		end
	end)
	gui.Destroying:Connect(function()
		frameConn:Disconnect()
		infoConn:Disconnect()
		fade:Destroy()
		infoFade:Destroy()
	end)

	----------------------------------------------------------------
	-- Topbar (part of the window)
	----------------------------------------------------------------
	local topbar = create("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = Alpha,
		BorderSizePixel = 0,
		Bind = { BackgroundColor3 = "Topbar" },
		Parent = main,
	})
	corner(topbar, 14)
	-- Square off the topbar's bottom corners (hidden while minimized)
	local filler = create("Frame", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundTransparency = Alpha,
		BorderSizePixel = 0,
		Bind = { BackgroundColor3 = "Topbar" },
		Parent = topbar,
	})

	local dot = create("Frame", {
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.new(0, 16, 0.5, -3),
		BorderSizePixel = 0,
		Bind = { BackgroundColor3 = "Accent" },
		Parent = topbar,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })

	local title = label(topbar, string.upper(settings.Name or "Window"), 18)
	title.Size = UDim2.new(1, -130, 1, 0)
	title.Position = UDim2.fromOffset(34, 0)
	bindFont(title, "Title")
	-- faint accent outline on the title text gives it a soft glow
	create("UIStroke", {
		Thickness = 1,
		Transparency = 0.7,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Bind = { Color = "Accent" },
		Parent = title,
	})

	local function topButton(text, offset)
		local b = create("TextButton", {
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, offset, 0, 4),
			BackgroundTransparency = 1,
			Text = text,
			FontRole = "Heading",
			TextSize = 16,
			Bind = { TextColor3 = "SubText" },
			Parent = topbar,
		})
		b.MouseEnter:Connect(function() b.TextColor3 = Theme.Text end)
		b.MouseLeave:Connect(function() b.TextColor3 = Theme.SubText end)
		return b
	end
	local closeBtn = topButton("X", -36)
	local minBtn = topButton("-", -66)

	-- Settings gear (opens/closes the Settings page). Drawn from frames, so it needs no assets.
	local settingsEntry, lastNormalEntry
	local settingsBtn = create("TextButton", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -96, 0, 4),
		BackgroundTransparency = 1,
		Text = "",
		Parent = topbar,
	})
	local gearIcon = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Parent = settingsBtn,
	})
	local gearHub = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gearIcon,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = gearHub })
	local gearStroke = create("UIStroke", {
		Thickness = 3,
		Color = Theme.SubText,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = gearHub,
	})
	local gearTeeth = {}
	for i = 0, 7 do
		local a = math.rad(i * 45)
		table.insert(gearTeeth, create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.sin(a) * (7 / 18), 0.5 - math.cos(a) * (7 / 18)),
			Size = UDim2.fromOffset(3, 5),
			Rotation = i * 45,
			BackgroundColor3 = Theme.SubText,
			BorderSizePixel = 0,
			Parent = gearIcon,
		}))
	end

	local gearHover = false
	local function refreshGear()
		local active = settingsEntry ~= nil and selectedTab == settingsEntry
		local color = active and Theme.Accent or (gearHover and Theme.Text or Theme.SubText)
		tween(gearStroke, { Color = color }, 0.15)
		for _, tooth in ipairs(gearTeeth) do
			tween(tooth, { BackgroundColor3 = color }, 0.15)
		end
		tween(gearIcon, { Rotation = active and 90 or 0 }, 0.4, Enum.EasingStyle.Back)
	end
	settingsBtn.MouseEnter:Connect(function()
		gearHover = true
		refreshGear()
	end)
	settingsBtn.MouseLeave:Connect(function()
		gearHover = false
		refreshGear()
	end)
	settingsBtn.MouseButton1Click:Connect(function()
		if not settingsEntry then return end
		if selectedTab == settingsEntry then
			if lastNormalEntry then lastNormalEntry.select() end
		else
			settingsEntry.select()
		end
	end)
	onTheme(settingsBtn, refreshGear)

	----------------------------------------------------------------
	-- Window body: tab list + pages
	----------------------------------------------------------------
	local content = create("Frame", {
		Size = UDim2.new(1, 0, 1, -36),
		Position = UDim2.fromOffset(0, 36),
		BackgroundTransparency = 1,
		Parent = main,
	})
	local tabBar = create("ScrollingFrame", {
		Size = UDim2.new(0, 130, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabBar,
	})
	create("UIPadding", {
		PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6),
		Parent = tabBar,
	})
	local pages = create("Frame", {
		Size = UDim2.new(1, -130, 1, 0),
		Position = UDim2.fromOffset(130, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})

	-- Hairline dividers: under the topbar and between the sidebar and the pages
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 36),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Bind = { BackgroundColor3 = "Stroke" },
		Parent = main,
	})
	local sideDivider = create("Frame", {
		Size = UDim2.new(0, 1, 1, -52),
		Position = UDim2.fromOffset(130, 44),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Bind = { BackgroundColor3 = "Stroke" },
		Parent = main,
	})

	-- Soft highlight across the top of the window for a bit of depth
	local sheen = create("Frame", {
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = main,
	})
	create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.945),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = sheen,
	})

	-- Window outline (last, so it sits on top of everything)
	hairline(main, 14, 0.3)

	-- Dragging
	local dragging, dragStart, startPos
	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, input.Position, holder.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	-- Minimize (keeps the top edge in place) / close (fades out first)
	local minimized = false
	local resizing = false
	minBtn.MouseButton1Click:Connect(function()
		if resizing then return end
		resizing = true
		minimized = not minimized
		content.Visible = not minimized
		filler.Visible = not minimized
		sheen.Visible = not minimized
		sideDivider.Visible = not minimized

		local curH = holder.Size.Y.Offset
		local newH = minimized and 36 or fullSize.Y.Offset
		local t = tween(holder, {
			Size = UDim2.fromOffset(fullSize.X.Offset, newH),
			Position = holder.Position + UDim2.fromOffset(0, (newH - curH) / 2),
		}, 0.3, Enum.EasingStyle.Quint)
		t.Completed:Connect(function() resizing = false end)
	end)
	closeBtn.MouseButton1Click:Connect(function()
		visible = false
		infoOn = false
		tween(infoFade, { Value = 0 }, 0.25)
		fadeTo(0, 0.25, function()
			gui:Destroy()
		end)
	end)

	-- Show / hide + toggle key
	function Window:SetVisible(v)
		if v == visible then return end
		visible = v
		if v then
			holder.Visible = true
			backdrop.Visible = true
			sprinkleHolder.Visible = true
			fadeTo(1, 0.4)
		else
			fadeTo(0, 0.25, function()
				if not visible then
					holder.Visible = false
					backdrop.Visible = false
					sprinkleHolder.Visible = false
				end
			end)
		end
	end
	function Window:Toggle()
		Window:SetVisible(not visible)
	end
	function Window:SetToggleKey(key)
		toggleKey = key
		if toggleBind then toggleBind:Set(key, true) end
	end
	function Window:Destroy()
		gui:Destroy()
	end

	local keyConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or listeningForKey or splashActive then return end
		if input.KeyCode == toggleKey then
			Window:Toggle()
		end
	end)
	gui.Destroying:Connect(function() keyConn:Disconnect() end)

	------------------------------------------------------------------
	-- Tabs
	------------------------------------------------------------------
	function Window:CreateTab(name, _internal)
		local Tab = {}

		-- Save key for an element: explicit Flag, or "<Tab>/<Element name>"
		local function flagOf(o, fallback)
			return o.Flag or (name .. "/" .. (o.Name or fallback))
		end

		tabCount += 1
		local tabButton = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = name,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontRole = "Body",
			TextSize = 13,
			LayoutOrder = _internal and 1000 or tabCount, -- Settings always last
			Bind = { BackgroundColor3 = "Element" },
			Parent = tabBar,
		})
		corner(tabButton, 10)
		tabButton.Visible = not _internal
		create("UIPadding", { PaddingLeft = UDim.new(0, 16), Parent = tabButton })
		local indicator = create("Frame", {
			Size = UDim2.fromOffset(3, 14),
			Position = UDim2.new(0, -11, 0.5, -7),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Bind = { BackgroundColor3 = "Accent" },
			Parent = tabButton,
		})
		corner(indicator, 2)

		local page = create("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Visible = false,
			Bind = { ScrollBarImageColor3 = "SubText" },
			Parent = pages,
		})
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
		create("UIPadding", {
			PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 10),
			Parent = page,
		})

		local entry = { button = tabButton, page = page, indicator = indicator }
		table.insert(tabs, entry)

		local function styleTab(e)
			local selected = e == selectedTab
			tween(e.button, {
				BackgroundTransparency = selected and Alpha or 1,
				TextColor3 = selected and Theme.Text or Theme.SubText,
			}, 0.18)
			tween(e.indicator, { BackgroundTransparency = selected and 0 or 1 }, 0.18)
		end
		local function select()
			selectedTab = entry
			if not _internal then lastNormalEntry = entry end
			refreshGear()
			for _, t in ipairs(tabs) do
				t.page.Visible = (t == entry)
				styleTab(t)
			end
		end
		entry.select = select
		onTheme(tabButton, function() styleTab(entry) end)
		tabButton.MouseButton1Click:Connect(select)
		tabButton.MouseEnter:Connect(function()
			if selectedTab ~= entry then tween(tabButton, { BackgroundTransparency = 0.6 }, 0.12) end
		end)
		tabButton.MouseLeave:Connect(function()
			if selectedTab ~= entry then tween(tabButton, { BackgroundTransparency = 1 }, 0.12) end
		end)
		if not selectedTab and not _internal then
			select()
		else
			styleTab(entry)
		end

		-- Label ------------------------------------------------------
		function Tab:CreateLabel(text)
			local f = newElement(page, 28)
			local l = label(f, text, 13, "SubText")
			l.Size = UDim2.new(1, -24, 1, 0)
			l.Position = UDim2.fromOffset(12, 0)
			return { Set = function(_, t) l.Text = t end }
		end

		-- Button (press-in squish + ripple) --------------------------
		function Tab:CreateButton(o)
			-- The slot keeps the layout size; the CanvasGroup inside is what squishes
			local slot = create("Frame", {
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
				Parent = page,
			})
			local f = create("CanvasGroup", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = Alpha,
				BorderSizePixel = 0,
				Bind = { BackgroundColor3 = "Element" },
				Parent = slot,
			})
			corner(f, 10)
			hairline(f, 10)
			local squish = create("UIScale", { Parent = f })

			local b = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = o.Name or "Button",
				FontRole = "Body",
				TextSize = 14,
				Bind = { TextColor3 = "Text" },
				Parent = f,
			})
			hover(b, f)

			b.MouseButton1Down:Connect(function()
				tween(squish, { Scale = 0.96 }, 0.08)
				ripple(f, pointerIn(f))
			end)
			local function release()
				tween(squish, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
			end
			b.MouseButton1Up:Connect(release)
			b.MouseLeave:Connect(release)
			b.MouseButton1Click:Connect(function() fire(o.Callback) end)

			return { Destroy = function() slot:Destroy() end }
		end

		-- Toggle (knob stretch, halo pulse, row flash, optional Loop) -
		function Tab:CreateToggle(o)
			local flag = flagOf(o, "Toggle")
			local value
			if flags[flag] ~= nil then
				value = flags[flag] == true
			else
				value = o.CurrentValue == true
			end
			local token, loopId = 0, 0
			local interval = o.Interval or 0.1

			local f = newElement(page)
			local l = label(f, o.Name or "Toggle", 14)
			l.Size = UDim2.new(1, -74, 1, 0)
			l.Position = UDim2.fromOffset(12, 0)

			local track = create("Frame", {
				Size = UDim2.fromOffset(38, 18),
				Position = UDim2.new(1, -50, 0.5, -9),
				BorderSizePixel = 0,
				Parent = f,
			})
			corner(track, 9)
			local knob = create("Frame", {
				Size = UDim2.fromOffset(14, 14),
				Position = UDim2.fromOffset(2, 2),
				BorderSizePixel = 0,
				Bind = { BackgroundColor3 = "Knob" },
				Parent = track,
			})
			corner(knob, 7)
			local click = create("TextButton", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f,
			})

			local function stateColor() return value and Theme.Accent or Theme.SubText end
			local function knobX() return value and 22 or 2 end

			-- Instant (no animation): initial state and theme changes
			local function paint()
				track.BackgroundColor3 = stateColor()
				knob.Size = UDim2.fromOffset(14, 14)
				knob.Position = UDim2.fromOffset(knobX(), 2)
			end

			local function animate()
				token += 1
				local mine = token

				tween(track, { BackgroundColor3 = stateColor() }, 0.2)

				-- Knob stretches toward where it's going, then snaps into place with a bounce
				tween(knob, {
					Size = UDim2.fromOffset(20, 14),
					Position = UDim2.fromOffset(value and 2 or 16, 2),
				}, 0.09)
				task.delay(0.09, function()
					if mine ~= token then return end
					tween(knob, {
						Size = UDim2.fromOffset(14, 14),
						Position = UDim2.fromOffset(knobX(), 2),
					}, 0.28, Enum.EasingStyle.Back)
				end)

				-- Halo pulse behind the knob
				local ring = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(1, -50 + knobX() + 7, 0.5, 0),
					Size = UDim2.fromOffset(14, 14),
					BackgroundColor3 = stateColor(),
					BackgroundTransparency = 0.4,
					BorderSizePixel = 0,
					ZIndex = 0,
					Parent = f,
				})
				create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
				tween(ring, { Size = UDim2.fromOffset(38, 38), BackgroundTransparency = 1 }, 0.45)
				task.delay(0.5, function() ring:Destroy() end)

				-- Quick flash of the whole row
				f.BackgroundColor3 = Theme.ElementHover
				tween(f, { BackgroundColor3 = Theme.Element }, 0.4)
			end

			local Toggle = {}

			-- Loop: runs over and over while the toggle is on
			local function startLoop()
				if type(o.Loop) ~= "function" then return end
				loopId += 1
				local mine = loopId
				task.spawn(function()
					while value and mine == loopId and f:IsDescendantOf(game) do
						local ok, err = pcall(o.Loop)
						if not ok then
							warn(string.format("[GuiLibrary] Loop error in '%s': %s (toggle switched off)", o.Name or "Toggle", tostring(err)))
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
				value = v
				animate()
				changed(flag, v)
				if v then
					startLoop()
				else
					loopId += 1
				end
				if not silent then fire(o.Callback, v) end
			end
			function Toggle:Get()
				return value
			end

			click.MouseButton1Click:Connect(function() Toggle:Set(not value) end)
			onTheme(track, paint)
			paint()

			-- Starting ON (default or restored from the save file): run it
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

		-- Slider (gradient fill + shimmer, glow halo, press pulse, value pop) ---
		function Tab:CreateSlider(o)
			local flag = flagOf(o, "Slider")
			local min, max = o.Range and o.Range[1] or 0, o.Range and o.Range[2] or 100
			local inc = o.Increment or 1
			local fromSave = type(flags[flag]) == "number"
			local value = fromSave and flags[flag] or (o.CurrentValue or min)

			local f = newElement(page, 54)
			hover(f, f)

			local l = label(f, o.Name or "Slider", 14)
			l.Size = UDim2.new(0.6, -12, 0, 24)
			l.Position = UDim2.fromOffset(12, 4)
			local vl = label(f, "", 14, "Accent", Enum.TextXAlignment.Right)
			vl.Size = UDim2.new(0.4, -12, 0, 24)
			vl.Position = UDim2.new(0.6, 0, 0, 4)
			bindFont(vl, "Heading")

			local bar = create("Frame", {
				Size = UDim2.new(1, -24, 0, 8),
				Position = UDim2.new(0, 12, 1, -19),
				BorderSizePixel = 0,
				Bind = { BackgroundColor3 = "Background" },
				Parent = f,
			})
			corner(bar, 4)

			-- Fill: white base so the gradient supplies the color
			local fill = create("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Parent = bar,
			})
			corner(fill, 4)
			local fillGradient = create("UIGradient", { Parent = fill })

			-- A light band that sweeps across the filled part
			local shimmer = create("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Parent = fill,
			})
			corner(shimmer, 4)
			local shimmerGradient = create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.4, 1),
					NumberSequenceKeypoint.new(0.5, 0.6),
					NumberSequenceKeypoint.new(0.6, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Parent = shimmer,
			})

			-- Glow behind the handle (grows while dragging)
			local halo = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(12, 12),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Bind = { BackgroundColor3 = "Accent" },
				Parent = fill,
			})
			create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = halo })
			local handle = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(12, 12),
				BorderSizePixel = 0,
				Bind = { BackgroundColor3 = "Text" },
				Parent = fill,
			})
			corner(handle, 6)

			local function recolor()
				fillGradient.Color = ColorSequence.new(
					Theme.Accent:Lerp(Color3.new(0, 0, 0), 0.25),
					Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.2)
				)
			end
			onTheme(bar, recolor)
			recolor()

			table.insert(animators, {
				inst = f,
				fn = function(t)
					shimmerGradient.Offset = Vector2.new(((t * 0.45) % 2) - 1, 0)
				end,
			})

			-- Handle states: idle 12px, hover 14px, dragging 16px + halo
			local sliding, hovering = false, false
			local function refreshHandle()
				local s = sliding and 16 or (hovering and 14 or 12)
				tween(handle, { Size = UDim2.fromOffset(s, s) }, 0.18, Enum.EasingStyle.Back)
				local h = sliding and 30 or 12
				tween(halo, {
					Size = UDim2.fromOffset(h, h),
					BackgroundTransparency = sliding and 0.75 or 1,
				}, 0.2)
			end
			f.MouseEnter:Connect(function()
				hovering = true
				refreshHandle()
			end)
			f.MouseLeave:Connect(function()
				hovering = false
				refreshHandle()
			end)

			-- Expanding ring from the handle when you grab it
			local function pulse()
				local ring = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromOffset(12, 12),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = fill,
				})
				create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
				local stroke = create("UIStroke", {
					Thickness = 2,
					Transparency = 0.2,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Bind = { Color = "Accent" },
					Parent = ring,
				})
				tween(ring, { Size = UDim2.fromOffset(36, 36) }, 0.45)
				tween(stroke, { Transparency = 1 }, 0.45)
				task.delay(0.5, function() ring:Destroy() end)
			end

			local Slider = {}
			local function render(v, instant)
				v = math.clamp(math.floor(v / inc + 0.5) * inc, min, max)
				local moved = v ~= value
				value = v
				local size = UDim2.fromScale(max > min and (v - min) / (max - min) or 0, 1)
				if instant then
					fill.Size = size
				else
					tween(fill, { Size = size }, 0.09)
				end
				vl.Text = string.format("%s%s", tostring(math.round(v * 100) / 100), o.Suffix and (" " .. o.Suffix) or "")
				if moved and not instant then
					-- the number "pops" when it changes
					vl.TextSize = 17
					tween(vl, { TextSize = 14 }, 0.2)
				end
				return v
			end
			function Slider:Set(v, silent)
				v = render(v)
				changed(flag, v)
				if not silent then fire(o.Callback, v) end
			end

			local function fromX(x)
				local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
				Slider:Set(min + (max - min) * rel)
			end
			local conns = {}
			table.insert(conns, bar.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					sliding = true
					refreshHandle()
					pulse()
					fromX(input.Position.X)
				end
			end))
			table.insert(conns, UserInputService.InputChanged:Connect(function(input)
				if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					fromX(input.Position.X)
				end
			end))
			table.insert(conns, UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					if sliding then
						sliding = false
						refreshHandle()
					end
				end
			end))
			f.Destroying:Connect(function()
				for _, c in ipairs(conns) do c:Disconnect() end
			end)

			render(value, true)
			if fromSave then
				task.defer(function() fire(o.Callback, value) end)
			end
			return Slider
		end

		-- Input ------------------------------------------------------
		function Tab:CreateInput(o)
			local flag = flagOf(o, "Input")
			local fromSave = type(flags[flag]) == "string" and flags[flag] ~= ""

			local f = newElement(page)
			local l = label(f, o.Name or "Input", 14)
			l.Size = UDim2.new(0.5, -12, 1, 0)
			l.Position = UDim2.fromOffset(12, 0)

			local box = create("TextBox", {
				Size = UDim2.new(0.5, -20, 0, 24),
				Position = UDim2.new(0.5, 8, 0.5, -12),
				BorderSizePixel = 0,
				Text = fromSave and flags[flag] or "",
				PlaceholderText = o.PlaceholderText or "",
				FontRole = "Light",
				TextSize = 13,
				ClearTextOnFocus = false,
				Bind = { BackgroundColor3 = "Background", TextColor3 = "Text", PlaceholderColor3 = "SubText" },
				Parent = f,
			})
			corner(box, 8)
			box.FocusLost:Connect(function()
				if not o.RemoveTextAfterFocusLost then
					changed(flag, box.Text)
				end
				fire(o.Callback, box.Text)
				if o.RemoveTextAfterFocusLost then box.Text = "" end
			end)

			if fromSave then
				task.defer(function() fire(o.Callback, box.Text) end)
			end
			return {
				Set = function(_, t)
					box.Text = t
					if not o.RemoveTextAfterFocusLost then changed(flag, t) end
				end,
			}
		end

		-- Dropdown ---------------------------------------------------
		function Tab:CreateDropdown(o)
			local flag = flagOf(o, "Dropdown")
			local options = o.Options or {}
			local current = o.CurrentOption or options[1]

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

			local f = newElement(page, 34)
			f.ClipsDescendants = true

			local header = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
				Text = "",
				Parent = f,
			})
			local l = label(header, "", 14)
			l.Size = UDim2.new(1, -44, 1, 0)
			l.Position = UDim2.fromOffset(12, 0)
			local arrow = label(header, "v", 14, "SubText", Enum.TextXAlignment.Center)
			arrow.Size = UDim2.fromOffset(30, 34)
			arrow.Position = UDim2.new(1, -36, 0, 0)

			local list = create("Frame", {
				Size = UDim2.new(1, -12, 0, 0),
				Position = UDim2.fromOffset(6, 38),
				BackgroundTransparency = 1,
				Parent = f,
			})
			create("UIListLayout", { Padding = UDim.new(0, 3), Parent = list })

			local Dropdown = {}
			local open = false

			local function refreshHeader()
				l.Text = string.format("%s: %s", o.Name or "Dropdown", tostring(current))
			end

			function Dropdown:Set(v, silent)
				current = v
				refreshHeader()
				changed(flag, v)
				if not silent then fire(o.Callback, v) end
			end

			local function setOpen(state)
				open = state
				local h = open and (38 + #options * 29 + 4) or 34
				tween(f, { Size = UDim2.new(1, 0, 0, h) })
				arrow.Text = open and "^" or "v"
			end
			header.MouseButton1Click:Connect(function() setOpen(not open) end)

			for _, opt in ipairs(options) do
				local ob = create("TextButton", {
					Size = UDim2.new(1, 0, 0, 26),
					BorderSizePixel = 0,
					Text = tostring(opt),
					FontRole = "Light",
					TextSize = 13,
					Bind = { BackgroundColor3 = "Background", TextColor3 = "Text" },
					Parent = list,
				})
				corner(ob, 8)
				ob.MouseButton1Click:Connect(function()
					Dropdown:Set(opt)
					setOpen(false)
				end)
			end

			refreshHeader()
			if fromSave then
				task.defer(function() fire(o.Callback, current) end)
			end
			return Dropdown
		end

		-- Keybind ----------------------------------------------------
		-- Callback(key) fires when the bound key is pressed; Changed(key) fires when rebound.
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

			local f = newElement(page)
			local l = label(f, o.Name or "Keybind", 14)
			l.Size = UDim2.new(1, -120, 1, 0)
			l.Position = UDim2.fromOffset(12, 0)

			local btn = create("TextButton", {
				Size = UDim2.fromOffset(96, 24),
				Position = UDim2.new(1, -108, 0.5, -12),
				BorderSizePixel = 0,
				Text = key.Name,
				FontRole = "Body",
				TextSize = 12,
				Bind = { BackgroundColor3 = "Background", TextColor3 = "Text" },
				Parent = f,
			})
			corner(btn, 8)

			local Keybind = {}
			function Keybind:Set(k, silent)
				key = k
				btn.Text = k.Name
				changed(flag, k.Name)
				if not silent then fire(o.Changed, k) end
			end

			btn.MouseButton1Click:Connect(function()
				if listeningForKey then return end
				listeningForKey = true
				btn.Text = "Press a key..."
				local conn
				conn = UserInputService.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
					conn:Disconnect()
					-- Release on the next frame so other key handlers ignore this very press
					task.defer(function() listeningForKey = false end)
					if input.KeyCode == Enum.KeyCode.Escape then
						btn.Text = key.Name -- cancel
					else
						Keybind:Set(input.KeyCode)
					end
				end)
			end)

			local pressConn = UserInputService.InputBegan:Connect(function(input, processed)
				if processed or listeningForKey then return end
				if key ~= Enum.KeyCode.Unknown and input.KeyCode == key then
					fire(o.Callback, key)
				end
			end)
			f.Destroying:Connect(function() pressConn:Disconnect() end)

			if fromSave then
				task.defer(function() fire(o.Changed, key) end)
			end
			return Keybind
		end

		Tab._entry = entry
		return Tab
	end

	------------------------------------------------------------------
	-- Permanent Settings tab
	------------------------------------------------------------------
	local SettingsTab = Window:CreateTab("Settings", true)
	SettingsTab:CreateDropdown({
		Name = "Theme",
		Options = ThemeOrder,
		CurrentOption = Library.CurrentTheme,
		Callback = function(name)
			Library:SetTheme(name)
		end,
	})
	SettingsTab:CreateDropdown({
		Name = "Font",
		Options = FontOrder,
		CurrentOption = Library.CurrentFont,
		Callback = function(name)
			Library:SetFont(name)
		end,
	})
	toggleBind = SettingsTab:CreateKeybind({
		Name = "Toggle Window",
		CurrentKeybind = toggleKey,
		Changed = function(key)
			toggleKey = key
		end,
	})
	SettingsTab:CreateToggle({
		Name = "Info Bar",
		CurrentValue = settings.InfoBar ~= false,
		Callback = function(v)
			Window:SetInfoBar(v)
		end,
	})
	if not saveEnabled then
		SettingsTab:CreateLabel("Autosave: off")
	elseif not hasFiles then
		SettingsTab:CreateLabel("Autosave: unavailable (no file access here)")
	else
		SettingsTab:CreateLabel("Autosave: on  -  " .. filePath)
	end
	Window.SettingsTab = SettingsTab
	settingsEntry = SettingsTab._entry
	refreshGear()

	-- Startup screen, then fade the window in
	local splashOpts = settings.Splash
	if splashOpts == false then
		Window:SetVisible(true)
	else
		splashActive = true
		playSplash(type(splashOpts) == "table" and splashOpts or {}, settings.Name, function()
			splashActive = false
			Window:SetVisible(true)
		end)
	end

	return Window
end

----------------------------------------------------------------------
-- Put your own code here (before the return), for example:
--
--   local Window = Library:CreateWindow({ Name = "My Hub" })
--   local Tab = Window:CreateTab("Main")
--   Tab:CreateToggle({
--       Name = "Spam hi",
--       Loop = function() print("hi") end,   -- keeps running until switched off
--       Interval = 0.5,
--   })
----------------------------------------------------------------------

return Library
