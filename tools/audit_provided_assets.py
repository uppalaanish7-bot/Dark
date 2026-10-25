"""Read-only GLB inventory; never edits or imports supplied files into the game."""
from pathlib import Path
import argparse
import hashlib
import json
import struct


def role_for(path):
    parts = path.parts
    if parts[0] == "Character":
        return "Player (female, user selected)"
    if parts[0] == "Boss":
        return "Main boss"
    if parts[0] == "Boss Sub Guard":
        return "Main boss guard"
    return "Sub-boss" if "BOSS" in parts else "Sub-boss soldier"


def inspect(path, source):
    size = path.stat().st_size
    record = {"source": str(path), "relative_path": path.relative_to(source).as_posix(),
              "role": role_for(path.relative_to(source)), "bytes": size, "errors": []}
    errors = record["errors"]
    with path.open("rb") as stream:
        header = stream.read(12)
        magic, version, declared = struct.unpack("<4sII", header)
        record.update(version=version, declared_bytes=declared)
        if magic != b"glTF" or version != 2:
            errors.append("Not a GLB 2.0 header")
        if size != declared:
            errors.append(f"Header length {declared:,} differs from actual {size:,}")
        document, binary_start, binary_size = None, None, 0
        if errors:
            stream.seek(0)
            prefix = stream.read(2 * 1024 * 1024)
            record["header_hex"] = prefix[:24].hex()
            record["utf8_replacement_sequences_in_first_2mib"] = prefix.count(b"\xef\xbf\xbd")
            marker = prefix.find(b"JSON{")
            if marker >= 0:
                try:
                    document, _ = json.JSONDecoder().raw_decode(prefix[marker + 4:].decode("utf-8", "replace"))
                    record["metadata_salvaged_only"] = True
                except ValueError:
                    pass
        else:
            cursor = 12
            while cursor < size:
                stream.seek(cursor)
                raw = stream.read(8)
                if len(raw) != 8:
                    errors.append("Truncated chunk header")
                    break
                length, kind = struct.unpack("<I4s", raw)
                if length % 4 or cursor + 8 + length > size:
                    errors.append("Misaligned or truncated GLB chunk")
                    break
                if kind == b"JSON":
                    try:
                        document = json.loads(stream.read(length))
                    except ValueError as exc:
                        errors.append("Invalid JSON: " + str(exc))
                elif kind == b"BIN\x00":
                    binary_start, binary_size = cursor + 8, length
                cursor += 8 + length
        if document is not None:
            nodes = document.get("nodes", [])
            accessors = document.get("accessors", [])
            views = document.get("bufferViews", [])
            record["asset_metadata"] = document.get("asset", {})
            record["extensions_required"] = document.get("extensionsRequired", [])
            record["meshes"] = len(document.get("meshes", []))
            primitives = [p for m in document.get("meshes", []) for p in m.get("primitives", [])]
            record["primitives"] = len(primitives)
            record["triangles"] = sum(accessors[p.get("indices", p["attributes"]["POSITION"])]["count"] // 3
                                      for p in primitives if p.get("mode", 4) == 4)
            record["vertices"] = sum(accessors[p["attributes"]["POSITION"]]["count"] for p in primitives)
            record["skins"] = [{"name": sk.get("name", ""), "joints": len(sk.get("joints", [])),
                                "bone_names": [nodes[n].get("name", str(n)) for n in sk.get("joints", [])]}
                               for sk in document.get("skins", [])]
            record["animations"] = [{"name": a.get("name", ""), "channels": len(a.get("channels", [])),
                                     "duration_seconds": max([accessors[s["input"]].get("max", [0])[0]
                                                              for s in a.get("samplers", [])] or [0])}
                                    for a in document.get("animations", [])]
            record["materials"] = [m.get("name", "") for m in document.get("materials", [])]
            record["external_uris"] = [v["uri"] for k in ("buffers", "images") for v in document.get(k, [])
                                       if "uri" in v and not v["uri"].startswith("data:")]
            record["images"] = []
            if not record.get("metadata_salvaged_only"):
                for index, buffer in enumerate(document.get("buffers", [])):
                    if "uri" not in buffer and (index != 0 or binary_start is None or buffer["byteLength"] > binary_size):
                        errors.append(f"Buffer {index} exceeds embedded binary")
                for index, view in enumerate(views):
                    buffer_index = view.get("buffer", 0)
                    buffers = document.get("buffers", [])
                    if buffer_index >= len(buffers) or view.get("byteOffset", 0) + view["byteLength"] > buffers[buffer_index]["byteLength"]:
                        errors.append(f"Buffer view {index} exceeds its buffer")
                for uri in record["external_uris"]:
                    if not (path.parent / uri).is_file():
                        errors.append("Missing external dependency: " + uri)
            for im in document.get("images", []):
                info = {"name": im.get("name", ""), "mime": im.get("mimeType", ""), "embedded": "bufferView" in im}
                if "bufferView" in im and binary_start is not None:
                    view = views[im["bufferView"]]
                    stream.seek(binary_start + view.get("byteOffset", 0))
                    start = stream.read(min(32, view["byteLength"]))
                    if start[:8] == b"\x89PNG\r\n\x1a\n":
                        info["width"], info["height"] = struct.unpack(">II", start[16:24])
                    info["bytes"] = view["byteLength"]
                record["images"].append(info)
            record["metadata_document"] = document
        else:
            errors.append("No readable glTF JSON metadata")
    record["container_valid"] = not errors
    with path.open("rb") as stream:
        record["sha256"] = hashlib.file_digest(stream, "sha256").hexdigest()
    return record


def main():
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=project.parent / "Game Asserts")
    parser.add_argument("--output", type=Path, default=project / "art" / "asset_review")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    metadata = args.output / "metadata"
    metadata.mkdir(exist_ok=True)
    records = []
    for path in sorted(args.source.rglob("*.glb")):
        record = inspect(path, args.source)
        document = record.pop("metadata_document", None)
        if document is not None:
            (metadata / (path.stem + ".json")).write_text(json.dumps(document, indent=2), encoding="utf-8")
        records.append(record)
        print(f"{'VALID' if record['container_valid'] else 'INVALID'} | {record['relative_path']} | "
              f"{record.get('triangles', 0):,} triangles | {len(record.get('skins', []))} skins | "
              f"{len(record.get('animations', []))} clips", flush=True)
    result = {"source_root": str(args.source.resolve()), "files": len(records),
              "total_bytes": sum(r["bytes"] for r in records),
              "valid_containers": sum(r["container_valid"] for r in records), "assets": records}
    (args.output / "provided_assets_inventory.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"INVENTORY: {result['valid_containers']}/{len(records)} valid containers")


if __name__ == "__main__":
    main()
