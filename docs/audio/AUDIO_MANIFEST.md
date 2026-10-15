# MedTech Tycoon — Audio Manifest (V1)

12 music loops + 31 sound effects. Every file listed here exists in this pack and was decode-tested (see "Verification" at the bottom).

- **Format:** 16-bit PCM WAV, mono. Music is 22,050 Hz; SFX are 44,100 Hz.
- **Loudness:** all music is normalized to about −18.5 dBFS RMS, so tracks are already level-matched. Suggested volumes below are `volume_db` values for the AudioStreamPlayer, relative to the Music/SFX bus.
- **Looping:** every music file has an embedded WAV `smpl` loop (forward, start 0 → end). Godot's default WAV import option *Loop Mode: Detect From WAV* picks it up. The audio was rendered cyclically, so reverb tails and sustained notes wrap seamlessly across the loop point.
- **Source / license for every file:** Original — procedurally synthesized for this project (no samples) · CC0 1.0 · attribution: None required. See `LICENSES.md`.

## Location → track mapping (names from the current project)

| In-game location / state | Track |
|---|---|
| Main Menu (no screen yet — for the future title screen) | `music/main_menu/main_menu_theme.wav` |
| Home (apartment, start location) | `music/apartment/apartment_theme.wav` |
| Coffee Corner (map id `coffee`) | `music/cafe/cafe_theme.wav` |
| City Bank (map id `bank`, Lv 2) | `music/other_locations/city_bank_theme.wav` |
| Office Park (map id `office`, Lv 3) | `music/other_locations/office_park_theme.wav` |
| Supplier Depot (map id `warehouse`, Lv 4) | `music/supplier_depot/supplier_depot_theme.wav` |
| Trade Expo (map id `expo`, Lv 5) | `music/other_locations/trade_expo_theme.wav` |
| City Map (Travel tab) | `music/travel/travel_theme.wav` |
| Customer / sales meeting (phone → Schedule, Customers, Quotes) | `music/meetings/sales_meeting_theme.wav` |
| Negotiation (Deals / Quotes haggling) | `music/negotiation/negotiation_theme.wav` |
| Finance tab (also Tasks, Deals list, Collections) | `music/finance/finance_theme.wav` |
| Inventory tab | `music/inventory/inventory_theme.wav` |
| Phone overlay (Leads, Messages, …) | no change — keep the location track, duck Music −4 dB |

## Music

| File | Purpose | Scene / location | Mood | Loops | Length | Volume (dB) | Fade in | Fade out | Source | License | Attribution |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `music/main_menu/main_menu_theme.wav` | Signature MedTech Tycoon theme | Main Menu / title screen (not yet in the prototype) | Memorable, clean, optimistic, subtle | Yes (seamless) | 50s · 96 BPM | -6 | 2.5s | 1.5s | Original (synthesized) | CC0 1.0 | None required |
| `music/apartment/apartment_theme.wav` | Home base: planning the day, walking around the apartment | Home (apartment) | Calm, cozy, warm morning/evening | Yes (seamless) | 49.23s · 78 BPM | -7 | 1.5s | 1.2s | Original (synthesized) | CC0 1.0 | None required |
| `music/cafe/cafe_theme.wav` | Rooftop café scene: cold leads, small-business owners | Coffee Corner | Relaxed lo-fi jazz, swing, vinyl warmth | Yes (seamless) | 45.71s · 84 BPM | -7 | 1.5s | 1.2s | Original (synthesized) | CC0 1.0 | None required |
| `music/supplier_depot/supplier_depot_theme.wav` | Restocking inventory at wholesale | Supplier Depot (map id: warehouse, unlocks Lv 4) | Light logistics / industrial pulse, steady | Yes (seamless) | 55.38s · 104 BPM | -8 | 1.5s | 1.2s | Original (synthesized) | CC0 1.0 | None required |
| `music/travel/travel_theme.wav` | Choosing a destination on the city map | City Map (Travel tab) | Upbeat city / progression, forward motion | Yes (seamless) | 51.43s · 112 BPM | -7 | 0.8s | 0.8s | Original (synthesized) | CC0 1.0 | None required |
| `music/meetings/sales_meeting_theme.wav` | Pitching to a customer, presenting a product | Customer / sales meeting state (Schedule, Customers, Quotes in the phone) | Professional, subtle, focused | Yes (seamless) | 41.74s · 92 BPM | -9 | 2s | 1.5s | Original (synthesized) | CC0 1.0 | None required |
| `music/negotiation/negotiation_theme.wav` | Haggling price and terms on a deal | Negotiation state (Deals / Quotes back-and-forth) | Slightly energetic, strategic, focused | Yes (seamless) | 53.33s · 108 BPM | -8 | 1.5s | 1.5s | Original (synthesized) | CC0 1.0 | None required |
| `music/finance/finance_theme.wav` | Management screens: money, tasks, deal pipeline | Finance tab (also Tasks, Deals list, Collections) | Focused productivity, light and steady | Yes (seamless) | 42.67s · 90 BPM | -9 | 1s | 1s | Original (synthesized) | CC0 1.0 | None required |
| `music/inventory/inventory_theme.wav` | Browsing and organising stock | Inventory tab | Light, organised, bouncy | Yes (seamless) | 40s · 96 BPM | -8 | 1s | 1s | Original (synthesized) | CC0 1.0 | None required |
| `music/other_locations/city_bank_theme.wav` | Deposits, credit, business loans | City Bank (map id: bank, unlocks Lv 2) | Classy, calm, polished | Yes (seamless) | 48s · 80 BPM | -8 | 1.5s | 1.2s | Original (synthesized) | CC0 1.0 | None required |
| `music/other_locations/office_park_theme.wav` | Corporate towers, bigger-client meetings | Office Park (map id: office, unlocks Lv 3) | Corporate-light, confident, clean | Yes (seamless) | 38.4s · 100 BPM | -8 | 1.5s | 1.2s | Original (synthesized) | CC0 1.0 | None required |
| `music/other_locations/trade_expo_theme.wav` | Busy trade-show floor, warm leads | Trade Expo (map id: expo, unlocks Lv 5) | Bright, busy, upbeat but not aggressive | Yes (seamless) | 33.1s · 116 BPM | -8 | 1s | 1.2s | Original (synthesized) | CC0 1.0 | None required |

