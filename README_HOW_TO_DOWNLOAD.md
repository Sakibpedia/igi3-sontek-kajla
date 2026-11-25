# How to download and play IGI 3 — Sontek Kajla

You only need a browser. Nothing is installed on your computer.

## 1. Get the game

- Go to <https://github.com/Sakibpedia/igi3-sontek-kajla/releases> and download
  `IGI3_SontekKajla.exe` from the latest release, **or**
- open the repository's **Actions** tab, choose the newest successful run and
  download the **IGI3-SontekKajla-Windows** artifact (a `.zip`), then unzip it.

## 2. Run it

1. Double-click `IGI3_SontekKajla.exe`.
2. Windows SmartScreen may say the publisher is unknown: click
   **More info → Run anyway**. The build is not code-signed.
3. The game opens in Bengali. Pick a mission from the menu; later missions unlock
   as you finish earlier ones.

## 3. If the game is slow

- Use a 64-bit Windows PC with a dedicated or recent integrated GPU.
- The project targets Godot's **GL Compatibility** renderer for weak laptops.
- Close other GPU-heavy apps; a mission takes ~24 s to generate the 1,500-building
  city, so the first few seconds after **Start** are a loading card, not a freeze.

## Controls (quick card)

| Action | Key |
|---|---|
| Move / sprint / crouch / prone | WASD / Shift / Ctrl |
| Lean | C or Q |
| Fire / aim / scope | LMB / RMB / 8 |
| Weapons / grenade / molotov / bomb | 1-3 / 4 / 5 / 6 |
| Reload | R |
| Interact, shop, vault, photo, drive | E |
| Answer a BCS gate question | 1-4 |
| Thermal / headphones / binoculars | T / N / B |
| Objectives / map / pause | Tab / M / Esc |

Full feature list: [README.md](README.md). Design notes: [CITY_DESIGN.md](CITY_DESIGN.md).
