# Shooter asset pipeline workspace

This folder is an archive and review workflow for preparing selected 3D assets for external animation with Argon. It is intentionally isolated from live runtime paths. The `.gdignore` marker keeps Godot from scanning/importing these archived copies. Do not remove it unless you intentionally want Godot to import the archive.

## Folder purposes

- `originals/characters/`: preserved playable character source GLBs.
- `originals/bosses/`: preserved boss and sub-boss source GLBs.
- `originals/soldiers/`: preserved soldier source GLBs.
- `originals/weapons/`: preserved weapon source GLBs.
- `originals/environments/`: preserved environment GLBs and Blender source.
- `originals/textures/<asset-id>/`: preserved standalone texture image files. Subfolder names follow filename prefixes only; exact model/material association is unverified unless separately confirmed.
- `originals/licenses_and_manifests/`: source attribution, asset provenance, credits, and license files.
- `originals/source_inventory.csv`: source path, archived path, file extension, byte size, SHA-256, and association notes for each copy made in this workspace.
- `argon_queue/ready_to_send/`: only the specific files prepared for the next Argon request. It is empty initially; do not bulk-fill it.
- `argon_queue/sent_originals/`: exact copies of assets actually sent, kept per asset with the matching textures and notes. Create an asset subfolder only when preparing a real submission.
- `argon_queue/asset_manifest.template.json`: copy and fill for each asset. Leave unknown Argon fields blank; do not invent job IDs, versions, or animation names.
- `argon_returns/unreviewed/`: all returned files start here. Never replace the originals with a return.
- `argon_returns/return_manifest.template.json`: record received files and pending identity, rig, texture, animation, and import reviews.
- `approved/animations/`: animation files that passed review and are approved for Godot use.
- `approved/characters/`: approved character files, if a returned character file is accepted.
- `approved/textures_and_materials/`: reviewed returned or adjusted textures/materials.
- `approved/manifests/`: completed provenance and approval records; includes `approval_manifest.template.json`.
- `godot_staging/import_candidates/`: isolated candidates for a later Godot import check.
- `godot_staging/tested/`: candidates that passed a documented Godot import and visual/runtime check.
- `godot_staging/rejected/`: candidates that failed review, with a note explaining why. Keep originals and rejected returns for traceability.

## Safe workflow

1. Choose one asset. Start from its preserved copy under `originals/`; do not edit that copy.
2. Copy only the selected GLB and verified/needed texture files into `argon_queue/ready_to_send/`. Fill a copy of `asset_manifest.template.json`. If a texture association is uncertain, label it unverified and do not silently treat it as part of the model.
3. Before sending, duplicate the exact submission into a new `argon_queue/sent_originals/<asset-id>/` folder. Keep the submitted filename unchanged, include the textures sent and a notes/manifest file, and record the source SHA-256.
4. Put every returned file into `argon_returns/unreviewed/` first. Record its original asset ID and returned file checksum. Keep it separate from originals and live project assets.
5. Review asset identity, skeleton hierarchy/rest pose, scale/orientation, weights, materials/textures, animation clip names, and Godot compatibility. Unknown results stay pending.
6. Only after those reviews pass, copy the approved files and completed provenance record into the matching `approved/` folders. Do not overwrite an original.
7. Copy candidates into `godot_staging/import_candidates/` for a later isolated import test. Move/copy them to `tested/` only after recording the Godot version, import result, clip list, and visual/runtime result. Use `rejected/` for failed candidates and record the reason.
8. Integrate an approved asset into live gameplay only in a later, separately reviewed task. Do not change runtime paths as part of this archive workflow.

## Texture and model evidence

The project GLBs inspected for this workspace contain embedded images with no external image URIs. The neighboring `*_Image_*.png`/`.jpg` files are preserved under `originals/textures/<asset-id>/`, grouped by filename prefix, but their exact association to a given model/material has not been verified. The Hollow Spire GLB also embeds images; loose building maps are preserved with association noted as unverified. `source_inventory.csv` records these limits. The GLB files themselves remain authoritative source copies.

## Pilot recommendation

Recommended first test asset: `subboss_1` from `originals/bosses/subboss_1.glb` (original project path: `assets/provided/subboss_1.glb`). The project provenance manifest identifies its source as `stelae_knight.glb` and records it as rigged; inspection of the GLB container found skeleton joint groups of 2 and 24 joints, one existing animation, six embedded images, two meshes, and about 20,060 source triangles. It is a substantially smaller and simpler test than `subboss_7` (142 joints, 90 embedded images, 23 meshes, about 127,594 triangles) and less entangled with the playable-character animation pipeline than `female.glb` or `omega.glb`. `subboss_1` is still used by the runtime and already has sculpted/animation resources and a sword loadout, so test any Argon return only in isolation. Argon compatibility has not been tested; this is a recommendation, not an assertion of compatibility. No Argon job has been started and `ready_to_send/` is intentionally empty.
