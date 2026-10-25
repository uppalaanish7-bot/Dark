"""Offline experimental anatomical rigs; never overwrites runtime derivatives.

These dense sculpt meshes did not pass automatic weighting/pose review. Exports
are kept outside the game and must pass a full deformation review before use.
"""
from pathlib import Path
import bpy
import math
import json
import shutil
from mathutils import Matrix, Vector

ROOT=Path(__file__).resolve().parents[1]
BACKUP=ROOT/'backups/pre-authored-animation'
BACKUP.mkdir(parents=True,exist_ok=True)
IDS=['subboss_2','subboss_3','subboss_6','subboss_8','main_boss','grand_soldier']
SIDE={'subboss_2','subboss_6','subboss_8','main_boss'}

def rig_model(identity):
    runtime=ROOT/'assets/provided'/f'{identity}.glb'
    archive=BACKUP/runtime.name
    if not archive.exists(): shutil.copy2(runtime,archive)
    experiment=ROOT/'art/asset_review/experimental_rigs'
    experiment.mkdir(parents=True,exist_ok=True)
    path=experiment/runtime.name
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(archive))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    canonical=Matrix.Rotation(-math.pi/2,4,'Z') if identity in SIDE else Matrix.Identity(4)
    for obj in meshes:
        world=canonical @ obj.matrix_world
        obj.parent=None;obj.matrix_world=Matrix.Identity(4)
        obj.data.transform(world)
    data=bpy.data.armatures.new('CourtCombatRig')
    rig=bpy.data.objects.new('CourtCombatRig',data);bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    specs=[('root',(0,0,0),(0,0,.2),None),('pelvis',(0,0,1.03),(0,0,1.19),'root'),
           ('spine_01',(0,0,1.19),(0,0,1.50),'pelvis'),('spine_03',(0,0,1.50),(0,0,1.70),'spine_01'),
           ('neck',(0,0,1.70),(0,0,1.80),'spine_03'),('head',(0,0,1.80),(0,0,2.06),'neck'),
           ('cape',(0,.13,1.59),(0,.17,.75),'spine_03')]
    for side,sign in [('l',1),('r',-1)]:
        specs += [('upperarm_'+side,(sign*.28,0,1.59),(sign*.40,-.01,1.32),'spine_03'),
                  ('lowerarm_'+side,(sign*.40,-.01,1.32),(sign*.47,-.045,1.04),'upperarm_'+side),
                  ('hand_'+side,(sign*.47,-.045,1.04),(sign*.47,-.09,.91),'lowerarm_'+side),
                  ('thigh_'+side,(sign*.16,0,1.03),(sign*.19,0,.57),'pelvis'),
                  ('calf_'+side,(sign*.19,0,.57),(sign*.22,0,.12),'thigh_'+side),
                  ('foot_'+side,(sign*.22,0,.12),(sign*.22,-.17,.045),'calf_'+side)]
    for name,head,tail,parent in specs:
        bone=data.edit_bones.new(name);bone.head=head;bone.tail=tail
        if parent: bone.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    segments={n:(Vector(a),Vector(b)) for n,a,b,_ in specs}
    robe=identity in {'main_boss','grand_soldier'}
    counts={}
    for obj in meshes:
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True);rig.select_set(True)
        bpy.context.view_layer.objects.active=rig
        bpy.ops.object.parent_set(type='ARMATURE_AUTO')
        unweighted=sum(not any(g.weight>0.0001 for g in v.groups) for v in obj.data.vertices)
        if unweighted:
            raise RuntimeError(f'{identity}: bone heat left {unweighted} vertices unweighted; rejected without export')
        counts[obj.name]=len(obj.data.vertices)
    # Preserve the source facing used by the runtime per-model orientation map.
    rig.matrix_world=canonical.inverted()
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,
        export_animations=False,export_cameras=False,export_lights=False)
    report={'id':identity,'bones':len(specs),'weighted_vertices':sum(counts.values()),'regions':counts,
            'previous_runtime':str(archive.relative_to(ROOT)),'source_geometry_preserved':True}
    (ROOT/'art/asset_review'/f'{identity}_rig.json').write_text(json.dumps(report,indent=2))
    print('COURT_RIG_READY',identity,counts,flush=True)

if __name__=='__main__':
    import sys
    for identity in (sys.argv[1:] or IDS): rig_model(identity)
