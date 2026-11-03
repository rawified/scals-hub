# Outfit library

Try on anything from the Roblox catalog: clothes, accessories, bodies, heads and faces. Everything happens on your side only, so other players see your normal avatar. No UI (the hub's Outfit Editor tile is built on this).

```lua
local REPO = "https://raw.githubusercontent.com/rawified/scals-hub/refs/heads/main/"
local Outfit = loadstring(game:HttpGet(REPO .. "libs/outfit.lua"))()
```

Items load with the executor's `game:GetObjects`, so that's required.

## Wearing

The wear functions yield while the item loads and return `true`, or `false` plus a reason ("This head needs an R15 avatar.", ...).

| Function | Description |
|---|---|
| `Outfit.wear(assetId)` | put one catalog item on |
| `Outfit.wearBundle(bundleId)` | put on every part of a bundle (bodies, dynamic heads) |
| `Outfit.wearEntry(entry)` | a search result or favorite: `{ Id, Name, Price, Bundle }` |
| `Outfit.remove(assetId)` / `removeBundle(id)` / `removeEntry(entry)` | take it off again |
| `Outfit.isWorn(assetId)` / `isBundleWorn(id)` / `isEntryWorn(entry)` | `true` while it's on |
| `Outfit.worn()` | asset ids you have on, in the order they went on |
| `Outfit.kind(assetId)` | `"Shirt"`, `"Pants"`, `"T-Shirt"`, `"Accessory"`, `"Body part"`, `"Head"` or `"Face"` |
| `Outfit.reset()` | back to your own avatar (also puts back accessories you took off) |
| `Outfit.removeMyAccessories()` | takes off your own hats, hair etc.; returns how many |
| `Outfit.keepOnRespawn(on)` | put everything back on after respawning (default on) |
| `Outfit.onChanged(fn)` | `fn()` whenever what you wear changes (at most once per frame). Returns a function that stops it |

Two items that use the same slot can't be worn together: a new shirt replaces the old one, a new head replaces the old head. Accessories stack.

Body parts keep **your** part in the character and give it the catalog part's mesh, size and attachment points, so no joint ever breaks. Your avatar's scaling is applied to the new part, R15 hip height follows the new legs, and the humanoid can't die from a missing neck while parts change. Taking a body part off puts your own back exactly.

```lua
local ok, err = Outfit.wear(607702162)
if not ok then warn(err) end
```

## Catalog

```lua
local results, err = Outfit.search({ Category = "Hats", Sort = "Bestselling", Keyword = "crown" }) -- yields
for _, item in ipairs(results.Items) do
	print(item.Name, item.Price, Outfit.thumbnail(item))
end
if not results.IsFinished then
	local more = results:more() -- next page, also added to results.Items
end
```

| Function / field | Description |
|---|---|
| `Outfit.search(opts)` | yields. `Category` (one of `Outfit.Categories`), `Sort` (one of `Outfit.Sorts`), `Keyword`. Returns a results object, or `nil, reason` |
| `results.Items` | `{ Id, Name, Price, Bundle }`, Price is `"R$ 5"`, `"Free"` or `"Off sale"` |
| `results.IsFinished` | no more pages |
| `results:more()` | yields; the next page's items, or `nil, reason` |
| `Outfit.Categories` | Shirts, Pants, T-Shirts, Hats, Hair, Face Acc., Neck, Shoulder, Front, Back, Waist, Jackets, Sweaters, Bodies, Heads, Classic Heads, Faces |
| `Outfit.Sorts` | Relevance, Most Favorited, Bestselling, Price: Low to High, Price: High to Low |
| `Outfit.thumbnail(entry)` | `rbxthumb://` picture for an entry |
| `Outfit.getName(assetId, fn)` | `fn(name)` once the item's name is known (looked up once) |

Bodies and Heads are bundles: wearing one puts on every part in it.

## Favorites and saved outfits

Saved to `Outfit.DataFile` (`ScalsHub/Outfits.json`) when the executor has file access, so they're still there next time.

| Function | Description |
|---|---|
| `Outfit.favorites()` | the list of favorite entries |
| `Outfit.isFavorite(entry)` | `true` if it's a favorite |
| `Outfit.toggleFavorite(entry)` | adds / removes it; returns `true` if it's a favorite now |
| `Outfit.outfits()` | saved outfits: `{ Name, Items = { assetId, ... } }` |
| `Outfit.saveOutfit(name)` | saves what you wear now (same name overwrites); returns the item count |
| `Outfit.deleteOutfit(name)` | removes a saved outfit |
| `Outfit.wearOutfit(outfitOrName)` | takes everything off, puts the outfit on; returns how many items worked (yields) |

## Cleanup

`Outfit.destroy()` takes everything off, puts your own avatar back and disconnects everything.
