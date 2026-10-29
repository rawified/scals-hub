--[[
	Rayfield/Sirius-style GUI library (self-contained)
	Place as a LocalScript in StarterPlayer > StarterPlayerScripts
	(or as a ModuleScript and require it)
 
	API:
		Library:CreateWindow({Name = "...", ToggleKey = Enum.KeyCode.RightShift, Theme = "Dark"})
		Window:CreateTab("Name")
		Tab:CreateButton / CreateToggle / CreateSlider / CreateInput / CreateDropdown / CreateKeybind / CreateLabel
		Window:Toggle() / Window:SetVisible(bool) / Window:SetToggleKey(Enum.KeyCode)
		Library:SetTheme("Dark" | "Light" | "Ocean" | "Rose" | "Forest")
		Library:Notify({Title, Content, Duration})
 
	Every window gets a permanent "Settings" tab (theme + toggle key) that always
	sits at the bottom of the tab list. It is available as Window.SettingsTab if
	you want to add your own items to it.
]]
 
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
 
local Library = {}
 
-- How see-through the window is (0 = solid). Keep this tiny.
local Alpha = 0.06
-- How see-through the dark screen behind the window is (1 = invisible).
local BackdropAlpha = 0.78
 
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
	},
	Light = {
		Background = Color3.fromRGB(240, 240, 245),
		Topbar = Color3.fromRGB(225, 225, 232),
		Element = Color3.fromRGB(255, 255, 255),
		ElementHover = Color3.fromRGB(235, 235, 243),
		Accent = Color3.fromRGB(70, 100, 240),
		Text = Color3.fromRGB(30, 30, 38),
		SubText = Color3.fromRGB(105, 105, 120),
	},
	Ocean = {
		Background = Color3.fromRGB(12, 25, 38),
		Topbar = Color3.fromRGB(18, 38, 58),
		Element = Color3.fromRGB(24, 48, 72),
		ElementHover = Color3.fromRGB(34, 64, 94),
		Accent = Color3.fromRGB(0, 170, 220),
		Text = Color3.fromRGB(230, 244, 252),
		SubText = Color3.fromRGB(140, 170, 190),
	},
	Rose = {
		Background = Color3.fromRGB(32, 20, 26),
		Topbar = Color3.fromRGB(46, 28, 36),
		Element = Color3.fromRGB(56, 34, 44),
		ElementHover = Color3.fromRGB(74, 46, 58),
		Accent = Color3.fromRGB(235, 90, 140),
		Text = Color3.fromRGB(250, 235, 240),
		SubText = Color3.fromRGB(190, 150, 165),
	},
	Forest = {
		Background = Color3.fromRGB(18, 28, 22),
		Topbar = Color3.fromRGB(26, 40, 32),
		Element = Color3.fromRGB(32, 50, 40),
		ElementHover = Color3.fromRGB(44, 68, 54),
		Accent = Color3.fromRGB(70, 200, 120),
		Text = Color3.fromRGB(232, 248, 238),
		SubText = Color3.fromRGB(150, 180, 162),
	},
}
local ThemeOrder = { "Dark", "Light", "Ocean", "Rose", "Forest" }
 
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
	props.Parent = nil
	props.Bind = nil
	for k, v in pairs(props) do
		inst[k] = v
	end
	if binds then
		for prop, key in pairs(binds) do
			bind(inst, prop, key)
		end
	end
	inst.Parent = parent
	return inst
end
 
local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end
 
local function tween(inst, props, time)
	TweenService:Create(inst, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad), props):Play()
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
	return frame
end
 
local function label(parent, text, size, colorKey, align)
	return create("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamMedium,
		TextSize = size or 14,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		Bind = { TextColor3 = colorKey or "Text" },
		Parent = parent,
	})
end
 
-- True while any keybind button is waiting for a key, so other key handlers stay quiet.
local listeningForKey = false
 
----------------------------------------------------------------------
-- Notifications
----------------------------------------------------------------------
local notifyGui, notifyHolder
 
