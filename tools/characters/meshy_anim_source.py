"""Prepara um .glb de animação do Meshy (rig feito pela API) como fonte de animação do jogo ([ART-03]).

- Renomeia os ossos do rig da API do Meshy (Hips, Spine02, neck...) para os nomes Mixamo do rig do site
  (mixamorig:Hips, mixamorig:Spine...), para valer o mesmo assets/characters/mixamo_bone_map.tres.
  Atenção: na API a coluna é Hips → Spine02 → Spine01 → Spine (o "Spine" é o de cima).
- Tira texturas e materiais (o arquivo só serve para ler a animação; não vai no jogo).
- Com um clipe só, renomeia (ex.: "Armature|Idle|baselayer" → "Idle"); arquivo com vários clipes (meshy_animate com
  action_ids) mantém os nomes do Meshy (ex.: "Right_Hand_Sword_Slash").

Com `--keep-materials`: mantém textura e materiais — para usar o próprio MODELO rigado pela API como corpo do jogo
(ex.: o zumbi, assets/characters/zombie/zombie.glb, [ART-03]); os ossos ficam com os nomes Mixamo e o modelo importa
com o mesmo mixamo_bone_map.tres dos outros corpos.

Uso: python3 meshy_anim_source.py entrada.glb saida.glb [NomeDoClipe] [--keep-materials]
"""
import json
import struct
import sys

RENAME: dict[str, str] = {"Spine02": "Spine", "Spine01": "Spine1", "Spine": "Spine2", "neck": "Neck"}
BONES: list[str] = ["Hips", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder",
                    "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
                    "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]


def main(src: str, dst: str, clip: str | None, keep_materials: bool = False) -> None:
    data = open(src, "rb").read()
    json_len = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + json_len])
    bin_start = 20 + json_len + 8
    blob = data[bin_start:bin_start + struct.unpack("<I", data[20 + json_len:24 + json_len])[0]]

    joints = {doc["nodes"][i]["name"] for i in doc["skins"][0]["joints"]}
    for node in doc["nodes"]:
        name = node.get("name", "")
        if name in joints and (name in RENAME or name in BONES):
            node["name"] = "mixamorig:" + RENAME.get(name, name)
    if clip is not None:
        assert len(doc["animations"]) == 1, "nome de clipe só vale para arquivo com um clipe"
        doc["animations"][0]["name"] = clip
    print("clipes:", [a.get("name") for a in doc["animations"]])

    if not keep_materials:
        for key in ("images", "textures", "samplers", "materials"):
            doc.pop(key, None)
        for mesh in doc["meshes"]:
            for prim in mesh["primitives"]:
                prim.pop("material", None)

    # Refaz o buffer só com os bufferViews ainda usados.
    used = {a["bufferView"] for a in doc["accessors"] if "bufferView" in a}
    used |= {img["bufferView"] for img in doc.get("images", []) if "bufferView" in img}
    remap: dict[int, int] = {}
    views: list[dict] = []
    out = bytearray()
    for i, view in enumerate(doc["bufferViews"]):
        if i not in used:
            continue
        chunk = blob[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]]
        out += b"\0" * (-len(out) % 4)
        view = dict(view, byteOffset=len(out))
        out += chunk
        remap[i] = len(views)
        views.append(view)
    for acc in doc["accessors"]:
        if "bufferView" in acc:
            acc["bufferView"] = remap[acc["bufferView"]]
    for img in doc.get("images", []):
        if "bufferView" in img:
            img["bufferView"] = remap[img["bufferView"]]
    doc["bufferViews"] = views
    out += b"\0" * (-len(out) % 4)
    doc["buffers"] = [{"byteLength": len(out)}]

    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(out)
    with open(dst, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(out), b"BIN\0") + bytes(out))


if __name__ == "__main__":
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    main(args[0], args[1], args[2] if len(args) > 2 else None, "--keep-materials" in flags)
