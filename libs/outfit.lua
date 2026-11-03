--[[
    Scals Hub - Outfit library
    Try on anything from the Roblox catalog: clothes, accessories, bodies, heads and faces.
    Client-side: only you see it. Favorites and saved outfits are kept in ScalsHub/Outfits.json.
    No UI (the hub's Outfit Editor tile is built on this).

        local Outfit = loadstring(game:HttpGet(REPO .. "libs/outfit.lua"))()

    WEARING (these yield while the item loads; they return true, or false + a reason)
        Outfit.wear(assetId)            Outfit.wearBundle(bundleId)
        Outfit.wearEntry(entry)         -- a search result / favorite: { Id, Name, Price, Bundle }
        Outfit.remove(assetId)          Outfit.removeBundle(bundleId)     Outfit.removeEntry(entry)
        Outfit.isWorn(assetId)          Outfit.isBundleWorn(bundleId)     Outfit.isEntryWorn(entry)
        Outfit.worn()                   -- asset ids you have on, in the order they went on
        Outfit.kind(assetId)            -- "Shirt", "Pants", "T-Shirt", "Accessory", "Body part", "Head", "Face"
        Outfit.reset()                  -- back to your own avatar
        Outfit.removeMyAccessories()    -- takes off your own hats / hair (reset puts them back), returns how many
        Outfit.keepOnRespawn(true)      -- put everything back on after respawning (default on)
        Outfit.onChanged(fn)            -- fn() whenever what you wear changes; returns a function that stops it

    CATALOG
        local results, err = Outfit.search({ Category = "Shirts", Sort = "Relevance", Keyword = "" })  -- yields
        results.Items                   -- { { Id, Name, Price = "R$ 5" | "Free" | "Off sale", Bundle }, ... }
        results.IsFinished              -- no more pages
        local more = results:more()     -- yields; the next page's items (also added to results.Items)
        Outfit.Categories  Outfit.Sorts -- the names search() accepts
        Outfit.thumbnail(entry)         -- rbxthumb:// image for an entry
        Outfit.getName(assetId, fn)     -- fn(name) once the item's name is known

    FAVORITES / OUTFITS (saved to Outfit.DataFile when the executor has file access)
        Outfit.favorites()  Outfit.isFavorite(entry)  Outfit.toggleFavorite(entry) -> true if now a favorite
        Outfit.outfits()    Outfit.saveOutfit(name) -> item count   Outfit.deleteOutfit(name)
        Outfit.wearOutfit(outfitOrName) -> how many items went on (yields)

    Outfit.destroy()                    -- takes everything off and disconnects
]]

local Outfit = {}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local MarketplaceService = game:GetService("MarketplaceService")
local AvatarEditorService = game:GetService("AvatarEditorService")

local player = Players.LocalPlayer
local connections = {}
local function track(conn)
	table.insert(connections, conn)
	return conn
end
local hasFiles = typeof(readfile) == "function" and typeof(writefile) == "function" and typeof(isfile) == "function"

local State = { KeepOnRespawn = true }

local templates = {}    -- [assetId] = Folder holding the loaded asset (cloned when worn)
local bundleItems = {}  -- [bundleId] = { assetId, ... }
local worn = {}         -- [assetId] = { slots = { ... }, undo = function }
local wornOrder = {}    -- asset ids in the order they were put on
local hidden = {}       -- your own accessories taken off by "Remove My Accessories"
local itemNames = {}    -- [assetId] = name, for the Wearing panel
local changedListeners = {}
local onWornChanged
do
	local queued = false
	onWornChanged = function()
		if queued then return end -- at most once per frame
		queued = true
		task.defer(function()
			queued = false
			for _, fn in ipairs(changedListeners) do task.spawn(fn) end
		end)
	end
end

local function markOurs(inst)
	inst:SetAttribute("ScalsOutfit", true)
	return inst
end

local function getTemplate(id)
	if templates[id] then return templates[id] end
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
	if not ok or type(objs) ~= "table" or #objs == 0 then
		return nil, "Couldn't load this item (your executor needs game:GetObjects)."
	end
	local holder = Instance.new("Folder") -- body parts have several root objects
	for _, o in ipairs(objs) do
		pcall(function() o.Parent = holder end)
	end
	templates[id] = holder
	return holder
end

local function firstDescendant(root, test)
	for _, d in ipairs(root:GetDescendants()) do
		if test(d) then return d end
	end
end

-- What kind of item this is and which "slots" it takes (two items sharing a slot can't stack)
local function planWear(template, char, hum)
	local cloth = firstDescendant(template, function(d) return d:IsA("Clothing") or d:IsA("ShirtGraphic") end)
	if cloth then return { kind = "clothing", src = cloth, slots = { cloth.ClassName } } end
	local acc = firstDescendant(template, function(d) return d:IsA("Accoutrement") end)
	if acc then return { kind = "accessory", src = acc, slots = {} } end
	local isR15 = hum.RigType == Enum.HumanoidRigType.R15
	local r15 = template:FindFirstChild("R15ArtistIntent", true) or template:FindFirstChild("R15Fixed", true)
		or template:FindFirstChild("R15", true)
	local r6 = template:FindFirstChild("R6", true)
	if r15 or r6 then
		if isR15 and r15 then
			local parts, slots = {}, {}
			for _, p in ipairs(r15:GetChildren()) do
				if p:IsA("BasePart") then
					table.insert(parts, p)
					table.insert(slots, p.Name)
				end
			end
			if #parts > 0 then return { kind = "r15", parts = parts, slots = slots } end
		elseif not isR15 and r6 then
			local meshes, slots = {}, {}
			for _, m in ipairs(r6:GetChildren()) do
				if m:IsA("CharacterMesh") then
					table.insert(meshes, m)
					table.insert(slots, "R6" .. m.BodyPart.Name)
				end
			end
			if #meshes > 0 then return { kind = "r6", meshes = meshes, slots = slots } end
		end
		return nil, ("This body part doesn't have a version for %s avatars."):format(isR15 and "R15" or "R6")
	end
	local dynamicHead = firstDescendant(template, function(d) return d:IsA("MeshPart") and d.Name == "Head" end)
	if dynamicHead then
		if not isR15 then return nil, "This head needs an R15 avatar." end
		return { kind = "r15", parts = { dynamicHead }, slots = { "Head" } }
	end
	local headMesh = firstDescendant(template, function(d) return d:IsA("SpecialMesh") end)
	if headMesh then return { kind = "headmesh", src = headMesh, slots = { "HeadMesh" } } end
	local face = firstDescendant(template, function(d) return d:IsA("Decal") end)
	if face then return { kind = "face", src = face, slots = { "Face" } } end
	return nil, "That item can't be worn."
end

local function findAttachment(char, n, exclude)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Attachment") and d.Name == n and not d:IsDescendantOf(exclude) then return d end
	end
	return nil
end

local function attachAccessory(char, hum, acc)
	local handle = acc:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.Anchored = false
		handle.CanCollide = false
		handle.Massless = true
	end
	if not pcall(hum.AddAccessory, hum, acc) then acc.Parent = char end
	if handle and handle:IsA("BasePart") and not handle:FindFirstChild("AccessoryWeld") then
		local att = handle:FindFirstChildOfClass("Attachment")
		local target = att and findAttachment(char, att.Name, acc)
		if target and target.Parent:IsA("BasePart") then
			local weld = Instance.new("Weld")
			weld.Name = "AccessoryWeld"
			weld.Part0 = handle
			weld.Part1 = target.Parent
			weld.C0 = att.CFrame
			weld.C1 = target.CFrame
			weld.Parent = handle
		end
	end
end

-- How much the avatar's scaling stretched one of its parts (unscaled size is in OriginalSize)
local function partScale(part)
	local orig = part:FindFirstChild("OriginalSize")
	if orig and orig:IsA("Vector3Value") then
		local o, s = orig.Value, part.Size
		if o.X > 0 and o.Y > 0 and o.Z > 0 then return Vector3.new(s.X / o.X, s.Y / o.Y, s.Z / o.Z) end
	end
	return Vector3.one
end

local function scalePart(part, scale)
	if (scale - Vector3.one).Magnitude < 1e-3 then return end
	part.Size = part.Size * scale
	for _, a in ipairs(part:GetChildren()) do
		if a:IsA("Attachment") then a.Position = a.Position * scale end
	end
end

local function isFaceDecal(d)
	return d:IsA("Decal") and d.Name:lower() == "face"
end

-- Swaps one body part for another; the new part goes in BEFORE joints move onto it
-- (a joint that leaves the world for a moment kills the humanoid)
local function swapPart(char, out, inn)
	inn.Anchored = false
	inn.CanCollide = out.CanCollide
	inn.Massless = out.Massless
	inn.Color = out.Color
	inn.CFrame = out.CFrame
	inn.Parent = char
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			if d.Part0 == out then d.Part0 = inn end
			if d.Part1 == out then d.Part1 = inn end
		end
	end
	for _, j in ipairs(out:GetChildren()) do
		if j:IsA("Motor6D") and not inn:FindFirstChild(j.Name) then j.Parent = inn end
	end
	if not inn:FindFirstChildOfClass("FaceControls") then
		local hasFace = false
		for _, d in ipairs(inn:GetChildren()) do
			if isFaceDecal(d) then hasFace = true break end
		end
		if not hasFace then
			for _, d in ipairs(out:GetChildren()) do
				if isFaceDecal(d) then d.Parent = inn end
			end
		end
	end
	out.Parent = nil
end

-- Lines up every joint on a part with its rig attachments (without rebuilding the Neck)
local function syncMotors(char, part)
	for _, m in ipairs(char:GetDescendants()) do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 and (m.Part0 == part or m.Part1 == part) then
			local a0 = m.Part0:FindFirstChild(m.Name .. "RigAttachment")
			local a1 = m.Part1:FindFirstChild(m.Name .. "RigAttachment")
			if a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment") then
				m.C0 = a0.CFrame
				m.C1 = a1.CFrame
			end
		end
	end
end

local function refitWelds(char, part)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Weld") and d.Part1 == part and d.Part0 and d.Part0 ~= part then
			local att = d.Part0:FindFirstChildOfClass("Attachment")
			local target = att and part:FindFirstChild(att.Name)
			if target and target:IsA("Attachment") then
				d.C0 = att.CFrame
				d.C1 = target.CFrame
			end
		end
	end
end

-- Main way to change a body part: keep YOUR part and give it the catalog part's mesh,
-- size and attachment points. Returns an undo function, or nil if it can't be reskinned.
local function reskinPart(char, old, src)
	if not (old:IsA("MeshPart") and src:IsA("MeshPart")) then return nil end
	local scale = partScale(old)
	local wasArchivable = old.Archivable
	old.Archivable = true
	local snap = old:Clone()
	old.Archivable = wasArchivable
	if not snap then return nil end
	snap:ClearAllChildren()
	if not pcall(old.ApplyMesh, old, src) then
		snap:Destroy()
		return nil
	end
	local oldSize = old.Size
	old.Size = src.Size * scale
	local moved = {}
	for _, a in ipairs(src:GetChildren()) do
		if a:IsA("Attachment") then
			local mine = old:FindFirstChild(a.Name)
			if mine and mine:IsA("Attachment") then
				table.insert(moved, { att = mine, cf = mine.CFrame })
				mine.CFrame = CFrame.new(a.Position * scale) * a.CFrame.Rotation
			end
		end
	end
	local hiddenFaces = {}
	if src:FindFirstChildOfClass("FaceControls") then
		for _, d in ipairs(old:GetChildren()) do
			if isFaceDecal(d) and d.Transparency < 1 then
				table.insert(hiddenFaces, { decal = d, t = d.Transparency })
				d.Transparency = 1
			end
		end
	end
	old:SetAttribute("ScalsBody", true)
	syncMotors(char, old)
	refitWelds(char, old)
	return function()
		pcall(old.ApplyMesh, old, snap)
		snap:Destroy()
		old.Size = oldSize
		for _, m in ipairs(moved) do
			if m.att.Parent then m.att.CFrame = m.cf end
		end
		for _, h in ipairs(hiddenFaces) do
			if h.decal.Parent then h.decal.Transparency = h.t end
		end
		old:SetAttribute("ScalsBody", nil)
		if old.Parent == char then
			syncMotors(char, old)
			refitWelds(char, old)
		end
	end
end

-- Backup: swap the whole part (only used inside a death guard)
local function swapInPart(char, old, src)
	local new = markOurs(src:Clone())
	for _, j in ipairs(new:GetDescendants()) do
		if j:IsA("JointInstance") then j:Destroy() end
	end
	scalePart(new, partScale(old))
	swapPart(char, old, new)
	syncMotors(char, new)
	refitWelds(char, new)
	return function()
		if new.Parent == char then
			swapPart(char, new, old)
			syncMotors(char, old)
			refitWelds(char, old)
		end
		new:Destroy()
	end
end

-- R15 hip height follows the legs (root joint -> hip -> knee -> ankle -> sole)
local function attY(part, n)
	local a = part and part:FindFirstChild(n)
	return a and a:IsA("Attachment") and a.Position.Y or nil
end

local function legHeight(char, side)
	local lt = char:FindFirstChild("LowerTorso")
	local ul = char:FindFirstChild(side .. "UpperLeg")
	local ll = char:FindFirstChild(side .. "LowerLeg")
	local foot = char:FindFirstChild(side .. "Foot")
	if not (lt and ul and ll and foot) then return nil end
	local y = {
		attY(lt, "RootRigAttachment"), attY(lt, side .. "HipRigAttachment"),
		attY(ul, side .. "HipRigAttachment"), attY(ul, side .. "KneeRigAttachment"),
		attY(ll, side .. "KneeRigAttachment"), attY(ll, side .. "AnkleRigAttachment"),
		attY(foot, side .. "AnkleRigAttachment"),
	}
	for i = 1, 7 do
		if not y[i] then return nil end
	end
	return (y[1] - y[2]) + (y[3] - y[4]) + (y[5] - y[6]) + y[7] + foot.Size.Y / 2
end

local function updateHipHeight(char, hum)
	if hum.RigType ~= Enum.HumanoidRigType.R15 then return end
	if hum:GetAttribute("ScalsHipHeight") == nil then hum:SetAttribute("ScalsHipHeight", hum.HipHeight) end
	local anyOurs = false
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("BasePart") and (c:GetAttribute("ScalsOutfit") or c:GetAttribute("ScalsBody")) then
			anyOurs = true
			break
		end
	end
	if not anyOurs then
		hum.HipHeight = hum:GetAttribute("ScalsHipHeight")
		hum:SetAttribute("ScalsHipHeight", nil)
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local rootY = attY(hrp, "RootRigAttachment")
	local leg = math.max(legHeight(char, "Left") or 0, legHeight(char, "Right") or 0)
	if not rootY or leg <= 0 then return end
	local h = leg - rootY - hrp.Size.Y / 2
	if h > 0 then hum.HipHeight = h end
end

-- While body parts change the humanoid can't die from a missing neck for a moment
local guardDepth = 0
local function guardDeath(hum)
	guardDepth += 1
	if hum:GetAttribute("ScalsRequiresNeck") == nil then hum:SetAttribute("ScalsRequiresNeck", hum.RequiresNeck) end
	pcall(function() hum.RequiresNeck = false end)
	pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
	local released = false
	return function()
		if released then return end
		released = true
		task.delay(0.5, function()
			guardDepth -= 1
			if guardDepth > 0 or not hum.Parent then return end
			local prev = hum:GetAttribute("ScalsRequiresNeck")
			hum:SetAttribute("ScalsRequiresNeck", nil)
			pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
			if prev ~= nil then pcall(function() hum.RequiresNeck = prev end) end
		end)
	end
end

-- Puts the planned item on and returns a function that takes it off again
local function applyPlan(plan, char, hum)
	local function stillHere()
		return player.Character == char and char.Parent ~= nil
	end
	if plan.kind == "clothing" then
		local item = markOurs(plan.src:Clone())
		local taken = {}
		for _, old in ipairs(char:GetChildren()) do
			if old.ClassName == item.ClassName then
				old.Parent = nil
				table.insert(taken, old)
			end
		end
		item.Parent = char
		return function()
			item:Destroy()
			if stillHere() then
				for _, old in ipairs(taken) do old.Parent = char end
			end
		end
	elseif plan.kind == "accessory" then
		local item = markOurs(plan.src:Clone())
		attachAccessory(char, hum, item)
		return function() item:Destroy() end
	elseif plan.kind == "face" then
		local head = char:FindFirstChild("Head")
		if not head then return nil, "Your avatar has no head." end
		local item = markOurs(plan.src:Clone())
		item.Name = "face"
		local taken = {}
		for _, d in ipairs(head:GetChildren()) do
			if d:IsA("Decal") and d.Name:lower() == "face" then
				d.Parent = nil
				table.insert(taken, d)
			end
		end
		item.Parent = head
		return function()
			item:Destroy()
			local now = stillHere() and char:FindFirstChild("Head")
			if now then
				for _, d in ipairs(taken) do d.Parent = now end
			end
		end
	elseif plan.kind == "headmesh" then
		local head = char:FindFirstChild("Head")
		local old = head and head:FindFirstChildOfClass("SpecialMesh")
		if not old then return nil, "Classic heads only work on avatars with a block head." end
		local item = markOurs(plan.src:Clone())
		old.Parent = nil
		item.Parent = head
		return function()
			item:Destroy()
			if stillHere() and head.Parent then old.Parent = head end
		end
	elseif plan.kind == "r6" then
		local added, taken = {}, {}
		for _, m in ipairs(plan.meshes) do
			for _, old in ipairs(char:GetChildren()) do
				if old:IsA("CharacterMesh") and old.BodyPart == m.BodyPart then
					old.Parent = nil
					table.insert(taken, old)
				end
			end
			local c = markOurs(m:Clone())
			c.Parent = char
			table.insert(added, c)
		end
		return function()
			for _, c in ipairs(added) do c:Destroy() end
			if stillHere() then
				for _, old in ipairs(taken) do old.Parent = char end
			end
		end
	elseif plan.kind == "r15" then
		local release = guardDeath(hum)
		local undos = {}
		local ok, err = pcall(function()
			for _, src in ipairs(plan.parts) do
				local old = char:FindFirstChild(src.Name)
				if old and old:IsA("BasePart") then
					table.insert(undos, reskinPart(char, old, src) or swapInPart(char, old, src))
				end
			end
		end)
		if not ok then
			for i = #undos, 1, -1 do pcall(undos[i]) end
		end
		pcall(updateHipHeight, char, hum)
		release()
		if not ok then error(err) end
		if #undos == 0 then return nil, "Your avatar doesn't have those body parts." end
		return function()
			local releaseUndo = guardDeath(hum)
			for i = #undos, 1, -1 do pcall(undos[i]) end
			if stillHere() then pcall(updateHipHeight, char, hum) end
			releaseUndo()
		end
	end
	return nil, "That item can't be worn."
end

local function overlaps(a, b)
	for _, x in ipairs(a) do
		if table.find(b, x) then return true end
	end
	return false
end

local function removeWorn(id)
	local w = worn[id]
	if not w then return end
	worn[id] = nil
	local i = table.find(wornOrder, id)
	if i then table.remove(wornOrder, i) end
	local ok, err = pcall(w.undo)
	if not ok then warn("[Scals Hub] Couldn't take off item " .. tostring(id) .. ": " .. tostring(err)) end
end

-- Yields (loads the item). Returns true, or false + a reason.
local function wearItem(id)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return false, "No character to dress." end
	if worn[id] then return true end
	local template, err = getTemplate(id)
	if not template then return false, err end
	if player.Character ~= char then return false, "You respawned, try again." end
	local plan, planErr = planWear(template, char, hum)
	if not plan then return false, planErr end
	for otherId, w in pairs(worn) do
		if overlaps(plan.slots, w.slots) then removeWorn(otherId) end
	end
	local ok, undo, applyErr = pcall(applyPlan, plan, char, hum)
	if not ok then
		warn("[Scals Hub] Couldn't wear item " .. tostring(id) .. ": " .. tostring(undo))
		return false, "Couldn't put that item on."
	end
	if not undo then return false, applyErr end
	worn[id] = { slots = plan.slots, undo = undo, kind = plan.kind }
	if not table.find(wornOrder, id) then table.insert(wornOrder, id) end
	onWornChanged()
	return true
end

local function getBundleAssets(bundleId)
	if bundleItems[bundleId] then return bundleItems[bundleId] end
	local ok, details = pcall(function() return AssetService:GetBundleDetailsAsync(bundleId) end)
	if not ok or type(details) ~= "table" then return nil, "Couldn't load that bundle." end
	local ids = {}
	for _, it in ipairs(details.Items or {}) do
		if it.Type == "Asset" and it.Id then table.insert(ids, it.Id) end
	end
	bundleItems[bundleId] = ids
	return ids
end

local function wearBundle(bundleId)
	local ids, err = getBundleAssets(bundleId)
	if not ids then return false, err end
	local okCount, lastErr = 0, nil
	for _, id in ipairs(ids) do
		local ok, e = wearItem(id)
		if ok then okCount += 1 else lastErr = e end
	end
	if okCount == 0 then return false, lastErr or "Nothing in that bundle could be worn." end
	return true
end

local function bundleWorn(bundleId)
	for _, id in ipairs(bundleItems[bundleId] or {}) do
		if worn[id] then return true end
	end
	return false
end

local function removeBundle(bundleId)
	for _, id in ipairs(bundleItems[bundleId] or {}) do removeWorn(id) end
end

local function restoreHidden()
	local char = player.Character
	for _, h in ipairs(hidden) do
		if h.char == char and char and char.Parent then h.inst.Parent = char end
	end
	table.clear(hidden)
end

local function resetOutfit()
	local ids = table.clone(wornOrder)
	for i = #ids, 1, -1 do removeWorn(ids[i]) end
	for id in pairs(worn) do removeWorn(id) end
	restoreHidden()
	table.clear(wornOrder)
	onWornChanged()
end

local function removeMyAccessories()
	local char = player.Character
	if not char then return 0 end
	local n = 0
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Accoutrement") and not c:GetAttribute("ScalsOutfit") then
			table.insert(hidden, { inst = c, char = char })
			c.Parent = nil
			n += 1
		end
	end
	return n
end

-- After respawning, put the outfit back on
track(player.CharacterAdded:Connect(function(char)
	table.clear(hidden)
	table.clear(worn)
	if not State.KeepOnRespawn then
		table.clear(wornOrder)
		onWornChanged()
		return
	end
	local ids = table.clone(wornOrder)
	table.clear(wornOrder)
	if #ids == 0 then return end
	char:WaitForChild("Humanoid", 10)
	task.wait(1)
	if player.Character ~= char then return end
	for _, id in ipairs(ids) do wearItem(id) end
	onWornChanged()
end))

----------------------------------------------------------------------
-- Favorites + saved outfits (ScalsHub/Outfits.json)
----------------------------------------------------------------------
local DATA_FILE = "ScalsHub/Outfits.json"
local Data = { Favorites = {}, Outfits = {} }
if hasFiles then
	pcall(function()
		if isfile(DATA_FILE) then
			local d = HttpService:JSONDecode(readfile(DATA_FILE))
			if type(d) == "table" then
				if type(d.Favorites) == "table" then Data.Favorites = d.Favorites end
				if type(d.Outfits) == "table" then Data.Outfits = d.Outfits end
			end
		end
	end)
end

local function saveData()
	if not hasFiles then return end
	pcall(function()
		if typeof(makefolder) == "function" and typeof(isfolder) == "function" and not isfolder("ScalsHub") then
			makefolder("ScalsHub")
		end
		writefile(DATA_FILE, HttpService:JSONEncode(Data))
	end)
end

local function sameEntry(a, b)
	return a.Id == b.Id and (a.Bundle == true) == (b.Bundle == true)
end
local function favoriteIndex(entry)
	for i, f in ipairs(Data.Favorites) do
		if sameEntry(f, entry) then return i end
	end
	return nil
end
local function toggleFavorite(entry)
	local i = favoriteIndex(entry)
	if i then
		table.remove(Data.Favorites, i)
	else
		table.insert(Data.Favorites, { Id = entry.Id, Name = entry.Name, Price = entry.Price, Bundle = entry.Bundle == true })
	end
	saveData()
	return i == nil
end
local function saveOutfit(outfitName)
	local items = table.clone(wornOrder)
	for i, o in ipairs(Data.Outfits) do
		if o.Name == outfitName then
			Data.Outfits[i].Items = items
			saveData()
			return
		end
	end
	table.insert(Data.Outfits, { Name = outfitName, Items = items })
	saveData()
end
local function deleteOutfit(outfitName)
	for i, o in ipairs(Data.Outfits) do
		if o.Name == outfitName then
			table.remove(Data.Outfits, i)
			saveData()
			return
		end
	end
end
local function wearOutfit(o)
	resetOutfit()
	local okCount = 0
	for _, id in ipairs(o.Items or {}) do
		if wearItem(id) then okCount += 1 end
	end
	return okCount
end

-- Item names for the Wearing panel: known from the catalog, otherwise looked up once
local nameWaiters = {}
local function withName(id, cb)
	if itemNames[id] then
		cb(itemNames[id])
		return
	end
	if nameWaiters[id] then
		table.insert(nameWaiters[id], cb)
		return
	end
	nameWaiters[id] = { cb }
	task.spawn(function()
		local ok, info = pcall(function() return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset) end)
		local waiting = nameWaiters[id]
		nameWaiters[id] = nil
		if ok and type(info) == "table" and type(info.Name) == "string" then
			itemNames[id] = info.Name
			for _, f in ipairs(waiting) do pcall(f, info.Name) end
		end
	end)
end

local ClothNames = { Shirt = "Shirt", Pants = "Pants", ShirtGraphic = "T-Shirt" }
local KindNames = { accessory = "Accessory", r15 = "Body part", r6 = "Body part", headmesh = "Head", face = "Face" }
local function wornKind(id)
	local w = worn[id]
	if not w then return "" end
	if w.kind == "clothing" then return ClothNames[w.slots[1]] or "Clothing" end
	return KindNames[w.kind] or ""
end

----------------------------------------------------------------------
-- Catalog settings
----------------------------------------------------------------------
local CategoryOrder = {
	"Shirts", "Pants", "T-Shirts", "Hats", "Hair", "Face Acc.", "Neck", "Shoulder", "Front", "Back", "Waist",
	"Jackets", "Sweaters", "Bodies", "Heads", "Classic Heads", "Faces",
}
local CategoryTypes = {
	Shirts = { assets = { "Shirt" } },
	Pants = { assets = { "Pants" } },
	["T-Shirts"] = { assets = { "TShirt" } },
	Hats = { assets = { "Hat" } },
	Hair = { assets = { "HairAccessory" } },
	["Face Acc."] = { assets = { "FaceAccessory" } },
	Neck = { assets = { "NeckAccessory" } },
	Shoulder = { assets = { "ShoulderAccessory" } },
	Front = { assets = { "FrontAccessory" } },
	Back = { assets = { "BackAccessory" } },
	Waist = { assets = { "WaistAccessory" } },
	Jackets = { assets = { "JacketAccessory" } },
	Sweaters = { assets = { "SweaterAccessory" } },
	Bodies = { bundles = { "BodyParts" } },
	Heads = { bundles = { "DynamicHead" } },
	["Classic Heads"] = { assets = { "Head" } },
	Faces = { assets = { "Face" } },
}
local SortOrder = { "Relevance", "Most Favorited", "Bestselling", "Price: Low to High", "Price: High to Low" }
local SortTypes = {
	Relevance = "Relevance", ["Most Favorited"] = "MostFavorited", Bestselling = "Bestselling",
	["Price: Low to High"] = "PriceLowToHigh", ["Price: High to Low"] = "PriceHighToLow",
}

local function enumItem(enum, n)
	local ok, v = pcall(function() return enum[n] end)
	return ok and v or nil
end
local function enumList(enum, names)
	local list = {}
	for _, n in ipairs(names or {}) do
		local v = enumItem(enum, n)
		if v then table.insert(list, v) end
	end
	return list
end


----------------------------------------------------------------------
-- API
----------------------------------------------------------------------
Outfit.DataFile = DATA_FILE
Outfit.Categories = CategoryOrder
Outfit.Sorts = SortOrder

function Outfit.wear(id)
	return wearItem(tonumber(id))
end

function Outfit.wearBundle(id)
	return wearBundle(tonumber(id))
end

function Outfit.wearEntry(entry)
	if entry.Bundle then
		local ok, err = wearBundle(entry.Id)
		for _, id in ipairs(bundleItems[entry.Id] or {}) do
			itemNames[id] = itemNames[id] or entry.Name
		end
		return ok, err
	end
	itemNames[entry.Id] = entry.Name
	return wearItem(entry.Id)
end

function Outfit.remove(id)
	removeWorn(tonumber(id))
	onWornChanged()
end

function Outfit.removeBundle(id)
	removeBundle(tonumber(id))
	onWornChanged()
end

function Outfit.removeEntry(entry)
	if entry.Bundle then removeBundle(entry.Id) else removeWorn(entry.Id) end
	onWornChanged()
end

function Outfit.isWorn(id)
	return worn[tonumber(id)] ~= nil
end

function Outfit.isBundleWorn(id)
	return bundleWorn(tonumber(id))
end

function Outfit.isEntryWorn(entry)
	if entry.Bundle then return bundleWorn(entry.Id) end
	return worn[entry.Id] ~= nil
end

function Outfit.worn()
	local list = {}
	for _, id in ipairs(wornOrder) do
		if worn[id] then table.insert(list, id) end
	end
	return list
end

Outfit.kind = wornKind
Outfit.reset = resetOutfit
Outfit.removeMyAccessories = removeMyAccessories
Outfit.getName = withName

function Outfit.keepOnRespawn(on)
	State.KeepOnRespawn = on == true
end

function Outfit.onChanged(fn)
	table.insert(changedListeners, fn)
	return function()
		local i = table.find(changedListeners, fn)
		if i then table.remove(changedListeners, i) end
	end
end

function Outfit.thumbnail(entry)
	local kind = entry.Bundle and "BundleThumbnail" or "Asset"
	return ("rbxthumb://type=%s&id=%d&w=150&h=150"):format(kind, entry.Id)
end

local function priceText(item)
	local p = item.Price or item.LowestPrice
	if p == nil then return "Off sale" end
	if p == 0 then return "Free" end
	return "R$ " .. tostring(p)
end

local function readPage(pages, into)
	local ok, items = pcall(function() return pages:GetCurrentPage() end)
	if not ok or type(items) ~= "table" then return nil, "Couldn't read the results, try again." end
	local added = {}
	for _, item in ipairs(items) do
		if item.Id then
			local entry = {
				Id = item.Id,
				Name = item.Name or "?",
				Price = priceText(item),
				Bundle = tostring(item.ItemType) == "Bundle",
			}
			table.insert(into, entry)
			table.insert(added, entry)
		end
	end
	return added
end

-- Catalog search (AvatarEditorService). Yields. Returns a results object, or nil + a reason.
function Outfit.search(opts)
	opts = opts or {}
	local cat = CategoryTypes[opts.Category or "Shirts"] or CategoryTypes.Shirts
	local params = CatalogSearchParams.new()
	params.SearchKeyword = opts.Keyword or ""
	if cat.bundles then
		local types = enumList(Enum.BundleType, cat.bundles)
		if #types > 0 then params.BundleTypes = types end
	else
		local types = enumList(Enum.AvatarAssetType, cat.assets)
		if #types > 0 then params.AssetTypes = types end
	end
	local sort = enumItem(Enum.CatalogSortType, SortTypes[opts.Sort or "Relevance"] or "")
	if sort then params.SortType = sort end
	pcall(function() params.Limit = 30 end)
	local ok, pages = pcall(function() return AvatarEditorService:SearchCatalog(params) end)
	if not ok then
		warn("[Outfit] Catalog search failed: " .. tostring(pages))
		return nil, "Catalog search failed, try again in a moment."
	end
	local results = { Items = {}, IsFinished = pages.IsFinished }
	local _, err = readPage(pages, results.Items)
	if err then return nil, err end
	function results:more()
		if pages.IsFinished then return {} end
		local okNext = pcall(function() pages:AdvanceToNextPageAsync() end)
		if not okNext then return nil, "Couldn't load more, try again." end
		self.IsFinished = pages.IsFinished
		return readPage(pages, self.Items)
	end
	return results
end

function Outfit.favorites()
	return Data.Favorites
end

function Outfit.isFavorite(entry)
	return favoriteIndex(entry) ~= nil
end

Outfit.toggleFavorite = toggleFavorite

function Outfit.outfits()
	return Data.Outfits
end

function Outfit.saveOutfit(outfitName)
	saveOutfit(outfitName)
	return #wornOrder
end

Outfit.deleteOutfit = deleteOutfit

function Outfit.wearOutfit(o)
	if type(o) == "string" then
		for _, saved in ipairs(Data.Outfits) do
			if saved.Name == o then o = saved break end
		end
	end
	if type(o) ~= "table" then return 0 end
	local n = wearOutfit(o)
	onWornChanged()
	return n
end

function Outfit.destroy()
	resetOutfit()
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	table.clear(changedListeners)
end

return Outfit
