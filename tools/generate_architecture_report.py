import os
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), fill_hex)
    tcPr.append(shd)

def create_reports():
    # 1. Read player.gd verbatim
    with open("player.gd", "r", encoding="utf-8") as f:
        player_code = f.read()

    # Build Markdown Content
    md_content = f"""# HERO: CATHEDRAL OF CINDERS — COMPLETE ARCHITECTURAL REPORT

---

## 1. ENGINE & INPUT MAP

### Exact Godot Version & Renderer
* **Engine Feature Flags (`project.godot`):** `4.7`, `GL Compatibility`
* **Official Binary in Repository / Packaging:** Godot Engine `v4.7.2.stable.official.ed1daf0bf` (`Godot_v4.7.2-stable_win64_console.exe`, version 4.7.2.0)
* **Renderer Configuration:**
  - `renderer/rendering_method="gl_compatibility"` (OpenGL ES 3.0 / Compatibility pipeline)
  - `renderer/rendering_method.mobile="gl_compatibility"`
  - `rendering_device/driver.windows="d3d12"` (Direct3D 12 underlying driver for Windows display server)
  - `textures/vram_compression/import_etc2_astc=true`
  - `antialiasing/quality/msaa_3d=1`
* **Physics Engine:** `3d/physics_engine="Jolt Physics"` (Godot Jolt native physics)

### Input Map Configuration
* **In `project.godot` file:**
  There is **no `[input]` section** declared in `project.godot`. The engine configuration file does not declare input actions statically.
* **Runtime Programmatic Setup (`scripts/game.gd` -> `setup_input()`):**
  All game actions are dynamically registered into Godot's `InputMap` singleton during `game._ready()`:
  - `"forward"`: `KEY_W`
  - `"back"`: `KEY_S`
  - `"left"`: `KEY_A`
  - `"right"`: `KEY_D`
  - `"jump"`: `KEY_SPACE`
  - `"sprint"`: `KEY_SHIFT`
  - `"dodge"`: `KEY_CTRL`
  - `"melee"`: `KEY_V`
  - `"magic_slash"` (Enchant Sword): `KEY_Q`
  - `"ultimate"` (Sky Spell - Meteor / Thunderstorm): `KEY_R`
  - `"shoulder"` (Swap Camera Shoulder): `KEY_E`
  - `"pause_game"`: `KEY_ESCAPE`
  - `"interact"` (Talk to Elder Orin / Read Echo): `KEY_T`
  - `"hero_growth"` (Hero Upgrades / Spend XP): `KEY_U`
  - `"journal"` (Open Story Journal): `KEY_J`
  - `"fire"`: `MOUSE_BUTTON_LEFT` (Three-hit sword combo)
  - `"aim"`: `MOUSE_BUTTON_RIGHT` (Cast Fireball / Arc Bolt)
* **Additional Input & Motion Mechanics in `player.gd`:**
  - **Mouse Look:** `InputEventMouseMotion` relative vector scales yaw and pitch by `game.sensitivity`.
  - **Double-Tap W Sprint:** Rapid double-tap of `forward` within 0.35s activates sprinting (`_w_sprinting`).
  - **Auto-Forward Sprint:** Pressing `sprint` (Shift) with no directional keys automatically drives forward run velocity (`Vector2(0, -1.0)`).
  - **Space Continuous Bunny-Hop:** Holding `jump` (Space) buffers jumps and immediately triggers ground jumps or mid-air double jumps.
  - **Touchscreen & Mobile Controls (`scripts/touch_controls.gd`):** Left virtual joystick for 360° locomotion (full deflection activates sprint), right-screen swipe for camera rotation, and dedicated touchscreen action buttons for Sword, Ranged Magic, Enchant Blade, Sky Ultimate, Jump, Dodge, Shoulder Swap, and Menu.

### Main Scene Path & Autoload / Singleton Architecture
* **Main Scene Path (`project.godot`):** `run/main_scene="res://ground.tscn"`
  - `res://ground.tscn` contains a single root node: `RelicArena (Node3D)` attached to `res://scripts/game.gd`.
* **Autoload / Singleton in `project.godot`:**
  There are **no `[autoload]` entries** defined in `project.godot`.
* **Runtime Service Architecture (`scripts/game.gd`):**
  Instead of project-level autoload singletons, `game.gd` manages systems via instantiated service nodes and reference-counted objects:
  - `progress`: `scripts/progress.gd` (Save game and transactional world session management)
  - `sound`: `scripts/sound.gd` (Synthesized audio engine)
  - `fx`: `scripts/effects.gd` (Combat VFX, slashes, damage numbers, dynamic lighting)
  - `arena`: `scripts/tower_arena.gd` (The 11-floor Cathedral of Cinders interior)
  - `story_world`: `scripts/story_world.gd` (The exterior Hollow Spire estate and Greywake refuge)
  - `hud`: `scripts/hud.gd` (Interface, menus, modals, health/mana bars)
  - `touch_controls`: `scripts/touch_controls.gd` (Virtual mobile touch interface)
  - `combatants`: `Node3D` (Container for all enemies, bosses, hazards, and projectiles)
  - `pickups`: `Node3D` (Container for dropped vitality and mana recovery orbs)

---

## 2. PLAYER & SKINS SETUP

### Full Node Hierarchy of the Player
The Player scene (`player.tscn`) is declared as a single root node:
```gdscript
[node name="Player" type="CharacterBody3D"]
script = ExtResource("1") # res://player.gd
```
In `player.gd` `_ready()`, the entire functional node tree is assembled dynamically:

```text
Player (CharacterBody3D) [Collision Layer 2, Collision Mask 5]
├── CollisionShape3D (CapsuleShape3D: radius 0.34m, height 1.85m, position y = 0.94m)
├── Character (Node3D) [script: res://scripts/character_visual.gd, extends provided_visual.gd]
│   ├── Motion (Node3D)
│   │   └── SourceModel (Node3D) [Instantiated from assets/provided/female.glb or omega.glb]
│   │       └── Skeleton3D [Rig with 18 bones on Girl Knight, 167 bones on Omega Knight]
│   │           └── MeshInstance3D(s) [Character mesh surfaces with overridden PBR materials]
│   ├── CombatAnimator (AnimationPlayer) [callback_mode_process = ANIMATION_CALLBACK_MODE_PROCESS_MANUAL]
│   └── DaVinciEmberSword / AbilityHand (Node3D) [Fastened to hand bone pose via dynamic palm matrix]
│       ├── sword (Node3D) [Instantiated from assets/provided/sword.glb]
│       │   └── MeshInstance3D(s) [Steampunk Da Vinci sword model with metallic/roughness adjustments]
│       ├── MagicOrigin (Marker3D) [Local position (0, 1.10, 0) at blade tip]
│       └── LivingBladeFire / LivingBladeLightning [Optional procedural VFX attached when Q is active]
├── Pivot (Node3D, position y = 1.5m)
│   └── SpringArm3D (SpringArm3D: length 5.8m, margin 0.18m, collision mask 1, SphereShape3D r = 0.24m)
│       └── Camera3D (Camera3D: fov 76°, near 0.08m, far 520m)
└── EmberPresence (OmniLight3D, position y = 1.8m, color #ffcf9a, energy 0.75, range 5.8m)
```

### The 2 Player Character Skins & 1 Sword Setup
1. **Skin Models:**
   - **Skin 0: Girl Knight (`female`)**
     - Model File: `assets/provided/female.glb` (backed by rest-binding repair in `tools/repair_character_bindings.gd`).
     - Combat Motion: Pre-baked 35-clip retargeted library `assets/motion/female_combat.res`.
     - Element: **Fire** (`#ff9355`).
     - Spells: **Fireball** (Right-Click, 12 mana, 62 damage), **Flame Blade** (Q, 26 mana, +80% combo damage, +1.2m reach for 12s), **Meteor** (R, 70 mana, 320 AoE damage).
   - **Skin 1: Omega Knight (`omega`)**
     - Model File: `assets/provided/omega.glb`.
     - Combat Motion: Pre-baked 35-clip retargeted library `assets/motion/omega_combat.res`.
     - Element: **Lightning** (`#81deff`).
     - Spells: **Arc Bolt** (Right-Click, 12 mana, 68 instant hitscan damage), **Storm Blade** (Q, 26 mana, +80% combo damage, +1.2m reach for 12s with lightning arcs), **Thunderstorm** (R, 70 mana, 240 damage to all visible enemies within 85m).
2. **Skin Switching Mechanism:**
   - Selected in the Lobby interface under the "Characters" tab (`scripts/lobby.gd`).
   - Handled via `player.visual.set_skin(index)` in `scripts/character_visual.gd`:
     ```gdscript
     func set_skin(index: int) -> void:
         skin_index = posmod(index, SKINS.size())
         set_asset("female" if skin_index == 0 else "omega", 1.82)
     ```
   - `set_asset()` cleans up the prior model, instantiates the selected glTF/scene via `scripts/asset_catalog.gd`, identifies bone indices (`Skeleton3D`), attaches the sword, loads the corresponding `.res` motion library, and resets IK targets.
3. **The 1 Sword Setup:**
   - Model File: `assets/provided/sword.glb` (Free Steampunk Da Vinci's Sword).
   - Attached via `character_visual.gd` -> `equip_sword()`:
     - Locates the right wrist/hand bone (`hand`) and calculates anatomical grip offsets using the index, pinky, and middle finger knuckle resting transforms (`_calibrate_grip()`).
     - Positions the sword hilt directly inside the palm rather than pivoting on the wrist joint.
     - Adds `Marker3D` named `MagicOrigin` at `Vector3(0, 1.10, 0)` for projectile alignment.
     - Automatically mirrors sword rotations to match player attack animations and dynamic cast targeting (`_aim_cast_blade()`).

### Complete Code of `player.gd` (Verbatim)
```gdscript
{player_code}
```

---

## 3. ANIMATION SYSTEM

### Animation Architecture: `AnimationPlayer` vs `AnimationTree` vs `AnimatedSprite`
* **Core Player:** The game **strictly uses `AnimationPlayer`** created via script (`animator = AnimationPlayer.new()`).
* **Process Mode:** Configured with `animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL`. The animation mixer is stepped manually via `animator.advance(delta)` inside `scripts/provided_visual.gd` and `scripts/character_visual.gd`.
* **State Machines & Blending:** Does **NOT** use `AnimationTree` and does **NOT** use `AnimatedSprite`.
* **Custom GDScript Blend Engine:**
  - `play(clip, speed, force)`: Controls cross-blending (`blend_time = 0.16s` or `0.055s` on force).
  - Gait-Preserving Phase Sync: Shifting between `Walk_Loop`, `Jog_Fwd_Loop`, and `Sprint_Loop` preserves continuous cycle phase (`_locomotion_clock`), eliminating foot-sliding and pop artifacts.
  - Lower-Body Movement Layering: When moving during an active one-shot action (e.g. swinging the sword or casting while walking), the engine dynamically samples bone tracks (pelvis position, thighs, shins, feet, balls) from the locomotion animation and slerps them onto the skeletal pose at 90% strength, preserving running feet under a swinging torso.
  - Analytical Two-Bone Inverse Kinematics: `_settle_foot()` in `character_visual.gd` calculates pole vectors and heel-plane rotations to plant boots flat against the ground without bending toes into floors.
  - Dynamic Secondary Motion: Centripetal banking when turning corners, landing squash and compression settle, organic breathing sway, cape bone articulation (`_cloth_bones`), wing flapping lift (`_wing_bones`), and real-time sword-aim IK (`_aim_cast_blade`).

### Complete List of Exact Animation Clips

#### 1. Player Animations (`assets/motion/female_combat.res` & `omega_combat.res`)
* **Locomotion & Posture:**
  - `Idle_Loop`
  - `Sword_Idle_Loop`
  - `Pistol_Idle_Loop`
  - `Walk_Loop`
  - `Jog_Fwd_Loop`
  - `Sprint_Loop`
  - `Crouch_Idle_Loop`
  - `Crouch_Fwd_Loop`
  - `Jump_Start`
  - `Jump_Loop`
  - `Jump_Fall`
  - `Double_Jump`
  - `Jump_Land`
  - `Roll`
  - `Dance_Loop`
* **Combat & Attacks:**
  - `Sword_Attack` (First horizontal slash combo)
  - `Sword_Attack02` (Second return backhand slash combo)
  - `Sword_Attack03` (Third heavy overhead vertical downstroke combo)
  - `Punch_Jab`
  - `Fire_Cast` (Aimed horizontal blade thrust releasing Fireball or Arc Bolt)
  - `Cast` (Two-handed sword overhead raise gathering mana motes for Sky Spell)
  - `Channel_Loop`
  - `Cast_Release`
  - `Hit_Chest`
  - `Death01`

#### 2. Soldiers & Bosses Elemental Cues & Loadout Actions
* **Skeletal Bosses / Soldiers (`subboss_1_combat.res`, `subboss_7_combat.res`, `soldier_1_combat.res`):**
  - Inherit all base locomotion loops (`Idle_Loop`, `Walk_Loop`, `Jog_Fwd_Loop`, `Sprint_Loop`, `Hit_Chest`, `Death01`).
* **Weapon Loadout Specific Action Clips (`scripts/enemy_loadout.gd`):**
  - `Blade_Right_Slash` (maps to `Sword_Attack`)
  - `Blade_Right_Return` (maps to `Sword_Attack02`)
  - `Blade_Left_Slash` (maps to `Sword_Attack`)
  - `Blade_Left_Return` (maps to `Sword_Attack02`)
  - `Blade_Overhead` (maps to `Sword_Attack03`)
  - `Dual_Blade_Cross` (maps to `Sword_Attack02`)
  - `Axe_Chop` (maps to `Sword_Attack03`)
  - `Axe_Backhand` (maps to `Sword_Attack02`)
  - `Staff_Sweep` (maps to `Sword_Attack02`)
  - `Staff_Thrust` (maps to `Sword_Attack`)
  - `Scythe_Reap` (maps to `Sword_Attack02`)
  - `Scythe_Return` (maps to `Sword_Attack`)
  - `Rifle_Butt` (special standing stock melee strike)
  - `Rifle_Aim_Shot` (standing shoulder-aimed rifle volley)
* **The 11 Court Elemental Attack Cues (`scripts/provided_visual.gd` & `encounter_data.gd`):**
  - Floor 1: `Stone_Slam`
  - Floor 2: `Water_Sweep`
  - Floor 3: `Fire_Combo`
  - Floor 4: `Soul_Channel`
  - Floor 5: `Lightning_Lunge`
  - Floor 6: `Wind_Cyclone`
  - Floor 7: `Poison_Cast`
  - Floor 8: `Ice_Cleave`
  - Floor 9: `Gravity_Pulse`
  - Floor 10: `Lava_Crash`
  - Floor 11: `Void_Reap`

### 3D Model Formats & Animation Import Pipeline
* **Blender Source Files (`.blend`):**
  - `art/hollow_spire/hollow_spire.blend` (Original editable source geometry of the exterior cathedral tower).
* **glTF Binary Files (`.glb`):**
  - Player models: `assets/provided/female.glb` (Girl Knight), `assets/provided/omega.glb` (Omega Knight).
  - Weapon: `assets/provided/sword.glb` (Steampunk Da Vinci Sword).
  - Bosses: `assets/provided/subboss_1.glb` through `subboss_9.glb`, `grand_boss.glb`, `main_boss.glb`.
  - Soldiers: `assets/provided/soldier_1.glb` through `soldier_9.glb`, `grand_soldier.glb`.
  - Architecture: `assets/buildings/hollow_spire.glb`.
  - Animation Source: `Godot/AnimationLibrary_Godot_Standard.glb` (Quaternius CC0 animation rig source).
* **Godot Pre-Baked Resources (`.res` & `.scn`):**
  - Motion Libraries: `assets/motion/female_combat.res`, `omega_combat.res`, `soldier_1_combat.res`, `subboss_1_combat.res`, `subboss_7_combat.res`.
  - 17-Bone Articulated Procedural Rigs: 18 generated `.scn` files under `assets/sculpt_motion/` (`soldier_2.scn` to `soldier_9.scn`, `subboss_2.scn` to `subboss_9.scn`, `grand_boss.scn`, `grand_soldier.scn`, `main_boss.scn`).
* **Animation Import / Retargeting Pipeline:**
  1. `tools/retarget_combat_motion.gd`: Retargets CC0 standard skeletal motion onto the provided knight and soldier rigs, matching anatomical bone names across diverse bone naming conventions.
  2. `tools/player_motion_authoring.gd`: Generates custom kinetic martial animations for the sword cuts, overhead spell cast raise, blade thrust, double jump, and roll.
  3. `tools/build_sculpt_rigs.gd`: Takes unrigged or dense sculpt models, fits a standardized 17-bone armature with weighted skinning (including knees, elbows, ankles, wings, and cloth), and saves optimized `.scn` binaries.
  4. At runtime, `scripts/sculpt_locomotion.gd` and `scripts/provided_visual.gd` dynamically proceduralize walking strides, spine twists, and combat strikes for static sculpts.

---

## 4. ENEMIES, BOSSES & WORLD

### Structure of the 11 Soldiers and 11 Bosses

#### Common Script & Entity Architecture
* **Single Base Controller:** All 11 bosses and 11 soldiers run on `scripts/enemy.gd` (`CharacterBody3D`, Collision Layer 4, Mask 7).
* **Boss Subclass:** `scripts/boss.gd` extends `enemy.gd` and sets `is_boss = true` in `_init()`.
* **AI & Navigation:**
  - Generates 2D planar routes via `AStarGrid2D` on the active floor mesh.
  - Flocks with neighboring minions to avoid stacking.
  - Senses player line-of-sight via `PhysicsRayQueryParameters3D` rays.
* **Leash & Court Ward:**
  - Encounters are anchored to `home_position` with `COMBAT_RADIUS = 43.0m`.
  - If the player retreats outside the court, the enemy enters a ward (`outside_court()`), becomes 100% immune to damage, stops attacks, and triggers a UI warning on the player's HUD.
* **Phases & Health Mechanics:**
  - Soldiers have between 95 HP (Floor 1) and 165 HP (Floor 10), and can be staggered (`stunned = 0.21s`) by player sword attacks.
  - Bosses have scaling health pools (640 HP on Floor 1 up to 2900 HP on Floor 11).
  - Bosses possess dynamic Phase Transitions:
    * Enter **Phase 2** (Awakening) when HP falls below **55%**, increasing movement speed, attack frequency, and unlocking expanded spell patterns.
    * Floor 11 Boss (Nox) enters **Phase 3** (Final Eclipse) below **30% HP**, releasing four consecutive high-damage jumping shockwaves.

#### The 11 Guardians, Soldiers, and Combat Identities
| Floor | Guardian (Boss ID) | Health | Retinue Soldier (ID) | Count | Element | Held Weapon | Combat Behavior & Patterns |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **I** | **Stelae Sentinel** (`subboss_1`) | 640 HP | **Skeleton Lord** (`soldier_1`) | 4 | Stone | Blade | Pure physical sword cuts, stone ground waves, lunging cleaves. No enemy magic. |
| **II** | **Vesper, Tidal Paladin** (`subboss_2`) | 740 HP | **Corrupted Fallen Priest** (`soldier_2`) | 4 | Water | Blade (Paladin) / Fists (Priests) | Committed sword slashes, martial punches, undertow pulling fields, geysers. |
| **III** | **Pyre, the Ember Lord** (`subboss_3`) | 850 HP | **Blood Priest** (`soldier_3`) | 5 | Fire | Fists / Claws | Enemy magic begins. Ember rain clusters, triple fire breath fans, sweeping cinders. |
| **IV** | **Morvane, Soul Shepherd** (`subboss_4`) | 880 HP | **Ash-Grey Cultist** (`soldier_4`) | 5 | Soul | Staff | Lingering soul wells, double spiral spirit rings, ritual recall of 2 fallen minions. |
| **V** | **The Stormbound Knight** (`subboss_5`) | 960 HP | **Corrupted Monk** (`soldier_5`) | 5 | Thunder | Blade | Forked lightning lanes, storm cross strikes, high-speed lunging charges. |
| **VI** | **The Gale Headsman** (`subboss_6`) | 1080 HP | **Shadow Monk Assassin** (`soldier_6`) | 6 | Wind | Executioner Axe | Pulling wind cyclones, dual gust axe lines, outward explosive blasts. |
| **VII** | **Pestilent Praetor** (`subboss_7`) | 1120 HP | **Plague Assassin** (`soldier_7`) | 6 | Blight / Poison | Sentinel Rifle | Persistent damaging poison pools, projectile fans, expanding blight waves. |
| **VIII** | **Frostblade, Oathbreaker** (`subboss_8`) | 1260 HP | **Desert Nomad Assassin** (`soldier_8`) | 6 | Frost | Broken Greatsword | Crossed ice lattices, frost slow zones (35% slow), teleporting shadow cleave. |
| **IX** | **The Six-Winged Judge** (`subboss_9`) | 1500 HP | **Executioner Angel** (`soldier_9`) | 7 | Gravity | Blade (Judge) / Axe (Angels) | Pulling black-hole singularities, star spirals, delayed starfall disk impacts. |
| **X** | **Azrael, Molten Sun** (`grand_boss`) | 2000 HP | **Obsidian Warden** (`grand_soldier`) | 7 | Lava | Dual Blades | Molten rock faults, lava eruptions, charging trails leaving 4 lingering lava pools. |
| **XI** | **Nox, the Last Reaper** (`main_boss`) | 2900 HP | **Obsidian Warden** (`grand_soldier`) | 7 | Void | Scythe | Echoing void rifts, reaping charges, three phases ending in 4 jumping eclipse waves. |

### Structure of the World & Map Scenes
The world is split into two major environments managed under `scripts/game.gd`:

#### 1. The Courtyard & Exterior Estate (`scripts/story_world.gd`)
* **Dimensions:** 460m × 500m enclosed fortress estate bounded by high stone walls.
* **Architecture:** Hollow Spire entrance approach featuring monumental stone archways, lanterns, bronze floor seals, and the imported `assets/buildings/hollow_spire.glb` mesh.
* **Ground Surface:** Continuous static body collision with custom `shaders/spire_grounds.gdshader` rendering terrain.
* **Key Entities:**
  - **Elder Orin:** NPC located at `Vector3(-8, 0, 157)` with interactive dialogue prompts.
  - **Greywake Villagers:** Sick villagers afflicted with mana illness resting under makeshift shelters.
  - **Spire Portal / Threshold:** Illuminated doorway leading into the Cathedral interior.

#### 2. The Cathedral of Cinders Interior (`scripts/tower_arena.gd` & `scripts/tower_layout.gd`)
* **11 Stacked Storeys:** 11 distinct levels separated vertically by 18 metres (`FLOOR_HEIGHT = 18.0m`), reaching a total height of 198m.
* **Floor Geometry (per floor):**
  - **Central Hall:** Enormous 220m × 520m stone arena bordered by 40-metre diameter circular ritual courts, decorative arches, and elemental braziers.
  - **5 Side Exploration Chambers:**
    - Four 80m × 100m side rooms.
    - One 100m × 100m rear chamber.
    - Each chamber features a 3-metre open doorway allowing player and roaming minions to pass freely.
* **Staircase & Progression Gates:**
  - Physical continuous double-flight staircase on the eastern wall (36 stone steps, 0.25m rise, 0.55m run, 6m wide).
  - Each floor's staircase is blocked by a physical stone gate and runic barrier.
  - **Unlocking Condition:** Requires **both** (1) finding the hidden **Floor Key** in one of the 5 side rooms, and (2) defeating the floor's **Guardian encounter**.
* **Performance Optimization (Floor Culling):**
  - Geometry is batched per floor into `Floor01Visuals` through `Floor11Visuals`.
  - `update_floor_visibility()` dynamically hides floors outside the player's immediate level range (rendering only `floor - 1` to `floor + 1`).
* **The Open Terrace (Roof at 198m):**
  - Accessed via Floor 11 stairs after defeating Nox and finding Key 11.
  - Contains the **Moonwell Healing Elixir** bottle at `Vector3(0, 198.12, -7)`.
  - Collecting the elixir unlocks the quest resolution and reveals an exit sign: *"Next Level — Under Construction"*.

---

## 5. UI, TEXTS & STORY

### Existing UI Scenes & Scripts
* **`scripts/lobby.gd` (Main Menu / Lobby System):**
  - **Enter World:** Launches into the saved world session at the latest checkpoint.
  - **Characters:** Interactive preview and switching between Girl Knight and Omega Knight.
  - **The Eleven (Field Manual):** Visual reference guide inspecting all 11 bosses, models, health, and combat patterns.
  - **Settings:** Controls 3D Render Scale (0.5x–1.0x), Master Volume, Mouse Sensitivity, and Camera Shake toggle.
  - **Credits:** Complete asset attribution and developer credits.
* **`scripts/hud.gd` (HUD & In-Game Interface):**
  - Top bar: Title banner, floor score, elimination counter, and coins.
  - Bottom-left: Vitality gauge (`200 / 200 HP`), Mana gauge (`100 / 100 MP`), and enchantment timers.
  - Bottom-center: Keybinding prompt bar and Mara's Echo inspection button (`T`).
  - Screen Flash: Dynamic red damage flash (`damage_flash`) and hit confirmation reticle.
* **`scripts/story_hud.gd` (Story & Dialogue Interface):**
  - Dialogue overlay with animated typewriter text for conversations with Elder Orin.
  - Displays current campaign objectives (e.g., *"Search the chambers for Floor Key I"*, *"Awaken the guardian"*).
* **`scripts/story_journal.gd` (The Story Journal - `J` Key):**
  - **Tab 1: Mara's Echoes:** Displays all 11 recovered blue-copper echoes found throughout the tower.
  - **Tab 2: Deductions / Mysteries:** Interactive deduction puzzle interface where players answer lore questions using discovered clues to uncover the Spire's true history.
* **`scripts/player_growth.gd` (Hero Upgrades - `U` Key):**
  - XP spending interface:
    - *Restore Vitality* (30 XP for 50% HP)
    - *Restore Mana* (25 XP for 100% MP)
    - *Power Upgrade* (+10% base damage, cost: `100 * level`)
    - *Health Upgrade* (+20 Max HP, cost: `80 * level`)
    - *Magic Upgrade* (+10 Max MP, cost: `80 * level`)
    - *Hero Level* (Increases Power, Health, and Magic simultaneously, cost: `210 * level`)
* **`scripts/touch_controls.gd` (Virtual Touchscreen Controls):**
  - Left virtual joystick (analog walk/run), right look-swipe area, and 8 dedicated touchscreen buttons.

### Text & Documentation Files in the Repository
* `README.md`: Comprehensive overview of gameplay, controls, 11 guardians, progression, and rebuild instructions.
* `PLATFORMS.md`: Build configurations and instructions for Windows, Android, and Web platforms.
* `CREDITS.md`: Full third-party licensing and artist attributions.
* `License.txt`: Standard open-source software license.
* `read me .txt`: Model usage guide covering UVs, alpha clipping, and GLB/FBX material setup.
* `assets/provided/ATTRIBUTION.md`: Line-by-line attribution for all 23 character models, sword, and source authors.
* `assets/provided/source_manifest.json`: Machine-readable JSON manifest recording source triangle counts, SHA256 checksums, and decimation ratios.

### Narrative, Lore & Story Elements ("The Borrowed Dawn")
* **Premise:**
  The village of Greywake suffers from a bizarre affliction: people's physical wounds heal instantly, but they lose their living memories and forget their loved ones. Mara, the village bellkeeper and daughter of Elder Orin, has forgotten her own father. Orin tasks the player with climbing the Hollow Spire, defeating its corrupted master Nox, and retrieving the Moonwell Healing Elixir.
* **The 11 Discoverable Memory Echoes (`scripts/story_data.gd`):**
  1. *Floor 1 (The Unbroken Seal):* The Spire doors were unlocked from the inside using a healer's crescent, disproving the legend of an invading army.
  2. *Floor 2 (The Dry Ferry):* Vesper's passenger ledger shows 43 sick villagers transported as patients, not prisoners of war.
  3. *Floor 3 (A Charred Admission):* Pyre preserved an order signed by "O." inviting all sick families into the Spire.
  4. *Floor 4 (Voices Without Bodies):* Morvane's soul choir consists of living villagers' echoes, not the dead.
  5. *Floor 5 (The Storm Ledger):* The copper ledger records the price: one closed wound costs the memory of summer rain; one cleared fever costs a child's first word.
  6. *Floor 6 (The Bellkeeper's Thread):* Mara tied a blue ribbon to her wrist to remember her own identity and recorded that speaking a person's true name guides their memory back.
  7. *Floor 7 (The Physician's Empty Page):* Praetor notes that the Moonwell burns living memories to brew its medicine.
  8. *Floor 8 (Nox Before the Mask):* Nox was originally the "First Keeper" who took the oath: *"If it hungers, take my memories before theirs."*
  9. *Floor 9 (A Counterweight of Names):* The Six-Winged Judge's balance reveals the 11 wardens are counterweights and the crown is a shackle holding Nox to an endless command.
  10. *Floor 10 (The Unburned Order):* Azrael kept Orin's original signed contract: *"Continue the healing until no one suffers. For my daughter, Mara."*
  11. *Floor 11 (The Last Bell):* Nox's final message reveals he is not a tyrant king, but the Spire's final prisoner who lost his memories trying to protect Greywake.
* **The 3 In-Game Mysteries:**
  1. *A Siege Without an Army:* Uncovers that the Spire was opened as a refuge, not invaded.
  2. *The Choir With No Graves:* Uncovers that the Moonwell consumes living memories, which can be restored if their names are spoken over unspent water.
  3. *The Prisoner on the Throne:* Uncovers that Nox and the 11 wardens were trapped by Orin's impossible command.
* **Branching Story Endings:**
  - **Standard Ending (*Dawn Restored*):** Triggered if the player returns the elixir without solving all mysteries. Orin heals the villagers' physical wounds, but Mara remains an amnesiac stranger to him.
  - **True Ending (*The Names We Carry*):** Triggered if all 11 echoes and 3 mysteries are solved. Orin confesses his mistake, speaks the villagers' names over the Moonwell water, restores their stolen memories, and Mara remembers her father.
"""

    with open("HERO_Game_Architecture_Report.md", "w", encoding="utf-8") as f:
        f.write(md_content)
    print("Generated HERO_Game_Architecture_Report.md")

    # Build DOCX Document
    doc = Document()

    # Document Title
    p_title = doc.add_paragraph()
    r_title = p_title.add_run("HERO: CATHEDRAL OF CINDERS")
    r_title.bold = True
    r_title.font.size = Pt(24)
    r_title.font.color.rgb = RGBColor(18, 52, 86)
    
    p_sub = doc.add_paragraph()
    r_sub = p_sub.add_run("Comprehensive Game Architecture & Technical Systems Report")
    r_sub.italic = True
    r_sub.font.size = Pt(14)
    r_sub.font.color.rgb = RGBColor(100, 110, 120)

    doc.add_paragraph("—" * 65)

    def add_h1(text):
        h = doc.add_paragraph()
        run = h.add_run(text)
        run.bold = True
        run.font.size = Pt(18)
        run.font.color.rgb = RGBColor(25, 60, 100)
        h.paragraph_format.space_before = Pt(14)
        h.paragraph_format.space_after = Pt(4)

    def add_h2(text):
        h = doc.add_paragraph()
        run = h.add_run(text)
        run.bold = True
        run.font.size = Pt(14)
        run.font.color.rgb = RGBColor(40, 80, 130)
        h.paragraph_format.space_before = Pt(10)
        h.paragraph_format.space_after = Pt(3)

    def add_bullet(p_bold_prefix, text):
        p = doc.add_paragraph(style='List Bullet')
        r_pre = p.add_run(p_bold_prefix)
        r_pre.bold = True
        p.add_run(text)
        p.paragraph_format.space_after = Pt(2)

    def add_code_block(code_text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(4)
        p.paragraph_format.space_after = Pt(4)
        table = doc.add_table(rows=1, cols=1)
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        cell = table.cell(0, 0)
        set_cell_background(cell, "F2F4F7")
        cp = cell.paragraphs[0]
        c_run = cp.add_run(code_text)
        c_run.font.name = "Consolas"
        c_run.font.size = Pt(8.5)
        c_run.font.color.rgb = RGBColor(30, 30, 30)

    # Section 1
    add_h1("1. ENGINE & INPUT MAP")
    add_h2("Exact Godot Version & Renderer")
    add_bullet("Engine Feature Flags (project.godot): ", '4.7, "GL Compatibility"')
    add_bullet("Official Binary in Repository / Packaging: ", "Godot Engine v4.7.2.stable.official.ed1daf0bf (Godot_v4.7.2-stable_win64_console.exe, version 4.7.2.0)")
    add_bullet("Renderer Configuration: ", "gl_compatibility (OpenGL ES 3.0 compatible pipeline), mobile gl_compatibility, windows display driver D3D12, ETC2/ASTC VRAM compression enabled, 3D MSAA = 1.")
    add_bullet("Physics Engine: ", "3d/physics_engine = Jolt Physics (native Jolt physics integration).")

    add_h2("Input Map Configuration")
    add_bullet("In project.godot: ", "No [input] section declared statically.")
    add_bullet("Runtime Programmatic Registration (scripts/game.gd -> setup_input()): ", "Actions registered in InputMap at runtime: forward (W), back (S), left (A), right (D), jump (Space), sprint (Shift), dodge (Ctrl), melee (V), magic_slash / Enchant Sword (Q), ultimate / Sky Spell (R), shoulder / Swap Camera (E), pause_game (Esc), interact (T), hero_growth (U), journal (J), fire / Sword Combo (Left Mouse), aim / Fireball or Arc Bolt (Right Mouse).")
    add_bullet("Additional Motion Mechanics: ", "Mouse look with yaw/pitch scaling, double-tap W sprint trigger within 0.35s, Shift-only auto forward sprint, continuous bunny-hopping with buffered jump, and full mobile touch overlay (scripts/touch_controls.gd).")

    add_h2("Main Scene Path & Autoload Architecture")
    add_bullet("Main Scene Path: ", 'run/main_scene="res://ground.tscn" (Single root RelicArena: Node3D running scripts/game.gd).')
    add_bullet("Autoloads: ", "None in project.godot. Instead, game.gd instantiates and manages services via composition: progress (save persistence), sound (synthesizer), fx (combat VFX & lights), arena (11-floor Cathedral), story_world (courtyard estate), hud (UI overlay), and touch_controls (mobile).")

    # Section 2
    add_h1("2. PLAYER & SKINS SETUP")
    add_h2("Full Node Hierarchy of the Player Scene")
    doc.add_paragraph("Declared in player.tscn as CharacterBody3D and dynamically initialized in player.gd:")
    add_code_block("""Player (CharacterBody3D) [Collision Layer 2, Collision Mask 5]
├── CollisionShape3D (CapsuleShape3D: radius 0.34m, height 1.85m, position y = 0.94m)
├── Character (Node3D) [scripts/character_visual.gd -> scripts/provided_visual.gd]
│   ├── Motion (Node3D)
│   │   └── SourceModel (Node3D) [assets/provided/female.glb or omega.glb]
│   │       └── Skeleton3D [Rig with 18 bones on Girl Knight, 167 bones on Omega Knight]
│   │           └── MeshInstance3D(s) [Overridden PBR materials]
│   ├── CombatAnimator (AnimationPlayer) [ANIMATION_CALLBACK_MODE_PROCESS_MANUAL]
│   └── DaVinciEmberSword / AbilityHand (Node3D) [Fastened to hand bone via anatomical palm matrix]
│       ├── sword (Node3D) [assets/provided/sword.glb]
│       │   └── MeshInstance3D(s)
│       ├── MagicOrigin (Marker3D) [Local position (0, 1.10, 0)]
│       └── LivingBladeFire / LivingBladeLightning [Attached when Q enchant is active]
├── Pivot (Node3D, position y = 1.5m)
│   └── SpringArm3D (length 5.8m, margin 0.18m, collision mask 1, SphereShape3D r = 0.24m)
│       └── Camera3D (fov 76°, near 0.08m, far 520m)
└── EmberPresence (OmniLight3D, position y = 1.8m, color #ffcf9a, energy 0.75, range 5.8m)""")

    add_h2("The 2 Player Character Skins & 1 Sword Setup")
    add_bullet("Skin 0 - Girl Knight (female): ", "Asset assets/provided/female.glb, 35-clip retargeted library assets/motion/female_combat.res, Fire element (#ff9355). Fireball (Right-Click, 12 mana, 62 dmg), Flame Blade (Q, 26 mana, +80% combo dmg, +1.2m reach), Meteor (R, 70 mana, 320 AoE dmg).")
    add_bullet("Skin 1 - Omega Knight (omega): ", "Asset assets/provided/omega.glb, 35-clip retargeted library assets/motion/omega_combat.res, Lightning element (#81deff). Arc Bolt (Right-Click, 12 mana, 68 hitscan dmg), Storm Blade (Q, 26 mana, +80% combo dmg, +1.2m reach with electric arcs), Thunderstorm (R, 70 mana, 240 dmg to all visible foes within 85m).")
    add_bullet("Skin Switching: ", "Handled via player.visual.set_skin(index) in character_visual.gd, called from Lobby 'Characters' tab. Frees old model, instantiates new GLB via asset_catalog.gd, caches rig, loads motion library, and re-equips sword.")
    add_bullet("The 1 Sword Setup: ", "Asset assets/provided/sword.glb (Steampunk Da Vinci Sword). Equipped in character_visual.gd -> equip_sword(), derives palm matrix from finger knuckles (_calibrate_grip()), positions grip in palm, and sets MagicOrigin marker for spell casts.")

    add_h2("Complete Verbatim Code of player.gd")
    doc.add_paragraph("Below is the complete 828-line player controller code verbatim from player.gd:")
    add_code_block(player_code)

    # Section 3
    add_h1("3. ANIMATION SYSTEM")
    add_h2("Animation Architecture")
    add_bullet("Player Engine: ", "Strictly uses AnimationPlayer created in code with ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, advanced manually via animator.advance(delta).")
    add_bullet("Tree / Sprites: ", "Does NOT use AnimationTree and does NOT use AnimatedSprite.")
    add_bullet("Transitions & Blending: ", "Custom GDScript engine in provided_visual.gd. Cross-fades with 0.16s blend (0.055s forced). Preserves normalized cycle phase across walk/jog/sprint to eliminate foot-pops. Dynamically overlays running leg motion under swinging/casting upper bodies. Two-bone analytical IK plants soles flat.")

    add_h2("Complete List of Animation Clips")
    add_bullet("Player Locomotion: ", "Idle_Loop, Sword_Idle_Loop, Pistol_Idle_Loop, Walk_Loop, Jog_Fwd_Loop, Sprint_Loop, Crouch_Idle_Loop, Crouch_Fwd_Loop, Jump_Start, Jump_Loop, Jump_Fall, Double_Jump, Jump_Land, Roll, Dance_Loop.")
    add_bullet("Player Combat: ", "Sword_Attack (slash 1), Sword_Attack02 (slash 2), Sword_Attack03 (overhead slash 3), Punch_Jab, Fire_Cast (thrust cast), Cast (overhead raise), Channel_Loop, Cast_Release, Hit_Chest, Death01.")
    add_bullet("Enemy Loadout Action Clips: ", "Blade_Right_Slash, Blade_Right_Return, Blade_Left_Slash, Blade_Left_Return, Blade_Overhead, Dual_Blade_Cross, Axe_Chop, Axe_Backhand, Staff_Sweep, Staff_Thrust, Scythe_Reap, Scythe_Return, Rifle_Butt, Rifle_Aim_Shot.")
    add_bullet("11 Elemental Attack Cues: ", "Stone_Slam (F1), Water_Sweep (F2), Fire_Combo (F3), Soul_Channel (F4), Lightning_Lunge (F5), Wind_Cyclone (F6), Poison_Cast (F7), Ice_Cleave (F8), Gravity_Pulse (F9), Lava_Crash (F10), Void_Reap (F11).")

    add_h2("3D Model Formats & Import Pipeline")
    add_bullet("Blender (.blend): ", "art/hollow_spire/hollow_spire.blend (exterior cathedral).")
    add_bullet("glTF (.glb): ", "female.glb, omega.glb, sword.glb, subboss_1.glb to subboss_9.glb, grand_boss.glb, main_boss.glb, soldier_1.glb to soldier_9.glb, grand_soldier.glb, hollow_spire.glb, AnimationLibrary_Godot_Standard.glb.")
    add_bullet("Import Pipeline: ", "retarget_combat_motion.gd maps standard CC0 motions to rigs; player_motion_authoring.gd synthesizes martial attacks; build_sculpt_rigs.gd proceduralizes 17-bone armatures for sculpts (.scn files in assets/sculpt_motion/).")

    # Section 4
    add_h1("4. ENEMIES, BOSSES & WORLD")
    add_h2("Structure of the 11 Soldiers and 11 Bosses")
    add_bullet("Core Controller: ", "All 11 bosses and soldiers run on scripts/enemy.gd (CharacterBody3D, Layer 4, Mask 7). scripts/boss.gd extends enemy.gd setting is_boss = true.")
    add_bullet("AI & Combat Mechanics: ", "A* planar grid navigation, neighbor avoidance, raycast line-of-sight, 43m court leash with invulnerability ward when player flees, telegraph animations and readable ground hazard projections.")
    add_bullet("Boss Phases: ", "Phase 2 (Awakening) triggers at <55% HP (increased speed and expanded patterns). Floor 11 boss Nox triggers Phase 3 (Final Eclipse) at <30% HP (four jumping shockwaves).")

    # Table of 11 bosses
    table = doc.add_table(rows=1, cols=7)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    hdr = table.rows[0].cells
    headers = ["Floor", "Guardian", "HP", "Soldier Retinue", "Count", "Element", "Held Weapon"]
    for i, h in enumerate(headers):
        hdr[i].text = h
        set_cell_background(hdr[i], "1F4E79")
        p = hdr[i].paragraphs[0]
        p.runs[0].font.bold = True
        p.runs[0].font.color.rgb = RGBColor(255, 255, 255)
        p.runs[0].font.size = Pt(8.5)

    data = [
        ("I", "Stelae Sentinel (subboss_1)", "640", "Skeleton Lord (soldier_1)", "4", "Stone", "Blade"),
        ("II", "Vesper, Tidal Paladin (subboss_2)", "740", "Corrupted Priest (soldier_2)", "4", "Water", "Blade / Fists"),
        ("III", "Pyre, Ember Lord (subboss_3)", "850", "Blood Priest (soldier_3)", "5", "Fire", "Fists / Claws"),
        ("IV", "Morvane, Soul Shepherd (subboss_4)", "880", "Ash-Grey Cultist (soldier_4)", "5", "Soul", "Staff"),
        ("V", "Stormbound Knight (subboss_5)", "960", "Corrupted Monk (soldier_5)", "5", "Thunder", "Blade"),
        ("VI", "Gale Headsman (subboss_6)", "1080", "Shadow Monk (soldier_6)", "6", "Wind", "Axe"),
        ("VII", "Pestilent Praetor (subboss_7)", "1120", "Plague Assassin (soldier_7)", "6", "Blight", "Rifle"),
        ("VIII", "Frostblade (subboss_8)", "1260", "Desert Nomad (soldier_8)", "6", "Frost", "Broken Sword"),
        ("IX", "Six-Winged Judge (subboss_9)", "1500", "Executioner Angel (soldier_9)", "7", "Gravity", "Blade / Axe"),
        ("X", "Azrael, Molten Sun (grand_boss)", "2000", "Obsidian Warden (grand_soldier)", "7", "Lava", "Dual Blades"),
        ("XI", "Nox, Last Reaper (main_boss)", "2900", "Obsidian Warden (grand_soldier)", "7", "Void", "Scythe"),
    ]
    for row in data:
        r_cells = table.add_row().cells
        for col_idx, text in enumerate(row):
            r_cells[col_idx].text = text
            p = r_cells[col_idx].paragraphs[0]
            p.runs[0].font.size = Pt(8)

    add_h2("Structure of the World & Map Scenes")
    add_bullet("Courtyard & Exterior (scripts/story_world.gd): ", "460m x 500m walled estate, Hollow Spire fortress model (hollow_spire.glb), spire_grounds.gdshader terrain, Elder Orin NPC, sick villagers, and entrance portal.")
    add_bullet("Cathedral Interior (scripts/tower_arena.gd & tower_layout.gd): ", "11 storeys stacked vertically (18m per floor, total 198m). Each floor has a 220m x 520m central hall plus five side exploration chambers (four 80x100m, one 100x100m).")
    add_bullet("Staircases & Gates: ", "Physical two-flight stairs on eastern wall (36 steps, 0.25m rise, 0.55m run, 6m width). Blocked by stone gates requiring both Floor Key discovery and Guardian defeat to unlock.")
    add_bullet("Floor Culling: ", "Batched per floor; update_floor_visibility() renders only current floor +/- 1.")
    add_bullet("Terrace (Roof at 198m): ", "Open terrace housing Moonwell Elixir potion bottle and exit threshold.")

    # Section 5
    add_h1("5. UI, TEXTS & STORY")
    add_h2("Existing UI Scenes & Scripts")
    add_bullet("Lobby Menu (scripts/lobby.gd): ", "Enter World, Characters preview/switch, The Eleven field manual, Settings (3D render scale, sensitivity, volume, camera shake), Credits.")
    add_bullet("In-Game HUD (scripts/hud.gd): ", "Vitality (200 HP) and Mana (100 MP) gauges, boss health bars, announcement banners, score/coins/XP, controls hints.")
    add_bullet("Story HUD (scripts/story_hud.gd): ", "Elder Orin dialogue overlay with typewriter text, objective tracking.")
    add_bullet("Story Journal (scripts/story_journal.gd - J key): ", "Tab 1: Mara's 11 recovered blue-copper Echoes. Tab 2: Deductions / Mysteries puzzle interface.")
    add_bullet("Hero Growth (scripts/player_growth.gd - U key): ", "XP spending on Heal (30 XP), Mana (25 XP), Power (+10% dmg), Health (+20 HP), Magic (+10 MP), and Hero Level.")
    add_bullet("Touch Controls (scripts/touch_controls.gd): ", "Virtual movement stick and 8 action buttons.")

    add_h2("Text & Documentation Files")
    add_bullet("README.md: ", "Complete gameplay, controls, guardian list, progression, and packaging guide.")
    add_bullet("PLATFORMS.md: ", "Build presets and notes for Windows, Android, and Web.")
    add_bullet("CREDITS.md & ATTRIBUTION.md: ", "Full third-party asset licensing and author links.")
    add_bullet("assets/provided/source_manifest.json: ", "Machine-readable provenance manifest of 3D meshes.")

    add_h2("Lore, Narrative & Endings ('The Borrowed Dawn')")
    add_bullet("Setting: ", "Greywake and the Hollow Spire. Orin used the Moonwell to heal his daughter Mara with the command 'Continue the healing until no one suffers.' The machine consumed living memories to make medicine, turning guardians into corrupted wardens and Nox into a trapped prisoner.")
    add_bullet("11 Memory Echoes: ", "Reveals the door was opened from inside as a refuge, passenger lists of sick villagers, stolen memories, Nox's original selfless oath, and the truth of Orin's contract.")
    add_bullet("3 Mysteries: ", "A Siege Without an Army (refuge, not invasion), The Choir With No Graves (living memories burned), The Prisoner on the Throne (Nox trapped by Orin's order).")
    add_bullet("Branching Endings: ", "Standard Ending ('Dawn Restored'): Elixir heals bodies, but Mara remains an amnesiac stranger. True Ending ('The Names We Carry'): Finding all echoes and solving mysteries allows Orin to confess, speak the villagers' names over the Moonwell water, and restore Mara's memories.")

    doc.save("HERO_Game_Architecture_Report.docx")
    print("Generated HERO_Game_Architecture_Report.docx")

if __name__ == "__main__":
    create_reports()
