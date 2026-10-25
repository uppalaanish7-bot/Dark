# Hollow Spire — Blender building

The Hollow Spire is a monumental basalt fortress with ten architectural tiers, weathered masonry, heavy buttresses, carved recesses and sealed roofs. Its surrounding courtyard and glowing entrance retain the existing story and portal into the game's three arena levels. The model is an exterior with a short entrance vestibule; playable floor interiors have not been added.

- `hollow_spire.blend`: editable Blender 4.5 source with `Floor01` through `Floor10`, packed textures, a review camera and studio lights.
- `../../assets/buildings/hollow_spire.glb`: game asset with embedded PBR textures, 10 meshes, 39 material surfaces and 82,450 triangles.
- `textures/`: deterministic 2048 × 2048 basalt colour, normal and roughness textures, including darker stone and worn-edge colour variants. Textures repeat every eight metres.
- `hollow_spire_geometry_report.json`: generated bounds, mesh counts and ray checks for the vestibule, rear wall and central roof, including visible face winding.
- `previews/`: Godot captures of the actual story world. The preview script produces overview, low-angle, entrance, rear, roof, vestibule, gameplay and lobby views. The vestibule view temporarily hides the portal veil and rings to expose the stone walls, ceiling and solid rear wall.

The model measures **160 metres wide × 150 metres high × 80 metres deep** and faces Godot +Z. `scripts/story_world.gd` places it at `(0, 0, -50)` without scaling, giving world bounds `x = -80..80`, `y = 0..150`, `z = -90..-10`.

The entrance has **4.4 metres of width, 4.5 metres of height and six metres of depth**. Its local mouth is at `z = 40` and its solid rear wall is at `z = 34`, corresponding to the existing world threshold at `z = -10` and the vestibule rear at `z = -16`. The vestibule has a stone floor, inward-facing walls and ceiling. All five building materials are opaque stone; the translucent magical veil is a separate courtyard effect.

Native box collision shapes follow the main mass, entrance walls, floor and ceiling, buttresses, upper setback, bastion roofs and crown. The detailed masonry mesh remains visual geometry. The courtyard ground stops at the threshold to avoid overlapping the imported stone floor, and the existing portal still transfers Hero into the selected arena level.

From the project root, regenerate with Blender 4.5:

```powershell
blender --background --factory-startup --python tools/create_hollow_spire.py
```

For a Blender studio render, append `-- --render`. Alternatively, run `python tools/create_hollow_spire.py --render` in a Python 3.11 environment with Blender's official `bpy==4.5.3` package and NumPy. Generated swatch colours use linear values; baked colour textures are tagged sRGB, and roughness and normal maps use non-colour data. The generator validates geometry before saving the Blender file and exporting the GLB.

Reimport, check story integration, capture the building and rebuild the Windows package:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --import
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/story_tests.gd
Godot_v4.7.2-stable_win64_console.exe --path . --audio-driver Dummy --script tests/building_preview.gd
powershell -File tools/package_windows.ps1
```

The story tests inspect the actual imported dimensions and materials, entrance clearance, sealed vestibule and roof collisions, and walking through the portal. They also cover returning to the courtyard, the elixir quest and world saves. The rendered preview step requires a graphics display.

`art/.gdignore` excludes authoring files, source textures and previews from Godot exports. Earlier assets and scripts remain under `backups/building-reference-2026-10-04/` and `backups/stone-resume-2026-10-05/`. The Windows packaging command writes `build/Hero.exe` and its sidecar `Hero.pck`. Existing Android and web packages require separate rebuilds.