function Library:Notify(settings)
	settings = settings or {}
	if not notifyGui or not notifyGui.Parent then
		notifyGui = create("ScreenGui", {
			Name = "Notifications",
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
 
	local card = create("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = Alpha,
		BorderSizePixel = 0,
		Bind = { BackgroundColor3 = "Topbar" },
		Parent = notifyHolder,
	})
	corner(card, 12)
	local title = label(card, settings.Title or "Notification", 14)
	title.Size = UDim2.new(1, -20, 0, 22)
	title.Position = UDim2.fromOffset(10, 5)
	title.Font = Enum.Font.GothamBold
	local body = label(card, settings.Content or "", 12, "SubText")
	body.Size = UDim2.new(1, -20, 0, 26)
	body.Position = UDim2.fromOffset(10, 28)
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
 
	task.delay(settings.Duration or 4, function()
		card:Destroy()
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
	local visible = true
	local toggleBind
 
	local gui = create("ScreenGui", {
		Name = settings.Name or "Window",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
 
	-- Very see-through screen behind the window
	local backdrop = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = BackdropAlpha,
		BorderSizePixel = 0,
		Parent = gui,
	})
 
	local fullSize = UDim2.fromOffset(520, 340)
	local main = create("Frame", {
		Size = fullSize,
		Position = UDim2.new(0.5, -260, 0.5, -170),
		BackgroundTransparency = Alpha,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Bind = { BackgroundColor3 = "Background" },
		Parent = gui,
	})
	corner(main, 14)
 
	-- Topbar
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
 
	local title = label(topbar, settings.Name or "Window", 15)
	title.Size = UDim2.new(1, -80, 1, 0)
	title.Position = UDim2.fromOffset(16, 0)
	title.Font = Enum.Font.GothamBold
 
	local function topButton(text, offset)
		local b = create("TextButton", {
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, offset, 0, 4),
			BackgroundTransparency = 1,
			Text = text,
			Font = Enum.Font.GothamBold,
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
 
	-- Tab list + page container
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
		PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 4),
		Parent = tabBar,
	})
	local pages = create("Frame", {
		Size = UDim2.new(1, -130, 1, 0),
		Position = UDim2.fromOffset(130, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})
 
	-- Dragging
	local dragging, dragStart, startPos
	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, input.Position, main.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
 
	-- Minimize / close
	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		content.Visible = not minimized
		filler.Visible = not minimized
		tween(main, { Size = minimized and UDim2.fromOffset(520, 36) or fullSize }, 0.2)
	end)
	closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
 
	-- Show / hide + toggle key
	function Window:SetVisible(v)
		visible = v
		main.Visible = v
		backdrop.Visible = v
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
		if processed or listeningForKey then return end
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
 
		tabCount += 1
		local tabButton = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = name,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			LayoutOrder = _internal and 1000 or tabCount, -- Settings always last
			Bind = { BackgroundColor3 = "Element" },
			Parent = tabBar,
		})
		corner(tabButton, 10)
 
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
			PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8),
			Parent = page,
		})
 
		local entry = { button = tabButton, page = page }
		table.insert(tabs, entry)
 
		local function styleTab(e)
			local selected = e == selectedTab
			e.button.BackgroundTransparency = selected and Alpha or 1
			e.button.TextColor3 = selected and Theme.Text or Theme.SubText
		end
		local function select()
			selectedTab = entry
			for _, t in ipairs(tabs) do
				t.page.Visible = (t == entry)
				styleTab(t)
			end
		end
		onTheme(tabButton, function() styleTab(entry) end)
		tabButton.MouseButton1Click:Connect(select)
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
 
		-- Button -----------------------------------------------------
		function Tab:CreateButton(o)
			local f = newElement(page)
			local b = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = o.Name or "Button",
				Font = Enum.Font.GothamMedium,
				TextSize = 14,
				Bind = { TextColor3 = "Text" },
				Parent = f,
			})
			hover(b, f)
			b.MouseButton1Click:Connect(function() fire(o.Callback) end)
			return { Destroy = function() f:Destroy() end }
		end
 
		-- Toggle -----------------------------------------------------
		function Tab:CreateToggle(o)
			local value = o.CurrentValue == true
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
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Parent = track,
			})
			corner(knob, 7)
			local click = create("TextButton", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f,
			})
 
			local function paint(animate)
				local color = value and Theme.Accent or Theme.SubText
				local pos = value and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
				if animate then
					tween(track, { BackgroundColor3 = color })
					tween(knob, { Position = pos })
				else
					track.BackgroundColor3 = color
					knob.Position = pos
				end
			end
 
			local Toggle = {}
			function Toggle:Set(v, silent)
				value = v
				paint(true)
				if not silent then fire(o.Callback, v) end
			end
			click.MouseButton1Click:Connect(function() Toggle:Set(not value) end)
			onTheme(track, function() paint(false) end)
			paint(false)
			return Toggle
		end
 
		-- Slider -----------------------------------------------------
		function Tab:CreateSlider(o)
			local min, max = o.Range and o.Range[1] or 0, o.Range and o.Range[2] or 100
			local inc = o.Increment or 1
			local value = o.CurrentValue or min
 
			local f = newElement(page, 52)
			local l = label(f, "", 14)
			l.Size = UDim2.new(1, -24, 0, 24)
			l.Position = UDim2.fromOffset(12, 3)
 
			local bar = create("Frame", {
				Size = UDim2.new(1, -24, 0, 8),
				Position = UDim2.new(0, 12, 1, -18),
				BorderSizePixel = 0,
				Bind = { BackgroundColor3 = "Background" },
				Parent = f,
			})
			corner(bar, 4)
			local fill = create("Frame", {
				Size = UDim2.fromScale(0, 1),
				BorderSizePixel = 0,
				Bind = { BackgroundColor3 = "Accent" },
				Parent = bar,
			})
			corner(fill, 4)
 
			local Slider = {}
			function Slider:Set(v, silent)
				v = math.clamp(math.floor(v / inc + 0.5) * inc, min, max)
				value = v
				fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
				l.Text = string.format("%s: %s%s", o.Name or "Slider", tostring(math.round(v * 100) / 100), o.Suffix and (" " .. o.Suffix) or "")
				if not silent then fire(o.Callback, v) end
			end
 
			local sliding = false
			local function fromX(x)
				local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
				Slider:Set(min + (max - min) * rel)
			end
			bar.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					sliding = true
					fromX(input.Position.X)
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					fromX(input.Position.X)
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					sliding = false
				end
			end)
 
			Slider:Set(value, true)
			return Slider
		end
 
		-- Input ------------------------------------------------------
		function Tab:CreateInput(o)
			local f = newElement(page)
			local l = label(f, o.Name or "Input", 14)
			l.Size = UDim2.new(0.5, -12, 1, 0)
			l.Position = UDim2.fromOffset(12, 0)
 
			local box = create("TextBox", {
				Size = UDim2.new(0.5, -20, 0, 24),
				Position = UDim2.new(0.5, 8, 0.5, -12),
				BorderSizePixel = 0,
				Text = "",
				PlaceholderText = o.PlaceholderText or "",
				Font = Enum.Font.Gotham,
				TextSize = 13,
				ClearTextOnFocus = false,
				Bind = { BackgroundColor3 = "Background", TextColor3 = "Text", PlaceholderColor3 = "SubText" },
				Parent = f,
			})
			corner(box, 8)
			box.FocusLost:Connect(function()
				fire(o.Callback, box.Text)
				if o.RemoveTextAfterFocusLost then box.Text = "" end
			end)
			return { Set = function(_, t) box.Text = t end }
		end
 
		-- Dropdown ---------------------------------------------------
		function Tab:CreateDropdown(o)
			local options = o.Options or {}
			local current = o.CurrentOption or options[1]
 
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
					Font = Enum.Font.Gotham,
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
			return Dropdown
		end
 
		-- Keybind ----------------------------------------------------
		-- Callback(key) fires when the bound key is pressed; Changed(key) fires when rebound.
		function Tab:CreateKeybind(o)
			local key = o.CurrentKeybind or Enum.KeyCode.Unknown
 
			local f = newElement(page)
			local l = label(f, o.Name or "Keybind", 14)
			l.Size = UDim2.new(1, -120, 1, 0)
			l.Position = UDim2.fromOffset(12, 0)
 
			local btn = create("TextButton", {
				Size = UDim2.fromOffset(96, 24),
				Position = UDim2.new(1, -108, 0.5, -12),
				BorderSizePixel = 0,
				Text = key.Name,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Bind = { BackgroundColor3 = "Background", TextColor3 = "Text" },
				Parent = f,
			})
			corner(btn, 8)
 
			local Keybind = {}
			function Keybind:Set(k, silent)
				key = k
				btn.Text = k.Name
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
 
			return Keybind
		end
 
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
	toggleBind = SettingsTab:CreateKeybind({
		Name = "Toggle Window",
		CurrentKeybind = toggleKey,
		Changed = function(key)
			toggleKey = key
		end,
	})
	Window.SettingsTab = SettingsTab
 
	return Window
end
 
----------------------------------------------------------------------
-- Put your own code here (before the return), for example:
--
--   local Window = Library:CreateWindow({ Name = "My Hub" })
--   local Tab = Window:CreateTab("Main")
--   Tab:CreateButton({ Name = "Click Me", Callback = function() print("hi") end })
----------------------------------------------------------------------
 
return Library
