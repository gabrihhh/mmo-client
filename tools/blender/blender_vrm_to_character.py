"""Roda DENTRO do Blender (chamado por vrm_to_character.py): converte um personagem VRM (VRoid Studio) para o formato
dos corpos do jogo ([ART-12]): esqueleto Mixamo de 24 ossos (os mesmos nomes de male.glb / female.glb, então o
`mixamo_bone_map.tres`, as animações e os itens continuam valendo), uma malha só, origem nos pés, olhando para +Z no
Godot (−Y no Blender), na altura pedida, com os triângulos reduzidos para caber no celular.

Argumentos (depois de `--`): <entrada.glb> <humanoide.json> <saida.glb> <altura_m> <max_triangulos>
  humanoide.json = {"bones": {"hips": "<nome do nó>", ...}} (mapa humanoide lido do VRM pelo wrapper).
"""
import json
import sys

import bmesh
import bpy
from mathutils import Vector

# Osso humanoide do VRM → osso do Mixamo (o que male.glb usa).
VRM_TO_MIXAMO = {
    "hips": "Hips", "spine": "Spine", "chest": "Spine1", "upperChest": "Spine2", "neck": "Neck", "head": "Head",
    "leftShoulder": "LeftShoulder", "leftUpperArm": "LeftArm", "leftLowerArm": "LeftForeArm", "leftHand": "LeftHand",
    "rightShoulder": "RightShoulder", "rightUpperArm": "RightArm", "rightLowerArm": "RightForeArm", "rightHand": "RightHand",
    "leftUpperLeg": "LeftUpLeg", "leftLowerLeg": "LeftLeg", "leftFoot": "LeftFoot", "leftToes": "LeftToeBase",
    "rightUpperLeg": "RightUpLeg", "rightLowerLeg": "RightLeg", "rightFoot": "RightFoot", "rightToes": "RightToeBase",
}
# Pai de cada osso Mixamo (a árvore de male.glb).
MIXAMO_PARENT = {
    "Hips": None, "Spine": "Hips", "Spine1": "Spine", "Spine2": "Spine1", "Neck": "Spine2", "Head": "Neck",
    "HeadTop_End": "Head",
    "LeftShoulder": "Spine2", "LeftArm": "LeftShoulder", "LeftForeArm": "LeftArm", "LeftHand": "LeftForeArm",
    "RightShoulder": "Spine2", "RightArm": "RightShoulder", "RightForeArm": "RightArm", "RightHand": "RightForeArm",
    "LeftUpLeg": "Hips", "LeftLeg": "LeftUpLeg", "LeftFoot": "LeftLeg", "LeftToeBase": "LeftFoot",
    "RightUpLeg": "Hips", "RightLeg": "RightUpLeg", "RightFoot": "RightLeg", "RightToeBase": "RightFoot",
}
PREFIX = "mixamorig:"


