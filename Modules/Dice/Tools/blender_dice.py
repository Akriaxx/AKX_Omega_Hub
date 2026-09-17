"""Rendu Blender des dés numérotés. Lancer en mode --background --python."""
import bpy,json,math,sys,argparse,time
from pathlib import Path
from mathutils import Vector,Matrix,Euler
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'Tools'))
from dice_motion import rolling, Landing, verify_roll, FullRoll
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
p=argparse.ArgumentParser();p.add_argument('--sides',type=int,default=20);p.add_argument('--preview',action='store_true');p.add_argument('--engine',default='BLENDER_WORKBENCH')
p.add_argument('--first-value',type=int,default=1);p.add_argument('--last-value',type=int);p.add_argument('--skip-roll',action='store_true');p.add_argument('--validate-only',action='store_true');p.add_argument('--roll-only',action='store_true');p.add_argument('--flight',action='store_true');p.add_argument('--batch',action='store_true');p.add_argument('--resume',action='store_true');opt=p.parse_args(args)
OUT=ROOT/'Media'/'Continuous';OUT.mkdir(parents=True,exist_ok=True)
ROLL_FRAMES=96;LAND_FRAMES=48
mesh=json.loads((ROOT/'Tools'/'solid_geometry.json').read_text())[str(opt.sides)]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.engine=opt.engine
scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=True
scene.display.shading.light='FLAT'
scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True;scene.display.shading.cavity_type='BOTH'
scene.display.shading.curvature_ridge_factor=1.2;scene.display.shading.curvature_valley_factor=1.1
scene.display.render_aa='16';scene.view_settings.view_transform='Standard'
scene.world.color=(.17,.17,.17)

def material(name,color,metal,roughness):
    mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);mat.use_nodes=True
    bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None) or mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled');bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=roughness
    return mat
body=material('Obsidienne arcanique',(.012,.016,.025),.0,.8)
gold=material('Or lumineux',(.95,.57,.12),.0,.6)
highlight=material('Lumière des arêtes',(1,.85,.42),.0,.6)
shadowgold=material('Biseau ambré',(.38,.19,.035),.0,.6)
nodes=body.node_tree.nodes;links=body.node_tree.links
bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
coord=nodes.new('ShaderNodeTexCoord')
voronoi=nodes.new('ShaderNodeTexVoronoi');voronoi.feature='DISTANCE_TO_EDGE';voronoi.inputs['Scale'].default_value=7
links.new(coord.outputs['Generated'],voronoi.inputs['Vector'])
noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=4;noise.inputs['Detail'].default_value=3
links.new(coord.outputs['Generated'],noise.inputs['Vector'])
thin=nodes.new('ShaderNodeMath');thin.operation='LESS_THAN';thin.inputs[1].default_value=.022
links.new(voronoi.outputs['Distance'],thin.inputs[0])
sparse=nodes.new('ShaderNodeMath');sparse.operation='GREATER_THAN';sparse.inputs[1].default_value=.54
links.new(noise.outputs['Fac'],sparse.inputs[0])
mask=nodes.new('ShaderNodeMath');mask.operation='MULTIPLY';links.new(thin.outputs[0],mask.inputs[0]);links.new(sparse.outputs[0],mask.inputs[1])
mix=nodes.new('ShaderNodeMixRGB');mix.inputs[1].default_value=(.007,.008,.011,1);mix.inputs[2].default_value=(.38,.22,.055,1)
links.new(mask.outputs[0],mix.inputs[0]);links.new(mix.outputs[0],bs.inputs['Base Color'])
me=bpy.data.meshes.new('Die');me.from_pydata(mesh['verts'],[],mesh['faces']);me.update()
ob=bpy.data.objects.new('Die',me);scene.collection.objects.link(ob);ob.data.materials.append(body)
ob.data.materials.append(gold)
bpy.context.view_layer.objects.active=ob;ob.select_set(True)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
bevel=ob.modifiers.new('Arêtes en relief','BEVEL');bevel.width=.018 if opt.sides<100 else .006;bevel.segments=2
bevel.affect='EDGES';bevel.limit_method='ANGLE'
bevel.material=1
for polygon in me.polygons: polygon.use_smooth=False
weighted=ob.modifiers.new('Reflets continus','WEIGHTED_NORMAL');weighted.keep_sharp=True
parent=bpy.data.objects.new('Rotation',None);scene.collection.objects.link(parent);ob.parent=parent
font=bpy.data.fonts.load('C:/Windows/Fonts/georgia.ttf')
targets=[];centers=[];ornament_vertices=[];ornament_faces=[];ornament_materials=[]
def ornament(name,points,mat):
    start=len(ornament_vertices);ornament_vertices.extend(points)
    ornament_faces.append(list(range(start,start+len(points))))
    ornament_materials.append([gold,highlight,shadowgold].index(mat))