## Sound effects (one-shots, no loop)

| File | Purpose | Scene / location | Mood | Loops | Length | Volume (dB) | Fade in | Fade out | Source | License | Attribution |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `sfx/ui/ui_click.wav` | Generic button press (side menu tiles, phone rows) | All screens (UI) | Soft, crisp | No | 0.15s | -12 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/ui/ui_hover.wav` | Hover / focus move over a button | All screens (UI) | Barely-there tick | No | 0.08s | -18 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/ui/ui_tab_select.wav` | Selecting a side-menu tab (Tasks, Deals, Inventory, Finance) | All screens (UI) | Light two-note blip | No | 0.6s | -11 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/ui/ui_panel_open.wav` | Phone / panel slides open | All screens (UI) | Rising soft swish | No | 0.7s | -10 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/ui/ui_panel_close.wav` | Phone / panel closes (click outside, Esc, tile again) | All screens (UI) | Falling soft swish | No | 0.6s | -11 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/ui/ui_locked.wav` | Tapping a locked location / disabled LOCKED button | All screens (UI) | Muted, non-punishing thud | No | 0.5s | -9 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/ui/map_open.wav` | City Map opens from the Travel tab | All screens (UI) | Paper unfold + soft chime | No | 1.3s | -8 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/ui/map_pin_select.wav` | Selecting a destination pin on the City Map | All screens (UI) | Bubbly pop | No | 0.35s | -9 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/ui/travel_confirm.wav` | Pressing TRAVEL / arriving at a new location | All screens (UI) | Ascending pluck + whoosh | No | 1.4s | -7 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/sales/sale_success.wav` | Successful sale / deal closed | Sales / money events | Bright, rewarding, classy | No | 2.2s | -5 | 0 | 0.3s | Original (synthesized) | CC0 1.0 | None required |
| `sfx/sales/sale_failed.wav` | Customer declines / deal lost | Sales / money events | Gentle, sympathetic, not punishing | No | 1.4s | -8 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/sales/purchase.wav` | Buying stock / paying for something (cash out) | Sales / money events | Register cha-ching | No | 1.1s | -7 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/sales/payment_received.wav` | Money received (Collections, invoice paid) | Sales / money events | Coin clinks, satisfying | No | 1.2s | -6 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/notifications/notification_message.wav` | New phone message (Messages) | Phone / HUD notifications | Friendly two-tone ping | No | 1s | -7 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/notifications/new_lead.wav` | New lead added (Leads counter goes up) | Phone / HUD notifications | Bright rising chime, opportunity | No | 1.5s | -6 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/notifications/meeting_reminder.wav` | Upcoming meeting (Schedule) | Phone / HUD notifications | Calm double chime | No | 1.6s | -7 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/progression/level_up.wav` | Player level increases (unlocks new map locations) | Progression events | Uplifting, rewarding | No | 2.8s | -4 | 0 | 0.3s | Original (synthesized) | CC0 1.0 | None required |
| `sfx/progression/reputation_up.wav` | Reputation % increases (star stat) | Progression events | Sparkly glissando | No | 1.5s | -6 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/progression/task_complete.wav` | Task checked off (Tasks) | Progression events | Satisfying check-mark pluck | No | 1s | -7 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/progression/achievement_unlocked.wav` | Important achievement / milestone | Progression events | Light fanfare, proud | No | 3.2s | -4 | 0 | 0.3s | Original (synthesized) | CC0 1.0 | None required |
| `sfx/progression/day_end.wav` | End of day summary / going to sleep | Progression events | Warm, reflective, resolving | No | 5s | -5 | 0 | 0.3s | Original (synthesized) | CC0 1.0 | None required |
| `sfx/progression/day_start.wav` | New day begins (DAY counter increments) | Progression events | Fresh, optimistic morning | No | 3.2s | -5 | 0 | 0.3s | Original (synthesized) | CC0 1.0 | None required |
| `sfx/progression/location_unlocked.wav` | A locked map location becomes available | Progression events | Discovery, magical lift | No | 2.6s | -5 | 0 | 0.3s | Original (synthesized) | CC0 1.0 | None required |
| `sfx/environment/footstep_wood_01.wav` | Footstep on apartment wood floor (Home) | Home | Soft, muted | No | 0.25s | -16 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/environment/footstep_wood_02.wav` | Footstep on apartment wood floor (Home) | Home | Soft, muted | No | 0.25s | -16 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/environment/footstep_wood_03.wav` | Footstep on apartment wood floor (Home) | Home | Soft, muted | No | 0.25s | -16 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/environment/footstep_wood_04.wav` | Footstep on apartment wood floor (Home) | Home | Soft, muted | No | 0.25s | -16 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/environment/footstep_tile_01.wav` | Footstep on rooftop tiles (Coffee Corner) | Coffee Corner | Light, crisp | No | 0.25s | -16 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/environment/footstep_tile_02.wav` | Footstep on rooftop tiles (Coffee Corner) | Coffee Corner | Light, crisp | No | 0.25s | -16 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/environment/footstep_tile_03.wav` | Footstep on rooftop tiles (Coffee Corner) | Coffee Corner | Light, crisp | No | 0.25s | -16 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |
| `sfx/environment/footstep_tile_04.wav` | Footstep on rooftop tiles (Coffee Corner) | Coffee Corner | Light, crisp | No | 0.25s | -16 | 0 | 0 | Original (synthesized) | CC0 1.0 | None required |

## Verification

Every file was decoded with a standard browser audio decoder (Web Audio `decodeAudioData`) after export. For each file I checked: it decodes, the duration and sample rate are as expected, there are no NaN samples, it isn't silent, and (for music) the `smpl` loop chunk is present and the waveform is continuous across the loop point.

| File | Duration | Sample rate | Size | Peak | RMS | Loop chunk |
|---|---|---|---|---|---|---|
| `music/main_menu/main_menu_theme.wav` | 50s | 22050 Hz | 2159 KB | -3.7 dBFS | -18.4 dBFS | yes |
| `music/apartment/apartment_theme.wav` | 49.23s | 22050 Hz | 2126 KB | -2.9 dBFS | -18.4 dBFS | yes |
| `music/cafe/cafe_theme.wav` | 45.71s | 22050 Hz | 1974 KB | -2.9 dBFS | -18.4 dBFS | yes |
| `music/supplier_depot/supplier_depot_theme.wav` | 55.38s | 22050 Hz | 2391 KB | -4.7 dBFS | -18.4 dBFS | yes |
| `music/travel/travel_theme.wav` | 51.43s | 22050 Hz | 2221 KB | -3.1 dBFS | -18.4 dBFS | yes |
| `music/meetings/sales_meeting_theme.wav` | 41.74s | 22050 Hz | 1803 KB | -3.4 dBFS | -19.2 dBFS | yes |
| `music/negotiation/negotiation_theme.wav` | 53.33s | 22050 Hz | 2303 KB | -2.7 dBFS | -18.4 dBFS | yes |
| `music/finance/finance_theme.wav` | 42.67s | 22050 Hz | 1843 KB | -2.6 dBFS | -18.8 dBFS | yes |
| `music/inventory/inventory_theme.wav` | 40s | 22050 Hz | 1728 KB | -4.5 dBFS | -18.8 dBFS | yes |
| `music/other_locations/city_bank_theme.wav` | 48s | 22050 Hz | 2073 KB | -5.9 dBFS | -19.2 dBFS | yes |
| `music/other_locations/office_park_theme.wav` | 38.4s | 22050 Hz | 1659 KB | -3.7 dBFS | -18.8 dBFS | yes |
| `music/other_locations/trade_expo_theme.wav` | 33.1s | 22050 Hz | 1431 KB | -4.9 dBFS | -18.4 dBFS | yes |
| `sfx/ui/ui_click.wav` | 0.15s | 44100 Hz | 19 KB | -6 dBFS | -26 dBFS | — |
| `sfx/ui/ui_hover.wav` | 0.08s | 44100 Hz | 13 KB | -10.5 dBFS | -29.1 dBFS | — |
| `sfx/ui/ui_tab_select.wav` | 0.6s | 44100 Hz | 57 KB | -6.1 dBFS | -20.7 dBFS | — |
| `sfx/ui/ui_panel_open.wav` | 0.7s | 44100 Hz | 66 KB | -6.5 dBFS | -22.3 dBFS | — |
| `sfx/ui/ui_panel_close.wav` | 0.6s | 44100 Hz | 57 KB | -6.9 dBFS | -23.9 dBFS | — |
| `sfx/ui/ui_locked.wav` | 0.5s | 44100 Hz | 49 KB | -5.2 dBFS | -18.8 dBFS | — |
| `sfx/ui/map_open.wav` | 1.3s | 44100 Hz | 118 KB | -4.4 dBFS | -20.8 dBFS | — |
| `sfx/ui/map_pin_select.wav` | 0.35s | 44100 Hz | 36 KB | -5.2 dBFS | -19.5 dBFS | — |
| `sfx/ui/travel_confirm.wav` | 1.4s | 44100 Hz | 126 KB | -3.7 dBFS | -19.8 dBFS | — |
| `sfx/sales/sale_success.wav` | 2.2s | 44100 Hz | 195 KB | -3.1 dBFS | -18.1 dBFS | — |
| `sfx/sales/sale_failed.wav` | 1.4s | 44100 Hz | 126 KB | -5.2 dBFS | -18.8 dBFS | — |
| `sfx/sales/purchase.wav` | 1.1s | 44100 Hz | 100 KB | -3.7 dBFS | -16 dBFS | — |
| `sfx/sales/payment_received.wav` | 1.2s | 44100 Hz | 109 KB | -3.7 dBFS | -19.1 dBFS | — |
| `sfx/notifications/notification_message.wav` | 1s | 44100 Hz | 92 KB | -4.4 dBFS | -17.7 dBFS | — |
| `sfx/notifications/new_lead.wav` | 1.5s | 44100 Hz | 135 KB | -3.8 dBFS | -17.7 dBFS | — |
| `sfx/notifications/meeting_reminder.wav` | 1.6s | 44100 Hz | 143 KB | -4.4 dBFS | -18.3 dBFS | — |
| `sfx/progression/level_up.wav` | 2.8s | 44100 Hz | 247 KB | -2.5 dBFS | -18 dBFS | — |
| `sfx/progression/reputation_up.wav` | 1.5s | 44100 Hz | 135 KB | -4.6 dBFS | -18.4 dBFS | — |
| `sfx/progression/task_complete.wav` | 1s | 44100 Hz | 92 KB | -6 dBFS | -25.3 dBFS | — |
| `sfx/progression/achievement_unlocked.wav` | 3.2s | 44100 Hz | 281 KB | -2.7 dBFS | -16.6 dBFS | — |
| `sfx/progression/day_end.wav` | 5s | 44100 Hz | 436 KB | -3.8 dBFS | -19 dBFS | — |
| `sfx/progression/day_start.wav` | 3.2s | 44100 Hz | 281 KB | -3.7 dBFS | -19.1 dBFS | — |
| `sfx/progression/location_unlocked.wav` | 2.6s | 44100 Hz | 230 KB | -3.6 dBFS | -19.9 dBFS | — |
| `sfx/environment/footstep_wood_01.wav` | 0.25s | 44100 Hz | 27 KB | -6.7 dBFS | -21.9 dBFS | — |
| `sfx/environment/footstep_wood_02.wav` | 0.25s | 44100 Hz | 27 KB | -6.1 dBFS | -21.1 dBFS | — |
| `sfx/environment/footstep_wood_03.wav` | 0.25s | 44100 Hz | 27 KB | -6 dBFS | -21.3 dBFS | — |
| `sfx/environment/footstep_wood_04.wav` | 0.25s | 44100 Hz | 27 KB | -6 dBFS | -22.3 dBFS | — |
| `sfx/environment/footstep_tile_01.wav` | 0.25s | 44100 Hz | 27 KB | -6.2 dBFS | -24.8 dBFS | — |
| `sfx/environment/footstep_tile_02.wav` | 0.25s | 44100 Hz | 27 KB | -6 dBFS | -24.2 dBFS | — |
| `sfx/environment/footstep_tile_03.wav` | 0.25s | 44100 Hz | 27 KB | -6 dBFS | -24.3 dBFS | — |
| `sfx/environment/footstep_tile_04.wav` | 0.25s | 44100 Hz | 27 KB | -6 dBFS | -24 dBFS | — |

Total: 43 files, 26.4 MB.
