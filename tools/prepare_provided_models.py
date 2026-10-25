"""Create game-ready derivatives; never write to the supplied Game Asserts files.

Run using the installed Blender Python runtime. Preserves source surface textures,
reduces expensive sculpt meshes, normalizes height/grounding, retains existing rigs.
"""
from pathlib import Path
import argparse
import json
import re
import sys
import time

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / "Game Asserts"
OUTPUT = ROOT / "assets" / "provided"
OUTPUT.mkdir(parents=True, exist_ok=True)


def identify(relative):
    s = relative.as_posix()
    if s.startswith("Character/"):
        return "female"
    if s.startswith("Boss/"):
        return "main_boss"
    if s.startswith("Boss Sub Guard/Guard solider/"):
        return "grand_soldier"
    if s.startswith("Boss Sub Guard/gurad/"):
        return "grand_boss"
    match = re.search(r"Copy \((\d+)\)/(BOSS|SLODIER)/", s)
    return ("subboss_" if match[2] == "BOSS" else "soldier_") + match[1]


def prepare(asset):
    source = Path(asset["source"])
    identity = identify(source.relative_to(SOURCE))
    destination = OUTPUT / (identity + ".glb")
    print("PREPARE", identity, source.name, flush=True)
    started = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    bone_shapes = {bone.custom_shape for obj in bpy.context.scene.objects if obj.type == "ARMATURE" for bone in obj.pose.bones if bone.custom_shape}
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj not in bone_shapes]
    for obj in bone_shapes:
        bpy.data.objects.remove(obj, do_unlink=True)
    before = sum(len(obj.data.polygons) for obj in meshes)
    rigged = any(obj.type == "ARMATURE" for obj in bpy.context.scene.objects)
    # glTF exports split these sculpts into index-limit chunks, not anatomical
    # parts. Weld their shared vertices before decimation; simplifying chunks
    # independently creates thousands of small cracks in capes and armor.
    if not rigged and len(meshes) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in meshes:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=0.00001)
        bpy.ops.object.mode_set(mode="OBJECT")
        meshes = [joined]
    # Preserve the actual provided shapes, UV loops and authored skins.
    budget = 65000 if identity.startswith("subboss") or identity in ("grand_boss", "main_boss") else 28000
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        if before > budget and not rigged:
            modifier = obj.modifiers.new("Realtime silhouette reduction", "DECIMATE")
            modifier.ratio = max(0.012, budget / before)
            modifier.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
        for poly in obj.data.polygons:
            poly.use_smooth = True
    # 1K soldier / 2K boss maps preserve texture identities with bounded VRAM.
    texture_limit = 1024 if identity.startswith("soldier") or identity == "grand_soldier" else 2048
    for image in bpy.data.images:
        if image.size[0] > texture_limit or image.size[1] > texture_limit:
            ratio = texture_limit / max(image.size)
            image.scale(max(1, round(image.size[0] * ratio)), max(1, round(image.size[1] * ratio)))
            image.pack()
    # glTF import is Z-up in Blender; export converts it back to Y-up.
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    height = hi.z - lo.z
    target_height = 1.82 if identity == "female" else 2.1
    factor = target_height / max(height, 0.01)
    offset = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    root = bpy.data.objects.new("Provided_" + identity, None)
    bpy.context.collection.objects.link(root)
    for obj in list(bpy.context.scene.objects):
        if obj != root and obj.parent is None:
            obj.parent = root
    root.location = offset * factor
    root.scale = (factor, factor, factor)
    bpy.ops.export_scene.gltf(filepath=str(destination), export_format="GLB", export_yup=True,
                              export_apply=False, export_animations=True, export_cameras=False,
                              export_lights=False, export_image_format="AUTO")
    result = {"id": identity, "source": str(source), "derived": str(destination.relative_to(ROOT)),
              "source_triangles": asset.get("triangles", before),
              "runtime_triangles": sum(len(obj.data.polygons) for obj in meshes),
              "rigged": rigged, "texture_limit": texture_limit,
              "seconds": round(time.time() - started, 2),
              "attribution": asset.get("asset_metadata", {}).get("extras", {})}
    print("COMPLETE", identity, result["runtime_triangles"], result["seconds"], flush=True)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", nargs="*")
    parser.add_argument("--skip-existing", action="store_true")
    args = parser.parse_args()
    inventory = json.loads((ROOT / "art/asset_review/provided_assets_inventory.json").read_text())
    records = []
    report = OUTPUT / "source_manifest.json"
    if report.exists():
        records = json.loads(report.read_text()).get("assets", [])
    for asset in inventory["assets"]:
        if not asset["container_valid"]:
            continue
        identity = identify(Path(asset["source"]).relative_to(SOURCE))
        if args.only and identity not in args.only:
            continue
        if args.skip_existing and (OUTPUT / (identity + ".glb")).exists():
            continue
        result = prepare(asset)
        sidecars = ROOT / "art" / "asset_review" / "runtime"
        sidecars.mkdir(parents=True, exist_ok=True)
        (sidecars / (identity + ".json")).write_text(json.dumps(result, indent=2), encoding="utf-8")
        if report.exists():
            records = json.loads(report.read_text()).get("assets", [])
        records = [record for record in records if record["id"] != identity] + [result]
        report.write_text(json.dumps({"assets": records}, indent=2), encoding="utf-8")
    print("PROVIDED_MODELS_READY", len(records), flush=True)


if __name__ == "__main__":
    main()