for i,poly in enumerate(me.polygons):
    c=poly.center.copy();n=poly.normal.copy();u=(me.vertices[poly.vertices[1]].co-me.vertices[poly.vertices[0]].co).normalized();v=n.cross(u).normalized()
    basis=Matrix((u,v,n)).transposed()
    targets.append(basis.transposed().to_quaternion());centers.append(c)
    # Trois bandes donnent un biseau doré lisible sans reflet photographique.
    corners=[me.vertices[j].co.copy() for j in poly.vertices]
    for k,a in enumerate(corners):
        b=corners[(k+1)%len(corners)]
        for outer,inner,height,mat in [(0.98,.945,.009,shadowgold),(.945,.92,.013,highlight),(.92,.87,.009,gold)]:
            ornament('Bordure', [c+(a-c)*outer+n*height,c+(b-c)*outer+n*height,c+(b-c)*inner+n*height,c+(a-c)*inner+n*height],mat)
        # Fins motifs en pointe aux angles, à l'écart du chiffre.
        tip=c+(a-c)*.79;axis=(a-c).normalized();side=n.cross(axis)
        length=(a-c).length*.13;width=length*.22
        ornament('Rune', [tip+n*.014,tip-axis*length+side*width+n*.014,tip-axis*length*2+n*.014,tip-axis*length-side*width+n*.014],gold)
    # Distance aux arêtes pour garder chaque gravure sur sa face.
    radius=min((me.vertices[j].co-c).length for j in poly.vertices)*.47
    curve=bpy.data.curves.new('Face '+str(i+1),'FONT');curve.body=str(i+1);curve.align_x='CENTER';curve.align_y='CENTER'
    curve.font=font;curve.size=radius*2.3/(1 if i<9 else (1.4 if i<99 else 1.9));curve.extrude=.0008;curve.bevel_depth=.0003
    text=bpy.data.objects.new('Number '+str(i+1),curve);scene.collection.objects.link(text);text.data.materials.append(gold)
    text.rotation_mode='QUATERNION';text.rotation_quaternion=basis.to_quaternion();text.parent=parent
    bpy.context.view_layer.update()
    bounds=[Vector(p) for p in text.bound_box]
    inkcenter=Vector(((min(p.x for p in bounds)+max(p.x for p in bounds))/2,(min(p.y for p in bounds)+max(p.y for p in bounds))/2,0))
    text.location=c+n*.016-basis@inkcenter
