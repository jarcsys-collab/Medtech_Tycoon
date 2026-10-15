# Medtycoonv2 → Godot delta

Reference: `import demo/Medtycoonv2/godot/SalesSimulator/` (read-only). Art, UI icons, font and audio in V2 are
byte-identical to V1 / the audio pack already in `assets/`, so no assets were copied.

## Applied
| V2 | Godot |
|---|---|
| 13-step guided tutorial (`autoload/tutorial.gd`) replacing the V1 tip carousel | `scripts/autoload/tutorial.gd` (autoload `Tutorial`), steps adapted to existing mechanics |
| Tutorial box: step counter, SKIP, arrow on click steps, hint + sub line | `scenes/ui/hud.tscn` Tutorial card + `hud.gd` |
| Button highlight (`phone`, `travel`, `inventory`, `phone:leads`) | `hud.gd` nav pulse, `phone.gd` row pulse |
| REPLAY TUTORIAL in TASKS | `info_panel.gd` |
| `Tutorial.notify()` events | Main (overlay/phone page/`Player.moved_enough`), Customer (`sale_opened`), GameState signals |
| Progress saved | `GameState.tutorial_step/tutorial_done` in the save; `tutorial_version` 2 restarts unfinished V1 tips |
| Tutorial jingles (task_complete / achievement_unlocked) | `AudioDirector` via `Tutorial.step_completed` (jingle arbitration) |
| Input: `toggle_phone` P, `open_map` M, Space for `interact` | `project.godot`, `main.gd` |
| `SfxManager.set_volume()` persisted to `user://settings.json` | `sfx_manager.gd` (+ `MusicManager.set_base_volume_db`); no slider UI yet |

## Step adaptations (V2 systems that do not exist here)
- 5 "Book a Meeting" → "Find New Clients" (click). No booking system.
- 7/8 sale dialog with pitch/offer → existing café talk (E) and "Close deal".
- 10 "Order online / Depot at Level 4" → depot restock (Level 2); click or a purchase completes it.
- 12 hint "TASKS → END DAY" → bed only (no End Day button).

## Not applied (kept current behaviour)
- 941×1672 portrait viewport, `keep` aspect, Nearest filter, no mipmaps (conflicts with the responsive landscape layout).
- Supplier Depot unlock Level 4 (kept at 2 to avoid the early-stock soft-lock).
- Meetings list on "coming soon" places, meeting booking, negotiation stage, online ordering, volume sliders.
- V2 `world.gd` / `player.gd` / `locations.gd`: same data as V1, already implemented natively (collision, bed layer, wander).
