"""Roda DENTRO do Blender (chamado por tools/blender/export_zone.py, ver lá o uso). Leva o mapa do spawn.blend para o
jogo ([ART-10]): "puxa o spawn.blend pro jogo".

Eixos: X do Blender = X do jogo, Z do Blender = altura (Y do jogo), −Y do Blender = +Z do jogo. 1 unidade = 1 m.

O que sai (argumentos depois de `--`: <pasta do cliente> <pasta do servidor> <zona>):
1. `assets/zones/<zona>/<zona>.glb` (cliente): o que se VÊ. Toda malha da coleção `Jogo hoje` (direto nela; as
   subcoleções de NPCs/anéis ficam de fora) e da coleção `Terreno` com as subcoleções (`Objetos`, `Objetos sem colisão`),
   menos objetos `*_colisao`. Cada malha vai com a posição/giro/escala já aplicados (espaço do mundo), faces flat
   (low poly) e as cores numa cor por vértice: cor do vértice (as malhas vindas do jogo) × Base Color do material da
   face (o que o dono pintar). No jogo tudo usa um material só de cor por vértice (LowPolyShapes.material).
2. `assets/zones/<zona>/<zona>_height.png` (cliente): altura do chão numa grade de HEIGHT_STEP m de −HEIGHT_HALF a
   +HEIGHT_HALF nos dois eixos (pixel (i, j) = ponto x = −HEIGHT_HALF + i × passo, z = idem com j). Altura em cm
   + HEIGHT_OFFSET_CM em 16 bits: vermelho = byte alto, verde = byte baixo. Chão = `jogo_chao`, `jogo_praca` e as
   malhas soltas direto na coleção `Terreno` (não as de `Objetos`): raio de cima para baixo, o ponto mais alto.
3. `assets/zones/<zona>/<zona>_map.png` (cliente): mapa do Menu ([CLI-11]) visto de cima, 1 pixel = MAP_STEP m de
   −MAP_HALF a +MAP_HALF: cor da face mais alta de tudo o que se vê no centro de cada pixel.
4. `src/zones/maps/<zona>.json` (servidor): os cilindros da coleção `NPCs e zumbis`. Com Custom Property `nivel` =
   monstro (`tipo`, `ataque` melee/ranged, `nivel`, `alcance_reset`, `percepcao`); com `(id)` no nome = NPC de teste
   de `zones.ts` naquele lugar (ex. "Saco de pancadas (test_bag)").

Imprime `EXPORTADO <caminho> ...`, `AVISO ...` e `ERRO ...`.
ATENÇÃO: grade da altura = ZoneTerrain (mmo-client/scripts/world/zone_terrain.gd); mapa = ZoneMap
(scripts/ui/zone_map.gd); JSON = parseZoneMap (mmo-server/src/zones/zoneMap.ts).
"""
import json
import math
import os
import re
import struct
import sys
import zlib

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

VISUAL_COLLECTIONS = ("Jogo hoje",)
TERRAIN_COLLECTION = "Terreno"
COLLIDE_COLLECTION = "Objetos"
MOBS_COLLECTION = "NPCs e zumbis"
GROUND_OBJECTS = ("jogo_chao", "jogo_praca")
COLLISION_SUFFIX = "_colisao"
## Grade da altura (m) e deslocamento (cm) para caber alturas negativas. ATENÇÃO: = ZoneTerrain.
HEIGHT_HALF = 160.0
HEIGHT_STEP = 0.5
HEIGHT_OFFSET_CM = 10000
## Mapa do Menu (m). ATENÇÃO: = ZoneMap.SHOW_HALF / METERS_PER_PIXEL.
MAP_HALF = 160.0
MAP_STEP = 2.0
## Área andável (m): monstro/NPC fora dela é erro. ATENÇÃO: = ZONE_HALF_SIZE do servidor.
WALK_HALF = 150.0
## Tipos e ataques aceitos nas Custom Properties do mob → kind do servidor.
MOB_TYPES = ("zumbi",)
ATTACK_KINDS = {"melee": "fighter", "ranged": "shooter"}
NPC_ID = re.compile(r"\(([a-z0-9_]+)\)\s*$")
SKY = 10000.0


