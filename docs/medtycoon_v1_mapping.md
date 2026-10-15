# Medtycoonv1 → Godot mapping

Reference: `res://import demo/Medtycoonv1/` (read-only, not used at runtime).
`import demo/.gdignore` keeps Godot from importing any reference version; copy needed assets into `res://assets/` instead.
Use this table when diffing a future Medtycoonv2/v3 against the Godot build.

| Reference (Apartment HUD.dc.html) | Godot |
|---|---|
| `scenes.home` / `scenes.coffee` (`bg`, `walk`, `blocks`, `start`, `spots`) | `scenes/locations/apartment.tscn`, `coffee_corner.tscn` → `Walls/WalkBounds` (segments), other `Walls/*` polygons, `PlayerSpawn`, `WanderSpots` |
| `via` waypoints + `clearPath()` | Runtime-baked navmesh (`LocationBase._build_navigation`) + `WanderBrain` |
| `front` + `frontY()` + bed-layer png | `DepthOverlay` node (`BedOverlay` in apartment) |
| Player sprite sheet, 100×235 frames, idle 7fps / walk 11fps / auto 8fps | `assets/characters/char_frames.tres`, `scripts/player/player.gd` |
| Speeds 110 (keys) / 75 (wander), 4 s idle before wander | `Player.walk_speed`, `wander_speed`, `idle_before_wander` |
| `places[]` (map pins, min, cost, lvl, desc) | `data/locations/*.tres` (`LocationData`) |
| `state.cash`, `minutes`, day/date, reputation, leads | `GameState` autoload |
| `tips[]` | `GameData.TUTORIAL_TIPS` |
| Side nav / Sales phone rows / Travel map / Toast | `scenes/ui/hud.tscn`, `phone.tscn`, `travel_map.tscn`, `Hud.show_toast` |
| "SCENE COMING SOON" | `scenes/locations/coming_soon.tscn` (any location with empty `scene_path`) |

## Added in Godot V1 (not in the reference)
- Products (`data/products/*.tres`), inventory, café customers (meet → lead → in-person deal), phone deals, Supplier Depot shelves, XP/levels, tasks, finance/deals/inventory panels, bed = sleep/next day, JSON save/load (`user://savegame.json`).

## Presentation layer (visual pass)
- Display: 1280x720 logical base, `canvas_items` + `expand`; textures import with mipmaps, filter Linear Mipmap.
- Framing: `GameCamera` fits each location's `camera_focus` rect below the top bar; `LocationBase` adds a blurred backdrop and feathers the `Background` edges (any new location with a `Background` Sprite2D gets this for free).
- Final-art hooks: replace `Background` textures, `char-sheet.png` (same 100x235 frame grid), `DepotArt` node (procedural) with a Sprite2D, `ProductData.icon` (used instead of drawn cartons), `Shelf._draw` rack (keep `RACK_HEIGHT`).
- Fonts: `PixelifySansMedTycoon-*.ttf` are static weights of Pixelify Sans (OFL) with a redrawn "5" (the original looks like "S") and the "fi/fl" ligatures removed. Rebuild with `python tools/build_fonts.py assets/fonts/PixelifySans.ttf assets/fonts`.

## Intentional deviations
- Supplier Depot unlock level 4 → 2 (`data/locations/warehouse.tres`) so restocking is reachable in V1.
- Tutorial hides after the last tip (reference cycled forever).
- Added an LV/XP/clock strip under the top bar (hidden on the travel map).
