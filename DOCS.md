# rsg-hud — Developer Docs

**Version 3.3.0** · RSG Framework (rsg-core 3.x) · Lua 5.4 + Vue 3 NUI

Technical reference for server owners and developers. For a short overview and the player-facing feature list see [README.md](README.md).

## Contents
1. [Overview and dependencies](#1-overview-and-dependencies)
2. [File layout](#2-file-layout)
3. [Installation and database](#3-installation-and-database)
4. [Configuration](#4-configuration)
5. [Needs: hunger, thirst, stress, cleanliness](#5-needs-hunger-thirst-stress-cleanliness)
6. [Exports](#6-exports)
7. [Events and callbacks](#7-events-and-callbacks)
8. [Commands](#8-commands)
9. [Storage reference (state bags, KVP, localStorage)](#9-storage-reference)
10. [Features in detail](#10-features-in-detail)
11. [NUI reference](#11-nui-reference)
12. [Security model](#12-security-model)
13. [Locales](#13-locales)
14. [Server owner how-tos](#14-server-owner-how-tos)
15. [Troubleshooting](#15-troubleshooting)

---

## 1. Overview and dependencies

rsg-hud draws the player and horse HUD (rings for health, stamina, dead eye, hunger, thirst, cleanliness, stress, temperature, horse stats), mail / outlaw / clock / compass / ammo / weapon / well fed / injured horse badges, a money pop-up and a per-player settings window. It also owns the hunger / thirst / stress / cleanliness values (see section 5) and applies health damage, stress effects, flies and temperature rules.

| Dependency | Required | Used for |
|---|---|---|
| `rsg-core` | yes | player data, notifications (`RSGCore.Functions.Notify`), callbacks, commands, locales (`@rsg-core/shared/locale.lua`) |
| `oxmysql` | yes | reads `players.outlawstatus` (one query per player per 20 s at most) |
| `rsg-banking` v3 | optional | `/bank` total balance (`GetTotalBalance`), falls back to the core `bank` money |
| `rsg-stables` | optional | horse hunger / thirst circles (`GetActiveHorseNeeds`, see section 10.9) |
| `rsg-weather` | optional | keeps the game clock the clock badge reads in sync |
| `rsg-weapons` | optional | sets weapon degradation from item quality, which the weapon condition badge shows |

No `ox_lib`, no `ox_target`.

## 2. File layout

```
rsg-hud/
├── fxmanifest.lua          version, shared/client/server scripts, NUI files
├── shared/config.lua       every option (section 4)
├── client/client.lua       needs, stress, temperature, warnings, NUI feeds, settings window logic, exports
├── server/server.lua       /cash /bloodmoney /bank, outlaw callback, server-owned needs, decay modifiers, default layout, exports
├── server/versionchecker.lua   GitHub version check (prints to the server console)
├── html/index.html         NUI markup (HUD, money, settings window)
├── html/app.js             Vue apps: money, player HUD, drag/resize edit mode, settings window
├── html/styles.css         NUI styles (RDR2 leather and gold theme, no vignette)
├── locales/*.json          en, de, el, es, fr, it, ja, nl, pl, pt-br, ro, ru
└── stream/                 native HUD / minimap assets
```

## 3. Installation and database

1. Put `rsg-hud` in your resources folder.
2. `ensure rsg-hud` after `rsg-core` (and `oxmysql`) in `server.cfg`. Optionally set the language: `setr rsg:locale en`.
3. Adjust `shared/config.lua`.

**Database:** rsg-hud creates no tables and needs no SQL import. It only reads the `outlawstatus` column of rsg-core's `players` table.

**Persistence**
- Hunger, thirst, cleanliness and stress are state bags that rsg-core saves with the character (`stateBagKeys` in rsg-core).
- Each player's layout and display settings live in the player's own client KVP (`rsghud_preset`).
- The admin default layout lives in the server resource KVP (`rsghud_default_layout`).

## 4. Configuration

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
| `Config.WarningSound` | `true` | rsg-core warning notification sound with the low hunger / thirst, high stress and temperature warnings |
| `Config.HighStressWarning` | `80` | notify when stress reaches this value (0 = off) |
| `Config.DecayModifiers` | `table` | `enabled`, `maxMultiplier` (3.0), `activity` (run 1.25, sprint 2.0, swim 1.5, gallop 1.5), `environment` (hot / cold per-need), `wellFed` (`enabled`, `minimum` 80, `decayMultiplier` 0.5); needs `Config.ServerNeeds` |
| `Config.StressChance` | `0.1` | Default: 10% -- Percentage Stress Chance When Shooting (0-1) |
| `Config.MinimumStress` | `50` | Minimum Stress Level For Screen Shaking |
| `Config.MinimumSpeed` | `100` | Going Over This Speed Will Cause Stress |
| `Config.StressDecayRate` | `0.01` | Rate at which stress goes down. |
| `Config.HidePlayerHealthNative` | `true` | hide the game's own health core |
| `Config.HidePlayerStaminaNative` | `true` | hide the game's own stamina core |
| `Config.HidePlayerDeadEyeNative` | `true` | hide the game's own dead eye core |
| `Config.HideHorseHealthNative` | `true` | hide the game's own horse health core |
| `Config.HideHorseStaminaNative` | `true` | hide the game's own horse stamina core |
| `Config.HideHorseCourageNative` | `true` | hide the game's own horse courage core |
| `Config.ShowDeadEye` | `true` | deadeye core circle |
| `Config.ShowHorseBonding` | `true` | horse bonding level circle |
| `Config.ShowHorseNeeds` | `true` | horse hunger + thirst circles (needs rsg-stables, own active horse only) |
| `Config.ShowClock` | `true` | in-game time badge |
| `Config.Clock24h` | `false` | 24 hour clock |
| `Config.ShowCompass` | `false` | compass bearing badge |
| `Config.ShowAmmo` | `true` | ammo clip / reserve badge |
| `Config.ShowWeaponCondition` | `true` | weapon condition badge |
| `Config.ShowHorseInjury` | `true` | injured horse badge |
| `Config.HorseInjuredBelow` | `25` | horse health % at or below which the injured badge shows |
| `Config.BankCommand` | `'bank'` | command that shows the total bank balance |
| `Config.ShowVoice` | `false` | true = show the voice icon on the HUD, false = voice icon disabled |
| `Config.VoiceAlwaysVisible` | `true` | true = always visible, false = only when talking |
| `Config.ShowPercentages` | `false` | default for the % under circle icons (players change it in /hudsettings or /togglehudpct, saved per player) |
| `Config.SettingsCommand` | `'hudsettings'` | opens the HUD settings window |
| `Config.PresetCommand` | `'hudpreset'` | old command name, opens the same window |
| `Config.AllowPlayerMinimap` | `true` | let players choose minimap / compass / off (on foot + mounted); false = server Config only |
| `Config.AllowPlayerColors` | `true` | let players recolour icons + rings with the colour picker; false = Config.IconColors only |
| `Config.RingWarnAt` | `70` | ring turns orange at or below this % |
| `Config.RingBadAt` | `30` | ring turns red at or below this % |
| `Config.SettingsLimits` | `{ minOpacity = 30, minScale = 70, maxScale = 140 }` | limits for the player sliders |
| `Config.AllowPushToTalkWhileOpen` | `true` | While NUI is open, block game controls but allow push-to-talk. |
| `Config.PushToTalkControls` | `{ 0x4BC9DABB }` | controls left enabled while the NUI has focus |
| `Config.AdminPermission` | `'admin'` | permission level for `/pushhuddefault` and `/clearhuddefault` |
| `Config.PushDefaultCommand` | `'pushhuddefault'` | admin command that saves your current layout as the server default |
| `Config.ClearDefaultCommand` | `'clearhuddefault'` | admin command that removes the server default layout |
| `Config.DefaultPreset` | `{ size = 'medium', align = 'bottom-center', orientation = 'horizontal' }` | starting layout (size small/medium/large, align top/bottom + left/center/right, orientation horizontal/vertical) |
| `Config.OnFootMinimap` | `true` | set to true/false to disable/enable minimap when on foot |
| `Config.OnFootCompass` | `false` | true = have the minimap set to a compass instead of off or normal minimap |
| `Config.MountMinimap` | `true` | set to false if you want to disable the minimap when on mount |
| `Config.MountCompass` | `false` | set to true if you want to have a compass instead of normal minimap while on a mount |
| `Config.DoHealthDamage` | `true` | health damage from starvation, dehydration, dirt and extreme temperature |
| `Config.DoHealthDamageFx` | `false` | screen effect while taking that damage |
| `Config.DoHealthPainSound` | `true` | pain sound while taking that damage |
| `Config.TempFormat` | `'celsius'` | `'celsius'` or `'fahrenheit'` (display only) |
| `Config.TempFeature` | `false` | clothing warmth plus damage when too hot or cold |
| `Config.TempStaminaDrain` | `10` | cold/heatstroke drains this much stamina core per StatusInterval before health is hit |
| `Config.WearingHat` | `0` | warmth added in °C while worn (needs `TempFeature`) |
| `Config.WearingShirt` | `0` | warmth added in °C while worn (needs `TempFeature`) |
| `Config.WearingPants` | `0` | warmth added in °C while worn (needs `TempFeature`) |
| `Config.WearingBoots` | `0` | warmth added in °C while worn (needs `TempFeature`) |
| `Config.WearingCoat` | `15` | warmth added in °C while worn (needs `TempFeature`) |
| `Config.WearingOpenCoat` | `15` | warmth added in °C while worn (needs `TempFeature`) |
| `Config.WearingGloves` | `0` | warmth added in °C while worn (needs `TempFeature`) |
| `Config.WearingVest` | `0` | warmth added in °C while worn (needs `TempFeature`) |
| `Config.WearingPoncho` | `0` | warmth added in °C while worn (needs `TempFeature`) |
| `Config.WearingSkirt` | `0` | warmth added in °C while worn (needs `TempFeature`) |
| `Config.WearingChaps` | `0` | warmth added in °C while worn (needs `TempFeature`) |
| `Config.EnableNoWarmthJobs` | `true` | enable the job exemption below |
| `Config.NoWarmthJobs` | `{ 'leo', 'medic' }` | job types exempt from the warmth calculation |
| `Config.MinTemp` | `-5` | below this (°C) the status is `cold`, also used by the decay modifiers |
| `Config.MaxTemp` | `55` | above this (°C) the status is `hot`, also used by the decay modifiers |
| `Config.FlyEffect` | `true` | toggle flies on/off |
| `Config.MinCleanliness` | `30` | below this cleanliness the flies effect shows |
| `Config.RemoveHealth` | `1` | health removed per tick from dirt / extreme temperature |
| `Config.Intensity` | `table` | camera shake intensity per stress range |
| `Config.EffectInterval` | `table` | random ms between stress effects per stress range |
| `Config.IconColors` | `table` | default icon colours (players can override) |

### Configuration notes
- **Percent and rate options** are per `Config.StatusInterval` tick (default 5000 ms): `HungerRate = 0.01` removes 0.01 hunger every 5 s before modifiers.
- **Defaults vs player choices:** `ShowPercentages`, `VoiceAlwaysVisible`, `IconColors`, the minimap options, `RingWarnAt` / `RingBadAt` and `DefaultPreset` are only the starting values. A player's saved settings win, and an admin default layout (section 10.7) wins over `DefaultPreset` for players who never saved a layout.
- **Temperatures** (`MinTemp`, `MaxTemp`, warmth values) are always °C. `TempFormat` only changes what is displayed.
- **`Config.DecayModifiers`** needs `Config.ServerNeeds = true` (section 5.3).
- **`Config.IconColors`** keys: `voice`, `health`, `stamina`, `hunger`, `thirst`, `cleanliness`, `deadeye`, `stress`, `temp`, `mail`, `outlaw`, `horse_health`, `horse_stamina`, `horse_bond`, `horse_clean`, `horse_hunger`, `horse_thirst`, each with `normal` plus the alert colour (`low`, `active`, `hasmail` or `cold`).
- **`Config.Intensity` / `Config.EffectInterval`:** ranges of stress (`min`, `max`) with the camera shake `intensity` and the random `timeout = { minMs, maxMs }` between effects. Ranges are checked in order, so a stress value on a shared edge (60) uses the first matching range.

## 5. Needs: hunger, thirst, stress, cleanliness

All four are numbers 0-100 stored in the player's state bag: `LocalPlayer.state.hunger`, `.thirst`, `.cleanliness`, `.stress` (server: `Player(src).state.hunger`, ...). Stress 0 is calm, 100 is maximum stress.

### 5.1 Server-owned needs (`Config.ServerNeeds = true`, default)
The server keeps authoritative values for hunger, thirst and stress and decays them every `Config.StatusInterval`.
- Seeded from rsg-core metadata on `RSGCore:Server:PlayerLoaded` (never from the client's state bag). After a resource restart the live state bag is used instead.
- Clients may still change their own state bag (eating, drinking, smoking use `hud:client:UpdateHunger` and friends). The server reverts values that are not numbers, clamps values outside 0-100, and reverts hunger/thirst rising by more than `Config.MaxNeedGainPerMinute` per minute or stress falling by more than `Config.MaxStressReliefPerMinute` per minute (counted in one-minute windows). Changes that only hurt the player (hunger/thirst falling, stress rising) are accepted.
- Server exports (`SetNeed`, `GainStress`, `RelieveStress`) are trusted writes and skip these limits. Give large refills from the server.
- Cleanliness is client-driven (it follows the ped's dirt level) and is not server-owned.

With `Config.ServerNeeds = false` the client decays hunger, thirst and stress itself and the decay modifiers / well fed buff are unavailable.

### 5.2 What changes the values
| Source | Effect |
|---|---|
| Time (`HungerRate`, `ThirstRate`, `StressDecayRate`) | hunger and thirst go down, stress goes down |
| Speeding (vehicle or mount at or above `Config.MinimumSpeed` mph, checked every 10 s) | stress +1-3 |
| Shooting (`Config.StressChance` per shot) | stress +1-3 (law jobs of type `leo` never gain stress from the client path) |
| Other scripts | `hud:client:UpdateX` events or the exports in section 6 |
| Ped dirt level | cleanliness = 100 - dirt, refreshed every `Config.StatusInterval` |

### 5.3 Decay modifiers and the well fed buff (server)
`decayMultipliers(src, a)` in `server/server.lua` runs once per player per tick:
1. It reads the client-written state bags `rsghud_act` (`idle` `run` `sprint` `swim` `mounted` `gallop`) and `rsghud_env` (`hot` `cold` `none`) **only as lookup keys** into `Config.DecayModifiers`. Unknown values give multiplier 1.0.
2. Each client-driven multiplier is clamped to `[1.0, Config.DecayModifiers.maxMultiplier]`, so a modified client can only make itself hungrier.
3. The well fed multiplier (below 1.0, only possible here) applies when the server's own hunger and thirst are both at or above `wellFed.minimum`.
4. The buff is mirrored to the replicated state bag `rsghud_wellfed` (boolean). The client shows the badge and notifies on change (30 s cooldown, first value after login is silent).

```lua
-- shared/config.lua
Config.DecayModifiers = {
    enabled = true,
    maxMultiplier = 3.0,
    activity = { run = 1.25, sprint = 2.0, swim = 1.5, gallop = 1.5 },
    environment = { hot = { thirst = 1.75, hunger = 1.0 }, cold = { thirst = 1.0, hunger = 1.5 } },
    wellFed = { enabled = true, minimum = 80, decayMultiplier = 0.5 },
}
```
`hot` / `cold` use `Config.MaxTemp` / `Config.MinTemp` and work even with `Config.TempFeature = false`.

### 5.4 Health damage and effects
- Hunger or thirst at 0: 5-10 health lost per tick (`Config.DoHealthDamage`, pain sound `Config.DoHealthPainSound`).
- Dirty (cleanliness 0) or extreme temperature (`TempFeature` on): `Config.RemoveHealth` per tick. Cold / heatstroke drains the stamina core by `Config.TempStaminaDrain` first and only hurts health once it is empty.
- Stress at or above `Config.MinimumStress` shakes the camera (`Config.Intensity`); at 100 the player ragdolls and the screen fades.
- Cleanliness below `Config.MinCleanliness` spawns the flies effect (`Config.FlyEffect`).
- Low hunger / thirst (`Config.LowNeedWarning`) and high stress (`Config.HighStressWarning`) show a notification (sound `Config.WarningSound`), with hysteresis so it does not flicker. Heartbeat sound below `Config.LowHealthHeartbeat` % health.


## 6. Exports

Needs keys are `hunger`, `thirst`, `cleanliness`, `stress`.

### 6.1 Server exports (`server/server.lua`)
| Export | Arguments | Returns | Notes |
|---|---|---|---|
| `SetNeed` | `src, key, value` | `boolean` | absolute value 0-100. With `Config.ServerNeeds` and key hunger / thirst / stress this is a trusted write (no gain cap); cleanliness is sent to the client |
| `GetNeeds` | `src` | `table \| nil` | `{ hunger, thirst, cleanliness, stress }` read from the player's state bag |
| `GainStress` | `src, amount` | `boolean` | `amount > 0`; also shows the throttled stress notification |
| `RelieveStress` | `src, amount` | `boolean` | `amount > 0`, trusted (no relief cap) |
| `ShowAccount` | `src, account` | `boolean` | pops the money HUD for `'cash'`, `'bloodmoney'` or `'bank'` |

Server exports only change the HUD / needs. They never touch money or items.

```lua
-- server: a "soup" item that refills hunger and warms the player
RSGCore.Functions.CreateUseableItem('soup', function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not exports['rsg-inventory']:RemoveItem(source, 'soup', 1, item.slot, 'use-soup') then return end

    local needs = exports['rsg-hud']:GetNeeds(source)
    exports['rsg-hud']:SetNeed(source, 'hunger', math.min(100, needs.hunger + 35))
    exports['rsg-hud']:RelieveStress(source, 5)
end)

-- server: show the player's cash on the HUD
exports['rsg-hud']:ShowAccount(source, 'cash')
```

### 6.2 Client exports (`client/client.lua`)
| Export | Arguments | Returns | Notes |
|---|---|---|---|
| `GetNeeds` | none | `table` | `{ hunger, thirst, cleanliness, stress }` |
| `GetNeed` | `key` | `number \| nil` | `nil` for an unknown key |
| `SetNeed` | `key, value` | `boolean` | absolute 0-100. With `Config.ServerNeeds` big upward jumps are reverted by the per-minute cap, use the server export for refills |
| `AddNeed` | `key, amount` | `boolean` | add or (negative) remove, same cap rules |
| `GainStress` / `RelieveStress` | `amount` | none | local change plus throttled notification |
| `AddWarmth` | `amount, duration` | `boolean` | temporary body temperature change in °C (clamped ±15) for `duration` seconds, negative cools |
| `GetCurrentTemperature` | none | `number` | in `Config.TempFormat` units |
| `GetOutlawStatus` | none | `number` | cached, refreshed every 30 s (badge shows at 100 or more) |
| `SetHudVisible` / `IsHudVisible` | `visible` / none | none / `boolean` | hide the HUD for cutscenes, photo mode, etc. |
| `ToggleEditMode` / `IsEditMode` | `enabled?` / none | none / `boolean` | `nil` toggles |
| `OpenSettings` | none | none | opens `/hudsettings` |

```lua
-- client: hot drink warms the player for 2 minutes
exports['rsg-hud']:AddWarmth(4, 120)

-- client: hide the HUD during a cutscene, restore afterwards
exports['rsg-hud']:SetHudVisible(false)
-- ... cutscene ...
exports['rsg-hud']:SetHudVisible(true)

-- client: read needs
local needs = exports['rsg-hud']:GetNeeds()
if needs.thirst < 20 then print('very thirsty') end
```

## 7. Events and callbacks

### 7.1 Client events (all triggered by the server or other client scripts)
| Event | Arguments | Notes |
|---|---|---|
| `hud:client:UpdateNeeds` | `hunger, thirst, cleanliness` | cleanliness is offset by the ped's dirt |
| `hud:client:UpdateHunger` / `UpdateThirst` / `UpdateStress` | `value` | absolute 0-100 |
| `hud:client:UpdateCleanliness` | `value` | absolute, offset by the ped's dirt |
| `hud:client:GainStress` / `RelieveStress` | `amount, serverApplied` | `serverApplied = true` means the server already wrote the value and only the notification is shown |
| `hud:client:ShowAccounts` | `type, amount` | `'cash' \| 'bloodmoney' \| 'bank'` |
| `hud:client:OnMoneyChange` | `type, amount, isMinus` | fired by rsg-core on money changes |
| `hud:client:ToggleEditMode` | none | |
| `hud:client:SendDefaultLayout` | none | server asks an admin's client for its layout (section 10.7) |
| `hud:client:DefaultLayoutChanged` | none | refetch the server default layout |
| `HideAllUI` | none | **toggles** the HUD. Prefer `SetHudVisible(bool)`, which sets it explicitly |
| `RSGCore:Client:OnPlayerLoaded` / `OnPlayerUnload` | none | shows / hides the HUD, removes flies |

```lua
-- server: drink from a well (the client applies it, the server cap allows normal drinking amounts)
TriggerClientEvent('hud:client:UpdateThirst', source, 80)

-- client: legacy style used by many RSG scripts
TriggerEvent('hud:client:UpdateThirst', math.max(0, math.min(100, (LocalPlayer.state.thirst or 0) + 25)))
```

### 7.2 Server events
| Event | Arguments | Notes |
|---|---|---|
| `hud:server:setDefaultLayout` | `layout` | admin only (`Config.AdminPermission`), 5 s cooldown per player, payload sanitised (section 10.7). Do not trigger it from your own scripts |

### 7.3 Callbacks (rsg-core)
| Callback | Side | Returns |
|---|---|---|
| `hud:server:getoutlawstatus` | server | outlaw status number (cached 20 s per player on the server) |
| `hud:server:getDefaultLayout` | server | layout table or `false` |

```lua
RSGCore.Functions.TriggerCallback('hud:server:getoutlawstatus', function(status)
    print('outlaw status', status)
end)
```

## 8. Commands

| Command | Side | Permission | Description |
|---|---|---|---|
| `/hudsettings` (`Config.SettingsCommand`), `/hudpreset` (`Config.PresetCommand`) | client | everyone | open / close the settings window |
| `/edithud` | client | everyone | toggle drag and resize edit mode (`Esc` exits) |
| `/resethud` | client | everyone | reset dragged positions and sizes |
| `/togglehudpct` | client | everyone | toggle percentages in the circles |
| `/resethudlayout` | client | everyone | delete the player's saved layout so the server default (or `Config.DefaultPreset`) applies |
| `/cash`, `/bloodmoney` | server | everyone | show that balance on the HUD |
| `/bank` (`Config.BankCommand`) | server | everyone | show total bank balance (3 s cooldown) |
| `/pushhuddefault` (`Config.PushDefaultCommand`) | server | `Config.AdminPermission` | make your layout the server default |
| `/clearhuddefault` (`Config.ClearDefaultCommand`) | server | `Config.AdminPermission` | remove the server default layout |

## 9. Storage reference

### 9.1 State bags
| Key | Written by | Read by | Notes |
|---|---|---|---|
| `hunger`, `thirst`, `cleanliness`, `stress` | server (decay, exports) and client (eating, cleaning, stress) | both | replicated, saved by rsg-core. Server reverts illegal client writes (section 5.1) |
| `rsghud_act` | client | server | `idle run sprint swim mounted gallop`, only used as a lookup key |
| `rsghud_env` | client | server | `hot cold none`, only used as a lookup key |
| `rsghud_wellfed` | server | client | boolean, drives the badge and notification |

State bags rsg-hud only reads: `isLoggedIn`, `isBathingActive`, `inClothingStore`, `telegramUnreadMessages`, `telegramIsBirdPostApproaching`, and the player's `isdead` metadata.

### 9.2 Client KVP `rsghud_preset` (per player)
```lua
{
  size = 'medium', align = 'bottom-center', orientation = 'horizontal', offsetX = 0, offsetY = 0,
  hidden = { health = true, clock = true },   -- hideable keys: health stamina deadeye hunger thirst cleanliness stress temp voice
                                              -- mail outlaw horse horsebond horsehunger horsethirst clock compass ammo weapon wellfed horseinjury
  display = {
    showPct = false, alwaysShow = false, voiceAlways = true, money = true,
    opacity = 100,                    -- Config.SettingsLimits.minOpacity .. 100
    scale = 100,                      -- Config.SettingsLimits.minScale .. maxScale
    mapFoot = 'map', mapMount = 'map',-- 'off' | 'map' | 'compass' (used when Config.AllowPlayerMinimap)
    ringWarn = 70, ringBad = 30,      -- red is always at least 5 below orange
    palette = 'default',              -- 'default' | 'redgreen' | 'blueyellow' (when Config.AllowPlayerColors)
    colors = { ['health.normal'] = '#4fa3e0', ['ring.good'] = '#6fbf73' }, -- only #rrggbb, max 64 (when Config.AllowPlayerColors)
  }
}
```
Everything is sanitised on load (`sanitiseDisplay`, `sanitiseHidden`) and again on every save from the NUI (`savePreset`). Missing values fall back to Config.

### 9.3 Server resource KVP `rsghud_default_layout`
JSON of the admin default layout, same shape as above, already sanitised by `sanitiseLayout`.

### 9.4 NUI localStorage
| Key | Content |
|---|---|
| `hudPositions`, `hudSizes` | positions and sizes from edit mode (dragged icons). Cleared when the Layout tab changes or `/resethud` runs |
| `rsghud_settings_pos` | where the player moved the settings window |


## 10. Features in detail

### 10.1 Settings window (`/hudsettings`)
Movable NUI window (drag the title bar, double-click it to re-centre). Tabs: Layout, Icons, Display, Map (`Config.AllowPlayerMinimap`), Colours (`Config.AllowPlayerColors`). Every change previews live; Apply (`Enter`) saves, Cancel (`Esc`) reverts. Only changing the Layout tab clears custom drag/resize positions. From another script: `exports['rsg-hud']:OpenSettings()`.

All NUI focus goes through `applyNuiFocus`. While the window or edit mode has focus, game controls are disabled except `Config.PushToTalkControls`, so push-to-talk keeps working (`Config.AllowPushToTalkWhileOpen`).

### 10.2 Colours
Slots are `<icon>.normal` / `<icon>.alert` (icon keys as in `Config.IconColors`) and `ring.good` / `ring.warn` / `ring.bad`. *Alert* replaces the low / active / hasmail / cold colour. Only `#rrggbb` is kept, a colour equal to the default is not stored. Ring colours become CSS variables `--ring-good/-warn/-bad` on `#ui-container`. The picker is pure HTML (no native `<input type="color">`, which can crash RedM's CEF).

### 10.3 Ring thresholds
Players set when rings turn orange and red in Display (`ringWarn` / `ringBad`, 5-95 %, red always at least 5 below orange). Defaults `Config.RingWarnAt` (70) / `Config.RingBadAt` (30). Applies to health, stamina, dead eye, hunger, thirst, cleanliness, horse rings and the weapon condition badge. Stress (inverted) and temperature use fixed bands.

### 10.4 Colourblind-safe palettes
`display.palette` is `default`, `redgreen` (blue / yellow / vermilion) or `blueyellow` (teal / pink / red). Palettes are defined in `html/app.js` (`PALETTES`) and only recolour the three ring colours. A player's own `ring.*` colours override the palette. Only kept when `Config.AllowPlayerColors = true`.

### 10.5 Share codes
`Layout > Share Layout`. A code is `RSGHUD1:` + base64(JSON of `size, align, orientation, offsetX, offsetY, hidden, display`).
- **Export** builds the code, selects it and tries `document.execCommand('copy')`. If the clipboard is blocked the code stays selected for `Ctrl+C`.
- **Import** validates every field in the NUI (known enums, clamped numbers, known icon keys, hex colours, `allowMap` / `allowColors` respected), previews it live and only saves when the player presses Apply. `savePreset` sanitises again in Lua.

### 10.6 Extra badges
| Badge (hide key) | Config | Data source |
|---|---|---|
| Clock (`clock`) | `ShowClock`, `Clock24h` | `GetClockHours()` / `GetClockMinutes()` in the 500 ms `hudtick` (rsg-weather keeps the clock synced) |
| Compass (`compass`) | `ShowCompass` (default off) | `GetGameplayCamRot(2).z` converted to a clockwise bearing, 2 degree steps, own 200 ms feed. Letters from the `compass_dirs` locale key (8 comma separated values N to NW) |
| Ammo (`ammo`) | `ShowAmmo` | `GET_AMMO_IN_CLIP` 0x2E1202248937775C, `GET_AMMO_IN_PED_WEAPON` 0x015A522136D7F951, `GET_MAX_AMMO_IN_CLIP` 0xA38DCFFCEA8962FA. `reserve = total - clip`, assuming the total includes the loaded clip. Red when the clip is empty |
| Weapon condition (`weapon`) | `ShowWeaponCondition` | `GET_CURRENT_PED_WEAPON_ENTITY_INDEX` 0x3B390A939AF0B5FC (attach point 0) and `GET_WEAPON_DEGRADATION` 0x0D78E1097F89E637 (0.0 good to 1.0 poor), shown as `(1 - degradation) * 100` % |
| Well fed (`wellfed`) | needs `ServerNeeds` and `DecayModifiers.wellFed.enabled` | state bag `rsghud_wellfed` |
| Injured horse (`horseinjury`) | `ShowHorseInjury`, `HorseInjuredBelow` | computed in the NUI from `horsehealth`. There is no dedicated "injured" native, so this is a health threshold |

The ammo and weapon feed (`combat`) is only sent when its content changes and is hidden while the HUD is hidden or the weapon is unarmed. Each native call is wrapped in `pcall`, so a missing native never breaks the HUD.

### 10.7 Admin default layout
1. An admin with `Config.AdminPermission` sets up their HUD and runs `/pushhuddefault`.
2. The server triggers `hud:client:SendDefaultLayout` on that admin; the client answers with `hud:server:setDefaultLayout(getPreset())`.
3. The server re-checks permission (`RSGCore.Functions.HasPermission`), applies a 5 s per-player cooldown, runs `sanitiseLayout` (known enums, clamped numbers, booleans, `#rrggbb` colours, known icon keys, palette whitelist), stores the JSON in KVP `rsghud_default_layout` and broadcasts `hud:client:DefaultLayoutChanged`.
4. Each client calls the callback `hud:server:getDefaultLayout`. `getPreset()` uses the player's own saved preset first, then this default, then `Config.DefaultPreset`.

`/clearhuddefault` removes it. `/resethudlayout` lets a player drop their own layout to fall back to the default. Players who saved their own layout keep it.

### 10.8 Money HUD
`hud:client:OnMoneyChange` (sent by rsg-core) shows the cash / bloodmoney / bank chips plus a +/- delta for 2 s. `/cash`, `/bloodmoney`, `/bank` and `ShowAccount` show a balance for 3.5 s. Per-player switch: Display > Money Pop-ups.

### 10.9 Horse hunger and thirst (rsg-stables)
rsg-hud reads the values every HUD tick through a client export in rsg-stables, wrapped in `pcall`:

```lua
-- rsg-stables/client/client.lua (anywhere after `local activeHorse`)
exports('GetActiveHorseNeeds', function()
    if not activeHorse or not activeHorse.entity or not DoesEntityExist(activeHorse.entity) then return nil end
    return { entity = activeHorse.entity, hunger = activeHorse.hunger or 100, thirst = activeHorse.thirst or 100 }
end)
```
The values only show when `needs.entity` is the horse being ridden, so borrowed, stolen or wild horses show `--`. If rsg-stables is stopped or the export is missing the circles stay hidden. Config: `Config.ShowHorseNeeds`, `Config.IconColors.horse_hunger` / `horse_thirst`.

### 10.10 Temperature and warmth
Body temperature (°C) = `GetTemperatureAtCoords` + clothing warmth (`Config.Wearing*`, skipped for `Config.NoWarmthJobs` job types) + temporary warmth from `AddWarmth`. With `Config.TempFeature = true`, below `MinTemp` or above `MaxTemp` sets the status `cold` / `hot`: the icon pulses, a warning shows, stamina then health drain (section 5.4). The icon always shows the temperature in `Config.TempFormat` units.

### 10.11 Minimap
Every 500 ms the client picks off / map / compass for on-foot or mounted/vehicle/bird-post, from the player's setting (or `Config.OnFootMinimap`, `OnFootCompass`, `MountMinimap`, `MountCompass` when `AllowPlayerMinimap = false`). The map zooms in inside interiors. Stopping the resource restores the normal minimap.

### 10.12 Cleanup
`onResourceStop` removes the flies effect and downed effect, stops camera shaking, restores the minimap and releases NUI focus.

## 11. NUI reference

### 11.1 Lua to NUI (`SendNUIMessage`)
| `action` | Fields | When |
|---|---|---|
| `hudtick` | `show`, `health`, `stamina`, `hunger`, `thirst`, `cleanliness`, `stress`, `talking`, `temp` (string like `12°C`), `tempStatus`, `onHorse`, `horsehealth`, `horsestamina`, `horseclean`, `horsebond`, `horsehunger`, `horsethirst`, `deadeye`, `youhavemail`, `outlawstatus`, `wellfed`, `hour`, `minute` | every 500 ms, only when the payload changed. `{ show = false }` while hidden |
| `compass` | `heading` (0-359) | on change, 200 ms check |
| `combat` | `armed`, `hasAmmo`, `clip`, `reserve`, `condition` (0-100 or absent) | on change, 200 ms check |
| `setLocales` | `locales` (key to text) | once after `nuiReady` |
| `setConfig` | `iconColors`, `voiceEnabled`, `deadeyeEnabled`, `bondEnabled`, `horseNeedsEnabled`, `allowMap`, `allowColors`, `badges` (`clock compass ammo weapon wellfed horseinjury`), `horseInjuredBelow`, `clock24h`, `limits` | once after `nuiReady` |
| `applyPreset` | `preset`, `clearCustom` | layout / display apply and live revert |
| `openPresetMenu` / `closePresetMenu` | `preset` | settings window |
| `toggleEditMode` | `enabled` | edit mode |
| `resetPositions` | none | `/resethud` |
| `show` / `update` | `type`, `cash`, `bloodmoney`, `bank`, `amount`, `minus` | money chips |

### 11.2 NUI to Lua (`RegisterNUICallback`)
| Callback | Data | Notes |
|---|---|---|
| `nuiReady` | none | triggers `setLocales`, `setConfig`, `applyPreset` and the default layout fetch |
| `savePreset` | full preset, `thenEdit?` | validated by `sanitiseDisplay` / `sanitiseHidden` / `VALID_PRESET`; replies `'invalid'` for bad enums |
| `closePresetMenu` | none | cancel, reverts the live preview |
| `disableEditMode` | none | `Esc` in edit mode |

NUI rules followed: Roboto font, monochrome leather and gold theme, no vignette, no native `<select>` / `<option>`. The page loads Vue, Font Awesome and Google Fonts from CDNs, so players need internet access (see Troubleshooting).

## 12. Security model

- **No money or items.** rsg-hud never adds or removes money or items. Server exports only change HUD values.
- **Server-owned needs.** Client writes to hunger / thirst / stress are range-checked, rate-limited per minute and reverted (section 5.1). Seeded from rsg-core metadata, not from the client.
- **Decay modifiers cannot help a cheater.** `rsghud_act` / `rsghud_env` are only lookup keys, clamped to at least 1.0 and at most `maxMultiplier`. The well fed buff is decided from server values.
- **Admin default layout.** The only server net event is `hud:server:setDefaultLayout`: valid player, 5 s cooldown first, then `HasPermission`, then `sanitiseLayout` (whitelists and clamps, 64 colour cap). The `pushhuddefault` / `clearhuddefault` commands are permission-restricted by rsg-core.
- **Rate limits and caching.** `/bank` has a 3 s cooldown (it queries rsg-banking), the outlaw callback is cached 20 s per player so a spamming client cannot hammer the database. All SQL uses `?` parameters.
- **Client-only data.** Layout, colours and display settings are per-player cosmetics stored on the player's own machine and sanitised on load, so a tampered KVP or share code cannot inject anything beyond whitelisted values.
- **Other scripts.** `hud:client:UpdateX` events can only be triggered locally or by the server, but any script can call the client exports. If your reward scripts give hunger / thirst, do it from the server with `SetNeed`, after your own validation.

## 13. Locales

`locales/*.json`: `en` (master), `de`, `el`, `es`, `fr`, `it`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Every file has the same 125 keys. Set the language with `setr rsg:locale en`. Loaded by rsg-core through `@rsg-core/shared/locale.lua`, used as `locale('key', ...)`.

| Key group | Used for |
|---|---|
| `*_label` | edit mode handles and visibility list (health, stamina, clock, compass, ammo, weapon, wellfed, horse_injury, ...) |
| `edit_mode_*`, `reset_hud_*` | edit mode and reset notifications |
| `stress_gain`, `stress_relief`, `high_stress`, `low_*`, `temp_*`, `wellfed_*` | gameplay notifications |
| `preset_*`, `settings_*`, `tab_*`, `set_*`, `map_*` | settings window |
| `col_*`, `palette_*` | Colours tab |
| `set_share`, `share_*` | share layout |
| `cmd_*`, `default_*`, `layout_reset_done` | commands and admin default layout notices |
| `compass_dirs` | 8 comma separated compass letters (N,NE,E,SE,S,SW,W,NW) |

To add a key, add it to all 12 files and, if the NUI needs it, to `localeKeys` in `client/client.lua`. The clock's `AM` / `PM` suffix is not localised.

## 14. Server owner how-tos

**Make hunger and thirst fade slower or faster:** change `Config.HungerRate` / `Config.ThirstRate` (per `StatusInterval`) or the multipliers in `Config.DecayModifiers`.

**Turn the decay modifiers or well fed buff off:**
```lua
Config.DecayModifiers = { enabled = false }          -- both off
-- or only the buff:
Config.DecayModifiers.wellFed.enabled = false
```

**Let the client fully manage needs (no anti-tamper):** `Config.ServerNeeds = false`. Decay modifiers and well fed are then unavailable.

**Hide a badge for everyone:** set its config option to `false` (`Config.ShowClock = false`). Players can additionally hide any badge themselves in `/hudsettings > Icons`.

**Give everyone the same HUD layout:** set it up, run `/pushhuddefault`. Players with no saved layout get it immediately.

**Use a different language:** `setr rsg:locale de`.

**Change warning wording or add a language:** edit or add `locales/<lang>.json` (keep all keys).

## 15. Troubleshooting

| Problem | Cause and fix |
|---|---|
| HUD does not show | Not logged in yet, `HideAllUI` was toggled by another script, or `SetHudVisible(false)` was called. Run `exports['rsg-hud']:SetHudVisible(true)` from the console script of your choice. The HUD also hides in the pause menu, cinematic cam, bathing and clothing stores |
| HUD blank or no icons | The NUI loads Vue, Font Awesome and Google Fonts from CDNs. Check the player's internet access / firewall, or host those files inside `html/` and point `index.html` at them |
| Hunger or thirst jumps back after a script fills it | The client gain cap (`MaxNeedGainPerMinute`) reverted it. Refill from the server with `exports['rsg-hud']:SetNeed(src, 'hunger', value)` |
| Horse hunger / thirst show `--` or are hidden | Not your own active rsg-stables horse, rsg-stables stopped, or the `GetActiveHorseNeeds` export (section 10.9) is missing |
| Temperature warnings never show | `Config.TempFeature = false` (default). The decay modifiers' hot / cold report still works |
| Ammo reserve looks wrong | The badge assumes the game's total ammo includes the loaded clip. If your ammo script reports it differently, adjust the `reserve` calculation in `client/client.lua` |
| Weapon condition badge missing | The weapon has no object in hand or no degradation; the badge hides itself |
| Admin default layout has no effect on a player | That player saved their own layout. They can run `/resethudlayout` |
| `/pushhuddefault` says no permission | Check `Config.AdminPermission` and the player's rsg-core permission level |
| Share code "not valid" | Must start with `RSGHUD1:`, be under 4000 characters and come from this version |
| Settings window stuck off-screen | Double-click the window title to re-centre it, or clear `rsghud_settings_pos` |
| Console warns about a missing locale key | A key exists in `en.json` but not in the active language file. Keep all files in sync |

---
Support the Project : https://rexshack.tebex.store/