def srgb(c: float) -> float:
    c = max(0.0, min(1.0, c))
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def material_color(mat) -> tuple:
    """Base Color (linear) do material; textura na Base Color → cor do Viewport Display."""
    if mat is None:
        return (1.0, 1.0, 1.0)
    if mat.use_nodes and mat.node_tree:
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is not None and not bsdf.inputs["Base Color"].is_linked:
            return tuple(bsdf.inputs["Base Color"].default_value[:3])
    return tuple(mat.diffuse_color[:3])


def collection_objects(name: str, recursive: bool) -> list:
    coll = bpy.data.collections.get(name)
    if coll is None:
        return []
    return list(coll.all_objects if recursive else coll.objects)


def visual_objects() -> list:
    found = []
    for name in VISUAL_COLLECTIONS:
        found += collection_objects(name, False)
    found += collection_objects(TERRAIN_COLLECTION, True)
    result = []
    for obj in found:
        if obj.name.endswith(COLLISION_SUFFIX) or obj in result:
            continue
        if obj.type != "MESH":
            if obj.type not in ("EMPTY", "CAMERA", "LIGHT"):
                print(f"AVISO {obj.name}: tipo {obj.type} não vai (só malhas; Ctrl+A > Convert to Mesh)")
            continue
        result.append(obj)
    return result


def ground_objects() -> list:
    result = [bpy.data.objects[n] for n in GROUND_OBJECTS if bpy.data.objects.get(n) is not None]
    result += [o for o in collection_objects(TERRAIN_COLLECTION, False)
               if o.type == "MESH" and not o.name.endswith(COLLISION_SUFFIX) and o not in result]
    return result


def world_mesh(obj, depsgraph) -> bpy.types.Mesh:
    """Cópia da malha avaliada (modificadores aplicados) no espaço do mundo."""
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), preserve_all_data_layers=True,
                                           depsgraph=depsgraph)
    mesh.transform(obj.matrix_world)
    if obj.matrix_world.determinant() < 0.0:
        mesh.flip_normals()
    return mesh


def face_colors(mesh: bpy.types.Mesh) -> list:
    """Cor linear de cada canto (loop): cor do vértice × Base Color do material da face."""
    attr = mesh.color_attributes.active_color
    mats = [material_color(m) for m in mesh.materials] or [(1.0, 1.0, 1.0)]
    colors = [None] * len(mesh.loops)
    for poly in mesh.polygons:
        base = mats[min(poly.material_index, len(mats) - 1)]
        for li in poly.loop_indices:
            if attr is None:
                vc = (1.0, 1.0, 1.0)
            elif attr.domain == "CORNER":
                vc = attr.data[li].color[:3]
            else:
                vc = attr.data[mesh.loops[li].vertex_index].color[:3]
            colors[li] = (vc[0] * base[0], vc[1] * base[1], vc[2] * base[2])
    return colors


def bake_for_export(obj, depsgraph, material) -> bpy.types.Object:
    """Objeto temporário: malha no mundo, faces flat, uma cor por canto ("Col"), um material só."""
    mesh = world_mesh(obj, depsgraph)
    colors = face_colors(mesh)
    for name in [a.name for a in mesh.color_attributes]:
        mesh.color_attributes.remove(mesh.color_attributes[name])
    col = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for li, c in enumerate(colors):
        col.data[li].color = (c[0], c[1], c[2], 1.0)
    mesh.color_attributes.active_color = col
    mesh.color_attributes.render_color_index = 0
    for poly in mesh.polygons:
        poly.use_smooth = False
    mesh.materials.clear()
    mesh.materials.append(material)
    temp = bpy.data.objects.new("zona_" + obj.name, mesh)
    bpy.context.scene.collection.objects.link(temp)
    return temp


