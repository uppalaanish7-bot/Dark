"""Import the three replacement downloads explicitly supplied by the user."""
from pathlib import Path
import json
import math
import numpy as np
import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/provided'
REVIEW = ROOT / 'art/asset_review/player_previews'
REVIEW.mkdir(parents=True, exist_ok=True)
SOURCES = [('female', 'girl_knight.glb'), ('omega', 'omega_knight.glb'),
           ('sword', 'free__steampunk_da_vincis_sword_game-ready.glb')]

def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z','Y').to_euler()

def actual_points(meshes):
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    return [o.matrix_world @ v.co for src in meshes for o in [src.evaluated_get(deps)] for v in o.data.vertices]

def rig_girl(meshes):
    # Bind the provided low-poly sculpt to a deliberately small deformation rig.
    # Coordinates follow the original A-pose; faces, armor and UVs are untouched.
    for obj in meshes:
        matrix=obj.matrix_world.copy()
        obj.parent=None
        obj.matrix_world=Matrix.Identity(4)
        obj.data.transform(matrix)
    data=bpy.data.armatures.new('GirlKnightCombatRig')
    rig=bpy.data.objects.new('GirlKnightCombatRig',data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    specs=[('root',(0,0,0),(0,0,.2),None),('pelvis',(0,0,.9),(0,0,1.08),'root'),
           ('spine_01',(0,0,1.08),(0,0,1.4),'pelvis'),('neck',(0,0,1.4),(0,0,1.5),'spine_01'),
           ('head',(0,0,1.5),(0,0,1.79),'neck'),('cape',(0,.09,1.05),(0,.1,.3),'spine_01')]
    for side,sign in [('l',1),('r',-1)]:
        specs += [('upperarm_'+side,(sign*.21,0,1.4),(sign*.39,0,1.19),'spine_01'),
                  ('lowerarm_'+side,(sign*.39,0,1.19),(sign*.50,0,.99),'upperarm_'+side),
                  ('hand_'+side,(sign*.50,0,.99),(sign*.53,0,.90),'lowerarm_'+side),
                  ('thigh_'+side,(sign*.13,0,.91),(sign*.19,0,.51),'pelvis'),
                  ('calf_'+side,(sign*.19,0,.51),(sign*.25,0,.12),'thigh_'+side),
                  ('foot_'+side,(sign*.25,0,.12),(sign*.25,-.12,.045),'calf_'+side)]
    for name,head,tail,parent in specs:
        bone=data.edit_bones.new(name);bone.head=head;bone.tail=tail
        if parent: bone.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    segments={n:(Vector(a),Vector(b)) for n,a,b,_ in specs}
    for obj in meshes:
        groups={name:obj.vertex_groups.new(name=name) for name in segments}
        for vertex in obj.data.vertices:
            p=vertex.co; side='l' if p.x>=0 else 'r'
            if p.z>1.45: choices=['head','neck']
            elif abs(p.x)>.23 and p.z>.87: choices=['upperarm_'+side,'lowerarm_'+side,'hand_'+side]
            elif p.z<.98 and p.y>.12 and abs(p.x)<.29: choices=['cape']
            elif p.z<.93: choices=['thigh_'+side,'calf_'+side,'foot_'+side]
            else: choices=['pelvis','spine_01','neck']
            ranked=[]
            for name in choices:
                a,b=segments[name];d=b-a;t=max(0,min(1,(p-a).dot(d)/max(d.length_squared,1e-8)))
                ranked.append((1/max((p-(a+d*t)).length,.025)**4,name))
            ranked.sort(reverse=True);ranked=ranked[:2];total=sum(w for w,n in ranked)
            for w,name in ranked: groups[name].add([vertex.index],w/total,'REPLACE')
        modifier=obj.modifiers.new('Combat deformation','ARMATURE');modifier.object=rig
        obj.parent=rig
    return rig

def run(identity, filename):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source = Path.home() / 'Downloads' / filename
    bpy.ops.import_scene.gltf(filepath=str(source))
    bone_shapes={b.custom_shape for o in bpy.context.scene.objects if o.type=='ARMATURE' for b in o.pose.bones if b.custom_shape}
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o not in bone_shapes]
    for obj in bone_shapes: bpy.data.objects.remove(obj,do_unlink=True)
    for im in bpy.data.images:
        if max(im.size) > 2048:
            ratio = 2048 / max(im.size)
            im.scale(round(im.size[0]*ratio), round(im.size[1]*ratio))
            im.pack()
    # Girl knight is a side-facing OBJ sculpt; rotate its native front towards
    # Blender -Y / glTF +Z. Sword's long blade axis is initially +X.
    adjustment = Matrix.Identity(4)
    if identity == 'female': adjustment = Matrix.Rotation(-math.pi/2, 4, 'Z')
    if identity == 'sword':
        points=actual_points(meshes)
        array=np.array([tuple(p) for p in points]);cov=np.cov(array.T)
        vals,vecs=np.linalg.eigh(cov);long_axis=Vector(vecs[:,-1].tolist())
        if long_axis.x<0: long_axis=-long_axis
        adjustment=long_axis.rotation_difference(Vector((0,0,1))).to_matrix().to_4x4()
    for obj in list(bpy.context.scene.objects):
        if obj.parent is None: obj.matrix_world = adjustment @ obj.matrix_world
    bpy.context.view_layer.update()
    points=actual_points(meshes)
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    target=1.82 if identity!='sword' else 1.38
    factor=target/max(hi.z-lo.z,0.01)
    offset=Vector((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))
    if identity=='sword': offset.z -= (hi.z-lo.z)*0.16
    holder=bpy.data.objects.new('Provided_'+identity,None)
    bpy.context.collection.objects.link(holder)
    for obj in list(bpy.context.scene.objects):
        if obj!=holder and obj.parent is None: obj.parent=holder
    holder.scale=(factor,)*3
    holder.location=offset*factor
    bpy.context.view_layer.update()
    if identity=='female': rig_girl(meshes)
    # The Girl Knight author baked lighting into an emissive albedo. Preserve
    # that palette while restoring material response to the interior lights.
    if identity=='female':
        for material in bpy.data.materials:
            if material.use_nodes:
                for node in material.node_tree.nodes:
                    if node.type=='BSDF_PRINCIPLED':
                        node.inputs['Emission Strength'].default_value=0.15
                        node.inputs['Roughness'].default_value=0.6
    bpy.ops.export_scene.gltf(filepath=str(OUT/(identity+'.glb')),export_format='GLB',
        export_yup=True,export_animations=True,export_cameras=False,export_lights=False)
    report={'id':identity,'source':str(source),'derived':'assets/provided/'+identity+'.glb',
            'runtime_triangles':sum(len(o.data.polygons) for o in meshes),
            'rigged':any(o.type=='ARMATURE' for o in bpy.context.scene.objects),
            'native_dimensions':list(hi-lo)}
    (REVIEW/(identity+'.json')).write_text(json.dumps(report,indent=2))
    # Contact sheets make front/orientation/scale review repeatable.
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=8
    scene.cycles.use_denoising=True
    scene.render.resolution_x=500;scene.render.resolution_y=600;scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    if scene.world is None: scene.world=bpy.data.worlds.new('ReviewWorld')
    scene.world.color=(0.1,0.1,0.1)
    scene.view_settings.view_transform='AgX'
    for x,y,z,power,size in [(3,-4,6,650,5),(-4,-2,3,400,4),(1,3,4,700,3)]:
        data=bpy.data.lights.new('ReviewSoftbox','AREA');data.energy=power;data.shape='DISK';data.size=size
        light=bpy.data.objects.new('ReviewSoftbox',data);scene.collection.objects.link(light);light.location=(x,y,z);look_at(light,(0,0,0.9))
    data=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new('ReviewCamera',data);scene.collection.objects.link(cam);scene.camera=cam
    data.type='ORTHO';data.ortho_scale=2.25
    for name,location in [('front',(0,-4,1.05)),('back',(0,4,1.05))]:
        cam.location=location;look_at(cam,(0,0,0.9));scene.render.filepath=str(REVIEW/(identity+'_'+name+'.png'));bpy.ops.render.render(write_still=True)
    print('REPLACEMENT_READY',identity,flush=True)

if __name__=='__main__':
    for identity,filename in SOURCES: run(identity,filename)