decor=bpy.data.meshes.new('Ornements');decor.from_pydata(ornament_vertices,[],ornament_faces);decor.update()
obj=bpy.data.objects.new('Ornements',decor);scene.collection.objects.link(obj);obj.parent=parent
for mat in [gold,highlight,shadowgold]:decor.materials.append(mat)
for poly,index in zip(decor.polygons,ornament_materials):poly.material_index=index
# Un seul maillage pour les gravures : même image, moins de passes de dessin,
# particulièrement pour les cent faces du D100.
bpy.ops.object.select_all(action='DESELECT')
texts=[obj for obj in scene.objects if obj.type=='FONT']
for obj in texts:obj.select_set(True)
bpy.context.view_layer.objects.active=texts[0]
bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
camdata=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',camdata);scene.collection.objects.link(cam)
cam.location=(0,0,5);cam.rotation_euler=(0,0,0);camdata.type='ORTHO';camdata.ortho_scale=2.6;scene.camera=cam
for name,loc,power,size in [('Key',(-3,4,5),450,4),('Fill',(4,1,3),220,3),('Rim',(0,-3,2),300,2)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    light=bpy.data.objects.new(name,data);scene.collection.objects.link(light);light.location=loc;light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
parent.rotation_mode='QUATERNION'
def render(q,path,offset=None):
    parent.rotation_quaternion=q;parent.location=offset if offset is not None else (0,0,0)
    scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
if opt.flight:
    scene.display.render_aa='8'
    folder=ROOT/'Media'/'Flight'/f'd{opt.sides}';folder.mkdir(parents=True,exist_ok=True)
    profiles=[FullRoll(i) for i in range(1,5)]
    checks=[motion.verify() for motion in profiles]
    metadata=[];batch=[]
    for value in range(opt.first_value,(opt.last_value or opt.sides)+1):
        target=targets[value-1];profile=(value*7+opt.sides)%4
        motion=profiles[profile]
        center=target@centers[value-1];offset=Vector((-center.x,-center.y,0))
        assert (target@me.polygons[value-1].normal).z>.99999
        metadata.append({'value':value,'profile':profile+1,'front_dot':(target@me.polygons[value-1].normal).z,
                         'center_error':math.hypot(center.x+offset.x,center.y+offset.y),**checks[profile]})
        if not opt.validate_only and not (opt.resume and (folder/f'face-{value:03}-143.png').exists()):
            for i in range(144):
                t=i/143
                q=motion.at(t,target);location=offset*t*t*(3-2*t)
                path=folder/f'face-{value:03}-{i:03}.png'
                if opt.batch:
                    batch.append(path);frame=len(batch)
                    parent.rotation_quaternion=q;parent.location=location
                    parent.keyframe_insert(data_path='rotation_quaternion',frame=frame)
                    parent.keyframe_insert(data_path='location',frame=frame)
                else:render(q,path,location)
    if batch:
        scene.frame_start=1;scene.frame_end=len(batch)
        prefix=folder/f'batch-{opt.first_value}-'
        scene.render.filepath=str(prefix)
        bpy.ops.render.render(animation=True)
        for frame,path in enumerate(batch,1):
            Path(str(prefix)+f'{frame:04}.png').replace(path)
    (folder/('motion-check.json' if opt.validate_only else f'faces-{opt.first_value}.json')).write_text(json.dumps(metadata))
elif opt.roll_only:
    folder=ROOT/'Media'/'Tumble'/f'd{opt.sides}';folder.mkdir(parents=True,exist_ok=True)
    start=Euler((.8,.5,.3)).to_quaternion()
    checks=[]
    for variant in range(1,5):
        checks.append(verify_roll(start,variant))
        if not opt.validate_only:
            for i in range(ROLL_FRAMES):
                render(rolling(start,i/(ROLL_FRAMES-1),variant),folder/f'roll-v{variant}-{i:02}.png')
    (folder/'motion-check.json').write_text(json.dumps(checks))
elif opt.preview:
    scene.render.resolution_x=512;scene.render.resolution_y=512
    render(targets[min(11,opt.sides-1)],OUT/f'd{opt.sides}-preview.png')
else:
    folder=OUT/f'd{opt.sides}';folder.mkdir(exist_ok=True)
    start=Euler((.8,.5,.3)).to_quaternion()
    # Toutes les rotations partagent exactement leur jonction avec le lancer.
    for i in range(0 if opt.skip_roll or opt.validate_only else ROLL_FRAMES):
        t=i/(ROLL_FRAMES-1)
        q=rolling(start,t)
        render(q,folder/f'roll-{i:02}.png')
    metadata=[]
    for value,target in enumerate(targets,1):
        n=me.polygons[value-1].normal
        assert (target@n).z>.99999,'La face du résultat doit être exactement face caméra'
        assert max(range(len(me.polygons)),key=lambda j:(target@me.polygons[j].normal).z)==value-1
        center=target@centers[value-1];offset=Vector((-center.x,-center.y,0))
        metadata.append({'value':value,'front_dot':(target@n).z,'center_error':math.hypot(center.x+offset.x,center.y+offset.y)})
        if value<opt.first_value or value>(opt.last_value or opt.sides):continue
        motion=Landing(start,target)
        metadata[-1].update(motion.verify(start))
        if opt.validate_only:continue
        for i in range(LAND_FRAMES):
            q,progress=motion.at(i/(LAND_FRAMES-1))
            center_progress=progress*progress*(3-2*progress)
            render(q,folder/f'land-{value:03}-{i:02}.png',offset*center_progress)
    (folder/('motion-check.json' if opt.validate_only else f'faces-{opt.first_value}.json')).write_text(json.dumps(metadata))
