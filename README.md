# rsg-hud

A HUD for RedM servers running [RSG-Core](https://github.com/Rexshack-RedM/rsg-core): player and horse status bars, money display, stress, temperature, outlaw status and a drag-and-drop layout editor.

## Features

- **Status bars:** health, stamina, armor, hunger, thirst, cleanliness, stress, temperature, voice range, unread telegram mail and outlaw status. Bars hide automatically when full/empty and turn red at 30% or below.
- **Horse bars:** health, stamina and cleanliness while mounted.
- **Money HUD:** cash, bloodmoney and bank show briefly when they change. `/cash` and `/bloodmoney` show them on demand.
- **Needs system:** hunger, thirst, cleanliness and stress decay over time. Optional health damage when hunger/thirst/cleanliness hit 0 or the temperature is out of range.
- **Stress:** gained by shooting and by speeding in vehicles. Screen shake starts at `Config.MinimumStress`, and at 100 the player ragdolls and the screen fades.
- **Temperature:** optional feature (`Config.TempFeature`) with clothing warmth values and job exemptions (Celsius or Fahrenheit).
- **Flies effect** when cleanliness drops below `Config.MinCleanliness`.
- **Minimap and compass:** separate settings for on foot and mounted.
- **HUD editor:** drag and resize every element. Layout is saved per player in the NUI local storage.
- **Native HUD hiding:** hides the default health, stamina, deadeye and horse cores.
- **Localisation:** `en`, `el`, `es`, `fr`, `it`, `pl`, `pt-br` (`locales/`).
- Only sends updates to the NUI when a value changes.

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql) (outlaw status is read from `players.outlawstatus`)
- Optional: `rsg-telegram` (drives the mail icon via the `telegramUnreadMessages` state bag)

## Installation

1. Put the `rsg-hud` folder in your `resources` directory.
2. Make sure the dependencies above start first, then add to `server.cfg`:
   ```
   ensure ox_lib
   ensure oxmysql
   ensure rsg-core
   ensure rsg-hud
   ```
3. Configure `config.lua` to taste and restart the server.

## Commands

| Command | Description |
| --- | --- |
| `/edithud` | Toggle edit mode. Drag to move, use the corner handle to resize, press ESC to exit. |
| `/resethud` | Reset all element positions and sizes to default. |
| `/cash` | Show your cash balance. |
| `/bloodmoney` | Show your bloodmoney balance. |

## Configuration (`config.lua`)

| Option | Description |
| --- | --- |
| `StatusInterval` | How often (ms) needs decay and health damage are applied. |
| `HungerRate`, `ThirstRate` | Amount hunger/thirst drop each interval. |
| `StressChance`, `MinimumStress`, `MinimumSpeed`, `StressDecayRate` | Stress gain chance when shooting, shake threshold, speeding threshold (mph) and decay per interval. |
| `Intensity`, `EffectInterval` | Shake strength and delay between effects per stress range. |
| `Hide*Native` | Hide the default player/horse health, stamina, deadeye and courage cores. |
| `VoiceAlwaysVisible` | `true` always shows the voice icon, `false` only while talking. |
| `OnFootMinimap`, `OnFootCompass`, `MountMinimap`, `MountCompass` | Minimap/compass behaviour on foot and mounted. |
| `DoHealthDamage`, `DoHealthDamageFx`, `DoHealthPainSound` | Damage from starvation, dehydration, dirt and temperature, plus its screen effect and pain sound. |
| `RemoveHealth` | Health removed per interval from dirt or temperature damage. |
| `TempFormat` | `'celsius'` or `'fahrenheit'`. |
| `TempFeature` | Enable temperature damage and clothing warmth. |
| `Wearing*` | Warmth added per clothing slot. |
| `EnableNoWarmthJobs`, `NoWarmthJobs` | Job types that ignore clothing warmth. |
| `MinTemp`, `MaxTemp` | Temperature range before health damage (same unit as `TempFormat`). |
| `FlyEffect`, `MinCleanliness` | Flies effect toggle and the cleanliness level that triggers it. |
| `IconColors` | Colours for each icon state. |

## Exports (client)

```lua
exports['rsg-hud']:GetOutlawStatus()       -- number
exports['rsg-hud']:GetCurrentTemperature() -- number, in Config.TempFormat units
```

## Events (client)

```lua
TriggerClientEvent('hud:client:UpdateNeeds', src, hunger, thirst, cleanliness)
TriggerClientEvent('hud:client:UpdateHunger', src, hunger)
TriggerClientEvent('hud:client:UpdateThirst', src, thirst)
TriggerClientEvent('hud:client:UpdateCleanliness', src, cleanliness)
TriggerClientEvent('hud:client:UpdateStress', src, stress)
TriggerClientEvent('hud:client:GainStress', src, amount)
TriggerClientEvent('hud:client:RelieveStress', src, amount) -- ignored for job type 'leo'
TriggerClientEvent('hud:client:ToggleEditMode', src)
TriggerClientEvent('HideAllUI', src)                        -- toggles the whole HUD
```

## Notes

- Hunger, thirst, stress and cleanliness live in client-set state bags. Treat them as client-trusted.
- Custom currency formatting is in `formatMoney` in `html/app.js`.

## Credits

- RSG Developers for building this script
- Staff Member Phil for updates to this script
