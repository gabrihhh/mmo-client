"""Roda DENTRO do Blender (chamado por tools/blender/export_items.py, ver lá o uso). Exporta as peças sob medida ([ART-08]).

Peça = objeto MESH dentro da coleção "Itens" (em qualquer subcoleção) chamado `<slot>-<nome>-<corpo>`, ex.
`chest-healer-female`. Vai para `assets/itens/<slot>/<nome>/<corpo>/<slot>-<nome>.glb`, no espaço do personagem
(origem nos pés, metros, glTF Y para cima). Os corpos ficam lado a lado no .blend: a posição e o giro do objeto
`<corpo>-body` são descontados (pode mover o corpo à vontade).

Cores: cada MATERIAL da peça é uma cor (a Base Color dele). Todas viram 1 material só com uma textura de N×1 pixels
(um pixel por cor) e a UV de cada face aponta para o pixel da cor dela: 1 draw call, textura minúscula.
Furos de até 6 lados são tapados; sombreado flat (low poly).

Argumentos (depois de `--`): <pasta assets/itens> [nomes de objetos...]. Sem nomes = todas as peças.
Imprime uma linha `EXPORTADO <caminho> <triângulos> <cores>` por peça, `AVISO ...` e `ERRO ...`.
"""
import os
import re
import sys

import bmesh
import bpy
import mathutils

NAME = re.compile(r"^(head|chest|boot|hand)-([a-z0-9-]+)-(male|female)$")
## Limite de triângulos de uma peça (orçamento low poly do personagem, [ART-01]).
MAX_TRIS = 600


def body_frame(body: str):
    """Onde está o corpo [body] no .blend (posição e giro do objeto `<corpo>-body`; sem ele, `<corpo>-armature`).
    As peças são modeladas em cima desse corpo, onde quer que ele esteja: o jogo usa o espaço do próprio corpo."""
    obj = bpy.data.objects.get(f"{body}-body") or bpy.data.objects.get(f"{body}-armature")
    if obj is None:
        return None
    loc, rot, _scale = obj.matrix_world.decompose()
    return mathutils.Matrix.Translation(loc) @ rot.to_matrix().to_4x4()


def srgb(c: float) -> float:
    """Base Color do Blender é linear; os pixels da imagem são sRGB."""
    c = max(0.0, min(1.0, c))
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def material_color(mat) -> tuple:
    if mat is None:
        return (1.0, 1.0, 1.0)
    if mat.use_nodes and mat.node_tree:
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is not None:
            socket = bsdf.inputs["Base Color"]
            if socket.is_linked:
                print(f"AVISO material '{mat.name}' usa textura na Base Color: vale a cor do Viewport Display")
                return tuple(mat.diffuse_color[:3])
            return tuple(socket.default_value[:3])
    return tuple(mat.diffuse_color[:3])


def items_objects(names: list) -> list:
    root = bpy.data.collections.get("Itens")
    if root is None:
        print("ERRO o .blend não tem a coleção 'Itens'")
        return []
    found = [o for o in root.all_objects if o.type == "MESH" and NAME.match(o.name)]
    for o in root.all_objects:
        if o.type == "MESH" and not NAME.match(o.name):
            print(f"AVISO '{o.name}' ignorado: o nome precisa ser <slot>-<nome>-<male|female> (slot: head, chest, boot, hand)")
    if names:
        missing = set(names) - {o.name for o in found}
        for n in sorted(missing):
            print(f"ERRO peça '{n}' não encontrada na coleção Itens")
        found = [o for o in found if o.name in names]
    return found


def export(src, itens_dir: str) -> None:
    slot, name, body = NAME.match(src.name).groups()
    folder = f"{itens_dir}/{slot}/{name}/{body}"
    if not os.path.isdir(folder):
        print(f"ERRO pasta {folder} não existe (o item {slot}/{name} existe no jogo?)")
        return
    frame = body_frame(body)
    if frame is None:
        print(f"AVISO sem objeto '{body}-body': peça exportada como está no .blend")
        frame = mathutils.Matrix.Identity(4)
    mesh = src.data.copy()
    mesh.transform(frame.inverted() @ src.matrix_world)
    colors = []
    for slot_mat in src.material_slots or [None]:
        color = material_color(slot_mat.material if slot_mat else None)
        colors.append(tuple(round(srgb(c), 3) for c in color))
    palette = sorted(set(colors))
    if not src.material_slots:
        print(f"AVISO '{src.name}' não tem material: sai branca (pinte com materiais, um por cor)")
    while mesh.uv_layers:
        mesh.uv_layers.remove(mesh.uv_layers[0])
    obj = bpy.data.objects.new(f"{slot}-{name}", mesh)
    bpy.context.scene.collection.objects.link(obj)
    img = bpy.data.images.new("palette", len(palette), 1)
    pixels = []
    for c in palette:
        pixels += [c[0], c[1], c[2], 1.0]
    img.pixels = pixels
    mat = bpy.data.materials.new(f"{slot}-{name}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    bm = bmesh.new()
    bm.from_mesh(mesh)
    filled = bmesh.ops.holes_fill(bm, edges=bm.edges[:], sides=6)
    bmesh.ops.triangulate(bm, faces=filled["faces"])
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        index = palette.index(colors[f.material_index]) if f.material_index < len(colors) else 0
        f.material_index = 0
        for loop in f.loops:
            loop[uv].uv = ((index + 0.5) / len(palette), 0.5)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.clear()
    mesh.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = False
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    if filled["faces"]:
        print(f"AVISO '{src.name}': {len(filled['faces'])} furo(s) pequeno(s) tapado(s) na exportação")
    if tris > MAX_TRIS:
        print(f"AVISO '{src.name}': {tris} triângulos, acima do limite de {MAX_TRIS}")
    for o in bpy.context.scene.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = f"{folder}/{slot}-{name}.glb"
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=False,
                              export_skins=False, export_apply=True, export_yup=True, export_materials="EXPORT")
    print(f"EXPORTADO {path} {tris} {len(palette)}")


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not args:
        print("ERRO falta a pasta assets/itens")
        return
    # Arquivo salvo em Edit Mode: volta ao Object Mode (o que foi salvo já está na malha).
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for src in items_objects(args[1:]):
        export(src, args[0])


main()
