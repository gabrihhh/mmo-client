"""Roda DENTRO do Blender: tira as roupas de um personagem VRM do VRoid Studio vestido e grava como peças **sob medida**
do jogo ([ART-12], [ART-08]).

    blender -b --python tools/blender/blender_vrm_to_clothes.py -- <vestido.vrm> <male|female> <item> [--tris-chest N] [--tris-boot N]

Exemplo: `... -- healer.vrm female healer` grava
  assets/itens/chest/healer/female/chest-healer.glb  (todas as roupas do VRoid menos o calçado: o peito é o traje
                                                      do corpo inteiro)
  assets/itens/boot/healer/female/boot-healer.glb    (o calçado do VRoid, os DOIS pés numa malha)

No Windows sem Python, o Blender roda o script direto (não precisa de wrapper): o mapa humanoide é lido do próprio VRM.

Como sai:
- Só os materiais de roupa do VRoid (`..._CLOTH`); corpo, rosto e cabelo são descartados.
- No espaço do corpo anime do jogo (`blender_vrm_to_character.py`): mesma rotação (frente +Z no Godot), mesma escala
  (altura do corpo **sem** as roupas = 1,75 m / 1,80 m) e pés na origem. Por isso o VRM vestido tem de ser do MESMO
  personagem do corpo (mesmo projeto do VRoid), só com as roupas a mais.
- Malha sem esqueleto e sem pesos: o jogo copia os pesos do corpo ([BodySkinning]).
- Triângulos reduzidos só se passar do teto pedido (padrão: sem redução, para ver a peça como o VRoid fez).
"""
import json
import struct
import sys
import tempfile
from pathlib import Path

import bmesh
import bpy
import mathutils
from mathutils import Vector

CLIENT = Path(__file__).resolve().parents[2]
# Altura (m) de cada corpo do jogo; igual a vrm_to_character.py.
HEIGHT: dict[str, float] = {"male": 1.80, "female": 1.75}
# Pedaço do nome do material do VRoid que identifica o calçado (vai para "boot"; o resto das roupas vai para "chest").
SHOES_TAG = "_Shoes_"
CLOTH_TAG = "_CLOTH"


