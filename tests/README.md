# The Hollow Spire validation

Run these scripts with Godot 4.7.2 from the project root. The current tower checks use temporary profiles. The two rendered checks cap the renderer at 60 FPS. The other scripts in this folder include coverage for retained legacy campaign and animation systems.

| Script | Coverage |
| --- | --- |
| `tower_progression_validation.gd` | All eleven floors, one guardian and retinue at a time, actual moving lift, exact once-per-arrival health, no combat healing, wing roster, game over, and floor-one restart; uses an isolated profile |
| `boss_reward_validation.gd` | Real guardian defeat, growth and XP, no health restoration, duplicate reward prevention, and lift activation after the retinue falls |
| `battle_royale_validation.gd` | Shared eleven-floor construction, arena bounds, distinct guardian/faction identities, stable arena radius, floor heights, and floor-ten/eleven roster |
| `tower_rendered_performance_profile.gd` | 60 FPS capped, 1.5-second rendered samples for floor one and the final-boss floor; reports FPS, longest frame, and draw-call average |
| `final_boss_rendered_validation.gd` | Rendered final guardian, grounded main retinue, winged target, jumping melee, Q impact, boss phases/attacks, beam warning capture, and a short 60 FPS capped profile |
| `elemental_powers_validation.gd` | Fire/lightning selection, 200 HP, timed sword enchantment, enhanced melee, ranged lightning collision, meteor/storm damage, self immunity and repeated R casts after mana regeneration |
| `provided_motion_tests.gd` | All 23 actor variants, actual bone motion during attacks, finite transforms and valid bind/rest poses for the new sculpt rigs |
| `combat_validation.gd` | 290 checks including active pursuit, physical punch/weapon contact, interruption, walls/dodging, visible active powers, mana, phases and court boundaries; also verifies the flying-soldier Q counter and final boss beam, void sphere and phase-three elemental signatures |
| `player_combat_validation.gd` | Player/Stelae grounding, parent-space pelvis motion, palm grip alignment, distinct three-cut trajectories and return to guard |
| `player_animation_quality.gd` | Planted foot motion, continuous gait during attacks and action recovery on both player skins |
| `player_cast_motion_validation.gd` | Raised blade, weighted downstroke, aimed ranged release and palm grip on both player skins |
| `player_ground_contact_validation.gd` | Actual skinned boot vertices remain grounded through idle, sword cuts and spell casts on both player skins |
| `sculpt_motion_validation.gd` | Articulated enemy gait, attacks, grounding, weapon shape and finite rig transforms |
| `rifle_motion_validation.gd` | Supplied rifle grip, aimed shot and stock strike |
| `enemy_loadout_validation.gd` | 212 checks for the preserved source sword/rifle geometry, rigid weapon size, grip attachment during movement/strikes/death and sheath placement |
| `live_input_validation.gd` | Real scene event routing for physical Q/R, repeated R, pause/resume and mouse sword input; run without `--headless`, with `--audio-driver Dummy --fixed-fps 60` |
| `combat_endgame_validation.gd` | Lethal multi-target final blow, exact guardian/clear rewards, servant dissolution, hostile-spell cancellation and safe portal exploration |
| `cathedral_campaign_tests.gd` | All eleven encounters, supplied player forms, checkpoint/resume including summon budgets and expanded estate positions, defeat/retry and exact final portal message |
| `movement_contact_validation.gd` | Drives the real player around the complete exterior tower, through the doorway and along the interior nave; checks curb stepping, wall blocking/sliding, double jump, dodge and stable recovery from invalid or embedded poses. Run with `--fixed-fps 60` |
| `exterior_world_tests.gd` | Continuous estate floor coverage, perimeter collision, clear doorway approach, valid spawn and compatibility with old courtyard positions |
| `interior_tests.gd` | Arena layout, walkable routes and portal lifecycle |
| `tower_layout_validation.gd` | Enlarged hall and five-room dimensions, separated doors and key placement on all eleven floors |
| `tower_stair_validation.gd` | Real player and minion door clearance, eleven stair ascents and descents, locks and terrace access; use `--fixed-fps 60`. Pass `-- descents-only` for descent coverage alone |
| `tower_session_migration_validation.gd` | Checkpoint migration, eleven-floor keys and discoveries, growth data and safe positions |
| `roaming_minion_validation.gd` | 17 checks for minions passing all five doors in both directions, long pursuit, floor isolation and guardian completion with roaming enemies still present |
| `player_growth_validation.gd` | 23 checks for XP costs, healing, resource caps, individual stat upgrades and overall levels |
| `growth_session_validation.gd` | 21 checks for world-specific XP/upgrades, disk persistence, reward/enemy atomicity, stale-runtime protection, failed-write recovery and backup integrity |
| `touch_combat_validation.gd` | Independent touch ownership, spells, pausing and cleanup; pass `-- --touch-controls` |

Example: `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/cathedral_campaign_tests.gd`.

The campaign check keeps its temporary profile under `user://` and removes it after completion. It can also run directly from the `build` directory against `Hero.pck`, using an absolute path for `--script`; the packaged game does not need a `tests` directory for saves.

For the full movement check, use `Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script tests/movement_contact_validation.gd --log-file tests/movement-contact-validation.log`.

Rendered reviews run without `--headless`, using `--audio-driver Dummy` if the host has no audio device. These scripted scenes are visual checks, not representative live-play performance benchmarks.

| Rendered script | Coverage and outputs |
| --- | --- |
| `elemental_gameplay_preview.gd` | Both characters, fire/lightning blade enchantment, meteor, thunderstorm, ranged powers and updated character menu |
| `enemy_animation_preview.gd` | All 21 enemy types, rest, three run phases and three attack poses; writes `tests/enemies_*.png` |
| `combat_motion_review.gd` | Isolated manual close-combat review in Court III; logs repeated physical strikes without touching the player's campaign |
| `cathedral_preview.gd` | Desktop gameplay, boss encounters, portal and menus |
| `cathedral_touch_preview.gd` | Character menu, Omega Knight and touch combat; launch with `--resolution 960x600 -- --touch-controls` |
| `elemental_visual_review.gd` | Labelled comparison of all eleven elemental projectile silhouettes and materials; writes `tests/elemental_projectiles.png` |
| `fire_magic_preview.gd` | Supplied character's burning sword and sweeping fire slash; writes `tests/burning_sword.png` and `tests/living_fire_slash.png`. Pass `-- omega` to review Omega Knight instead of Girl Knight |
| `quality_visual_review.gd` | Final bestiary at desktop and 960×600, real fire-slash damage presentation, cathedral entry and the two final guardians |
| `authored_motion_preview.gd` | Movement, dodge, jump, sword and casting contact frames; pass `-- female`, `-- omega` or a guardian asset ID |
| `enemy_choreography_review.gd` | All 21 enemy types in guard, run, anticipation and contact poses using their supplied weapon profiles; writes `art/asset_review/choreography/` |
| `expanded_floor_review.gd` | Enlarged hall, small room doors, key collection, locked/open stairs and XP menu at desktop and 960×600; pass `-- --manual` for an isolated playable review |
| `packaged_play_review.gd` | Manual input smoke review with the exported runtime and an isolated profile; starts at the menu, then moves the review player near the entrance and first court |

Example: `Godot_v4.7.2-stable_win64_console.exe --path . --audio-driver Dummy --script tests/fire_magic_preview.gd --log-file tests/fire-magic-preview.log`.

Previous pistol, energy, four-operator and five-wave checks have been preserved under `backups/retired-gun-arena-tests/`. Those tests assert behavior intentionally replaced by this update and are excluded from the current suite.
