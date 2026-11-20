--[[
    Scals Hub - one script for every game
        loadstring(game:HttpGet("https://raw.githubusercontent.com/rawified/scals-hub/refs/heads/main/hub.lua"))()

    This script is only the UI. All game logic lives in the libraries (each has a .md doc):
        ps5.luau            the UI (console style)
        libs/mm2.lua        Murder Mystery 2: coin farm, role ESP, kill all, event log
        libs/autotap.lua    the tapping game: auto tap
        libs/universal.lua  every game: WalkSpeed, Infinite Jump, Fly, ESP, Aimbot
        libs/outfit.lua     every game: catalog try-on, favorites, saved outfits

    1. Sign in (console style): click your user, enter your Jnkie key (skipped when the saved key
       still works). Signing in opens the hub; the libraries load after that.
    2. A tile per game. Game-specific features have Game = MM2.PlaceIds / Game = Tap.inGame:
       outside that game the card is locked ("ONLY IN ...") and the tile's Play button teleports you.
    3. Tile order: the game you're in first, then the universal tiles, then the other games.
    4. Click your picture (top right) for Change Key, Hide my info, Sign Out and Unload.
    5. After a key check: getgenv().SCRIPT_KEY = the key, getgenv().GuiLibraryUser = { Premium, Tier }.
       Premium = true on a tile / feature locks it for everyone else.
]]
local REPO = "https://raw.githubusercontent.com/rawified/scals-hub/refs/heads/main/"

----------------------------------------------------------------------
-- Jnkie settings (from your Jnkie dashboard)
----------------------------------------------------------------------
local Jnkie = {
	Service = "YOUR_SERVICE_NAME",       -- exact service name: Dashboard > your service
	Identifier = "YOUR_JNKIE_USER_ID",   -- YOUR Jnkie user ID from the dashboard (not a Roblox or Discord ID)
	Provider = "YOUR_PROVIDER_NAME",     -- the provider that makes the Get Key link (e.g. "Mixed")
	AllowKeyless = false,                -- true only if your service has keyless access turned on
}

----------------------------------------------------------------------
-- Hub settings
----------------------------------------------------------------------
local Config = {
	Name = "Scals Hub",
	ToggleKey = Enum.KeyCode.RightControl, -- changeable in Settings
	Folder = "ScalsHub",
	KeyFile = "ScalsHub/key.txt",
	SaveFile = "Hub",                      -- ScalsHub/Hub.json: every toggle / slider is remembered
	Footer = "gg/v4nta",
	Status = "Working / Undetected",
	StatusColor = Color3.fromRGB(52, 199, 123),
	Splash = {
		Image = "rbxassetid://114362863794226",
		Duration = 3.5,
		Subtitle = "hub",
	},
	PremiumText = "Get a premium key to unlock this.",
	TapPlaceId = nil, -- the tapping game's PlaceId, if you know it (gives its tile a Play button)
}

----------------------------------------------------------------------
-- Don't run twice
----------------------------------------------------------------------
local env = (typeof(getgenv) == "function" and getgenv()) or _G
if env.ScalsHubRunning then
	warn("[Scals Hub] Already running. Unload it first (click your picture, top right).")
	return
end
env.ScalsHubRunning = true

-- Download + run, retrying a few times (GitHub can briefly return nothing or an error page)
local function download(url)
	local last = "no response"
	for i = 1, 5 do
		local ok, src = pcall(function() return game:HttpGet(url) end)
		if ok and type(src) == "string" and #src > 0 then
			local fn, err = loadstring(src)
			if fn then return fn() end
			last = "not a script: " .. tostring(err)
		else
			last = ok and "empty response" or tostring(src)
		end
		task.wait(i)
	end
	error("Couldn't download " .. url .. " (" .. last .. ")", 0)
end

local okLib, Library = pcall(download, REPO .. "ps5.luau")
if not okLib then
	env.ScalsHubRunning = nil
	error("[Scals Hub] " .. tostring(Library), 0)
end

----------------------------------------------------------------------
-- Jnkie SDK + keys
----------------------------------------------------------------------
local Junkie
do
	local ok, lib = pcall(function()
		return loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))()
	end)
	if ok and type(lib) == "table" then
		Junkie = lib
		Junkie.service = Jnkie.Service
		Junkie.identifier = Jnkie.Identifier
		Junkie.provider = Jnkie.Provider
	else
		warn("[Scals Hub] Couldn't load the Jnkie SDK: " .. tostring(lib))
	end
end

local hasFiles = typeof(readfile) == "function" and typeof(writefile) == "function" and typeof(isfile) == "function"

local function trim(s)
	return (tostring(s or ""):match("^%s*(.-)%s*$"))
end

local function loadSavedKey()
	if not hasFiles then return nil end
	local ok, key = pcall(function()
		if isfile(Config.KeyFile) then return readfile(Config.KeyFile) end
	end)
	key = ok and key and trim(key)
	return key ~= "" and key or nil
end

local function saveKey(key)
	if not hasFiles then return end
	pcall(function()
		if typeof(makefolder) == "function" and typeof(isfolder) == "function" and not isfolder(Config.Folder) then
			makefolder(Config.Folder)
		end
		writefile(Config.KeyFile, key)
	end)
end

local function clearKey()
	if hasFiles and typeof(delfile) == "function" then
		pcall(function()
			if isfile(Config.KeyFile) then delfile(Config.KeyFile) end
		end)
	end
end

local function friendlyError(err)
	err = tostring(err or "ERROR")
	if err == "ERROR" then return "Couldn't reach Jnkie, try again." end
	if err == "http 429" then return "Too many tries, wait a moment." end
	if err:find("^http ") then return "Key server error (" .. err .. "). Check the Jnkie settings." end
	return "Invalid key (" .. err .. ")"
end

-- what the UI reads (it never talks to Jnkie itself)
local function publishUser(key, premium, tier)
	env.SCRIPT_KEY = key
	if key then
		env.GuiLibraryUser = { Premium = premium == true, Tier = tier }
	else
		env.GuiLibraryUser = nil
	end
