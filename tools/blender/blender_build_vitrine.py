"""Roda DENTRO do Blender (chamado por tools/blender/build_vitrine.py). Monta a coleção `vitrine` no testes.blend
([ART-09]): um boneco vestido por classe e corpo (female, male), em ESCADA NA DIAGONAL (de frente e de lado dá para
ver todos, nenhum fica atrás do outro), com a arma da classe em pé ao lado da dupla. Bonecos e roupas são CÓPIAS
LIGADAS (mesma malha) das peças de Itens/<conjunto>/<parte> e dos corpos: editar a malha numa muda a outra (o que vai
para o jogo continua sendo a peça de Itens). Rodar de novo refaz a vitrine do zero.
Argumentos (depois de `--`): <pasta com as armas .glb> (tools/blender/weapons_to_glb.gd)."""
import sys
import bpy
import mathutils

SETS = ["training", "mage", "knight", "ranger", "assassin", "healer"]
BODIES = ["female", "male"]
WEAPONS = {"training": "training_sword", "mage": "arcane_staff", "knight": "knight_sword",
           "ranger": "ranger_crossbow", "assassin": "assassin_daggers"}
BASE = mathutils.Vector((3.5, -1.5, 0.0))
STEP = mathutils.Vector((1.3, -1.3, 0.0))
WEAPON_OFFSET = mathutils.Vector((-0.7, 0.0, 0.0))

weapons_dir = sys.argv[sys.argv.index("--") + 1]

if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")


def collection(parent, name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        parent.children.link(c)
    return c


# Refaz do zero se já existir (roda de novo sem duplicar).
old = bpy.data.collections.get("vitrine")
if old is not None:
    for o in list(old.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(old.children_recursive):
        bpy.data.collections.remove(c)
    bpy.data.collections.remove(old)
root = collection(bpy.context.scene.collection, "vitrine")


def frame(body):
    obj = bpy.data.objects[f"{body}-body"]
    loc, rot, _ = obj.matrix_world.decompose()
    return mathutils.Matrix.Translation(loc) @ rot.to_matrix().to_4x4()


def place(src, target_world, col, name, armature=None):
    o = src.copy()
    o.name = name
    col.objects.link(o)
    o.parent = None
    o.matrix_world = target_world
    if armature is not None:
        for m in o.modifiers:
            if m.type == "ARMATURE":
                m.object = armature
    return o


def one_foot(obj):
    xs = [v.co.x for v in obj.data.vertices]
    return min(xs) > -0.01 or max(xs) < 0.01


def lift_to_ground(obj, x, y):
    """Põe o objeto em pé no chão (z mínimo = 0), centrado em (x, y)."""
    bpy.context.view_layer.update()
    corners = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
    min_z = min(c.z for c in corners)
    cx = sum(c.x for c in corners) / 8.0
    cy = sum(c.y for c in corners) / 8.0
    obj.location += mathutils.Vector((x - cx, y - cy, -min_z))


k = 0
for s in SETS:
    set_col = collection(root, f"vitrine-{s}")
    female_spot = None
    for b in BODIES:
        spot = BASE + STEP * k
        k += 1
        if female_spot is None:
            female_spot = spot
        body_col = collection(set_col, f"vitrine-{s}-{b}")
        f_inv = frame(b).inverted()
        d = mathutils.Matrix.Translation(spot)
        move = lambda src: d @ f_inv @ src.matrix_world
        arm_src = bpy.data.objects[f"{b}-armature"]
        arm = place(arm_src, move(arm_src), body_col, f"vitrine-{s}-{b}-armature")
        body_src = bpy.data.objects[f"{b}-body"]
        place(body_src, move(body_src), body_col, f"vitrine-{s}-{b}-body", arm)
        for slot in ["head", "chest", "boot"]:
            src = bpy.data.objects.get(f"{slot}-{s}-{b}")
            if src is None:
                print(f"AVISO sem {slot}-{s}-{b}")
                continue
            o = place(src, move(src), body_col, f"vitrine-{slot}-{s}-{b}", arm)
            if slot == "boot" and one_foot(src):
                mirror = o.modifiers.new("Espelho (pé direito)", "MIRROR")
                mirror.use_axis[0] = True
    # Arma da classe, em pé ao lado da dupla.
    target = female_spot + WEAPON_OFFSET
    if s in WEAPONS:
        before = set(bpy.data.objects)
        for o in bpy.context.view_layer.objects:
            o.select_set(False)
        bpy.ops.import_scene.gltf(filepath=f"{weapons_dir}/{WEAPONS[s]}.glb")
        new = [o for o in bpy.data.objects if o not in before]
        meshes = [o for o in new if o.type == "MESH"]
        for o in new:
            if o.type != "MESH":
                for child in o.children:
                    world = child.matrix_world.copy()
                    child.parent = None
                    child.matrix_world = world
        for o in new:
            if o.type != "MESH":
                bpy.data.objects.remove(o, do_unlink=True)
        for o in bpy.context.view_layer.objects:
            o.select_set(o in meshes)
        bpy.context.view_layer.objects.active = meshes[0]
        if len(meshes) > 1:
            bpy.ops.object.join()
        weapon = bpy.context.view_layer.objects.active
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        weapon.name = f"vitrine-{s}-arma"
        for c in list(weapon.users_collection):
            c.objects.unlink(weapon)
        set_col.objects.link(weapon)
    else:
        src = bpy.data.objects["hand-healer"]
        weapon = src.copy()
        weapon.name = f"vitrine-{s}-arma"
        set_col.objects.link(weapon)
        weapon.parent = None
    lift_to_ground(weapon, target.x, target.y)
    print(f"VITRINE {s}: arma {weapon.name}")

for c in list(bpy.data.collections):
    if c.name.startswith("glTF_not_exported") and not c.all_objects:
        bpy.data.collections.remove(c)
bpy.ops.wm.save_mainfile()
print("SALVO")
