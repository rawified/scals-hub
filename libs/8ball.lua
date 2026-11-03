local POOL = {}

POOL.PlaceIds = { 107430170196919 }

function POOL.inGame()
	for _, id in ipairs(POOL.PlaceIds) do
		if game.PlaceId == id or game.GameId == id then return true end
	end
	return false
end

local REPO = "https://raw.githubusercontent.com/rawified/scals-hub/refs/heads/main/"
local M = loadstring(game:HttpGet(REPO .. "libs/math.lua"))()
local Iter = loadstring(game:HttpGet(REPO .. "libs/iterations.lua"))()
local Move = loadstring(game:HttpGet(REPO .. "libs/movement.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local connections = {}
local alive = true

local halloweencandy = Iter.path("Workspace/HalloweenCandy")

function POOL.tptonearestcandy()
    local candy, dist = Iter.nearest(halloweencandy, { Name = "Candy", IsA = "BasePart" })
    Move.teleport(candy, {KeepRotation=true})
end

return POOL
