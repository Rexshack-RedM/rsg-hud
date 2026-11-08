# rsg-hud

Player and horse HUD for RSG-Core (RedM): health, stamina, dead eye, hunger, thirst, cleanliness, stress, temperature, voice, mail and outlaw badges, horse health/stamina/cleanliness/bonding/hunger/thirst, a money pop-up, and a drag-and-resize edit mode.

## Features
- **Server-owned needs** (`Config.ServerNeeds`): the server decays hunger, thirst and stress and reverts state bag tampering. Clients can still add hunger/thirst by eating/drinking, capped by `Config.MaxNeedGainPerMinute`; stress relief from the client is capped by `Config.MaxStressReliefPerMinute`. Values persist through rsg-core metadata.
- **Warnings**: a notification when hunger/thirst drops to `Config.LowNeedWarning`, and a heartbeat sound below `Config.LowHealthHeartbeat` % health.
- **Dead eye and horse bonding icons** (`Config.ShowDeadEye`, `Config.ShowHorseBonding`).
- **Horse hunger and thirst icons** while mounted on your own active rsg-stables horse (`Config.ShowHorseNeeds`). Needs the `GetActiveHorseNeeds` client export in rsg-stables (see DOCS.md); hidden on borrowed/wild horses or when rsg-stables isn't running.
- **Cold / heatstroke status** (with `Config.TempFeature`): the temperature icon switches to a snowflake/sun and pulses; the stamina core drains by `Config.TempStaminaDrain` first, and health is only hit once it's empty.
- **HUD settings window** (`/hudsettings`): movable NUI to adjust every HUD feature per player (layout, icons, display, minimap).
- **Bank balance** via `/bank`, using rsg-banking v3's total across all branches (falls back to the core `bank` money).

## Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-banking](https://github.com/Rexshack-RedM/rsg-banking) v3 (optional, for `/bank`)
- [rsg-stables](https://github.com/Rexshack-RedM/rsg-stables) (optional, for horse hunger/thirst)
- [oxmysql](https://github.com/overextended/oxmysql) (reads `players.outlawstatus`)

## Installation
1. Drop `rsg-hud` into your resources folder.
2. Add `ensure rsg-hud` after `rsg-core` in `server.cfg`.
3. Configure `shared/config.lua`.

## Commands
| Command | Description |
|---|---|
| `/edithud` | Toggle edit mode (drag elements, resize with the corner handle, `ESC` to exit) |
| `/resethud` | Reset all HUD positions and sizes |
| `/hudsettings` | Open the HUD settings window (see below), command name `Config.SettingsCommand` |
| `/hudpreset` | Old name, opens the same window (`Config.PresetCommand`) |
| `/togglehudpct` | Show/hide percentages in the circles (saved per player) |
| `/cash` | Show cash balance |
| `/bloodmoney` | Show bloodmoney balance |
| `/bank` | Show total bank balance (rsg-banking v3), command name `Config.BankCommand` |

Dragged positions/sizes are saved in the player's NUI storage; everything in the settings window is saved per player in client KVP.

## HUD settings window (`/hudsettings`)
A movable NUI window (drag it by the title bar, double-click the title to re-centre; its spot is remembered) where each player adjusts every HUD feature:

| Tab | Settings |
|---|---|
| **Layout** | Icon size (small/medium/large), screen position (click a spot on the mini screen), horizontal/vertical, fine position with the **arrow keys** (Shift = bigger steps) |
| **Icons** | Show/hide each icon (incl. dead eye, horse bonding, horse hunger/thirst), *Always show icons* (even when full), **Drag & Resize Icons** (saves and enters edit mode), **Reset Icon Positions** |
| **Display** | Percentages on/off, voice icon always on, money pop-ups on/off, HUD opacity slider, icon scale slider, ring colour thresholds (when rings turn orange / red) |
| **Map** | Minimap / compass / off, separately for on foot and on horse/vehicle (only when `Config.AllowPlayerMinimap = true`) |
| **Colours** | Colour picker (colour square, hue bar, swatches, hex input) for every icon's *normal* and *alert* colour, and for the ring colours (good / warning / low). Per-icon and reset-all buttons (only when `Config.AllowPlayerColors = true`) |

Every change previews live. `Enter` / **Apply** saves (client KVP, survives relogs); `Esc` / **Cancel** / ✕ reverts.
Only changing the *Layout* tab clears custom drag/resize of the stat icons; other settings keep them.
Push-to-talk keeps working while the window or edit mode is open (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`).

Config: `Config.SettingsCommand`, `Config.PresetCommand`, `Config.DefaultPreset`, `Config.AllowPlayerMinimap`, `Config.AllowPlayerColors`, `Config.SettingsLimits` (min opacity, min/max scale), `Config.RingWarnAt` / `Config.RingBadAt` (default ring thresholds). `Config.ShowPercentages`, `Config.VoiceAlwaysVisible`, `Config.IconColors` and the minimap options are the defaults for players who haven't changed them.

## Voice icon
Disabled by default. Enable with `Config.ShowVoice = true`; `Config.VoiceAlwaysVisible` controls always-on vs only while talking.

## Events (client)
| Event | Args |
|---|---|
| `hud:client:UpdateNeeds` | hunger, thirst, cleanliness |
| `hud:client:UpdateHunger` / `UpdateThirst` / `UpdateStress` / `UpdateCleanliness` | value (0-100) |
| `hud:client:GainStress` / `hud:client:RelieveStress` | amount |
| `hud:client:ShowAccounts` | `'cash' \| 'bloodmoney' \| 'bank'`, amount |
| `hud:client:ToggleEditMode` | - |
| `HideAllUI` | toggles the HUD |

Needs are stored in player state bags: `LocalPlayer.state.hunger`, `.thirst`, `.cleanliness`, `.stress`.

## Exports

### Client
```lua
local hud = exports['rsg-hud']
hud:GetNeeds()                      -- { hunger, thirst, cleanliness, stress }
hud:GetNeed('hunger')               -- number
hud:SetNeed('thirst', 100)          -- set absolute value (0-100)
hud:AddNeed('hunger', 25)           -- add / subtract (negative)
hud:GainStress(5)
hud:RelieveStress(10)
hud:SetHudVisible(false)            -- hide/show the HUD
hud:IsHudVisible()
hud:ToggleEditMode(true)            -- nil toggles
hud:IsEditMode()
hud:GetCurrentTemperature()         -- number, in Config.TempFormat units
hud:GetOutlawStatus()               -- number
```
Needs are: `hunger`, `thirst`, `cleanliness`, `stress`.

### Server
```lua
local hud = exports['rsg-hud']
hud:SetNeed(source, 'hunger', 100)   -- with ServerNeeds this is a trusted write (no gain cap)
hud:GetNeeds(source)                -- reads the player's state bag
hud:GainStress(source, 5)
hud:RelieveStress(source, 10)
hud:ShowAccount(source, 'cash')     -- 'cash' | 'bloodmoney' | 'bank'
```
All setters return `true`/`false`. Server exports only push values to the player's HUD; they never touch money or items.

## Configuration highlights
- `Config.StatusInterval`, `HungerRate`, `ThirstRate`, `StressDecayRate`: needs decay.
- `Config.DoHealthDamage`: damage when starving, dehydrated, filthy or at extreme temperature (`Config.TempFeature`, `MinTemp`/`MaxTemp` in °C).
- `Config.EffectInterval`: `timeout = { min, max }` in ms between stress screen effects.
- `Config.IconColors`: per-icon colours.
- Minimap/compass behaviour on foot and mounted.

## Locales
`locales/*.json`: en, de, el, es, fr, it, ja, nl, pl, pt-br, ro (handled by rsg-core). Set the language with `setr rsg:locale en`.

## Notes
- No ox_lib dependency: locales, notifications and helpers come from rsg-core.
- Cleanliness follows the ped's dirt level every `Config.StatusInterval`; wash the ped to change it rather than setting the need directly.
- Speeding stress counts both vehicles and mounts.
- With `Config.ServerNeeds = true`, other scripts keep using `hud:client:UpdateHunger/UpdateThirst` as before; large client-side jumps beyond the per-minute cap are reverted, so give big refills from the server with `exports['rsg-hud']:SetNeed(src, ...)`.

---
Support: https://buymeacoffee.com/rexshack