def humanoid_bones(vrm: Path) -> dict[str, str]:
    """Mapa osso humanoide → nome do nó, do JSON do glTF (VRMC_vrm 1.0 ou VRM 0.x)."""
    data = vrm.read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + length])
    ext = gltf.get("extensions", {})
    nodes = gltf["nodes"]
    if "VRMC_vrm" in ext:
        return {k: nodes[v["node"]]["name"] for k, v in ext["VRMC_vrm"]["humanoid"]["humanBones"].items()}
    if "VRM" in ext:
        return {b["bone"]: nodes[b["node"]]["name"] for b in ext["VRM"]["humanoid"]["humanBones"] if b.get("node", -1) >= 0}
    raise SystemExit("ERRO: o arquivo não é VRM (sem extensão VRMC_vrm/VRM)")


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:]
    vrm, body_id, item = Path(args[0]), args[1], args[2]
    tris_cap = {"chest": 0, "boot": 0}
    for flag, slot in (("--tris-chest", "chest"), ("--tris-boot", "boot")):
        if flag in args:
            tris_cap[slot] = int(args[args.index(flag) + 1])
    human = humanoid_bones(vrm)

    # O importador do Blender só aceita .glb; o VRM é um glb com extensões a mais.
    glb = Path(tempfile.gettempdir()) / f"vrm_clothes_{body_id}.glb"
    glb.write_bytes(vrm.read_bytes())
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    # Só as malhas presas ao esqueleto e com material (o VRoid exporta malhas auxiliares vazias).
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm and o.data.materials]

    # 1. Transformação do corpo: a mesma de blender_vrm_to_character.py, medida SEM as roupas (calçado tem sola).
    foot = arm.data.bones[human["leftFoot"]].head_local
    toe = arm.data.bones[human["leftToes"]].head_local
    forward = Vector((toe.x - foot.x, toe.y - foot.y, 0)).normalized()
    angle = forward.to_2d().angle_signed(Vector((0, -1)))
    zs: list[float] = []
    for o in meshes:
        for poly in o.data.polygons:
            if CLOTH_TAG in o.data.materials[poly.material_index].name:
                continue
            zs.extend((o.matrix_world @ o.data.vertices[v].co).z for v in poly.vertices)
    scale = HEIGHT[body_id] / (max(zs) - min(zs))
    xform = (mathutils.Matrix.Rotation(-angle, 4, "Z") @ mathutils.Matrix.Scale(scale, 4)
             @ mathutils.Matrix.Translation((0, 0, -min(zs))))
    # Ajuste fino pelos ossos do corpo que está no jogo: a altura medida acima muda uns milímetros com o cabelo (o
    # corpo foi exportado com outra redução); quadril e cabeça do VRM caem em cima dos do <corpo>_anime/<corpo>.glb.
    hips = xform @ (arm.matrix_world @ arm.data.bones[human["hips"]].head_local)
    head = xform @ (arm.matrix_world @ arm.data.bones[human["head"]].head_local)
    ref_hips, ref_head = _reference_bones(CLIENT / "assets" / "characters" / f"{body_id}_anime" / f"{body_id}.glb")
    fine = (ref_head.z - ref_hips.z) / (head.z - hips.z)
    xform = mathutils.Matrix.Translation(ref_hips - hips * fine) @ mathutils.Matrix.Scale(fine, 4) @ xform
    print(f"VRM→ROUPA escala {scale * fine:.5f} (ajuste pelos ossos ×{fine:.5f}), quadril em "
          f"{tuple(round(c, 4) for c in ref_hips)} (Blender, Z p/ cima)")

    # 2. Uma malha por peça: copia cada malha, deixa só as faces dos materiais da peça, aplica a transformação.
    for slot in ("chest", "boot"):
        parts = []
        for o in meshes:
            names = [m.name if m else "" for m in o.data.materials]
            wanted = {i for i, n in enumerate(names) if CLOTH_TAG in n and ((SHOES_TAG in n) == (slot == "boot"))}
            if not wanted:
                continue
            copy = o.copy()
            copy.data = o.data.copy()
            bpy.context.scene.collection.objects.link(copy)
            if copy.data.shape_keys:
                bpy.context.view_layer.objects.active = copy
                copy.shape_key_clear()
            bm = bmesh.new()
            bm.from_mesh(copy.data)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index not in wanted], context="FACES")
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
            bm.to_mesh(copy.data)
            bm.free()
            copy.modifiers.clear()
            copy.vertex_groups.clear()
            copy.parent = None
            copy.matrix_world = xform @ o.matrix_world
            parts.append(copy)
        if not parts:
            print(f"VRM→ROUPA sem {slot} no VRM (nenhum material {CLOTH_TAG}{' ' + SHOES_TAG if slot == 'boot' else ''})")
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for p in parts:
            p.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        if len(parts) > 1:
            bpy.ops.object.join()
        piece = bpy.context.view_layer.objects.active
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        # Tira os slots de material que ficaram sem face.
        used = {p.material_index for p in piece.data.polygons}
        for index in sorted(range(len(piece.data.materials)), reverse=True):
            if index not in used:
                piece.active_material_index = index
                bpy.ops.object.material_slot_remove()
        name = f"{slot}-{item}"
        piece.name = name
        tris = _count_tris(piece)
        if tris_cap[slot] and tris > tris_cap[slot]:
            mod = piece.modifiers.new("decimate", "DECIMATE")
            mod.ratio = tris_cap[slot] / tris
            mod.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=mod.name)
        out = CLIENT / "assets" / "itens" / slot / item / body_id / f"{name}.glb"
        out.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        piece.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", use_selection=True, export_animations=False,
                                  export_morph=False, export_skins=False, export_yup=True)
        print(f"VRM→ROUPA {name}: {tris} → {_count_tris(piece)} triângulos, materiais "
              f"{[m.name for m in piece.data.materials]}")
        print("SALVO", out)


def _reference_bones(path: Path) -> tuple[Vector, Vector]:
    """Posição (Blender, Z p/ cima) dos ossos Hips e Head do corpo do jogo em [param path]; apaga o que importou."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    added = [o for o in bpy.data.objects if o not in before]
    ref = next(o for o in added if o.type == "ARMATURE")
    hips = ref.matrix_world @ ref.data.bones["mixamorig:Hips"].head_local
    head = ref.matrix_world @ ref.data.bones["mixamorig:Head"].head_local
    for o in added:
        bpy.data.objects.remove(o, do_unlink=True)
    return hips, head


def _count_tris(o) -> int:
    bm = bmesh.new()
    bm.from_mesh(o.data)
    n = sum(len(f.verts) - 2 for f in bm.faces)
    bm.free()
    return n


main()
