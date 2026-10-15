# Godot 4.7 Audio Integration Brief (for Claude Code)

You are integrating this audio pack into the existing MedTech Diagnostics Tycoon / Sales Simulator Godot project. **Do not change gameplay or UI.** Only add audio wiring. The per-file details (purpose, length, volume, fades) are in `AUDIO_MANIFEST.md`. This file covers placement, buses, mapping, and architecture.

The location names and ids below come from the design prototype: `home`, `coffee`, `bank`, `office`, `expo`, `warehouse`, plus the side-menu tabs TASKS / PHONE / TRAVEL / DEALS / INVENTORY / FINANCE. Map them to whatever identifiers the Godot project actually uses.

---

## 1. File placement

Copy the folders as-is:

```
res://assets/audio/music/<folder>/<file>.wav      (from music/)
res://assets/audio/sfx/<folder>/<file>.wav        (from sfx/)
```

Do not copy `documentation/` into `res://`. Keep it in the repo's `docs/` instead.

## 2. Import settings

All files are 16-bit PCM WAV, mono. Music is 22,050 Hz; SFX are 44,100 Hz.

**Music (`res://assets/audio/music/**`):**
- **Edit → Loop Mode: `Detect From WAV`** (the default). Every music file has an embedded forward loop over the whole file. Check in the Import dock that the loop is detected. If it isn't, set Loop Mode to `Forward` with Loop Begin 0 and Loop End −1 (end of file).
- **Compress → Mode: `QOA`** to cut memory use. Keep `PCM` if the audio quality is noticeably worse.
- Don't trim silence, and don't normalize. The tracks are already level-matched at about −18.5 dBFS RMS.

**SFX (`res://assets/audio/sfx/**`):**
- Loop Mode: `Disabled`.
- Compress Mode: `PCM` for UI and footsteps (short, latency-sensitive). `QOA` is fine for jingles in `progression/`.

**Optional OGG conversion:** if you need smaller files, convert with `ffmpeg -i in.wav -c:a libvorbis -q:a 5 out.ogg`. Then enable **Loop** in each music .ogg's import settings, because the WAV loop chunk is lost in conversion.

## 3. Audio buses (`default_bus_layout.tres`)

| Bus | Parent | Default volume | Notes |
|---|---|---|---|
| Master | — | 0 dB | |
| Music | Master | −6 dB | All music players. Duck target. |
| SFX | Master | −3 dB | Gameplay one-shots (sales, notifications, progression). |
| UI | SFX | −4 dB | Clicks, tabs, panel open/close, map. |
| Ambience | SFX | −6 dB | Footsteps (and any future ambience loops). |

Expose Master, Music, and SFX sliders in settings, using `AudioServer.set_bus_volume_db` with linear-to-dB conversion. Persist the values.

## 4. Music mapping

| Game state / location | Track | Loop | volume_db | Fade in | Fade out |
|---|---|---|---|---|---|
| Main Menu (when one exists) | `music/main_menu/main_menu_theme.wav` | yes | −6 | 2.5 s | 1.5 s |
| Home (`home`) | `music/apartment/apartment_theme.wav` | yes | −7 | 1.5 s | 1.2 s |
| Coffee Corner (`coffee`) | `music/cafe/cafe_theme.wav` | yes | −7 | 1.5 s | 1.2 s |
| City Bank (`bank`) | `music/other_locations/city_bank_theme.wav` | yes | −8 | 1.5 s | 1.2 s |
| Office Park (`office`) | `music/other_locations/office_park_theme.wav` | yes | −8 | 1.5 s | 1.2 s |
| Supplier Depot (`warehouse`) | `music/supplier_depot/supplier_depot_theme.wav` | yes | −8 | 1.5 s | 1.2 s |
| Trade Expo (`expo`) | `music/other_locations/trade_expo_theme.wav` | yes | −8 | 1.0 s | 1.2 s |
| City Map open (TRAVEL tab) | `music/travel/travel_theme.wav` | yes | −7 | 0.8 s | 0.8 s |
| Sales meeting with a customer | `music/meetings/sales_meeting_theme.wav` | yes | −9 | 2.0 s | 1.5 s |
| Negotiation | `music/negotiation/negotiation_theme.wav` | yes | −8 | 1.5 s | 1.5 s |
| FINANCE / TASKS / DEALS screens | `music/finance/finance_theme.wav` | yes | −9 | 1.0 s | 1.0 s |
| INVENTORY screen | `music/inventory/inventory_theme.wav` | yes | −8 | 1.0 s | 1.0 s |
| PHONE overlay | keep the current track | — | duck Music −4 dB | 0.25 s | 0.4 s |

Rules:
- **Overlays vs. screens:** if a tab only shows a small panel over the scene, don't change the track; just duck it (−3 to −4 dB). Only crossfade when the tab takes over the whole screen (like the City Map, which replaces the background).
- **Return to the location:** when the map closes without travelling, crossfade back to the current location's track and **resume from the stored playback position** (see section 6).
- **After TRAVEL:** fade out `travel_theme`, play `sfx/ui/travel_confirm.wav`, then fade in the destination's track.
- A locked location never plays its track.

## 5. SFX mapping

