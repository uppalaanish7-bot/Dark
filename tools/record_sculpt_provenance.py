"""Record additional rig derivatives without changing source model provenance."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
path = root / "assets/provided/source_manifest.json"
data = json.loads(path.read_text(encoding="utf-8"))
rigs = json.loads((root / "art/asset_review/sculpt_rigs.json").read_text())
data["sculpt_motion"] = []
for rig in rigs:
    derived = f"assets/sculpt_motion/{rig['id']}.scn"
    data["sculpt_motion"].append({**rig, "derived": derived,
        "source_derivative": f"assets/provided/{rig['id']}.glb",
        "sha256": hashlib.sha256((root / derived).read_bytes()).hexdigest(),
        "modifications": f"{rig['bones']}-bone fitted region-weighted skin; preserved primary UVs and source materials; corrected facing; joint, equipment and cloth weights; procedural stride, articulated attacks and death poses."})
data["rest_binding_repairs"] = []
for identity, changes in [
    ("female", "Reassigned stray skirt vertices from arm bones to pelvis/cape; source geometry and materials retained."),
    ("subboss_1", "Corrected body rest-space grounding and source sword hand attachment; source mesh and materials retained."),
]:
    derived = f"assets/sculpt_motion/{identity}.scn"
    data["rest_binding_repairs"].append({"id": identity, "derived": derived,
        "source_derivative": f"assets/provided/{identity}.glb",
        "sha256": hashlib.sha256((root / derived).read_bytes()).hexdigest(),
        "generator": "tools/repair_character_bindings.gd", "modifications": changes})
motion = data["motion"]["retargeted_assets"]
if not any(item["id"] == "subboss_1" for item in motion):
    motion.append({"id": "subboss_1", "library": "assets/motion/subboss_1_combat.res", "clips": 35})
for item in motion:
    item["sha256"] = hashlib.sha256((root / item["library"]).read_bytes()).hexdigest()
data["notes"][2] = "Both player forms, subboss_1, subboss_7 and soldier_1 have retargeted motion. Eighteen additional enemy derivatives have 17-bone fitted rigs with procedural locomotion and combat poses. Girl Knight and Stelae also have rest/binding repair derivatives. Soldier_1 and subboss_7 retain their source sword/rifle via runtime hand attachments in scripts/enemy_loadout.gd. Original GLBs remain preserved."
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(f"Recorded {len(rigs)} sculpt rigs and {len(motion)} animation libraries.")