end

-- Jnkie's check_key can bind the key to this device and start its expiry timer,
-- so it's called once per key entry / startup, never in a loop
local function checkKey(key)
	key = trim(key)
	if key == "" then return false, "Enter a key first." end
	if not Junkie then return false, "Couldn't load the Jnkie SDK, try again." end
	local ok, result = pcall(Junkie.check_key, key)
	if not ok then
		warn("[Scals Hub] check_key failed: " .. tostring(result))
		return false, "Key check failed. Check the Jnkie settings (F9)."
	end
	if type(result) ~= "table" or not result.valid then
		return false, friendlyError(type(result) == "table" and result.error)
	end
	local tier = result.JD_TIER_NAME or (result.is_premium and "Premium") or (result.is_keyless and "Keyless") or "Free"
	local premium = result.is_premium == true or tostring(tier):lower():find("premium", 1, true) ~= nil
	publishUser(key, premium, tier)
	return true, result
end

local function getKeyLink()
	if not Junkie then return nil, "Couldn't load the Jnkie SDK." end
	local ok, link, err = pcall(Junkie.get_key_link)
	if not ok then
		warn("[Scals Hub] get_key_link failed: " .. tostring(link))
		return nil, "Couldn't get a key link. Check the Jnkie settings (F9)."
	end
	if not link then
		if err == "RATE_LIMITTED" then return nil, "Too many requests, wait a moment." end
		return nil, "Couldn't get a key link (" .. tostring(err) .. ")."
	end
	return link
end

local function notify(title, text, duration)
	Library:Notify({ Title = title, Content = text, Duration = duration or 3 })
end

-- a lib call that can refuse (returns false / nil + reason): show the reason
local function try(ok, reason)
	if not ok and reason then notify(Config.Name, reason, 3) end
	return ok
end

----------------------------------------------------------------------
-- MURDER MYSTERY 2 tile (libs/mm2.lua)
----------------------------------------------------------------------
local function buildMM2(Window, MM2)
	MM2.Notify = function(title, text) notify(title, text, 4) end
	local Farm = MM2.Farm
	local MM2_ONLY = MM2.PlaceIds

	local Tab = Window:CreateTab("Murder Mystery 2", {
		Description = "Coin farm, role ESP and kill all. Only works in MM2.",
		PlaceId = MM2.PlaceIds[1], -- Play button
		ForGame = MM2.PlaceIds,    -- first tile when you're in MM2
		Section = "Farming",
	})
	Tab:CreateToggle({
		Name = "Auto Collect Coins",
		Description = "Flies to the coins for you",
		Game = MM2_ONLY,
		CurrentValue = false,
		Flag = "AutoCollectCoins",
		Callback = function(on) try(MM2.farm(on)) end,
	})
	Tab:CreateDropdown({
		Name = "Farming Mode",
		Description = "Clusters clears the biggest group first",
		Game = MM2_ONLY,
		Options = { "Nearest", "Clusters" },
		CurrentOption = Farm.FarmMode,
		Flag = "CoinFarmMode",
		Callback = function(v) MM2.setFarm({ FarmMode = v }) end,
	})
	Tab:CreateDropdown({
		Name = "Position Mode",
		Description = "Under Floor always uses noclip",
		Game = MM2_ONLY,
		Options = { "Normal", "Under Floor" },
		CurrentOption = Farm.PositionMode,
		Flag = "CoinPositionMode",
		Callback = function(v) MM2.setFarm({ PositionMode = v }) end,
	})
	Tab:CreateSlider({
		Name = "Tween Speed",
		Game = MM2_ONLY,
		Range = { 10, 300 },
		Increment = 1,
		Suffix = "studs/s",
		CurrentValue = Farm.Speed,
		Flag = "CoinTweenSpeed",
		Callback = function(v) MM2.setFarm({ Speed = v }) end,
	})
	Tab:CreateSlider({
		Name = "Cluster Radius",
		Game = MM2_ONLY,
		Range = { 10, 80 },
		Increment = 1,
		Suffix = "studs",
		CurrentValue = Farm.ClusterRadius,
		Flag = "CoinClusterRadius",
		Callback = function(v) MM2.setFarm({ ClusterRadius = v }) end,
	})
	Tab:CreateSlider({
		Name = "Under Floor Depth",
		Game = MM2_ONLY,
		Range = { 0.5, 6 },
		Increment = 0.5,
		Suffix = "studs",
		CurrentValue = Farm.FloorDepth,
		Flag = "CoinFloorDepth",
		Callback = function(v) MM2.setFarm({ FloorDepth = v }) end,
	})
	Tab:CreateToggle({
		Name = "Stop & Reset When Full",
		Description = "Resets when the coin bag is full",
		Game = MM2_ONLY,
		CurrentValue = Farm.StopWhenFull,
		Flag = "CoinStopWhenFull",
		Callback = function(on) MM2.setFarm({ StopWhenFull = on }) end,
	})
	Tab:CreateToggle({
		Name = "Noclip While Farming",
		Game = MM2_ONLY,
		CurrentValue = Farm.Noclip,
		Flag = "CoinNoclip",
		Callback = function(on) MM2.setFarm({ Noclip = on }) end,
	})
	Tab:CreateLabel("Speeds above ~150 may get you flagged.")

	Tab:CreateSection("Visuals")
	Tab:CreateToggle({
		Name = "Role ESP",
		Description = "Red murderer, blue sheriff, green innocent",
		Game = MM2_ONLY,
		CurrentValue = false,
		Flag = "RoleEsp",
		Callback = function(on) try(MM2.esp(on)) end,
	})
	Tab:CreateToggle({
		Name = "Highlights",
		Game = MM2_ONLY,
		CurrentValue = true,
		Flag = "RoleEspHighlights",
		Callback = function(on) MM2.setEsp({ Highlights = on }) end,
	})
	Tab:CreateToggle({
		Name = "Name, Role & Distance",
		Game = MM2_ONLY,
		CurrentValue = true,
		Flag = "RoleEspLabels",
		Callback = function(on) MM2.setEsp({ Labels = on }) end,
	})
	Tab:CreateToggle({
		Name = "Show Innocents",
		Game = MM2_ONLY,
		CurrentValue = true,
		Flag = "RoleEspInnocents",
		Callback = function(on) MM2.setEsp({ ShowInnocents = on }) end,
	})

	Tab:CreateSection("Combat")
	local perTarget = 1.5
	local function killAll()
		local killed, reason = MM2.killAll({ PerTarget = perTarget })
		if killed then
			notify("Kill All", ("Done, %d killed."):format(killed))
		elseif reason then
			notify("Kill All", reason)
		end
	end
	Tab:CreateButton({
		Name = "Kill All",
		Description = "Only when you're the murderer",
		Game = MM2_ONLY,
		Callback = killAll,
	})
	Tab:CreateKeybind({
		Name = "Kill All Hotkey",
		Game = MM2_ONLY,
		CurrentKeybind = Enum.KeyCode.K,
		Flag = "KillAllKey",
		Callback = function() task.spawn(killAll) end,
	})
	Tab:CreateButton({
		Name = "Stop Kill All",
		Game = MM2_ONLY,
		Callback = function() MM2.stopKillAll() end,
	})
	Tab:CreateSlider({
		Name = "Time Per Player",
		Game = MM2_ONLY,
		Range = { 0.5, 5 },
		Increment = 0.5,
		Suffix = "s",
		CurrentValue = perTarget,
		Flag = "KillPerTarget",
		Callback = function(v) perTarget = v end,
	})

	Tab:CreateSection("Debug")
	Tab:CreateToggle({
		Name = "Log Game Events (F9)",
		Description = "Play until a round ends, then check F9",
		Game = MM2_ONLY,
		CurrentValue = false,
		Flag = "DebugLogEvents",
		Callback = function(on) MM2.logEvents(on) end,
	})