| Event | File | Bus | volume_db | Notes |
|---|---|---|---|---|
| Any button press | `sfx/ui/ui_click.wav` | UI | −12 | pitch_scale random 0.95–1.05 |
| Button hover / focus | `sfx/ui/ui_hover.wav` | UI | −18 | optional; throttle to 1 per 60 ms |
| Side-menu tab selected | `sfx/ui/ui_tab_select.wav` | UI | −11 | |
| Phone / panel opens | `sfx/ui/ui_panel_open.wav` | UI | −10 | |
| Phone / panel closes (click outside, Esc, tile) | `sfx/ui/ui_panel_close.wav` | UI | −11 | |
| Tap a locked location / LOCKED button | `sfx/ui/ui_locked.wav` | UI | −9 | |
| City Map opens | `sfx/ui/map_open.wav` | UI | −8 | |
| Map pin selected | `sfx/ui/map_pin_select.wav` | UI | −9 | |
| TRAVEL pressed / arrival | `sfx/ui/travel_confirm.wav` | UI | −7 | |
| Successful sale / deal closed | `sfx/sales/sale_success.wav` | SFX | −5 | duck Music −6 dB for 1.5 s |
| Failed sale | `sfx/sales/sale_failed.wav` | SFX | −8 | |
| Purchase (cash out) | `sfx/sales/purchase.wav` | SFX | −7 | |
| Payment received / collection | `sfx/sales/payment_received.wav` | SFX | −6 | |
| New phone message | `sfx/notifications/notification_message.wav` | SFX | −7 | |
| New lead | `sfx/notifications/new_lead.wav` | SFX | −6 | |
| Meeting reminder | `sfx/notifications/meeting_reminder.wav` | SFX | −7 | |
| Level up | `sfx/progression/level_up.wav` | SFX | −4 | duck Music −8 dB for 2.5 s |
| Reputation increase | `sfx/progression/reputation_up.wav` | SFX | −6 | |
| Task completed | `sfx/progression/task_complete.wav` | SFX | −7 | |
| Achievement unlocked | `sfx/progression/achievement_unlocked.wav` | SFX | −4 | duck Music −8 dB for 3 s |
| End of day | `sfx/progression/day_end.wav` | SFX | −5 | fade Music out over 1.5 s first, then play |
| Start of day | `sfx/progression/day_start.wav` | SFX | −5 | then fade in the location track |
| Location unlocked | `sfx/progression/location_unlocked.wav` | SFX | −5 | duck Music −6 dB for 2 s |
| Footstep, Home | `sfx/environment/footstep_wood_01..04.wav` | Ambience | −16 | random variant, no immediate repeat, pitch 0.92–1.08 |
| Footstep, Coffee Corner | `sfx/environment/footstep_tile_01..04.wav` | Ambience | −16 | same |

Trigger footsteps from the walk animation. With the 8-frame walk cycle, play a step on frames 0 and 4. Play nothing while idle.

## 6. Recommended architecture (don't write this verbatim; adapt it to the project)

**`MusicManager` (autoload singleton)**
- Two `AudioStreamPlayer` children (`PlayerA`, `PlayerB`) on the `Music` bus, for crossfading.
- `const TRACKS := { &"home": preload(...), &"coffee": ..., &"travel": ..., ... }`, keyed by the same ids the game uses for locations and states.
- `play_track(id: StringName, fade_in := 1.5, fade_out := 1.2)`: if `id` is already playing, do nothing. Otherwise start the idle player at −80 dB, tween it to the track's `volume_db` over `fade_in`, and tween the active player to −80 dB over `fade_out`, then stop it. Swap the active/idle roles.
- `_positions: Dictionary` stores `get_playback_position()` per track when it fades out, so location tracks resume where they left off (the City Map → back to Home case). Forget the positions on day change.
- `duck(db := -4.0, attack := 0.25)` / `unduck(release := 0.4)` tween a dedicated offset on the **Music bus**, not the players, so ducking and crossfades never fight.
- `stinger(stream, duck_db, hold)` plays a one-shot jingle on the SFX bus through `SfxManager`, ducks the music, holds it, then releases.
- Signals to connect: location changed, map opened/closed, screen changed, day started/ended.
- Use a tween per player, and kill the previous tween before starting a new one. That avoids pops when the player spams tabs.

**`SfxManager` (autoload)**
- Pool of 8 `AudioStreamPlayer`s (non-positional, since the game is a 2D UI-driven scene), round-robin.
- `play(id: StringName, bus := &"SFX", volume_db := 0.0, pitch_jitter := 0.0)`.
- Groups such as `&"footstep_wood"` that pick a random variant from an array and avoid repeating the last one.
- A per-sound cooldown (≈50 ms) to prevent stacking on rapid clicks.

**Wiring points (no gameplay changes):**
- Side-menu tile pressed → `ui_tab_select`. PHONE toggle → `ui_panel_open` / `ui_panel_close` + duck/unduck.
- TRAVEL tab → `map_open` + `play_track(&"travel", 0.8, 0.8)`. Pin tapped → `map_pin_select` (or `ui_locked` if locked). TRAVEL button → `travel_confirm`, then `play_track(destination_id)`.
- Stat changes in the HUD: Leads +1 → `new_lead`, Reputation ↑ → `reputation_up`, Cash ↓ for a purchase → `purchase`, Cash ↑ from a collection → `payment_received`.

## 7. Acceptance checks for the integration

1. Each location plays its mapped track on entry and loops without an audible gap.
2. Opening and closing the City Map crossfades, and the location track resumes from where it was.
3. Spamming tabs or the phone never causes clicks, stacked music, or volume drift.
4. Master, Music, and SFX sliders work and persist.
5. Jingles (level up, achievement, sale success) are clearly audible over the music because of ducking.
