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

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-hud 3.2.1**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.StatusInterval` | `5000` | how often to update hunger/thirst status in milliseconds |
| `Config.HungerRate` | `0.01` | Rate at which hunger goes down. |
| `Config.ThirstRate` | `0.01` | Rate at which thirst goes down. |
| `Config.ServerNeeds` | `true` | server-owned needs: the server decays hunger/thirst/stress and reverts client state bag tampering |
| `Config.MaxStressReliefPerMinute` | `50` | max stress a client may remove per minute (smoking, drinking, etc.); more is reverted |
| `Config.MaxNeedGainPerMinute` | `150` | max hunger/thirst a client may add per minute (eating/drinking); more is reverted |
| `Config.LowNeedWarning` | `20` | notify when hunger/thirst drops to this value (0 = off) |
| `Config.LowHealthHeartbeat` | `25` | play a heartbeat below this health % (0 = off) |
| `Config.HeartbeatSound` | `{ name = 'Heartbeat', set = 'RDRO_Sniper_Tension_Sounds' }` | rdr3_discoveries audio/frontend_soundsets |
| `Config.StressChance` | `0.1` | Default: 10% -- Percentage Stress Chance When Shooting (0-1) |
| `Config.MinimumStress` | `50` | Minimum Stress Level For Screen Shaking |
| `Config.MinimumSpeed` | `100` | Going Over This Speed Will Cause Stress |
| `Config.StressDecayRate` | `0.01` | Rate at which stress goes down. |
| `Config.HidePlayerHealthNative` | `true` |  |
| `Config.HidePlayerStaminaNative` | `true` |  |
| `Config.HidePlayerDeadEyeNative` | `true` |  |
| `Config.HideHorseHealthNative` | `true` |  |
| `Config.HideHorseStaminaNative` | `true` |  |
| `Config.HideHorseCourageNative` | `true` |  |
| `Config.ShowDeadEye` | `true` | deadeye core circle |
| `Config.ShowHorseBonding` | `true` | horse bonding level circle |
| `Config.ShowHorseNeeds` | `true` | horse hunger + thirst circles (needs rsg-stables, own active horse only) |
| `Config.BankCommand` | `'bank'` |  |
| `Config.ShowVoice` | `false` | true = show the voice icon on the HUD, false = voice icon disabled |
| `Config.VoiceAlwaysVisible` | `true` | true = always visible, false = only when talking |
| `Config.ShowPercentages` | `false` | default for the % under circle icons (players change it in /hudsettings or /togglehudpct, saved per player) |
| `Config.SettingsCommand` | `'hudsettings'` | opens the HUD settings window |
| `Config.PresetCommand` | `'hudpreset'` | old command name, opens the same window |
| `Config.AllowPlayerMinimap` | `true` | let players choose minimap / compass / off (on foot + mounted); false = server Config only |
| `Config.AllowPlayerColors` | `true` | let players recolour icons + rings with the colour picker; false = Config.IconColors only |
| `Config.RingWarnAt` | `70` | ring turns orange at or below this % |
| `Config.RingBadAt` | `30` | ring turns red at or below this % |
| `Config.SettingsLimits` | `table` |  |
| `Config.AllowPushToTalkWhileOpen` | `true` | While NUI is open, block game controls but allow push-to-talk. |
| `Config.PushToTalkControls` | `table` |  |
| `Config.DefaultPreset` | `table` |  |
| `Config.OnFootMinimap` | `true` | set to true/false to disable/enable minimap when on foot |
| `Config.OnFootCompass` | `false` | true = have the minimap set to a compass instead of off or normal minimap |
| `Config.MountMinimap` | `true` | set to false if you want to disable the minimap when on mount |
| `Config.MountCompass` | `false` | set to true if you want to have a compass instead of normal minimap while on a mount |
| `Config.DoHealthDamage` | `true` |  |
| `Config.DoHealthDamageFx` | `false` |  |
| `Config.DoHealthPainSound` | `true` |  |
| `Config.TempFormat` | `'celsius'` |  |
| `Config.TempFeature` | `false` |  |
| `Config.TempStaminaDrain` | `10` | cold/heatstroke drains this much stamina core per StatusInterval before health is hit |
| `Config.WearingHat` | `0` |  |
| `Config.WearingShirt` | `0` |  |
| `Config.WearingPants` | `0` |  |
| `Config.WearingBoots` | `0` |  |
| `Config.WearingCoat` | `15` |  |
| `Config.WearingOpenCoat` | `15` |  |
| `Config.WearingGloves` | `0` |  |
| `Config.WearingVest` | `0` |  |
| `Config.WearingPoncho` | `0` |  |
| `Config.WearingSkirt` | `0` |  |
| `Config.WearingChaps` | `0` |  |
| `Config.EnableNoWarmthJobs` | `true` | set to true/false to enable/disable the feature |
| `Config.NoWarmthJobs` | `table` |  |
| `Config.MinTemp` | `-5` |  |
| `Config.MaxTemp` | `55` |  |
| `Config.FlyEffect` | `true` | toggle flies on/off |
| `Config.MinCleanliness` | `30` |  |
| `Config.RemoveHealth` | `1` |  |
| `Config.Intensity` | `table` |  |
| `Config.EffectInterval` | `table` |  |
| `Config.IconColors` | `table` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `SetNeed` | `src, key, value` | `server/server.lua` |
| `GetNeeds` | `src` | `server/server.lua` |
| `GainStress` | `src, amount` | `server/server.lua` |
| `RelieveStress` | `src, amount` | `server/server.lua` |
| `ShowAccount` | `src, account` | `server/server.lua` |

**Client**

| Export | Arguments | File |
|---|---|---|
| `GetCurrentTemperature` | `` | `client/client.lua` |
| `GetOutlawStatus` | `` | `client/client.lua` |
| `OpenSettings` | `` | `client/client.lua` |
| `GetNeeds` | `` | `client/client.lua` |
| `GetNeed` | `key` | `client/client.lua` |
| `SetNeed` | `key, value` | `client/client.lua` |
| `AddNeed` | `key, amount` | `client/client.lua` |
| `GainStress` | `amount` | `client/client.lua` |
| `RelieveStress` | `amount` | `client/client.lua` |
| `SetHudVisible` | `visible` | `client/client.lua` |
| `IsHudVisible` | `` | `client/client.lua` |
| `ToggleEditMode` | `enabled` | `client/client.lua` |
| `IsEditMode` | `` | `client/client.lua` |

```lua
-- example
local result = exports['rsg-hud']:SetNeed(src, key, value)
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `hud:server:getoutlawstatus` | server | `source, cb` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('hud:server:getoutlawstatus', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `HideAllUI` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `hud:client:UpdateNeeds` | client | `newHunger, newThirst, newCleanliness` | `client/client.lua` |
| `hud:client:UpdateHunger` | client | `v` | `client/client.lua` |
| `hud:client:UpdateThirst` | client | `v` | `client/client.lua` |
| `hud:client:UpdateStress` | client | `v` | `client/client.lua` |
| `hud:client:UpdateCleanliness` | client | `v` | `client/client.lua` |
| `hud:client:GainStress` | client | `amount, serverApplied` | `client/client.lua` |
| `hud:client:RelieveStress` | client | `amount, serverApplied` | `client/client.lua` |
| `hud:client:ShowAccounts` | client | `type, amount` | `client/client.lua` |
| `hud:client:OnMoneyChange` | client | `type, amount, isMinus` | `client/client.lua` |
| `hud:client:ToggleEditMode` | client | `` | `client/client.lua` |

```lua
-- from a server script
TriggerClientEvent('HideAllUI', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/edithud` |  | `client/client.lua` |
| `/togglehudpct` |  | `client/client.lua` |
| `/resethud` |  | `client/client.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `it`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