end

----------------------------------------------------------------------
-- AUTO TAP tile (libs/autotap.lua)
----------------------------------------------------------------------
local function buildAutoTap(Window, Tap)
	Tap.PlaceId = Config.TapPlaceId or Tap.PlaceId
	local TAP_ONLY = Tap.inGame -- found by the game's tap remote
	local maxRate = Tap.inGame() and Tap.maxRate() or 20

	local Tab = Window:CreateTab("Auto Tap", {
		Description = "Taps for you at a steady rate. Only works in the tapping game.",
		PlaceId = Tap.PlaceId,
		ForGame = TAP_ONLY, -- first tile when you're in the tapping game
		GameName = "the tapping game",
		Section = "Tapping",
	})
	local autoToggle = Tab:CreateToggle({
		Name = "Auto Tap",
		Game = TAP_ONLY,
		GameName = "the tapping game",
		CurrentValue = false,
		Flag = "AutoTap",
		Callback = function(on) try(Tap.auto(on)) end,
	})
	Tab:CreateKeybind({
		Name = "Auto Tap Hotkey",
		Game = TAP_ONLY,
		GameName = "the tapping game",
		CurrentKeybind = Enum.KeyCode.F,
		Flag = "AutoTapKey",
		Callback = function() autoToggle:Set(not autoToggle:Get()) end,
	})
	Tab:CreateSlider({
		Name = "Taps Per Second",
		Description = ("The game ignores more than %d/s"):format(maxRate),
		Game = TAP_ONLY,
		GameName = "the tapping game",
		Range = { 1, maxRate },
		Increment = 1,
		Suffix = "/s",
		CurrentValue = math.min(Tap.Settings.Rate, maxRate),
		Flag = "TapRate",
		Callback = function(v) Tap.set({ Rate = v }) end,
	})
	Tab:CreateDropdown({
		Name = "Method",
		Description = "Game Tap = the game's own sounds + effects",
		Game = TAP_ONLY,
		GameName = "the tapping game",
		Options = { "Remote", "Game Tap" },
		CurrentOption = Tap.Settings.Method,
		Flag = "TapMethod",
		Callback = function(m)
			Tap.set({ Method = m })
			if m == "Game Tap" and not Tap.hasGameTap() then
				notify("Auto Tap", "TapController not found, using Remote instead.", 4)
			end
		end,
	})
	Tab:CreateDropdown({
		Name = "Tap Source",
		Game = TAP_ONLY,
		GameName = "the tapping game",
		Options = Tap.Sources,
		CurrentOption = Tap.Settings.Source,
		Flag = "TapSource",
		Callback = function(s) Tap.set({ Source = s }) end,
	})
	-- live stats: if "Paid out" stays well below "Sent", the server is rate-limiting you
	local statsLabel = Tab:CreateLabel("Sent: 0/s   Paid out: 0/s")
	task.spawn(function()
		while env.ScalsHubRunning do
			task.wait(1)
			local s, p = Tap.stats()
			statsLabel:Set(("Sent: %d/s   Paid out: %d/s"):format(s, p))
		end
	end)
end

