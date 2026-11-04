"""Conta triângulos, vértices, materiais e texturas de modelos .glb (orçamento em mmo-docs [ART-05]).

Uso (da pasta mmo-client):
    python3 tools/count_triangles.py assets/items/*/*.glb
    python3 tools/count_triangles.py novo_item.glb      # conferir um modelo antes de colocar no jogo

Lê só o cabeçalho JSON do GLB (sem dependências). Malha usada por vários nós conta uma vez por nó.
"""
import json
import struct
import sys


def count(path: str) -> tuple[int, int, int, int]:
    """Devolve (triângulos, vértices, materiais, imagens) do arquivo .glb em [path]."""
    with open(path, "rb") as f:
        data = f.read()
    json_length = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + json_length])
    meshes = gltf.get("meshes", [])
    used = [node["mesh"] for node in gltf.get("nodes", []) if "mesh" in node] or list(range(len(meshes)))
    triangles = vertices = 0
    for mesh_index in used:
        for primitive in meshes[mesh_index]["primitives"]:
            if primitive.get("mode", 4) != 4:  # só listas de triângulos
                continue
            positions = gltf["accessors"][primitive["attributes"]["POSITION"]]["count"]
            indices = primitive.get("indices")
            triangles += (gltf["accessors"][indices]["count"] if indices is not None else positions) // 3
            vertices += positions
    return triangles, vertices, len(gltf.get("materials", [])), len(gltf.get("images", []))


if __name__ == "__main__":
    print("triâng.\tvért.\tmat.\ttext.\tarquivo")
    for file_path in sys.argv[1:]:
        tris, verts, mats, images = count(file_path)
        print(f"{tris}\t{verts}\t{mats}\t{images}\t{file_path}")
