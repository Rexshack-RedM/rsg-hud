<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 🧭 rsg-hud

**Player HUD for RSG Framework.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

---

## 🛠️ Dependencies

- **rsg-core**
- **ox_lib**
- **rsg-telegram**

`ui_page`: `html/index.html`

---

## ✨ Features

- **Status bars:** health, stamina, Dead Eye.
- **Needs:** hunger, thirst, cleanliness (with red icons when low).
- **Temperature display.**
- **Money display:** cash, bloodmoney, bank (driven by client logic).
- **Stress system:** chance on actions, threshold effects, and decay (see config keys).
- **Telegram visual notification**.
- **Server logo display:** Customizable logo with 6 position options (see `LOGO_SETUP.md`).
- **Localization** via `locales/*.json`.
- **Pure NUI** HUD (`html/index.html`, `app.js`, `styles.css`).

---

## ⚙️ Configuration (`config.lua`)

```lua
Config = {}

-- Update/decay
Config.StatusInterval   = 5000
Config.HungerRate       = 0.10
Config.ThirstRate       = 0.15
Config.CleanlinessRate  = 0.01

-- Stress
Config.StressChance     = 0.1
Config.MinimumStress    = 50
Config.MinimumSpeed     = 100
Config.StressDecayRate  = 0.5

-- Native HUD toggles
Config.HidePlayerHealthNative  = true
Config.HidePlayerStaminaNative = true
Config.HidePlayerDeadEyeNative = true
Config.HideHorseHealthNative   = true
Config.HideHorseStaminaNative  = true
Config.HideHorseCourageNative  = true

-- Effects
Config.EffectInterval   = 1000
Config.Intensity        = 0.5
Config.DoHealthDamage   = false
Config.DoHealthDamageFx = false
Config.DoHealthPainSound= false
Config.FlyEffect        = false

-- Temperature
Config.TempFormat       = 'c' -- c|f

-- Voice HUD (icon visibility)
Config.VoiceAlwaysVisible = false

-- Clothing flags (read by HUD to adjust cleanliness/overlays)
Config.WearingHat       = true
Config.WearingCoat      = true
Config.WearingOpenCoat  = false
Config.WearingVest      = true
Config.WearingShirt     = true
Config.WearingGloves    = true
Config.WearingPoncho    = false
Config.WearingChaps     = false
Config.WearingPants     = true
Config.WearingSkirt     = false
Config.WearingBoots     = true

-- Icon colors (normal/low) for each meter (excerpt)
Config.IconColors = {
  hunger = { normal = '#a16600', low = '#FF0000' },
  thirst = { normal = '#a16600', low = '#FF0000' },
  health = { normal = '#a16600', low = '#FF0000' },
  stamina= { normal = '#a16600', low = '#FF0000' },
  deadeye= { normal = '#a16600', low = '#FF0000' },
  temperature = { normal = '#a16600', low = '#FF0000' },
}

-- Server Logo
Config.Logo = {
  showLogo = true,
  logoPosition = 'top-left', -- 'top-left', 'top-middle', 'top-right', 'bottom-left', 'bottom-middle', 'bottom-right'
  logoName = 'logoEx.png',   -- Place your logo in /html/assets/
  logoSize = 200,            -- Width in pixels (50-500)
  logoOpacity = 1.0          -- Transparency (0.0-1.0)
}
```

> 🔎 The file contains additional keys; see `config.lua` for the full list.

---

## 📂 Files

- `client/client.lua` — HUD logic (reads `Config.*`, toggles native HUD parts, updates bars, stress & temperature).
- `config.lua`
- `html/` — `index.html`, `app.js`, `styles.css`.
- `locales/*.json` — language strings.
- `fxmanifest.lua` — declares scripts and dependencies.

---

## 📦 Installation

1. Put `rsg-hud` in `resources/[rsg]`.
2. In `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure rsg-telegram
   ensure rsg-hud
   ```
3. (Optional) Edit `config.lua` to tune decay, stress, native HUD toggles, icon colours, etc.

---

## 💎 Credits

- **qbcore-redm-framework/qbr-hud** — base inspiration  
  🔗 https://github.com/qbcore-redm-framework/qbr-hud
- **QRCore-RedM-Re/qr-hud** — base inspiration  
  🔗 https://github.com/QRCore-RedM-Re/qr-hud
- **RexshackGaming / RSG Framework** — author & maintenance  
  🔗 https://github.com/Rexshack-RedM
- **philmcracken892's** — edit hud option
  🔗 https://github.com/philmcracken892

- **Community contributors & translators**
- License: **GPL‑3.0**