----------------------------------------------------------------------
-- UNIVERSAL tile (libs/universal.lua)
----------------------------------------------------------------------
local function buildUniversal(Window, U)
	local Tab = Window:CreateTab("Universal", {
		Description = "Movement, fly, ESP and aimbot. Works in every game.",
		Section = "Player",
	})
	Tab:CreateToggle({
		Name = "Custom WalkSpeed",
		CurrentValue = false,
		Flag = "WalkSpeedEnabled",
		Callback = U.walkSpeed,
	})
	Tab:CreateSlider({
		Name = "WalkSpeed",
		Description = "Roblox default is 16",
		Range = { 16, 200 },
		Increment = 1,
		Suffix = "studs/s",
		CurrentValue = U.Settings.WalkSpeed,
		Flag = "WalkSpeed",
		Callback = U.setWalkSpeed,
	})
	Tab:CreateToggle({
		Name = "Infinite Jump",
		CurrentValue = false,
		Flag = "InfiniteJump",
		Callback = U.infiniteJump,
	})

	Tab:CreateSection("Fly")
	Tab:CreateToggle({
		Name = "Fly",
		Description = "WASD where you look, Space up, Ctrl down",
		CurrentValue = false,
		Flag = "Fly",
		Callback = U.fly,
	})
	Tab:CreateDropdown({
		Name = "Mode",
		Description = "Platform: walk on a part that follows you",
		Options = { "Noclip", "Platform" },
		CurrentOption = U.Fly.Mode,
		Flag = "FlyMode",
		Callback = function(v) U.setFly({ Mode = v }) end,
	})
	Tab:CreateSlider({
		Name = "Fly Speed (Noclip)",
		Range = { 10, 300 },
		Increment = 1,
		Suffix = "studs/s",
		CurrentValue = U.Fly.Speed,
		Flag = "FlySpeed",
		Callback = function(v) U.setFly({ Speed = v }) end,
	})
	Tab:CreateSlider({
		Name = "Up/Down (Platform)",
		Range = { 5, 100 },
		Increment = 1,
		Suffix = "studs/s",
		CurrentValue = U.Fly.VerticalSpeed,
		Flag = "FlyVerticalSpeed",
		Callback = function(v) U.setFly({ VerticalSpeed = v }) end,
	})
	Tab:CreateToggle({
		Name = "Show Platform",
		CurrentValue = U.Fly.ShowPlatform,
		Flag = "FlyShowPlatform",
		Callback = function(on) U.setFly({ ShowPlatform = on }) end,
	})

	Tab:CreateSection("ESP")
	local function espToggle(name, key, desc)
		Tab:CreateToggle({
			Name = name,
			Description = desc,
			CurrentValue = U.Esp[key],
			Flag = "Esp" .. key,
			Callback = function(on) U.setEsp({ [key] = on }) end,
		})
	end
	espToggle("ESP Boxes", "Boxes")
	espToggle("Names & Distance", "Names")
	espToggle("Chams", "Chams", "Roblox draws at most 31 at once")
	Tab:CreateSlider({
		Name = "Chams Fill",
		Range = { 0, 1 },
		Increment = 0.05,
		CurrentValue = U.Esp.ChamsFill,
		Flag = "ChamsFill",
		Callback = function(v) U.setEsp({ ChamsFill = v }) end,
	})
	Tab:CreateDropdown({
		Name = "ESP Color",
		Options = U.EspColors,
		CurrentOption = U.Esp.Color,
		Flag = "EspColor",
		Callback = function(c) U.setEsp({ Color = c }) end,
	})
	espToggle("Team Check", "TeamCheck")
	espToggle("Include NPCs", "IncludeNPCs", "Models with a HumanoidRootPart")

	Tab:CreateSection("Aimbot")
	Tab:CreateToggle({
		Name = "Aimbot",
		CurrentValue = false,
		Flag = "Aimbot",
		Callback = U.aimbot,
	})
	local function aimOption(name, key, options, desc)
		Tab:CreateDropdown({
			Name = name,
			Description = desc,
			Options = options,
			CurrentOption = U.Aim[key],
			Flag = "Aim" .. key,
			Callback = function(v)
				U.setAimbot({ [key] = v })
				if key == "Method" and v == "Mouse" and not U.hasMouseMove() then
					notify("Aimbot", "Your executor has no mousemoverel, using Camera instead.", 4)
				end
			end,
		})
	end
	local function aimToggle(name, key)
		Tab:CreateToggle({
			Name = name,
			CurrentValue = U.Aim[key],
			Flag = "Aim" .. key,
			Callback = function(on) U.setAimbot({ [key] = on }) end,
		})
	end
	aimOption("Activation", "Activation", { "Hold Right Mouse", "Always" })
	aimOption("Aim Part", "Part", { "Head", "Torso" })
	aimOption("Aim Method", "Method", { "Camera", "Mouse" }, "Mouse if the game has its own camera")
	aimToggle("Use FOV", "UseFov")
	aimToggle("Show FOV Circle", "ShowFov")
	Tab:CreateSlider({
		Name = "FOV Radius",
		Range = { 20, 500 },
		Increment = 5,
		Suffix = "px",
		CurrentValue = U.Aim.Fov,
		Flag = "AimFov",
		Callback = function(v) U.setAimbot({ Fov = v }) end,
	})
	Tab:CreateSlider({
		Name = "Smoothing",
		Description = "1 = snap, higher = slower",
		Range = { 1, 20 },
		Increment = 0.5,
		CurrentValue = U.Aim.Smoothing,
		Flag = "AimSmoothing",
		Callback = function(v) U.setAimbot({ Smoothing = v }) end,
	})
	aimToggle("Team Check", "TeamCheck")
	aimToggle("Wall Check", "WallCheck")
	aimToggle("Target NPCs", "IncludeNPCs")
end

----------------------------------------------------------------------
-- SHOOTER tile (libs/shooter.lua): mouse aimbot + recoil control tuned for this game's guns.
-- WalkSpeed, Fly and ESP are on the Universal tile.
----------------------------------------------------------------------
local SHOOTER_NAME = "Shooter"           -- rename to the game's name
local SHOOTER_IDS = { 78884249003161 }   -- PlaceId or GameId (both are checked)

