# Iterations library

Walk through children and descendants, find things anywhere in the game, and wait for things to appear.

```lua
local REPO = "https://raw.githubusercontent.com/rawified/scals-hub/refs/heads/main/"
local Iter = loadstring(game:HttpGet(REPO .. "libs/iterations.lua"))()
```

## Queries

Almost every function takes a **query** that decides what matches.

| Query | Matches |
|---|---|
| `nil` | everything |
| `"Coin"` | exact name |
| `function(inst) return ... end` | your own test (errors count as "no match") |
| `{ ... }` table | every field you set must match (see below) |

### Table query fields

| Field | Example | Meaning |
|---|---|---|
| `Name` | `"Coin"` or `{ "Coin", "Gem" }` | exact name (any in the list) |
| `Pattern` | `"^Coin%d+$"` | Lua pattern on the name |
| `Contains` | `"coin"` | name contains this (case-insensitive) |
| `Class` | `"Part"` or a list | exact `ClassName` |
| `IsA` | `"BasePart"` or a list | `inst:IsA(...)`, any in the list |
| `Parent` | `"Coins"` | parent's name |
| `Ancestor` | `workspace.Map` | is inside this instance |
| `HasChild` | `"TouchInterest"` | has a child with this name |
| `Tag` | `"Collectable"` | has this CollectionService tag |
| `Attribute` | `"Value"` | has this attribute (any value) |
| `Attributes` | `{ Rarity = "Gold" }` | attributes equal these values |
| `Props` | `{ Transparency = 0 }` | properties equal these values |
| `Where` | `function(inst) ... end` | extra test |

`Iter.compile(query)` turns any query into a plain `function(inst) -> bool` if you need it yourself.

## Iterating

All of these work in a generic `for` loop.

| Function | Description |
|---|---|
| `Iter.children(parent, query)` | direct children that match |
| `Iter.descendants(root, query)` | every descendant that matches |
| `Iter.folders(parent, deep)` | Folders and Models (direct children, or all with `deep = true`) |
| `Iter.walk(root, query, maxDepth)` | breadth-first, also returns the depth (1 = direct child) |
| `Iter.forEach(root, query, fn, opts)` | calls `fn(inst)` for each match; returning `false` stops |

`forEach` options: `Deep` (default `true`), `YieldEvery = N` (waits a frame every N instances so big maps don't freeze).

```lua
for part in Iter.descendants(workspace, { IsA = "BasePart", Contains = "coin" }) do
	print(part:GetFullName())
end

for inst, depth in Iter.walk(workspace.Map, nil, 2) do
	print(string.rep("  ", depth) .. inst.Name)
end
```

## Finding

| Function | Returns |
|---|---|
| `Iter.find(root, query, deep)` | first match or `nil` (deep by default) |
| `Iter.findAll(root, query, opts)` | list of matches. opts: `Deep`, `Limit`, `YieldEvery` |
| `Iter.findInWorkspace(query)` | first match in workspace |
| `Iter.findAnywhere(query, opts)` | first match in every common service, plus your PlayerGui / Backpack / PlayerScripts. `opts.All = true` returns a list, `opts.Services = { ... }` picks where to look |
| `Iter.nearest(root, query, position, maxDistance)` | closest BasePart / Model / Attachment match and its distance. Position defaults to your character |
| `Iter.count(root, query, deep)` | number of matches |
| `Iter.path("Workspace.Map.Coins")` | resolves a dotted (or `/`) path; `game.` and `workspace` prefixes work |
| `Iter.getPath(inst)` | `"Workspace.Map.Coins.Coin"` |
| `Iter.positionOf(inst)` | Vector3 of a part, model or attachment |

```lua
local remote = Iter.path("ReplicatedStorage/Remotes/Buy")
local gem, dist = Iter.nearest(workspace, { Name = "Gem", IsA = "BasePart" })
local all = Iter.findAnywhere({ IsA = "RemoteEvent" }, { All = true })
```

## Waiting and watching

| Function | Description |
|---|---|
| `Iter.waitFor(root, query, timeout)` | yields until a match exists; `nil` after `timeout` seconds |
| `Iter.watch(root, query, onAdded, onRemoved, opts)` | calls `onAdded` for each match that appears (and the ones already there unless `opts.Existing == false`), `onRemoved` when one leaves |

The watcher object has `:Disconnect()`, `:GetAll()` (list of tracked instances still in the game) and `.Tracked` (`[inst] = true`).

```lua
local coins = Iter.watch(workspace, { Name = "Coin" }, function(coin)
	print("new coin", coin)
end, function(coin)
	print("coin gone", coin)
end)

-- later
coins:Disconnect()
```

## Debug

`Iter.tree(root, maxDepth, query)` prints a tree of names and classes to F9 (default depth 3) and returns the lines.
