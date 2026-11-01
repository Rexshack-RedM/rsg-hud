# rsg-hud

Player and horse HUD for RSG-Core (RedM): health, stamina, dead eye, hunger, thirst, cleanliness, stress, temperature, voice, mail and outlaw badges, horse health/stamina/cleanliness/bonding, a money pop-up, and a drag-and-resize edit mode.

## Features
- **Server-owned needs** (`Config.ServerNeeds`): the server decays hunger, thirst and stress and reverts state bag tampering. Clients can still add hunger/thirst by eating/drinking, capped by `Config.MaxNeedGainPerMinute`. Values persist through rsg-core metadata.
- **Warnings**: a notification when hunger/thirst drops to `Config.LowNeedWarning`, and a heartbeat sound below `Config.LowHealthHeartbeat` % health.
- **Dead eye and horse bonding icons** (`Config.ShowDeadEye`, `Config.ShowHorseBonding`).
- **Cold / heatstroke status** (with `Config.TempFeature`): the temperature icon switches to a snowflake/sun and pulses; the stamina core drains by `Config.TempStaminaDrain` first, and health is only hit once it's empty.
- **Per-icon visibility** in `/hudpreset` (saved per player).
- **Bank balance** via `/bank`, using rsg-banking v3's total across all branches (falls back to the core `bank` money).

## Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-banking](https://github.com/Rexshack-RedM/rsg-banking) v3 (optional, for `/bank`)
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
| `/togglehudpct` | Show/hide percentages under the circles (saved per player) |
| `/hudpreset` | Open the HUD preset panel (see below) |
| `/cash` | Show cash balance |
| `/bloodmoney` | Show bloodmoney balance |
| `/bank` | Show total bank balance (rsg-banking v3), command name `Config.BankCommand` |

Positions, sizes and the percentage toggle are saved in the player's NUI storage.

## HUD presets (`/hudpreset`)
A NUI panel where each player picks:
- **Icon size**: small / medium / large
- **Position**: top or bottom, left / center / right (click a spot on the mini screen)
- **Layout**: horizontal or vertical
- **Show icons**: hide individual icons (they still appear in edit mode)
- **Fine position**: nudge the whole HUD with the **arrow keys** (Shift = bigger steps), with a live X/Y readout

Changes preview live. `Enter` / **Apply** saves (client KVP, survives relogs); `Esc` / **Cancel** reverts.
Applying a preset clears custom drag/resize of the stat icons (the money HUD keeps its spot).
Server default: `Config.DefaultPreset` · command name: `Config.PresetCommand`.

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