local function buildShooter(Window, S)
	local Tab = Window:CreateTab(SHOOTER_NAME, {
		Description = "Aimbot and recoil control made for this game's guns.",
		Section = "Aimbot",
		ForGame = SHOOTER_IDS, -- first tile in this game
		Game = SHOOTER_IDS,    -- every card only works in this game
		GameName = SHOOTER_NAME,
	})
	local gunLabel = Tab:CreateLabel("Gun: none found yet")
	local alive = true
	Library:OnUnload(function() alive = false end)
	task.spawn(function() -- shows which gun the aimbot is tuned for
		while alive do
			local gun = S.getWeapon()
			pcall(function()
				gunLabel:Set(gun and ("Gun: %s (zoom %s, aim spread %s°, %d rounds)"):format(gun.name, gun.aimFov, gun.spread.aim, gun.mag)
					or "Gun: none found yet (uses average stats)")
			end)
			task.wait(0.5)
		end
	end)
	Tab:CreateToggle({
		Name = "Aimbot",
		CurrentValue = false,
		Flag = "ShooterAimbot",
		Callback = function(on)
			S.aimbot(on)
			if on and not S.hasMouseMove() then
				notify("Aimbot", "Your executor has no mousemoverel, so the aimbot can't move your mouse.", 5)
			end
		end,
	})
	local function aimOption(name, key, options, desc)
		Tab:CreateDropdown({
			Name = name,
			Description = desc,
			Options = options,
			CurrentOption = S.Aim[key],
			Flag = "ShooterAim" .. key,
			Callback = function(v) S.setAimbot({ [key] = v }) end,
		})
	end
	local function aimToggle(name, key, desc)
		Tab:CreateToggle({
			Name = name,
			Description = desc,
			CurrentValue = S.Aim[key],
			Flag = "ShooterAim" .. key,
			Callback = function(on) S.setAimbot({ [key] = on }) end,
		})
	end
	aimOption("Activation", "Activation", { "Hold Right Mouse", "Hold Left or Right Mouse", "Always" }, "Right mouse = aiming down sights")
	aimOption("Aim Part", "Part", { "Auto", "Head", "Torso" }, "Auto: chest when hip fire would miss the head")
	aimToggle("Use FOV", "UseFov")
	aimToggle("Show FOV Circle", "ShowFov")
	Tab:CreateSlider({
		Name = "FOV Radius",
		Range = { 20, 500 },
		Increment = 5,
		Suffix = "px",
		CurrentValue = S.Aim.Fov,
		Flag = "ShooterAimFov",
		Callback = function(v) S.setAimbot({ Fov = v }) end,
	})
	Tab:CreateSlider({
		Name = "Smoothing",
		Description = "1 = snap, higher = slower",
		Range = { 1, 20 },
		Increment = 0.5,
		CurrentValue = S.Aim.Smoothing,
		Flag = "ShooterAimSmoothing",
		Callback = function(v) S.setAimbot({ Smoothing = v }) end,
	})
	aimToggle("Prediction", "Prediction", "Leads moving targets by your ping")
	aimToggle("Team Check", "TeamCheck")
	aimToggle("Wall Check", "WallCheck", "Ignores your own gun")
	aimToggle("Target NPCs", "IncludeNPCs")

	Tab:CreateSection("Recoil")
	Tab:CreateToggle({
		Name = "Recoil Control",
		Description = "Pulls down by your gun's kick while you shoot",
		CurrentValue = false,
		Flag = "ShooterRecoil",
		Callback = function(on)
			S.recoilControl(on)
			if on and not S.hasMouseMove() then
				notify("Recoil Control", "Your executor has no mousemoverel, so this can't move your mouse.", 5)
			end
		end,
	})
	Tab:CreateSlider({
		Name = "Recoil Strength",
		Range = { 0, 100 },
		Increment = 5,
		Suffix = "%",
		CurrentValue = S.Aim.RecoilStrength * 100,
		Flag = "ShooterRecoilStrength",
		Callback = function(v) S.setAimbot({ RecoilStrength = v / 100 }) end,
	})
end

