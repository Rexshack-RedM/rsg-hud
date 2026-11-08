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
Horse hunger/thirst come from `exports['rsg-stables']:GetActiveHorseNeeds()` and only show for your own active horse; otherwise the circles show `--`.

### Locales
`horse_hunger_label`, `horse_thirst_label` (all locale files).


## HUD settings window
Opened with `/hudsettings` (or `/hudpreset`), or from another script with `exports['rsg-hud']:OpenSettings()`.

### Saved data (client KVP `rsghud_preset`)
```lua
{
  size = 'medium', align = 'bottom-center', orientation = 'horizontal', offsetX = 0, offsetY = 0,
  hidden = { health = true, horsebond = true, ... },  -- hideable keys: health stamina deadeye hunger thirst cleanliness stress temp voice mail outlaw horse horsebond horsehunger horsethirst
  display = {
    showPct = false, alwaysShow = false, voiceAlways = true, money = true,
    opacity = 100,  -- Config.SettingsLimits.minOpacity..100
    scale = 100,    -- Config.SettingsLimits.minScale..maxScale (multiplies the preset circle/badge size)
    mapFoot = 'map', mapMount = 'map', -- 'off' | 'map' | 'compass' (player value only used when Config.AllowPlayerMinimap)
    ringWarn = 70, ringBad = 30,  -- ring turns orange / red at or below these % (red is always ≥5 below orange)
    colors = { ['health.normal'] = '#4fa3e0', ['health.alert'] = '#c0392b', ['ring.good'] = '#6fbf73' }, -- only when Config.AllowPlayerColors
  }
}
```
Everything is sanitised client-side in `sanitiseDisplay` / `sanitiseHidden`; missing values fall back to Config. `/togglehudpct` now flips `display.showPct` in the KVP (the old `rsghud_showpct` localStorage value is no longer read).

### NUI messages / callbacks
| Name | Direction | Notes |
|---|---|---|
| `openPresetMenu` / `closePresetMenu` | Lua → NUI | carries `preset` |
| `applyPreset` | Lua → NUI | applies layout classes, hidden icons and `display` (`applyDisplay`) |
| `setConfig` | Lua → NUI | adds `allowMap`, `limits` |
| `savePreset` | NUI → Lua | full preset; `thenEdit = true` saves then enters edit mode |
| `closePresetMenu` | NUI → Lua | cancel, reverts the live preview |

### Window position
The settings window position is stored in NUI localStorage (`rsghud_settings_pos`) and clamped to the screen on open/resize.

### NUI focus
All focus goes through `applyNuiFocus`; while the settings window or edit mode has focus, game controls are disabled except `Config.PushToTalkControls`.

### Locales
`settings_title`, `settings_subtitle`, `tab_*`, `set_*`, `map_off`, `map_map`, `map_compass` (all locale files).

### Colours
Keys are `<icon>.normal` / `<icon>.alert` (icon keys as in `Config.IconColors`: health, stamina, deadeye, hunger, thirst, cleanliness, stress, temp, voice, mail, outlaw, horse_health, horse_stamina, horse_clean, horse_bond, horse_hunger, horse_thirst) and `ring.good` / `ring.warn` / `ring.bad`. *Alert* replaces the low/active/hasmail/cold colour. Only `#rrggbb` values are kept (max 64 entries); a colour equal to the server default isn't stored. Ring colours are applied as CSS variables `--ring-good/-warn/-bad` on `#ui-container`. The picker is pure HTML (no native `<input type="color">`).
Locales: `tab_colors`, `col_*`.


## Ring thresholds

Each player can set when stat rings change colour from **/hudsettings → Display** (*Orange Ring Below* / *Red Ring Below*, 5–95% in steps of 5). Defaults come from `Config.RingWarnAt` (70) and `Config.RingBadAt` (30). Saved in the player's preset (`display.ringWarn` / `display.ringBad`), clamped client-side so red always stays at least 5% below orange. Applies to health, stamina, dead eye, hunger, thirst, cleanliness and the horse rings; stress (inverted) and temperature keep their own fixed bands.

## Server-owned needs (anti-tamper)

With `Config.ServerNeeds = true` the server keeps the authoritative hunger / thirst / stress values:

- Seeded from rsg-core metadata on `RSGCore:Server:PlayerLoaded` (not from the client's state bag).
- Clients may raise hunger/thirst by up to `Config.MaxNeedGainPerMinute` and lower stress by up to `Config.MaxStressReliefPerMinute` per minute; anything beyond that is reverted.
- Server exports `SetNeed`, `GainStress` and `RelieveStress` write the value directly and are not subject to these limits.
