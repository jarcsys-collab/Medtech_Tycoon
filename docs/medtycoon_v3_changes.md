# Medtycoonv3 ("Sales Simulator") → Godot delta

Reference: `Sales simulator_.zip` in the project root (218,128,403 bytes, SHA-256 starts `c6b2db3e57eed215`,
git-ignored by `*.zip`). Analyzed 2026-10-22; nothing from it has been imported yet.

**What it is:** a design-tool export, not a Godot project. It holds HTML "Design Component" mockups (`*.dc.html`), their
art, the audio pack, and a small Godot add-on pack (`godot/SalesSimulator/`: 7 `.gd` files and assets, with no `project.godot` and
no scenes). Its own `PROJECT_STATUS.md` (Oct 19) says the Godot pack is "behind the prototype" and that changes should be
ported only after a prototype is approved. The mockups do not save anything and make no network calls.

| ZIP path | Contents |
|---|---|
| `Main.dc.html` (~1,700 lines) | The game: Apartment HUD, phone, booking, meetings, tasks, team |
| `Lobby.dc.html` | "One Jarc" street scene with 12 fake online players and canned chat |
| `TicketsSwitch.dc.html`, `ItineraryMapReal.dc.html`, `Middle App*.dc.html` | Mockups of the real "Middle App" itinerary tool and a game ↔ real-app transition |
| `shared-data.js`, `support.js` | Shared mockup data; the `.dc.html` runtime (same as V1) |
| `assets/`, `assets/ui/` | Art used by the mockups |
| `godot/SalesSimulator/` | V2 Godot pack plus small changes (below) |
| `MedTech-Tycoon-Audio-Pack-V1/` | Byte-identical to the audio pack already in `assets/audio/` |
| `uploads/`, `scratch/`, `middle-app*/`, `design_handoff_middle_app_itinerary/` | Raw uploads, debug images, Figma extracts. Not needed by the game |

## Already in the game (no action)
- **Audio pack:** the ZIP's 43 WAVs are identical to the earlier pack, and the 38 in `assets/audio/` match by hash. The
  5 that were never copied (`main_menu_theme`, `negotiation_theme`, `meeting_reminder`, `payment_received`, `sale_failed`)
  still have no matching feature.
- **Godot pack:** the 13-step tutorial, music and sound managers, P/M keys, the volume API (see `medtycoon_v2_changes.md`).
- **Art:** byte-identical: `PixelifySans.ttf`, 18 UI icons, `char-sheet.png`, `cafe-bg.png`, `city-map.png`, `bed-layer-full.png`.

## Godot pack changes since V2 (confirmed by diff)
| File | Change |
|---|---|
| `scripts/player.gd` | "Step-wander": idle wander at 26 px/s (was 75) in short bursts of 0.5 s with 0.6–1.5 s pauses; `wander_speed` multiplier 0.5–2.5; outdoor idle/walk sheets |
| `scripts/tutorial_box.gd` | Optional pixel frame (`ui/dialog-box.png`, NinePatch, 911×245 box, portrait slot); named type styles (H2 / BODY / SUB / CAPTION) |
| `INSTRUCTIONS.md` | Adds the type-scale table (Display 34/700, H1 30/600, H2 26/600, Label 21/600, Body 22/400, Sub 19/400, Caption 16/600) |
| `assets/art/apartment-bg.png` | Touch-up: the small upper-left window strip is painted over. Same 941×1672 size and room layout, so collision is unchanged |
| New art | `char-idle-out-4.png` (400×235, 4 frames), `char-walk-out.png` (1040×235, 8×130), `maya-idle.png` (400×235), `ui/dialog-box.png` (2027×501) |

`apartment-bg.png`, `char-idle-out-4.png` and `maya-idle.png` also exist under the ZIP's `assets/`. Each copy has the same
size as the pack's copy but differs in about 360 bytes near the file header (probably metadata), and they look the same.
Confirm the pixels match before choosing a copy in G1.

## New in the HTML mockups (`Main.dc.html`) vs the Godot game
Legend: ✅ exists · 🟡 partial · ❌ new · ⚠️ conflicts with current design

**World, characters, art**
| Mockup | Godot today | Status |
|---|---|---|
| Step-wander; walk shows only the first step frame | Continuous wander, full walk cycle | 🟡 |
| Outdoor sprites outside the apartment | One sheet everywhere | ❌ |
| Time-of-day backgrounds: `cafe-bg-evening.png`, `city-map-evening.png`, `city-map-suburb.png`, `city-map-suburb-night.png` | Day art only | ❌ |
| Daytime apartment | Night art is reused in the mockup too | ⚠️ art missing |
| Bed and shelf tap-glow (`bed-layer-cropped.png`, `shelf-layer.png`) | Bed = sleep (E) | 🟡 the mockup's shelf has no action |
| Delivery package at home | — | ⚠️ the mockup reuses `ui/inv.png` |

**Time, energy, progression**
| Mockup | Godot today | Status |
|---|---|---|
| Slots: Morning 8:30–12:30, Afternoon 12:30–4:30, Evening 4:30–8:30 | `GameState.minutes` | ❌ can be worked out from the clock |
| Day ends at 8:30 PM, end-of-day summary | "Late" toast at 10 PM; sleep any time | ❌ |
| Energy pips: start 3, max 3/4/5 by Stamina, meeting −1, sleep refills | None | ❌ needs a save field |
| XP thresholds 0/60/150/280/450 | `GameData.LEVEL_XP` 0/100/250/450/700 | ⚠️ keep the Godot values (changing them re-levels saves) |
| Level 1–3 task list (book, coffee, meet, deal, restock, sleep, pickup, book2, …) | 7 tasks | 🟡 |
| Tutorial lock (`tutorialGuard`) | None | ❌ off by default in the mockup |
| Achievement / level-up banners | Toasts and floating text | 🟡 |