----------------------------------------------------------------------
-- OUTFIT EDITOR tile (libs/outfit.lua): preview grids in full-width panels
----------------------------------------------------------------------
local function buildOutfit(Window, Outfit)
	local TEXT = Color3.fromRGB(240, 244, 252)
	local FONT = Enum.Font.GothamMedium
	local grids = {}

	local function corner(inst, r)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r)
		c.Parent = inst
	end

	local function setStatus(G, msg)
		G.status.Text = tostring(msg)
	end
	-- a message the automatic "N items" line won't overwrite for a few seconds
	local function note(G, msg)
		G.status.Text = tostring(msg)
		G.noteUntil = os.clock() + 3
	end

	local function newGrid(tab, height)
		local host = tab:CreateContainer(height)
		local G = { tiles = {}, count = 0, noteUntil = 0 }
		local status = Instance.new("TextLabel")
		status.BackgroundTransparency = 1
		status.Position = UDim2.fromOffset(14, 8)
		status.Size = UDim2.new(1, -28, 0, 18)
		status.Font = FONT
		status.TextColor3 = TEXT
		status.TextSize = 13
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.TextTruncate = Enum.TextTruncate.AtEnd
		status.Text = "Loading..."
		status.Parent = host
		G.status = status

		local grid = Instance.new("ScrollingFrame")
		grid.BackgroundTransparency = 1
		grid.BorderSizePixel = 0
		grid.Position = UDim2.fromOffset(10, 32)
		grid.Size = UDim2.new(1, -20, 1, -40)
		grid.ScrollBarThickness = 3
		grid.ScrollBarImageColor3 = TEXT
		grid.ScrollingDirection = Enum.ScrollingDirection.Y
		grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
		grid.CanvasSize = UDim2.new()
		grid.Parent = host
		G.grid = grid
		local pad = Instance.new("UIPadding")
		pad.PaddingRight = UDim.new(0, 5)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.Parent = grid
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(1 / 6, -6, 0, 126) -- 6 per row, follows the window width
		layout.CellPadding = UDim2.fromOffset(6, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid

		local more = Instance.new("TextButton")
		more.Text = "Load more"
		more.Font = FONT
		more.TextSize = 13
		more.TextColor3 = TEXT
		more.AutoButtonColor = false
		more.BackgroundColor3 = Color3.new(1, 1, 1)
		more.BackgroundTransparency = 0.85
		more.LayoutOrder = 1000000
		more.Visible = false
		more.Parent = grid
		corner(more, 8)
		G.more = more
		table.insert(grids, G)
		return G
	end

	local function paintTile(t)
		if t.star then t.star.TextTransparency = t.starOn and 0 or 0.65 end
		t.stroke.Enabled = t.isWorn ~= nil and t.isWorn() or false
	end

	-- o = { image, title, sub, onClick, isWorn, entry, corner = { text, on, onClick(tile) } }
	local function makeTile(G, o)
		G.count += 1
		local button = Instance.new("TextButton")
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = Color3.new(1, 1, 1)
		button.BackgroundTransparency = 0.88
		button.LayoutOrder = G.count
		button.Parent = G.grid
		corner(button, 10)
		local stroke = Instance.new("UIStroke") -- white outline = you're wearing it
		stroke.Thickness = 2
		stroke.Color = Color3.new(1, 1, 1)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button
		local thumb = Instance.new("ImageLabel")
		thumb.BackgroundTransparency = 1
		thumb.Position = UDim2.fromOffset(4, 4)
		thumb.Size = UDim2.new(1, -8, 0, 84)
		thumb.ScaleType = Enum.ScaleType.Fit
		thumb.Image = o.image or ""
		thumb.Parent = button
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(6, 90)
		title.Size = UDim2.new(1, -12, 0, 16)
		title.Font = FONT
		title.TextColor3 = TEXT
		title.TextSize = 11
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.Text = o.title or "?"
		title.Parent = button
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromOffset(6, 106)
		sub.Size = UDim2.new(1, -12, 0, 14)
		sub.Font = FONT
		sub.TextColor3 = TEXT
		sub.TextSize = 10
		sub.TextTransparency = 0.35
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Text = o.sub or ""
		sub.Parent = button
		local t = { button = button, stroke = stroke, title = title, isWorn = o.isWorn, entry = o.entry }
		if o.corner then
			local c = Instance.new("TextButton")
			c.AnchorPoint = Vector2.new(1, 0)
			c.Position = UDim2.new(1, -4, 0, 4)
			c.Size = UDim2.fromOffset(22, 22)
			c.BackgroundTransparency = 1
			c.Text = o.corner.text
			c.TextSize = 16
			c.Font = Enum.Font.GothamBold
			c.TextColor3 = TEXT
			c.TextStrokeTransparency = 0.5
			c.ZIndex = 3
			c.Parent = button
			t.star = c
			t.starOn = o.corner.on
			c.MouseButton1Click:Connect(function() o.corner.onClick(t) end)
		end
		button.MouseEnter:Connect(function() button.BackgroundTransparency = 0.78 end)
		button.MouseLeave:Connect(function() button.BackgroundTransparency = 0.88 end)
		button.MouseButton1Click:Connect(o.onClick)
		table.insert(G.tiles, t)
		paintTile(t)
		return t
	end

	local function clearGrid(G)
		for _, t in ipairs(G.tiles) do t.button:Destroy() end
		table.clear(G.tiles)
		G.count = 0
		G.more.Visible = false
		G.grid.CanvasPosition = Vector2.zero
	end

	local catGrid, favGrid, outfitGrid, wearGrid
	local refreshFavorites, refreshOutfits, rebuildWearing

	local function syncStars()
		for _, G in ipairs(grids) do
			for _, t in ipairs(G.tiles) do
				if t.entry and t.star then t.starOn = Outfit.isFavorite(t.entry) end
				paintTile(t)
			end
		end
	end

	-- the library tells us when what you wear changes: outlines + the Wearing list
	Outfit.onChanged(function()
		syncStars()
		if rebuildWearing then rebuildWearing() end
	end)

	local busy = {}
	local function clickEntry(G, entry)
		local key = (entry.Bundle and "b" or "a") .. entry.Id
		if busy[key] then return end
		if Outfit.isEntryWorn(entry) then
			Outfit.removeEntry(entry)
			setStatus(G, "Took off " .. entry.Name)
			return
		end
		busy[key] = true
		setStatus(G, "Loading " .. entry.Name .. "...")
		task.spawn(function()
			local ok, err = Outfit.wearEntry(entry)
			busy[key] = nil
			setStatus(G, ok and ("Wearing " .. entry.Name) or err)
		end)
	end

	local function addEntryTile(G, entry)
		makeTile(G, {
			image = Outfit.thumbnail(entry),
			title = entry.Name,
			sub = (entry.Bundle and "Bundle · " or "") .. (entry.Price or ""),
			entry = entry,
			isWorn = function() return Outfit.isEntryWorn(entry) end,
			onClick = function() clickEntry(G, entry) end,
			corner = {
				text = "★",
				on = Outfit.isFavorite(entry),
				onClick = function()
					local now = Outfit.toggleFavorite(entry)
					refreshFavorites()
					syncStars()
					setStatus(G, now and ("Added " .. entry.Name .. " to favorites") or ("Removed " .. entry.Name .. " from favorites"))
				end,
			},
		})
	end

	-- catalog search: a newer search cancels an older one
	local query = { Category = "Shirts", Sort = "Relevance", Keyword = "" }
	local searchToken = 0
	local results
	local function showCount()
		catGrid.more.Visible = results ~= nil and not results.IsFinished
		if #catGrid.tiles == 0 then
			setStatus(catGrid, "Nothing found.")
		else
			setStatus(catGrid, ("%d items. Click to wear, again to take off, star to favorite."):format(#catGrid.tiles))
		end
	end
	local function search()
		if not catGrid then return end
		searchToken += 1
		local mine = searchToken
		results = nil
		clearGrid(catGrid)
		setStatus(catGrid, "Searching...")
		task.spawn(function()
			local r, err = Outfit.search(query)
			if mine ~= searchToken then return end
			if not r then
				setStatus(catGrid, err)
				return
			end
			results = r
			for _, entry in ipairs(r.Items) do addEntryTile(catGrid, entry) end
			showCount()
		end)
	end
	local loadingMore = false
	local function loadMore()
		if not results or results.IsFinished or loadingMore then return end
		loadingMore = true
		local mine = searchToken
		catGrid.more.Text = "Loading..."
		task.spawn(function()
			local items, err = results:more()
			loadingMore = false
			catGrid.more.Text = "Load more"
			if mine ~= searchToken then return end
			if not items then
				setStatus(catGrid, err)
				return
			end
			for _, entry in ipairs(items) do addEntryTile(catGrid, entry) end
			showCount()
		end)
	end

	refreshFavorites = function()
		if not favGrid then return end
		clearGrid(favGrid)
		local favs = Outfit.favorites()
		for _, e in ipairs(favs) do addEntryTile(favGrid, e) end
		setStatus(favGrid, #favs == 0 and "No favorites yet. Click the star on any item in the catalog."
			or ("%d favorites. Click to wear, star to remove."):format(#favs))
	end

	local wearingOutfit = false
	local deleteArmed
	refreshOutfits = function()
		if not outfitGrid then return end
		clearGrid(outfitGrid)
		local list = Outfit.outfits()
		for _, o in ipairs(list) do
			local first = o.Items and o.Items[1]
			makeTile(outfitGrid, {
				image = first and Outfit.thumbnail({ Id = first }) or "",
				title = o.Name,
				sub = ("%d items"):format(o.Items and #o.Items or 0),
				onClick = function()
					if wearingOutfit then return end
					wearingOutfit = true
					setStatus(outfitGrid, "Putting on " .. o.Name .. "...")
					task.spawn(function()
						local n = Outfit.wearOutfit(o)
						wearingOutfit = false
						setStatus(outfitGrid, ("Wearing %s (%d of %d items)"):format(o.Name, n, o.Items and #o.Items or 0))
					end)
				end,
				corner = {
					text = "X",
					on = true,
					onClick = function()
						if deleteArmed ~= o.Name then -- two clicks to delete
							deleteArmed = o.Name
							setStatus(outfitGrid, "Click X again to delete " .. o.Name)
							task.delay(3, function()
								if deleteArmed == o.Name then deleteArmed = nil end
							end)
							return
						end
						deleteArmed = nil
						Outfit.deleteOutfit(o.Name)
						refreshOutfits()
						setStatus(outfitGrid, "Deleted " .. o.Name)
					end,
				},
			})
		end
		setStatus(outfitGrid, #list == 0 and "No saved outfits yet. Wear some items, then save them with a name."
			or ("%d saved outfits. Click one to wear it."):format(#list))
	end

	rebuildWearing = function()
		if not wearGrid then return end
		clearGrid(wearGrid)
		local ids = Outfit.worn()
		for _, id in ipairs(ids) do
			local t = makeTile(wearGrid, {
				image = Outfit.thumbnail({ Id = id }),
				title = "Item " .. id,
				sub = Outfit.kind(id),
				isWorn = function() return Outfit.isWorn(id) end,
				onClick = function()
					Outfit.remove(id)
					note(wearGrid, "Took off item " .. id)
				end,
			})
			Outfit.getName(id, function(itemName)
				if t.title.Parent then t.title.Text = itemName end
			end)
		end
		if os.clock() >= wearGrid.noteUntil then
			setStatus(wearGrid, #ids == 0 and "Nothing on yet. Pick items in the catalog, favorites or outfits."
				or ("%d items on. Click one to take it off."):format(#ids))
		end
	end

	local Tab = Window:CreateTab("Outfit Editor", {
		Description = "Try on anything from the catalog. Only you see it.",
		Section = "Catalog",
	})
	Tab:CreateDropdown({
		Name = "Category",
		Options = Outfit.Categories,
		CurrentOption = query.Category,
		Flag = "OutfitCategory",
		Callback = function(c)
			query.Category = c
			search()
		end,
	})
	Tab:CreateDropdown({
		Name = "Sort",
		Options = Outfit.Sorts,
		CurrentOption = query.Sort,
		Flag = "OutfitSort",
		Callback = function(s)
			query.Sort = s
			search()
		end,
	})
	Tab:CreateInput({
		Name = "Search",
		PlaceholderText = "Search the catalog...",
		RemoveTextAfterFocusLost = false,
		Flag = "OutfitSearch",
		Callback = function(t)
			query.Keyword = t
			search()
		end,
	})
	Tab:CreateToggle({
		Name = "Keep After Respawn",
		CurrentValue = true,
		Flag = "OutfitKeep",
		Callback = Outfit.keepOnRespawn,
	})
	catGrid = newGrid(Tab, 300)
	catGrid.more.MouseButton1Click:Connect(loadMore)

	Tab:CreateSection("Wearing")
	Tab:CreateInput({
		Name = "Wear by ID",
		PlaceholderText = "Item / bundle ID or link",
		RemoveTextAfterFocusLost = true,
		Callback = function(t)
			t = tostring(t)
			local id = tonumber(t:match("%d+"))
			if not id then return end
			local isBundle = t:lower():find("bundle") ~= nil
			note(wearGrid, "Loading " .. id .. "...")
			task.spawn(function()
				local ok, err
				if isBundle then ok, err = Outfit.wearBundle(id) else ok, err = Outfit.wear(id) end
				note(wearGrid, ok and ("Wearing " .. id) or err)
				if not ok then notify("Outfit", err, 4) end
			end)
		end,
	})
	Tab:CreateButton({
		Name = "Remove My Accessories",
		Description = "Reset Outfit puts them back",
		Callback = function()
			note(wearGrid, ("Took off %d of your own accessories."):format(Outfit.removeMyAccessories()))
		end,
	})
	Tab:CreateButton({
		Name = "Reset Outfit",
		Description = "Back to your own avatar",
		Callback = function()
			Outfit.reset()
			note(wearGrid, "Back to your own avatar.")
		end,
	})
	wearGrid = newGrid(Tab, 240)

	Tab:CreateSection("Favorites")
	favGrid = newGrid(Tab, 270)

	Tab:CreateSection("Outfits")
	Tab:CreateInput({
		Name = "Save Outfit As",
		Description = "Same name overwrites it",
		PlaceholderText = "Outfit name",
		RemoveTextAfterFocusLost = true,
		Callback = function(t)
			local outfitName = trim(t)
			if outfitName == "" then return end
			if #Outfit.worn() == 0 then
				setStatus(outfitGrid, "Wear something first, then save it.")
				return
			end
			local n = Outfit.saveOutfit(outfitName)
			refreshOutfits()
			setStatus(outfitGrid, ("Saved %s (%d items)"):format(outfitName, n))
			notify("Outfit Saved", outfitName)
		end,
	})
	outfitGrid = newGrid(Tab, 270)
	Tab:CreateLabel(hasFiles and ("Favorites and outfits are saved to " .. Outfit.DataFile)
		or "No file access: favorites and outfits are lost when you leave.")

	task.defer(function()
		search()
		refreshFavorites()
		refreshOutfits()
		rebuildWearing()
	end)
end

----------------------------------------------------------------------
-- Hub window + sign-in
----------------------------------------------------------------------
local Window
local signingIn = false
local openSignIn -- defined below
local saved, savedOk, savedReason -- the saved key, and whether it still works

-- name, library file, tile builder
local Sections = {
	{ "Murder Mystery 2", "scripts/mm2.lua", buildMM2 },
	{ "Auto Tap", "scripts/autotap.lua", buildAutoTap },
	{ "Universal", "scripts/universal.lua", buildUniversal },
	{ "Voxel Wars", "libs/shooter.lua", buildShooter },
	{ "Outfit Editor", "libs/outfit.lua", buildOutfit },
}
local loadedLibs = {}

local function buildHub()
	Window = Library:CreateWindow({
		Name = Config.Name,
		ToggleKey = Config.ToggleKey,
		StartHidden = true, -- shown once everything is built
		Splash = false,     -- the sign-in already played the boot animation
		PremiumText = Config.PremiumText,
		QueueOnTeleport = REPO .. "hub.lua", -- Play teleports: the hub comes back in the new server
		ConfigurationSaving = { Enabled = true, FolderName = Config.Folder, FileName = Config.SaveFile },
		ChangeKey = function()
			if signingIn then return end
			Window:SetVisible(false)
			openSignIn("change")
		end,
		-- Sign Out (picture menu): everything switches off, back to the user screen
		SignOut = function()
			if signingIn then return end
			Window._StopFeatures()
			Window:SetVisible(false)
			openSignIn("signout")
		end,
	})
	Library:OnUnload(function()
		for _, lib in ipairs(loadedLibs) do
			if type(lib.destroy) == "function" then pcall(lib.destroy) end
		end
		env.ScalsHubRunning = nil
	end)
	-- each library + tile on its own: one that fails to download or errors can't take the rest down
	for _, s in ipairs(Sections) do
		local ok, lib = pcall(download, REPO .. s[2])
		if ok and type(lib) == "table" then
			table.insert(loadedLibs, lib)
			local built, err = pcall(s[3], Window, lib)
			if not built then warn("[Scals Hub] " .. s[1] .. " failed: " .. tostring(err)) end
		else
			warn("[Scals Hub] Couldn't load " .. s[2] .. ": " .. tostring(lib))
			notify(Config.Name, s[1] .. " couldn't be loaded. Check F9.", 5)
		end
	end
	Window:SetVisible(true)
end

-- mode: "first" (startup), "change" (Change Key: key screen, closing keeps your key),
-- "signout" (Sign Out: user screen, closing it unloads the hub)
openSignIn = function(mode)
	signingIn = true
	local changing = mode == "change"
	local Loader
	local gettingLink = false
	Loader = Library:CreateLoader({
		Name = Config.Name,
		Footer = Config.Footer,
		Status = { Text = Config.Status, Color = Config.StatusColor },
		Splash = mode == "first" and Config.Splash or nil,
		Home = false, -- signing in goes straight into the hub
		StartScreen = changing and "key" or nil,
		StartPage = (not changing and (savedOk or (mode == "signout" and env.SCRIPT_KEY))) and "Main" or "Key",
		LoginText = changing and "Enter your new key" or nil,
		OnLoad = function()
			signingIn = false
			if Window then
				Window:SetVisible(true)
			else
				buildHub()
			end
		end,
		OnClose = function()
			signingIn = false
			if mode == "signout" then
				Library:Unload() -- signed out and closed: nothing keeps running
			elseif changing and Window then
				Window:SetVisible(true) -- keeps the key you had
			elseif not Window then
				env.ScalsHubRunning = nil -- closed before signing in
			end
		end,
		Key = {
			Note = "Press Get Key, finish the steps, then paste your key here.",
			OnGetKey = function()
				if gettingLink then return end
				gettingLink = true
				Loader:SetKeyStatus("Getting your key link...")
				local link, err = getKeyLink()
				gettingLink = false
				if not link then
					Loader:SetKeyStatus(err, true)
				elseif typeof(setclipboard) == "function" then
					pcall(setclipboard, link)
					Loader:SetKeyStatus("Key link copied, open it in your browser.")
				else
					Loader:SetKeyStatus(link)
				end
			end,
			Check = checkKey,
			OnSuccess = function(key)
				saveKey(trim(key))
				notify("Key Accepted", "Welcome to " .. Config.Name .. ".")
			end,
		},
	})
	return Loader
end

----------------------------------------------------------------------
-- Start: a saved key (or keyless access) is checked once, then the sign-in screen opens
----------------------------------------------------------------------
saved = loadSavedKey()
savedOk = false
if saved then
	savedOk, savedReason = checkKey(saved)
	if not savedOk then clearKey() end
elseif Jnkie.AllowKeyless then
	savedOk = checkKey("KEYLESS")
end

local firstLoader = openSignIn("first")
if saved and not savedOk then
	firstLoader:SetKeyStatus("Saved key no longer works: " .. tostring(savedReason), true)
end
