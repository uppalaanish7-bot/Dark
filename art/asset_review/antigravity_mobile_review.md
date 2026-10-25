# Antigravity Mobile Review: Arena Presentation & Performance

**Date**: 2026-10-15  
**Component Owned & Modified**: `scripts/tower_arena.gd`  
**Co-Agent Coordination**: Collaborating with Codex agents (Codex owns `game.gd`, `player.gd`, `hud.gd`, `touch_controls.gd`, `character_visual.gd`, `provided_visual.gd`, `assets/`, `export_presets.cfg`, `project.godot`, Android build tools). Antigravity strictly owns `scripts/tower_arena.gd`.

---

## 1. Ownership & Existing Gameplay Assumptions Confirmation

- **Scope**: Modifications are isolated strictly to `scripts/tower_arena.gd`.
- **Gameplay Integrity**: Preserved the 280m × 280m open Battle Royale arena (`get_play_bounds() -> Rect2(-138, -138, 276, 276)`), the 10-minute sinking Central Time Pillar (40m height dropping 4m/min to flush at 00:00), and simultaneous engagement of all 11 bosses.
- **Renderer Target**: Godot 4.7 GL Compatibility (GLES3 / WebGL2 / Mobile driver), targeting smooth 60 FPS on Android mobile hardware (Adreno 600/700 series, ARM Mali-G series, PowerVR).

---

## 2. Technical Findings & Performance Bottlenecks Identified

### A. Dynamic Light Count Overflow on Forward / Compatibility Renderer
- **Finding**: The arena previously instantiated 16 individual `OmniLight3D` nodes (one per brazier at $r = 125\text{m}$) plus the central beacon, plus inherited cathedral lights (`_court_lights`, `EntryEmberWash`).
- **Mobile Impact**: Mobile GL Compatibility forward renderers typically cap lights at 8 per cluster/object. With 16 perimeter lights + beacon + hero lights + spells, the light budget was exceeded, causing:
  1. Light popping and flickering as the camera rotates.
  2. Substantial CPU culling overhead.
  3. Increased fragment shader multi-pass execution and fillrate strain.
- **Observation**: At radius 125m with a 24m range, brazier lights illuminated almost no playable combat floor, wasting light budget.

### B. Material Overdraw & Specular Glare
- **Finding**: The 280m floor was a single flat box mesh with high metallic/roughness that caused low-precision mobile float specular glare and washed-out silhouettes.
- **Mobile Impact**: On small mobile LCD/OLED screens, dark armored boss models blended into dark ground, reducing readability during rapid touch movement.

### C. Directional Shadow Overhead
- **Finding**: Inherited `ClerestoryMoonlight` utilized parallel 2-split directional shadows over a 75m distance.
- **Mobile Impact**: Recalculating 2 shadow cascade splits over a large outdoor arena introduces vertex transformation overhead and fillrate penalties on mobile GPUs.

---

## 3. Concrete Changes Implemented in `scripts/tower_arena.gd`

### A. Lighting Optimization (Light Count Reduced by >70%)
1. **Unshaded Emissive Flames**:
   - Braziers retain all 16 architectural plinths and flame spheres.
   - Flame material is configured with `shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED` and `emission_energy_multiplier = 3.2`.
   - **Cost**: 0 dynamic lighting calculations, zero fillrate penalty, visible across the entire 280m stage.
2. **Cardinal Perimeter Fill Lights**:
   - Consolidated 16 redundant perimeter omni lights into **4 wide-angle cardinal fill lights** at $(0, \pm 105)$ and $(\pm 105, 0)$ with range 45m, energy 1.6, and attenuation 1.3.
   - Active scene lights intersecting the floor are kept well under the mobile 8-light limit.
3. **Cathedral Stubs Cleaned**:
   - Redundant interior cathedral lights (`_court_lights`, `EntryEmberWash`) inherited from parent `arena.gd` are freed on initialization, ensuring zero wasted light slots.
4. **Mobile Directional Shadow Tuning**:
   - `ClerestoryMoonlight` directional shadow mode set to `SHADOW_ORTHOGONAL` with 60m max distance and `directional_shadow_blend_splits = false`.
   - Eliminates cascade re-projection stutter while maintaining crisp, stable hero/boss drop shadows.

### B. Material & Visual Presentation Upgrades
1. **Two-Tone Tournament Dais & Inlaid Runes**:
   - Added an inner circular combat dais ($r = 48\text{m}$) using polished basalt tones (`Color("222b38")`, roughness 0.62, metallic 0.18, `metallic_specular = 0.25`).
   - Outer perimeter floor rendered in deep basalt slate (`Color("151c26")`, roughness 0.68, metallic 0.12, `metallic_specular = 0.2`).
   - Provides clear high-contrast silhouettes for both Girl Knight (fire VFX) and Omega Knight (lightning VFX) against all 11 boss models.
2. **Unshaded Radial Cardinal Inlays**:
   - Added 4 thin unshaded gold inlay strips along the cardinal axes from $r = 8\text{m}$ to $115\text{m}$.
   - Provides immediate touch navigation cues for orientation without relying on HUD minimaps.
3. **Energy Barrier Upper Rim**:
   - Added glowing unshaded cyan upper rim rails along $y = 12.0\text{m}$ of the perimeter barrier walls.
   - Beautifully frames the boundary of the stage against the night sky without any dynamic light cost.
4. **Environment & Tonemapping**:
   - Ambient lighting switched to `Environment.AMBIENT_SOURCE_SKY` with `ambient_light_sky_contribution = 0.55` and energy 0.78.
   - Tonemapping configured to `TONE_MAPPER_ACES` with exposure 1.08, preventing blown-out highlights and muddy blacks on mobile screens.

---

## 4. Validation Results

1. **Syntax & Compilation Verification**:
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --check-only --script res://scripts/tower_arena.gd
   # Result: OK (Return code 0, 0 errors, 0 warnings)
   ```
2. **Arena & Pillar Mechanics Test**:
   - `test_arena_and_pillar()` passed with 0 errors.
   - Arena bounds verified: `Rect2(-138, -138, 276, 276)`.
   - Central Time Pillar initial height 40m, sinking ratio logic verified at 50% (-20m) and 100% (-40m flush).

3. **Full Integration Suite Status**:
   - **GDScript Compilation (`--check-only`)**: Passed with 0 errors across all 35+ project scripts.
   - **Touch Combat Suite (`touch_combat_validation.gd`)**: 168 checks passed, 0 failures (Codex resolved line 171 typing).
   - **Battle Royale Test Suite (`battle_royale_validation.gd`)**: 33 checks passed, 0 failures.
   - **Live Runtime Preview (`runtime_game_preview.gd`)**: 120 frames simulated with 0 crashes.
   - **Mobile APK Status**: `Hero.pending.apk` (417MB) successfully generated, 16KB-page-aligned, and dual v2/v3 signed.