**Clients and meetings**
| Mockup | Godot today | Status |
|---|---|---|
| 3 named clients: Dr. Maya Patel (cost-conscious, Evening, Coffee Corner), Sam Okafor (prestige, Afternoon/Evening), Lena Novak (Prospect, in a hurry, Morning/Afternoon) | Random leads and café prospects | ⚠️ plan: add them alongside the random leads |
| Booking sheet: slot + venue, energy/fare preview, unavailable reasons | None | ❌ |
| Booked client appears at the venue; MEET button | Café customers always present; press E | 🟡 |
| 3 pitches → Sold / Quote / Follow-up / Walked away; relationship 0–5 | Pitch, then Close deal | ❌ |
| Commission = 20% of list price | Retail price × reputation (+15% in person) | ⚠️ |

**Restocking and products**
| Mockup | Godot today | Status |
|---|---|---|
| Company-issued stock up to a per-level allocation; request by phone → delivery next morning; Company HQ (level 4) restocks on the spot | Buy at wholesale from Supplier Depot shelves (level 2) | ⚠️ needs a decision |
| Products: Rapid Test Kit $60, Pulse Oximeter $220, Glucose Monitor $420, Portable ECG $1,500 | Oximeter, glucose, BP monitor, ECG patch, ultrasound | ⚠️ plan: add the test kit |
| City Bank unlocks at level 3 | Level 2 (`data/locations/bank.tres`) | ⚠️ |

**Phone and UI**
| Mockup | Godot today | Status |
|---|---|---|
| App grid, time-of-day banner (`ui/phone-sunrise/afternoon/evening.png`), greeting, battery-style energy | 6-row phone | 🟡 |
| Apps: One Jarc, Itinerary, Messages (boss "Ramon Cruz", placeholder), Tickets, Customers, Deals, Inventory, Finance, Quotes, Collect, Energy | Leads, Schedule, Messages, Customers, Quotes, Collections | 🟡 |
| New icons: `ui/pTicket.png`, `ui/pMsg-centered.png`, `ui/pMsg-clean.png`, `ui/phone-banner.png` | — | ❌ |
| Portrait 941×2036, tap-only, cash/rep/leads hidden in the top bar | Responsive landscape/portrait, WASD + tap, stats shown | ⚠️ keep the Godot layout; adopt the style only |

**Side features**
| Mockup | Status |
|---|---|
| Team: 3 AI reps (Rico, June, Theo) with slot schedules, list and map views | ❌ the data is hard-coded |
| One Jarc Lobby: 5016×1672 street, 12 fake players, chat; art `lobby-*.png`, `girl-*.png` | ❌ not networked; the chat contains "yo mama" lines that need a content review |
| Tickets / Middle App itinerary and game ↔ real-app transition | ❌ belongs to the real work app |

## Incomplete or missing in the ZIP
- `ItineraryMap.dc.html` is imported by `TicketsSwitch.dc.html` but is not in the ZIP.
- `ItineraryMapReal.dc.html` loads `assets/map.jpg`; the file is at `middle-app/assets/map.jpg`.
- No scene art for Office Park, City Bank, Trade Expo or Company HQ (they show "Scene coming soon").
- One Jarc navigates to a separate page, so game state resets. `SLOT_EFFECT` is stored but not used. Collections is always empty.
- Placeholders: the boss name and the lobby player names.

## Planned phases (each its own branch and pull request; old saves must keep loading)
| Phase | Scope | Assets from the ZIP | Save change |
|---|---|---|---|
| G0 (done) | Save validation, migration and backups; tests; PR checks; this document | none | none (still version 1) |
| **G1a** | Characters and movement: outdoor outfit (player outside home, café customers with lighter tints), step-wander (default; `WanderBrain.Style.CONTINUOUS` keeps the V1 wander), walk holds its first frame only while wandering | `godot/SalesSimulator/assets/art/char-idle-out-4.png`, `char-walk-out.png` (same pixels as the `assets/` copies) → `assets/characters/` | none |
| **G1b** | Environments and UI: apartment touch-up, evening café and map, phone banners, pixel tutorial frame (switchable), Messages icon, bed glow | `apartment-bg.png`; `assets/cafe-bg-evening.png`, `assets/city-map-evening.png`; `assets/ui/dialog-box.png`, `phone-sunrise/afternoon/evening.png`, `pMsg-centered.png`, `bed-layer-cropped.png` | none |
| G2 | Time slots and end-of-day summary | — | optional day log |
| G3 | Energy and Stamina | — | version 2 (`energy`, `stamina`) |
| G4 | Named clients, booking, pitch meetings, relationships | — | `client_states` |
| G5 | Company restock and deliveries (after the design decision) | package art still needed | restock fields |
| G6 | Task list and tutorial rewrite | — | `tutorial_version` 3 |
| G7 | Phone redesign | phone icons and banners | none |
| G8 | Team (view only) | — | none |
| Later | Lobby (needs multiplayer and a content review); suburb map overlays; Tickets / Middle App | `lobby-*`, `girl-*`, `city-map-suburb*` | — |

**Import rules:** copy only the files a phase uses into `assets/` and hash-compare them first. Never import `uploads/`,
`scratch/` or `middle-app*/`. The ZIP stays where it is until a decision is made to move it to `import demo/Medtycoonv3/`
(which is git-ignored and excluded by `.gdignore`).
