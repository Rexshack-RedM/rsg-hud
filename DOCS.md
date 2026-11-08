# rsg-hud — Developer Docs

## Horse hunger & thirst

When mounted, rsg-hud shows two extra horse circles (wheat = hunger, droplet = thirst) next to the horse health/stamina/clean/bonding circles. They turn red at 30% or below and can be dragged/resized in edit mode like the others. They are part of the `horse` group in `/hudpreset` visibility.

### Data source
Horse hunger/thirst live in **rsg-stables** (`activeHorse.hunger` / `activeHorse.thirst`, synced from the server session). rsg-hud reads them every HUD tick (500 ms) through a client export:

```lua
-- rsg-stables/client/client.lua (anywhere after `local activeHorse`)
exports('GetActiveHorseNeeds', function()
    if not activeHorse or not activeHorse.entity or not DoesEntityExist(activeHorse.entity) then return nil end
    return { entity = activeHorse.entity, hunger = activeHorse.hunger or 100, thirst = activeHorse.thirst or 100 }
end)
```

rsg-hud only shows the values when `needs.entity` matches the horse you're riding, so a borrowed, stolen or wild horse shows no hunger/thirst. If rsg-stables is stopped or the export is missing, the call is wrapped in `pcall` and the circles simply stay hidden.

### Config
| Option | Default | Description |
|---|---|---|
| `Config.ShowHorseNeeds` | `true` | Show horse hunger + thirst circles |
| `Config.IconColors.horse_hunger` | `normal #f2f2f2 / low #e0554f` | Hunger icon colours |
| `Config.IconColors.horse_thirst` | `normal #f2f2f2 / low #e0554f` | Thirst icon colours |

### NUI payload (`hudtick`)
`horsehunger` / `horsethirst` — number 0–100, or omitted (nil) when there's no data for the mounted horse.

### Debug
`/hudhorseneeds` prints (F8) the rsg-stables export result and the mounted horse handle. If `mount` and `active` differ, or `ok=false`, the circles show `--`.

### Locales
`horse_hunger_label`, `horse_thirst_label` (all locale files).
