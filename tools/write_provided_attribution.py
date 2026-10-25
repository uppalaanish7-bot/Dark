"""Consolidate provenance for imported derivatives and create UI portraits."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/provided'
manifest=json.loads((OUT/'source_manifest.json').read_text())
for sidecar in (ROOT/'art/asset_review/runtime').glob('*.json'):
    record=json.loads(sidecar.read_text())
    manifest['assets']=[a for a in manifest['assets'] if a['id']!=record['id']]+[record]
replacement=json.loads((ROOT/'art/asset_review/replacement_player_inventory.json').read_text())['assets']
inventory=json.loads((ROOT/'art/asset_review/provided_assets_inventory.json').read_text())['assets']
originals={entry['source']:entry for entry in inventory+replacement}
for identity,source in zip(['female','omega','sword'],replacement):
    runtime=json.loads((ROOT/f'art/asset_review/player_previews/{identity}.json').read_text())
    runtime.update(source_triangles=source['triangles'],attribution=source['asset_metadata']['extras'],
                   source_sha256=source['sha256'],source_container_valid=True)
    runtime['modifications']={'female':'Original mesh and textures preserved; normalized orientation and height; custom 18-bone combat deformation rig added.',
       'omega':'Original 167-bone rig, mesh and textures preserved; normalized height and origin; authored CC0 combat motions retargeted into the original rig.',
       'sword':'Original mesh and material textures preserved; texture resolution limited to 2048; aligned blade axis and grip origin; metallic/roughness adapted for the dark interior.'}[identity]
    manifest['assets']=[a for a in manifest['assets'] if a['id']!=identity]+[runtime]
for entry in manifest['assets']:
    path=ROOT/entry['derived']
    entry['runtime_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    if entry['source'] in originals:
        entry['source_sha256']=originals[entry['source']]['sha256']
        entry['source_container_valid']=originals[entry['source']]['container_valid']
    if 'modifications' not in entry:
        entry['modifications']='Normalized origin and height; textures resized to runtime budget; sculpt index chunks welded before decimation to preserve continuous surfaces and UV loops. Existing rigs preserved. Runtime root motion, spectral hover and combat poses added. Interior material adaptation reduces metallic response and disables incompatible second-UV normals.'
manifest['motion']={'source':'Godot/AnimationLibrary_Godot_Standard.glb','source_name':'Quaternius Universal Animation Library','license':'CC0-1.0','retargeted_assets':[]}
for identity in ['female','omega','subboss_7','soldier_1']:
    path=ROOT/f'assets/motion/{identity}_combat.res'
    if path.exists(): manifest['motion']['retargeted_assets'].append({'id':identity,'library':str(path.relative_to(ROOT)).replace('\\','/'),'clips':35,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
manifest['notes']=['Source originals were not modified.','The damaged Hornet file is not used. User-selected Girl Knight and Omega Knight replace it.',
    'Girl Knight, Omega Knight, subboss_7 and soldier_1 use authored retargeted skeletal animations. Most other enemies were supplied unrigged and use eleven distinct keyed elemental body motions, telegraphed attacks and VFX. Existing source rigs remain intact. Rejected experimental rig derivatives are excluded from the game.',
    'Materials and source UVs are preserved. Source files using separate normal-map UV sets may show small shading differences in Godot.']
(OUT/'source_manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf8')
lines=['# Provided model attribution','','The following runtime models are derivatives of files explicitly supplied by the user. Original source files are preserved outside the project. Their individual licenses are listed below; these models are not CC0.','','| Runtime ID | Model | Author | License | Source |','|---|---|---|---|---|']
for a in manifest['assets']:
    info=a.get('attribution',{})
    title=info.get('title',a['id']).replace('|',r'\|')
    lines.append(f"| `{a['id']}` | {title} | {info.get('author','See original asset')} | {info.get('license','See original asset')} | [Original]({info.get('source','')}) |")
lines += ['','## Changes made for this game','','Enemy derivatives are grounded and scaled to a consistent 2.1 m baseline. Expensive sculpt meshes are reduced to approximately 28,000 triangles for soldiers and 65,000 triangles for bosses (UV seams can increase the final count). Source rigs are preserved; high-resolution maps are reduced to 1K for soldiers and 2K for bosses. Godot can generate additional mesh LODs.','','Girl Knight uses the original supplied 3,596-triangle mesh and palette. An 18-bone deformation rig was added. Omega Knight retains the supplied 167-bone rig. Both use 35 authored retargeted clips from the Quaternius Universal Animation Library (CC0), with A-pose calibration, blended locomotion, sword-combo variations, casting, jump/roll poses, moving attack overlays and secondary cape motion. Both player models are grounded at 1.82 m. The supplied Da Vinci sword follows the animated hand, with indoor material adaptation and living fire VFX; there is no gun.','','The supplied rigs of subboss_7 and soldier_1 also use retargeted skeletal motion. Most other enemy models were supplied without rigs or animation clips. They use eleven distinct keyed elemental body-motion profiles with anticipation, contact and recovery, coordinated with combat mechanics and VFX. Heavy figures stay grounded; spectral casters hover. This does not claim that the static sculpts contain articulated skeletal attacks. Rejected automatic-rig experiments are excluded.','','The damaged Hornet download is excluded. The manifest records source, runtime and animation-library hashes for repeatability.','Source inventory and exact changes: [source_manifest.json](source_manifest.json)']
lines += ['', 'The grand boss has a three-bone feather hinge rig authored in Blender. Smooth weights isolate the outer wings while the original body, armor and twin swords keep their supplied shape. Wing extension follows the levitation windup and diving strike.']
(OUT/'ATTRIBUTION.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
ui=ROOT/'assets/ui';ui.mkdir(exist_ok=True)
for identity,name in [('female','girl_knight_portrait'),('omega','omega_knight_portrait')]:
    image=Image.open(ROOT/f'art/asset_review/player_previews/{identity}_front.png').convert('RGBA')
    box=image.getbbox()
    if box:
        x0,y0,x1,y1=box
        crop=image.crop((max(0,x0-15),max(0,y0-10),min(image.width,x1+15),min(image.height,y0+int((y1-y0)*.75))))
        factor=min(500/crop.width,500/crop.height)
        crop=crop.resize((round(crop.width*factor),round(crop.height*factor)),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(512,512),(0,0,0,0))
        canvas.alpha_composite(crop,((512-crop.width)//2,512-crop.height))
        canvas.save(ui/(name+'.png'))
print('ATTRIBUTION_READY',len(manifest['assets']),'PORTRAITS_READY')
