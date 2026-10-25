"""Conservative feather-only hinge rig, exported for offline visual review."""
from pathlib import Path
import bpy
import shutil
from mathutils import Matrix

ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'backups/pre-authored-animation/grand_boss.glb'
if not source.exists(): shutil.copy2(ROOT/'assets/provided/grand_boss.glb',source)
out=ROOT/'assets/provided/grand_boss_wing_review.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
for obj in meshes:
    world=obj.matrix_world.copy();obj.parent=None;obj.matrix_world=Matrix.Identity(4);obj.data.transform(world)
data=bpy.data.armatures.new('GrandWingRig')
rig=bpy.data.objects.new('GrandWingRig',data);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
root=data.edit_bones.new('wing_body');root.head=(0,0,0);root.tail=(0,0,1)
for name,sign in [('wing_l',1),('wing_r',-1)]:
    bone=data.edit_bones.new(name);bone.head=(sign*.22,.06,1.57);bone.tail=(sign*.72,.06,1.71);bone.parent=root
bpy.ops.object.mode_set(mode='OBJECT')
def smooth(a,b,value):
    t=max(0,min(1,(value-a)/(b-a)));return t*t*(3-2*t)
for obj in meshes:
    groups={name:obj.vertex_groups.new(name=name) for name in ['wing_body','wing_l','wing_r']}
    affected=0
    for v in obj.data.vertices:
        p=v.co
        weight=smooth(.30,.54,abs(p.x))*smooth(1.30,1.62,p.z)
        groups['wing_body'].add([v.index],1-weight,'REPLACE')
        if weight>0.0001:
            groups['wing_l' if p.x>0 else 'wing_r'].add([v.index],weight,'REPLACE');affected+=1
    mod=obj.modifiers.new('Outer feather hinge','ARMATURE');mod.object=rig;obj.parent=rig
    print('FEATHERS_WEIGHTED',affected,'of',len(obj.data.vertices),flush=True)
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_animations=False,export_yup=True,export_lights=False,export_cameras=False)
print('WING_REVIEW_EXPORTED',out,flush=True)