def export_glb(objects: list, path: str) -> int:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    material = bpy.data.materials.new("zona_cor_por_vertice")
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in bpy.context.selected_objects:
        o.select_set(False)
    temps = [bake_for_export(o, depsgraph, material) for o in objects]
    for t in temps:
        t.select_set(True)
    tris = sum(sum(len(p.vertices) - 2 for p in t.data.polygons) for t in temps)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_normals=True, export_vertex_color="ACTIVE",
                              export_materials="EXPORT", export_texcoords=False, export_animations=False)
    return tris


class Caster:
    """Raio de cima para baixo nas malhas dadas: altura e cor (sRGB 0..255) da face mais alta."""

    def __init__(self, objects: list, with_colors: bool) -> None:
        depsgraph = bpy.context.evaluated_depsgraph_get()
        self.trees = []
        for obj in objects:
            mesh = world_mesh(obj, depsgraph)
            colors = None
            if with_colors:
                loops = face_colors(mesh)
                colors = []
                for poly in mesh.polygons:
                    acc = [0.0, 0.0, 0.0]
                    for li in poly.loop_indices:
                        for k in range(3):
                            acc[k] += loops[li][k]
                    n = max(1, poly.loop_total)
                    colors.append(tuple(int(round(srgb(a / n) * 255)) for a in acc))
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bpy.data.meshes.remove(mesh)
            # FromBMesh devolve o índice da face do bmesh = do polígono (sem triangular antes).
            self.trees.append((BVHTree.FromBMesh(bm), colors))
            bm.free()

    def cast(self, x: float, y: float):
        best = None
        best_color = None
        for tree, colors in self.trees:
            hit = tree.ray_cast(Vector((x, y, SKY)), Vector((0.0, 0.0, -1.0)))
            if hit[0] is not None and (best is None or hit[0].z > best):
                best = hit[0].z
                best_color = colors[hit[2]] if colors is not None else None
        return best, best_color


def write_png(path: str, width: int, height: int, rows: list) -> None:
    """PNG RGB 8 bits sem nenhum filtro de cor (bytes exatos: a altura vai codificada neles)."""
    raw = b"".join(b"\x00" + bytes(row) for row in rows)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def export_height(path: str) -> tuple:
    caster = Caster(ground_objects(), False)
    side = int(round(HEIGHT_HALF * 2.0 / HEIGHT_STEP)) + 1
    rows = []
    low, high, missing = 1e9, -1e9, 0
    for j in range(side):
        z_game = -HEIGHT_HALF + j * HEIGHT_STEP
        row = bytearray()
        for i in range(side):
            x = -HEIGHT_HALF + i * HEIGHT_STEP
            h, _c = caster.cast(x, -z_game)
            if h is None:
                h = 0.0
                missing += 1
            low, high = min(low, h), max(high, h)
            v = max(0, min(65535, int(round(h * 100.0)) + HEIGHT_OFFSET_CM))
            row += bytes((v >> 8, v & 0xFF, 0))
        rows.append(row)
    write_png(path, side, side, rows)
    if missing:
        print(f"AVISO altura: {missing} ponto(s) sem chão embaixo (ficaram em 0 m)")
    return side, low, high


def export_map(objects: list, path: str) -> int:
    caster = Caster(objects, True)
    side = int(round(MAP_HALF * 2.0 / MAP_STEP))
    rows = []
    for j in range(side):
        z_game = -MAP_HALF + (j + 0.5) * MAP_STEP
        row = bytearray()
        for i in range(side):
            x = -MAP_HALF + (i + 0.5) * MAP_STEP
            _h, color = caster.cast(x, -z_game)
            row += bytes(color if color is not None else (20, 24, 30))
        rows.append(row)
    write_png(path, side, side, rows)
    return side


