# HERO — The Hollow Spire

A third-person sword-and-magic boss tower built in Godot 4.7.2. Climb eleven copies of the same 280-metre arena, defeat the guardian and its faction on each floor, and ride the central lift to continue. Floors one through nine have distinct elemental guardians; Azrael guards floor ten, and Nox waits at the summit.

## The tower run

- Only the current floor's guardian and retinue spawn. The next encounter stays locked until every required fighter is defeated and the lift reaches the next floor.
- The lift platform carries the player and ally through the central shaft. The current floor, guardian name, and guardian health appear in the HUD.
- Health does not regenerate during a floor. Defeating enemies or buying capacity upgrades does not refill it. Health and mana refill once when the lift arrives on the next floor. There are no combat healing pickups.
- Death ends the run and is saved as a game-over state. The restart button begins again on floor one; it never revives a failed run.
- Guardians have distinct elemental moves and staged attacks. The Grand Guard is stronger than the first nine guardians. Nox has three phases, fast dashes, elemental attacks, a warned black beam, and a launched dark sphere.
- Only the visibly winged `soldier_9`, `subboss_9`, and `grand_boss` models fly. The other fighters stay grounded.

## Controls

Desktop: WASD to move, mouse to look, Shift to run, left mouse to attack, right mouse to cast, Q to enchant the blade (or fire at a targeted winged enemy), R for the ultimate, Space to jump, Ctrl to dodge, E to switch camera shoulder, U for upgrades, and Esc to pause. The lift boards automatically when the player steps onto it after the floor is clear.

Phone: move with the left joystick, swipe the open right side to look, and use the sword, jump, dodge, enchant/spell, ultimate, and upgrade buttons. The pause menu has an illustrated control guide. Settings include sensitivity, volume, camera shake, and render scale.

Normal movement, sword swings, jumps, and dodges do not cost mana. Mana regenerates automatically. The AI partner can recover after being knocked down.

## Android APK

The existing phone package is `build/android/Hero.apk`. It predates these tower changes and must be rebuilt before it contains the lift progression. It targets 64-bit ARM phones, Android 7.0 or newer, and OpenGL ES 3.0.

That package is signed locally. Its SHA-256 and verification details are beside it. The signing key is outside the project under `%LOCALAPPDATA%/RELIC/signing`; preserve this key for future updates. An older APK signed with a different key cannot be upgraded in place with this one.

The desktop renderer is capped at 60 FPS and starts at 85% 3D render scale; interface text stays at full resolution. Phone performance and installation still require testing on physical Android hardware. Desktop rendered checks are separate from headless validation. The characters are stylized, existing assets with procedural runtime motion; they are not AAA animation production assets.

## Development and validation

Open `project.godot` in Godot 4.7.2 and press F5. Run the available checks from this directory:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/tower_progression_validation.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/battle_royale_validation.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/boss_reward_validation.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/touch_combat_validation.gd -- --touch-controls
Godot_v4.7.2-stable_win64_console.exe --path . --script tests/tower_rendered_performance_profile.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script tests/final_boss_rendered_validation.gd
```

The rendered profile is capped at 60 FPS. It samples floor one and the final floor for 1.5 seconds each and writes `art/asset_review/final_boss_master/tower_rendered_profile.txt`. Headless frame rate is not a substitute for rendered performance.

Main files: `scripts/game.gd` (tower progression and health rules), `scripts/tower_arena.gd` (arena floors and lift), `scripts/enemy.gd` (boss AI and attacks), `player.gd` (combat and movement), and `scripts/hud.gd` (HUD and menus). Asset attribution and licenses are preserved in `CREDITS.md` and `assets/provided/ATTRIBUTION.md`.
