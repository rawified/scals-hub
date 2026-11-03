--[[
    Scals Hub - Iterations library
    Walk through children / descendants, find things anywhere in the game, wait for things to appear.

        local Iter = loadstring(game:HttpGet(REPO .. "libs/iterations.lua"))()

    QUERIES
    Almost every function takes a "query" that decides what matches. It can be:
        "Coin"                               -- exact Name
        function(inst) return ... end        -- your own test
        {                                    -- table: every field you set must match
            Name = "Coin",                   --   exact name (or a list: { "Coin", "Gem" })
            Pattern = "^Coin%d+$",           --   Lua pattern on the name
            Contains = "coin",               --   name contains this (case-insensitive)
            Class = "Part",                  --   exact ClassName (or a list)
            IsA = "BasePart",                --   inst:IsA(...) (or a list, any of them)
            Parent = "Coins",                --   parent's name
            Ancestor = workspace.Map,        --   is inside this instance
            HasChild = "TouchInterest",      --   has a child with this name
            Tag = "Collectable",             --   CollectionService tag
            Attribute = "Value",             --   has this attribute
            Attributes = { Rarity = "Gold" },--   attributes equal these values
            Props = { Transparency = 0 },    --   properties equal these values
            Where = function(inst) end,      --   extra test
        }
        nil                                  -- matches everything

    ITERATING (generic for-loops)
        for inst in Iter.children(folder, query) do ... end
        for inst in Iter.descendants(workspace, { IsA = "BasePart" }) do ... end
        for folder in Iter.folders(workspace) do ... end          -- Folders and Models
        for inst, depth in Iter.walk(root, query, maxDepth) do    -- breadth-first, with depth
        Iter.forEach(root, query, fn, { Deep = true, YieldEvery = 5000 })  -- fn returning false stops

    FINDING
        Iter.find(root, query)                 -- first match (deep) or nil
        Iter.findAll(root, query, opts)        -- list of matches  (opts: Deep, Limit, YieldEvery)
        Iter.findInWorkspace(query)            -- first match in workspace
        Iter.findAnywhere(query, opts)         -- searches every common service (opts.All = true -> list)
        Iter.nearest(root, query, position, maxDistance)  -- closest BasePart/Model match
        Iter.count(root, query)
        Iter.path("Workspace.Map.Coins")       -- resolve a dotted path (also game.Workspace...)
        Iter.getPath(inst)                     -- "Workspace.Map.Coins.Coin"

    WAITING / WATCHING
        Iter.waitFor(root, query, timeout)     -- yields until a match exists (nil on timeout)
        local w = Iter.watch(root, query, onAdded, onRemoved, { Existing = true })
        w:Disconnect()

    DEBUG
        Iter.tree(root, maxDepth)              -- prints a tree to F9
]]

local Iter = {}

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

----------------------------------------------------------------------
-- Queries
----------------------------------------------------------------------
local function asList(v)
	if v == nil then return nil end
	if type(v) == "table" then return v end
	return { v }
end

local function inList(list, value)
	for _, v in ipairs(list) do
		if v == value then return true end
	end
	return false
end

-- Turns a query (nil / string / function / table) into a function(inst) -> bool
function Iter.compile(query)
	if query == nil then
		return function() return true end
	end
	if type(query) == "function" then
		return function(inst)
			local ok, res = pcall(query, inst)
			return ok and res and true or false
		end
	end
	if type(query) == "string" then
		return function(inst) return inst.Name == query end
	end
	assert(type(query) == "table", "[Iterations] query must be nil, a string, a function or a table")

	local names = asList(query.Name)
	local classes = asList(query.Class)
	local isAs = asList(query.IsA)
	local contains = query.Contains and query.Contains:lower()

	return function(inst)
		if names and not inList(names, inst.Name) then return false end
		if classes and not inList(classes, inst.ClassName) then return false end
		if isAs then
			local any = false
			for _, c in ipairs(isAs) do
				if inst:IsA(c) then any = true break end
			end
			if not any then return false end
		end
		if query.Pattern and not inst.Name:match(query.Pattern) then return false end
		if contains and not inst.Name:lower():find(contains, 1, true) then return false end
		if query.Parent and not (inst.Parent and inst.Parent.Name == query.Parent) then return false end
		if query.Ancestor and not inst:IsDescendantOf(query.Ancestor) then return false end
		if query.HasChild and not inst:FindFirstChild(query.HasChild) then return false end
		if query.Tag and not CollectionService:HasTag(inst, query.Tag) then return false end
		if query.Attribute and inst:GetAttribute(query.Attribute) == nil then return false end
		if query.Attributes then
			for k, v in pairs(query.Attributes) do
				if inst:GetAttribute(k) ~= v then return false end
			end
		end
		if query.Props then
			for k, v in pairs(query.Props) do
				local ok, val = pcall(function() return inst[k] end)
				if not ok or val ~= v then return false end
			end
		end
		if query.Where then
			local ok, res = pcall(query.Where, inst)
			if not (ok and res) then return false end
		end
		return true
	end
