"""Roda DENTRO do Blender (chamado por tools/blender/item_to_blender.py, ver lá o uso). Põe no .blend um item do jogo.

Argumentos (depois de `--`): [--write <saida.blend>] <conjunto> <slot> e trios <arquivo.glb> <nome do objeto> <corpo>...
Com --write, o .blend aberto NÃO é salvo: as peças vão sozinhas para <saida.blend>, para o dono trazer com
File → Append sem fechar o arquivo em que está trabalhando.
Cada .glb (item vestido, no espaço do personagem: tools/blender/item_to_glb.gd) vira UM objeto `<nome do objeto>` na
coleção Itens/<conjunto>/<slot>, com a origem nos pés, em cima do objeto `<corpo>-body` (onde quer que ele esteja). Objeto com o mesmo nome já existente não é tocado (aviso). Salva o .blend.
"""
import sys

import bpy
import mathutils


def body_frame(body: str):
    """Onde está o corpo [body] no .blend (posição e giro do objeto `<corpo>-body`; sem ele, `<corpo>-armature`).
    As peças são modeladas em cima desse corpo, onde quer que ele esteja: o jogo usa o espaço do próprio corpo."""
    obj = bpy.data.objects.get(f"{body}-body") or bpy.data.objects.get(f"{body}-armature")
    if obj is None:
        return None
    loc, rot, _scale = obj.matrix_world.decompose()
    return mathutils.Matrix.Translation(loc) @ rot.to_matrix().to_4x4()


def child_collection(parent, name: str):
    """Subcoleção [name] de [parent]; nomes de coleção são únicos no .blend, então pode existir como `head.001`."""
    for c in parent.children:
        if c.name == name or c.name.split(".")[0] == name:
            return c
    c = bpy.data.collections.new(name)
    parent.children.link(c)
    return c


def layer_of(collection, layer=None):
    layer = layer or bpy.context.view_layer.layer_collection
    if layer.collection == collection:
        return layer
    for child in layer.children:
        found = layer_of(collection, child)
        if found:
            return found
    return None


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:]
    write_to = None
    if args[0] == "--write":
        write_to, args = args[1], args[2:]
    item_set, slot, pairs = args[0], args[1], args[2:]
    created = []
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    root = bpy.data.collections.get("Itens")
    if root is None:
        root = bpy.data.collections.new("Itens")
        bpy.context.scene.collection.children.link(root)
    target = child_collection(child_collection(root, item_set), slot)
    for i in range(0, len(pairs), 3):
        glb, name, body = pairs[i], pairs[i + 1], pairs[i + 2]
        if name in bpy.data.objects:
            print(f"AVISO '{name}' já existe no .blend: não mexi (apague ou renomeie o seu para puxar de novo)")
            continue
        for o in bpy.context.view_layer.objects:
            o.select_set(False)
        bpy.context.view_layer.active_layer_collection = layer_of(target)
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=glb)
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
        if not meshes:
            print(f"ERRO nenhuma malha em {glb}")
            continue
        for o in bpy.context.view_layer.objects:
            o.select_set(o in meshes)
        bpy.context.view_layer.objects.active = meshes[0]
        if len(meshes) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.name = name
        obj.data.name = name
        frame = body_frame(body)
        if frame is not None:
            obj.matrix_world = frame
        for c in list(obj.users_collection):
            if c != target:
                c.objects.unlink(obj)
        if target not in obj.users_collection:
            target.objects.link(obj)
        created.append(obj)
        print(f"IMPORTADO {name} em {target.name} ({sum(len(p.vertices) - 2 for p in obj.data.polygons)} triângulos)")
    for c in list(bpy.data.collections):
        if c.name.startswith("glTF_not_exported") and not c.all_objects:
            bpy.data.collections.remove(c)
    if write_to:
        bpy.data.libraries.write(write_to, set(created), fake_user=True, compress=True)
        print(f"SALVO {write_to} (Append: File → Append → esse arquivo → Object)")
        return
    bpy.ops.wm.save_mainfile()
    print("SALVO")


main()