def read_mobs() -> tuple:
    """Monstros e NPCs de teste dos cilindros da coleção de mobs. Erro de dado → lista de erros (não exporta)."""
    monsters, npcs, errors = [], [], []
    for obj in sorted(collection_objects(MOBS_COLLECTION, False), key=lambda o: o.name):
        if obj.type != "MESH":
            continue
        x = round(obj.matrix_world.translation.x, 2)
        z = round(-obj.matrix_world.translation.y, 2)
        if abs(x) > WALK_HALF or abs(z) > WALK_HALF:
            errors.append(f"{obj.name}: fora da área andável (±{WALK_HALF:.0f} m): x {x}, z {z}")
            continue
        if "nivel" in obj:
            kind = str(obj.get("tipo", "")).strip().lower()
            attack = str(obj.get("ataque", "")).strip().lower()
            level = obj.get("nivel")
            reset = obj.get("alcance_reset")
            perception = obj.get("percepcao")
            if kind not in MOB_TYPES:
                errors.append(f"{obj.name}: tipo '{kind}' desconhecido (aceitos: {', '.join(MOB_TYPES)})")
            elif attack not in ATTACK_KINDS:
                errors.append(f"{obj.name}: ataque '{attack}' (use melee ou ranged)")
            elif not isinstance(level, int) or level < 0:
                errors.append(f"{obj.name}: nivel precisa ser inteiro, 0 ou mais ({level})")
            elif not all(isinstance(v, (int, float)) and v > 0 for v in (reset, perception)):
                errors.append(f"{obj.name}: alcance_reset e percepcao precisam ser maiores que 0")
            else:
                monsters.append({"kind": ATTACK_KINDS[attack], "level": level, "x": x, "z": z,
                                 "resetRange": round(float(reset), 2), "perception": round(float(perception), 2)})
            continue
        match = NPC_ID.search(obj.name)
        if match is not None:
            npcs.append({"id": match.group(1), "x": x, "z": z})
        elif not obj.name.startswith("txt_"):
            print(f"AVISO {obj.name}: sem Custom Properties de mob nem (id) de NPC no nome: ignorado")
    # Id estável e legível: zombie_<nível>_<n>, ordenado por nível e posição.
    monsters.sort(key=lambda m: (m["level"], m["z"], m["x"]))
    count = {}
    for m in monsters:
        count[m["level"]] = count.get(m["level"], 0) + 1
        m["id"] = f"zombie_{m['level']}_{count[m['level']]}"
    seen = set()
    for n in npcs:
        if n["id"] in seen:
            errors.append(f"NPC {n['id']} aparece duas vezes")
        seen.add(n["id"])
    ordered = [{"id": m["id"], "kind": m["kind"], "level": m["level"], "x": m["x"], "z": m["z"],
                "resetRange": m["resetRange"], "perception": m["perception"]} for m in monsters]
    return ordered, sorted(npcs, key=lambda n: n["id"]), errors


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:]
    client, server, zone = argv[0], argv[1], argv[2]
    monsters, npcs, errors = read_mobs()
    if errors:
        for e in errors:
            print("ERRO " + e)
        sys.exit(1)
    collide = [o for o in collection_objects(COLLIDE_COLLECTION, True) if o.type == "MESH"]
    if collide:
        print(f"AVISO {len(collide)} objeto(s) em '{COLLIDE_COLLECTION}': a colisão ainda não existe no jogo "
              "(vão só como visual)")
    out = os.path.join(client, "assets", "zones", zone)
    os.makedirs(out, exist_ok=True)
    objects = visual_objects()
    glb = os.path.join(out, f"{zone}.glb")
    tris = export_glb(objects, glb)
    print(f"EXPORTADO {glb} {len(objects)} malhas, {tris} triângulos: {', '.join(o.name for o in objects)}")
    height = os.path.join(out, f"{zone}_height.png")
    side, low, high = export_height(height)
    print(f"EXPORTADO {height} {side}x{side}, chão de {low:.2f} a {high:.2f} m")
    map_png = os.path.join(out, f"{zone}_map.png")
    print(f"EXPORTADO {map_png} {export_map(objects, map_png)} px")
    data_dir = os.path.join(server, "src", "zones", "maps")
    os.makedirs(data_dir, exist_ok=True)
    data = os.path.join(data_dir, f"{zone}.json")
    with open(data, "w", encoding="utf-8") as f:
        json.dump({"monsters": monsters, "npcs": npcs}, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"EXPORTADO {data} {len(monsters)} monstros, {len(npcs)} NPCs ({', '.join(n['id'] for n in npcs)})")


main()
