# Changelog

All notable changes to rsg-hud. Newest first.

## 3.3.0

### Added
- **Warning sounds**: the low hunger / thirst, high stress (`Config.HighStressWarning`) and cold/heat notifications play rsg-core's warning sound (`Config.WarningSound`).
- **Decay modifiers** (`Config.DecayModifiers`, needs `Config.ServerNeeds`): hunger/thirst fade faster while running, sprinting, swimming or galloping and in hot/cold weather. The client only reports what it is doing; the server picks the multiplier and never lets a reported value go below 1.0.
- **Well fed buff**: while hunger and thirst are both above `wellFed.minimum`, both fade slower. Decided by the server; shows a badge and a notification.
- **Clock badge** (`Config.ShowClock`, `Config.Clock24h`), **compass bearing badge** (`Config.ShowCompass`), **ammo badge** (clip / reserve) and **weapon condition badge**, **injured horse badge** (`Config.ShowHorseInjury`, `Config.HorseInjuredBelow`). Each can be hidden per player in `/hudsettings` > Icons.
- **Share layout**: export your layout as a code and import someone else's (`/hudsettings` > Layout). Imports are validated and only saved when you press Apply.
- **Admin default layout**: `/pushhuddefault` makes your layout the default for every player without a saved layout, `/clearhuddefault` removes it, `/resethudlayout` drops your own saved layout. The server re-validates everything it stores.
- **Colourblind-safe ring palettes** (red-green safe, blue-yellow safe) in `/hudsettings` > Colours.
- 28 new locale keys in all 12 languages.

### Notes
- Ammo reserve assumes `GET_AMMO_IN_PED_WEAPON` includes the loaded clip. Condition is the game's weapon degradation (rsg-weapons sets it from item quality). There is no verified horse "injured" native, so the injured badge is a health threshold.

## 3.2.3

### Fixed
- Stress effect ranges share edge values (e.g. 60), and `pairs` made the matched range random; now `ipairs`, so shake intensity and effect timing are deterministic.

### Changed
- Server need decay no longer rewrites hunger/thirst state bags once they are at 0 (less replication traffic).

## 3.2.2

### Added
- Client export `AddWarmth(amount, duration)`: temporary body temperature change in °C for `duration` seconds (used by rsg-consume for hot soup / cold drinks).

## 3.2.1

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
