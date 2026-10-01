# rsg-hud

Player and horse HUD for RSG-Core (RedM): health, stamina, hunger, thirst, cleanliness, stress, temperature, voice, mail and outlaw badges, a money pop-up, and a drag-and-resize edit mode.

## Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql) (reads `players.outlawstatus`)

## Installation
1. Drop `rsg-hud` into your resources folder.
2. Add `ensure rsg-hud` after `rsg-core` and `ox_lib` in `server.cfg`.
3. Configure `shared/config.lua`.

## Commands
| Command | Description |
|---|---|
| `/edithud` | Toggle edit mode (drag elements, resize with the corner handle, `ESC` to exit) |
| `/resethud` | Reset all HUD positions and sizes |
| `/togglehudpct` | Show/hide percentages under the circles (saved per player) |
| `/cash` | Show cash balance |
| `/bloodmoney` | Show bloodmoney balance |

Positions, sizes and the percentage toggle are saved in the player's NUI storage.

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
hud:SetNeed(source, 'hunger', 100)
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
`locales/*.json` (en, es, fr, it, pl, pt-br, el). Set the language with `setr ox:locale en`.
