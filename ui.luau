--[[
	Rayfield/Sirius-style GUI library (self-contained)
	Place as a LocalScript in StarterPlayer > StarterPlayerScripts

	API:
		Library:CreateWindow({Name = "..."})
		Window:CreateTab("Name")
		Tab:CreateButton / CreateToggle / CreateSlider / CreateInput / CreateDropdown / CreateLabel
		Library:Notify({Title, Content, Duration})
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Library = {}

local Theme = {
	Background = Color3.fromRGB(25, 25, 30),
	Topbar = Color3.fromRGB(35, 35, 42),
	Element = Color3.fromRGB(40, 40, 48),
	ElementHover = Color3.fromRGB(54, 54, 64),
	Accent = Color3.fromRGB(90, 120, 255),
	Text = Color3.fromRGB(240, 240, 245),
	SubText = Color3.fromRGB(160, 160, 170),
}

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

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
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
		BackgroundColor3 = Theme.Element,
		BorderSizePixel = 0,
		Parent = page,
	})
	corner(frame)
	return frame
end

local function label(parent, text, size, color, align)
	return create("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color or Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = size or 14,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

----------------------------------------------------------------------
-- Notifications
----------------------------------------------------------------------
local notifyGui, notifyHolder

function Library:Notify(settings)
	settings = settings or {}
	if not notifyGui then
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
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.Topbar,
		BorderSizePixel = 0,
		Parent = notifyHolder,
	})
	corner(card, 8)
	local title = label(card, settings.Title or "Notification", 14)
	title.Size = UDim2.new(1, -16, 0, 22)
	title.Position = UDim2.fromOffset(8, 4)
	title.Font = Enum.Font.GothamBold
	local body = label(card, settings.Content or "", 12, Theme.SubText)
	body.Size = UDim2.new(1, -16, 0, 26)
	body.Position = UDim2.fromOffset(8, 26)
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
	local Window = {}
	local tabs = {}
	local selectedTab

	local gui = create("ScreenGui", {
		Name = settings.Name or "Window",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	local fullSize = UDim2.fromOffset(520, 340)
	local main = create("Frame", {
		Size = fullSize,
		Position = UDim2.new(0.5, -260, 0.5, -170),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
	})
	corner(main, 8)

	-- Topbar
	local topbar = create("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.Topbar,
		BorderSizePixel = 0,
		Parent = main,
	})
	local title = label(topbar, settings.Name or "Window", 15)
	title.Size = UDim2.new(1, -80, 1, 0)
	title.Position = UDim2.fromOffset(12, 0)
	title.Font = Enum.Font.GothamBold

	local function topButton(text, offset)
		local b = create("TextButton", {
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, offset, 0, 4),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = Theme.SubText,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			Parent = topbar,
		})
		b.MouseEnter:Connect(function() b.TextColor3 = Theme.Text end)
		b.MouseLeave:Connect(function() b.TextColor3 = Theme.SubText end)
		return b
	end
	local closeBtn = topButton("X", -34)
	local minBtn = topButton("-", -64)

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
	create("UIListLayout", { Padding = UDim.new(0, 4), Parent = tabBar })
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

	-- Close / minimize
	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		content.Visible = not minimized
		tween(main, { Size = minimized and UDim2.fromOffset(520, 36) or fullSize }, 0.2)
	end)
	closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

	function Window:Destroy() gui:Destroy() end

	------------------------------------------------------------------
	-- Tabs
	------------------------------------------------------------------
	function Window:CreateTab(name)
		local Tab = {}

		local tabButton = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Theme.Element,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = name,
			TextColor3 = Theme.SubText,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			Parent = tabBar,
		})
		corner(tabButton)

		local page = create("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Visible = false,
			Parent = pages,
		})
		create("UIListLayout", { Padding = UDim.new(0, 6), Parent = page })
		create("UIPadding", {
			PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8),
			Parent = page,
		})

		local entry = { button = tabButton, page = page }
		table.insert(tabs, entry)

		local function select()
			for _, t in ipairs(tabs) do
				t.page.Visible = false
				t.button.BackgroundTransparency = 1
				t.button.TextColor3 = Theme.SubText
			end
			page.Visible = true
			tabButton.BackgroundTransparency = 0
			tabButton.TextColor3 = Theme.Text
			selectedTab = entry
		end
		tabButton.MouseButton1Click:Connect(select)
		if not selectedTab then select() end

		-- Label ------------------------------------------------------
		function Tab:CreateLabel(text)
			local f = newElement(page, 28)
			local l = label(f, text, 13, Theme.SubText)
			l.Size = UDim2.new(1, -20, 1, 0)
			l.Position = UDim2.fromOffset(10, 0)
			return { Set = function(_, t) l.Text = t end }
		end

		-- Button -----------------------------------------------------
		function Tab:CreateButton(o)
			local f = newElement(page)
			local b = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = o.Name or "Button",
				TextColor3 = Theme.Text,
				Font = Enum.Font.GothamMedium,
				TextSize = 14,
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
			l.Size = UDim2.new(1, -70, 1, 0)
			l.Position = UDim2.fromOffset(10, 0)

			local track = create("Frame", {
				Size = UDim2.fromOffset(38, 18),
				Position = UDim2.new(1, -48, 0.5, -9),
				BackgroundColor3 = Theme.Background,
				BorderSizePixel = 0,
				Parent = f,
			})
			corner(track, 9)
			local knob = create("Frame", {
				Size = UDim2.fromOffset(14, 14),
				Position = UDim2.fromOffset(2, 2),
				BackgroundColor3 = Theme.Text,
				BorderSizePixel = 0,
				Parent = track,
			})
			corner(knob, 7)

			local click = create("TextButton", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f,
			})

			local Toggle = {}
			function Toggle:Set(v, silent)
				value = v
				tween(track, { BackgroundColor3 = v and Theme.Accent or Theme.Background })
				tween(knob, { Position = v and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2) })
				if not silent then fire(o.Callback, v) end
			end
			click.MouseButton1Click:Connect(function() Toggle:Set(not value) end)
			Toggle:Set(value, true)
			return Toggle
		end

		-- Slider -----------------------------------------------------
		function Tab:CreateSlider(o)
			local min, max = o.Range and o.Range[1] or 0, o.Range and o.Range[2] or 100
			local inc = o.Increment or 1
			local value = o.CurrentValue or min

			local f = newElement(page, 50)
			local l = label(f, "", 14)
			l.Size = UDim2.new(1, -20, 0, 24)
			l.Position = UDim2.fromOffset(10, 2)

			local bar = create("Frame", {
				Size = UDim2.new(1, -20, 0, 8),
				Position = UDim2.new(0, 10, 1, -16),
				BackgroundColor3 = Theme.Background,
				BorderSizePixel = 0,
				Parent = f,
			})
			corner(bar, 4)
			local fill = create("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
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
			l.Size = UDim2.new(0.5, -10, 1, 0)
			l.Position = UDim2.fromOffset(10, 0)

			local box = create("TextBox", {
				Size = UDim2.new(0.5, -18, 0, 24),
				Position = UDim2.new(0.5, 8, 0.5, -12),
				BackgroundColor3 = Theme.Background,
				BorderSizePixel = 0,
				Text = "",
				PlaceholderText = o.PlaceholderText or "",
				PlaceholderColor3 = Theme.SubText,
				TextColor3 = Theme.Text,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				ClearTextOnFocus = false,
				Parent = f,
			})
			corner(box, 4)
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
			l.Size = UDim2.new(1, -40, 1, 0)
			l.Position = UDim2.fromOffset(10, 0)
			local arrow = label(header, "v", 14, Theme.SubText, Enum.TextXAlignment.Center)
			arrow.Size = UDim2.fromOffset(30, 34)
			arrow.Position = UDim2.new(1, -34, 0, 0)

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

			local function toggle(state)
				open = state
				local h = open and (38 + #options * 29 + 4) or 34
				tween(f, { Size = UDim2.new(1, 0, 0, h) })
				arrow.Text = open and "^" or "v"
			end
			header.MouseButton1Click:Connect(function() toggle(not open) end)

			for _, opt in ipairs(options) do
				local ob = create("TextButton", {
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundColor3 = Theme.Background,
					BorderSizePixel = 0,
					Text = tostring(opt),
					TextColor3 = Theme.Text,
					Font = Enum.Font.Gotham,
					TextSize = 13,
					Parent = list,
				})
				corner(ob, 4)
				ob.MouseButton1Click:Connect(function()
					Dropdown:Set(opt)
					toggle(false)
				end)
			end

			refreshHeader()
			return Dropdown
		end

		return Tab
	end

	return Window
end

----------------------------------------------------------------------
-- Example usage (delete or replace with your own)
----------------------------------------------------------------------
local Window = Library:CreateWindow({ Name = "My Hub" })

local Main = Window:CreateTab("Main")
Main:CreateLabel("Welcome! Items below were added with the API.")

Main:CreateButton({
	Name = "Say Hello",
	Callback = function()
		Library:Notify({ Title = "Hello", Content = "Button clicked!", Duration = 3 })
	end,
})

Main:CreateToggle({
	Name = "Example Toggle",
	CurrentValue = false,
	Callback = function(value)
		print("Toggle:", value)
	end,
})

Main:CreateSlider({
	Name = "Example Slider",
	Range = { 0, 100 },
	Increment = 1,
	Suffix = "%",
	CurrentValue = 50,
	Callback = function(value)
		print("Slider:", value)
	end,
})

local Extra = Window:CreateTab("Extra")
Extra:CreateInput({
	Name = "Your Name",
	PlaceholderText = "Type here...",
	Callback = function(text)
		print("Input:", text)
	end,
})

Extra:CreateDropdown({
	Name = "Mode",
	Options = { "Easy", "Normal", "Hard" },
	CurrentOption = "Normal",
	Callback = function(option)
		print("Selected:", option)
	end,
})

return Library