def main() -> None:
    src, humanoid_path, out, height, max_tris = sys.argv[sys.argv.index("--") + 1:][:5]
    height, max_tris = float(height), int(max_tris)
    human = json.load(open(humanoid_path))["bones"]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm]
    for o in list(bpy.data.objects):
        if o != arm and o not in meshes:
            bpy.data.objects.remove(o, do_unlink=True)

    # 1. Malhas: sem expressões (shape keys) e numa só.
    for o in meshes:
        if o.data.shape_keys:
            bpy.context.view_layer.objects.active = o
            o.shape_key_clear()
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "char1"

    # 2. Ossos: renomeia os humanoides; os outros (cabelo, saia, olhos, dedos...) passam o peso ao ancestral mapeado.
    name_of = {node: PREFIX + VRM_TO_MIXAMO[k] for k, node in human.items() if k in VRM_TO_MIXAMO}
    target_of = {}
    for bone in arm.data.bones:
        b = bone
        while b is not None and b.name not in name_of:
            b = b.parent
        target_of[bone.name] = name_of[b.name] if b is not None else PREFIX + "Hips"
    _merge_weights(body, target_of)
    for bone in arm.data.bones:
        if bone.name in name_of:
            bone.name = name_of[bone.name]

    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for b in list(eb):
        if not b.name.startswith(PREFIX):
            eb.remove(b)
    # Sem upperChest (ou chest): cria o que falta no meio do caminho, sem peso.
    if PREFIX + "Spine2" not in eb:
        eb[PREFIX + "Spine1"].name = PREFIX + "Spine2"
    if PREFIX + "Spine1" not in eb:
        spine, top = eb[PREFIX + "Spine"], eb[PREFIX + "Spine2"]
        mid = eb.new(PREFIX + "Spine1")
        mid.head, mid.tail = (spine.head + top.head) / 2, top.head
        spine.tail = mid.head
    head = eb[PREFIX + "Head"]
    top_z = max((body.matrix_world @ v.co).z for v in body.data.vertices)
    end = eb.new(PREFIX + "HeadTop_End")
    end.head = Vector((head.head.x, head.head.y, top_z))
    end.tail = end.head + Vector((0, 0, 0.05))
    for name, parent in MIXAMO_PARENT.items():
        b = eb.get(PREFIX + name)
        if b is None:
            raise SystemExit(f"ERRO: falta o osso {name} no VRM")
        b.parent = eb[PREFIX + parent] if parent else None
        b.use_connect = False
    for b in eb:
        if (b.tail - b.head).length < 1e-4:
            b.tail = b.head + Vector((0, 0, 0.05))
    bpy.ops.object.mode_set(mode="OBJECT")
    for vg in list(body.vertex_groups):
        if vg.name not in arm.data.bones:
            body.vertex_groups.remove(vg)

    # 3. Frente para −Y (pé → ponta do pé), pés no chão, na altura pedida; aplica nas malhas e no esqueleto.
    foot = arm.data.bones[PREFIX + "LeftFoot"].head_local
    toe = arm.data.bones[PREFIX + "LeftToeBase"].head_local
    forward = Vector((toe.x - foot.x, toe.y - foot.y, 0)).normalized()
    angle = forward.to_2d().angle_signed(Vector((0, -1)))
    zs = [(body.matrix_world @ v.co).z for v in body.data.vertices]
    scale = height / (max(zs) - min(zs))
    root = bpy.data.objects.new("root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in (arm, body):
        o.parent = None
    arm.matrix_world = arm.matrix_world.copy()
    import mathutils
    xform = mathutils.Matrix.Rotation(-angle, 4, "Z") @ mathutils.Matrix.Scale(scale, 4) @ mathutils.Matrix.Translation((0, 0, -min(zs)))
    for o in (arm, body):
        o.matrix_world = xform @ o.matrix_world
    bpy.ops.object.select_all(action="DESELECT")
    for o in (arm, body):
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.data.objects.remove(root, do_unlink=True)
    body.parent = arm
    for m in body.modifiers:
        if m.type == "ARMATURE":
            m.object = arm

    # 4. Triângulos: reduz para caber (Decimate colapsando arestas, mantém UV e pesos).
    tris = _count_tris(body)
    if tris > max_tris:
        mod = body.modifiers.new("decimate", "DECIMATE")
        mod.ratio = max_tris / tris
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    print(f"VRM→PERSONAGEM {tris} → {_count_tris(body)} triângulos, {len(body.data.materials)} materiais, "
          f"{len(arm.data.bones)} ossos, altura {height} m")

    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=False, export_morph=False,
                              export_yup=True, export_apply=False)
    print("SALVO", out)


def _merge_weights(body, target_of) -> None:
    groups = {vg.index: vg.name for vg in body.vertex_groups}
    for name in set(target_of.values()):
        if name not in body.vertex_groups:
            body.vertex_groups.new(name=name)
    target_index = {vg.name: vg.index for vg in body.vertex_groups}
    totals = []
    for v in body.data.vertices:
        acc = {}
        for g in v.groups:
            src = groups.get(g.group)
            if src is None or src not in target_of:
                continue
            dst = target_of[src]
            acc[dst] = acc.get(dst, 0.0) + g.weight
        totals.append((v.index, acc))
    for vg in list(body.vertex_groups):
        if vg.name not in target_index or vg.index != target_index[vg.name]:
            body.vertex_groups.remove(vg)
    keep = {name: body.vertex_groups[name] for name in set(target_of.values())}
    for vg in list(body.vertex_groups):
        if vg.name not in keep:
            body.vertex_groups.remove(vg)
    for vg in keep.values():
        vg.remove([v.index for v in body.data.vertices])
    for index, acc in totals:
        for dst, w in acc.items():
            keep[dst].add([index], w, "REPLACE")


def _count_tris(o) -> int:
    bm = bmesh.new()
    bm.from_mesh(o.data)
    n = sum(len(f.verts) - 2 for f in bm.faces)
    bm.free()
    return n


main()