end

-- Accepts a query or an already compiled matcher
local function matcher(query)
	if type(query) == "table" and query.__compiled then return query.fn end
	return Iter.compile(query)
end

----------------------------------------------------------------------
-- Iterators
----------------------------------------------------------------------
-- for inst in Iter.children(parent, query) do
function Iter.children(parent, query)
	local match = matcher(query)
	local list = parent:GetChildren()
	local i = 0
	return function()
		while true do
			i += 1
			local inst = list[i]
			if inst == nil then return nil end
			if match(inst) then return inst end
		end
	end
end

-- for inst in Iter.descendants(root, query) do
function Iter.descendants(root, query)
	local match = matcher(query)
	local list = root:GetDescendants()
	local i = 0
	return function()
		while true do
			i += 1
			local inst = list[i]
			if inst == nil then return nil end
			if match(inst) then return inst end
		end
	end
end

-- Folders and Models directly inside parent (Deep = true for all of them)
function Iter.folders(parent, deep)
	local q = { IsA = { "Folder", "Model" } }
	return deep and Iter.descendants(parent, q) or Iter.children(parent, q)
end

-- Breadth-first walk that also gives the depth (1 = direct child). maxDepth is optional.
function Iter.walk(root, query, maxDepth)
	local match = matcher(query)
	local queue, head = {}, 1
	for _, c in ipairs(root:GetChildren()) do
		table.insert(queue, { c, 1 })
	end
	return function()
		while head <= #queue do
			local item = queue[head]
			queue[head] = nil
			head += 1
			local inst, depth = item[1], item[2]
			if not maxDepth or depth < maxDepth then
				for _, c in ipairs(inst:GetChildren()) do
					table.insert(queue, { c, depth + 1 })
				end
			end
			if match(inst) then return inst, depth end
		end
		return nil
	end
end

-- Calls fn(inst) for every match. fn returning false stops early.
-- opts.Deep (default true), opts.YieldEvery = N waits a frame every N instances (big maps)
function Iter.forEach(root, query, fn, opts)
	opts = opts or {}
	local match = matcher(query)
	local list = (opts.Deep == false) and root:GetChildren() or root:GetDescendants()
	local every = opts.YieldEvery
	for i, inst in ipairs(list) do
		if match(inst) and fn(inst) == false then return end
		if every and i % every == 0 then task.wait() end
	end
end

----------------------------------------------------------------------
-- Finding
----------------------------------------------------------------------
function Iter.find(root, query, deep)
	local match = matcher(query)
	-- fast path for a plain name
	if type(query) == "string" then
		return root:FindFirstChild(query, deep ~= false)
	end
	local list = (deep == false) and root:GetChildren() or root:GetDescendants()
	for _, inst in ipairs(list) do
		if match(inst) then return inst end
	end
	return nil
end

-- opts: Deep (default true), Limit, YieldEvery
function Iter.findAll(root, query, opts)
	opts = opts or {}
	local out = {}
	Iter.forEach(root, query, function(inst)
		table.insert(out, inst)
		if opts.Limit and #out >= opts.Limit then return false end
	end, opts)
	return out
end

function Iter.findInWorkspace(query)
	return Iter.find(workspace, query)
end

-- Every place game objects usually live (that the client can read)
local SEARCH_SERVICES = {
	"Workspace", "ReplicatedStorage", "ReplicatedFirst", "Lighting",
	"StarterGui", "StarterPack", "StarterPlayer", "Teams", "SoundService", "Players",
}

-- opts.All = true -> list of every match; opts.Services = { ... } to choose where
function Iter.findAnywhere(query, opts)
	opts = opts or {}
	local out = {}
	local function search(root)
		if not root then return nil end
		if opts.All then
			for _, inst in ipairs(Iter.findAll(root, query, opts)) do
				table.insert(out, inst)
			end
		else
			return Iter.find(root, query)
		end
	end

	for _, name in ipairs(opts.Services or SEARCH_SERVICES) do
		local ok, service = pcall(game.GetService, game, name)
		local hit = ok and search(service)
		if hit then return hit end
	end
	-- your own PlayerGui / Backpack too
	local me = Players.LocalPlayer
	if me then
		for _, name in ipairs({ "PlayerGui", "Backpack", "PlayerScripts" }) do
			local hit = search(me:FindFirstChild(name))
			if hit then return hit end
		end
	end
	return opts.All and out or nil
end

local function positionOf(inst)
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then
		local ok, cf = pcall(inst.GetPivot, inst)
		if ok then return cf.Position end
	end
	if inst:IsA("Attachment") then return inst.WorldPosition end
	return nil
end
Iter.positionOf = positionOf

-- Closest match to a position (default: your character). Returns inst, distance.
function Iter.nearest(root, query, position, maxDistance)
	if not position then
		local char = Players.LocalPlayer and Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		position = hrp and hrp.Position
	end
	if not position then return nil end
	local best, bestDist = nil, maxDistance or math.huge
	Iter.forEach(root, query, function(inst)
		local p = positionOf(inst)
		if p then
			local d = (p - position).Magnitude
			if d < bestDist then best, bestDist = inst, d end
		end
	end)
	return best, best and bestDist or nil
end

function Iter.count(root, query, deep)
	local n = 0
	Iter.forEach(root, query, function() n += 1 end, { Deep = deep })
	return n
end

-- "Workspace.Map.Coins" / "game.Workspace.Map" / "ReplicatedStorage/Remotes/Buy"
function Iter.path(path, root)
	local current = root or game
	for part in path:gmatch("[^%./]+") do
		if part == "game" and current == game then
			-- skip
		elseif part == "workspace" or (part == "Workspace" and current == game) then
			current = workspace
		else
			local child = current:FindFirstChild(part)
			if not child and current == game then
				local ok, s = pcall(game.GetService, game, part)
				child = ok and s or nil
			end
			if not child then return nil end
			current = child
		end
	end
	return current
end

function Iter.getPath(inst)
	local parts = {}
	while inst and inst ~= game do
		table.insert(parts, 1, inst.Name)
		inst = inst.Parent
	end
	return table.concat(parts, ".")
end

----------------------------------------------------------------------
-- Waiting / watching
----------------------------------------------------------------------
-- Yields until something matching exists under root. Returns it, or nil after timeout (seconds).
function Iter.waitFor(root, query, timeout)
	local found = Iter.find(root, query)
	if found then return found end

	local match = matcher(query)
	local done = Instance.new("BindableEvent")
	local result
	local conn = root.DescendantAdded:Connect(function(inst)
		if not result and match(inst) then
			result = inst
			done:Fire()
		end
	end)
	local timer
	if timeout then
		timer = task.delay(timeout, function() done:Fire() end)
	end
	if not result then done.Event:Wait() end
	conn:Disconnect()
	if timer then pcall(task.cancel, timer) end
	done:Destroy()
	return result
end

-- Calls onAdded(inst) for every match that appears (and the existing ones unless opts.Existing == false),
-- onRemoved(inst) when one leaves. Returns an object with :Disconnect().
function Iter.watch(root, query, onAdded, onRemoved, opts)
	opts = opts or {}
	local match = matcher(query)
	local tracked = {}
	local conns = {}

	local function add(inst)
		if tracked[inst] or not match(inst) then return end
		tracked[inst] = true
		if onAdded then task.spawn(onAdded, inst) end
	end

	table.insert(conns, root.DescendantAdded:Connect(add))
	table.insert(conns, root.DescendantRemoving:Connect(function(inst)
		if tracked[inst] then
			tracked[inst] = nil
			if onRemoved then task.spawn(onRemoved, inst) end
		end
	end))

	if opts.Existing ~= false then
		task.spawn(function()
			Iter.forEach(root, query, add, { YieldEvery = opts.YieldEvery or 5000 })
		end)
	end

	local w = { Tracked = tracked }
	function w:Disconnect()
		for _, c in ipairs(conns) do c:Disconnect() end
		table.clear(conns)
	end
	function w:GetAll()
		local list = {}
		for inst in pairs(tracked) do
			if inst.Parent then table.insert(list, inst) end
		end
		return list
	end
	return w
end

----------------------------------------------------------------------
-- Debug
----------------------------------------------------------------------
function Iter.tree(root, maxDepth, query)
	maxDepth = maxDepth or 3
	local match = matcher(query)
	local lines = { root.Name .. " [" .. root.ClassName .. "]" }
	local function rec(inst, depth)
		if depth > maxDepth then return end
		for _, c in ipairs(inst:GetChildren()) do
			if match(c) then
				table.insert(lines, string.rep("  ", depth) .. "- " .. c.Name .. " [" .. c.ClassName .. "]")
			end
			rec(c, depth + 1)
		end
	end
	rec(root, 1)
	print(table.concat(lines, "\n"))
	return lines
end

return Iter
