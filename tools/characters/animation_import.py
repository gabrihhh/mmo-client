#!/usr/bin/env python3
"""Escreve o .import das animações próprias de habilidade (res://assets/itens/*/*/animation-*/{male,female}.glb, [ART-08]).

O tools/characters/make_animations.gd só entende animações com os ossos no perfil humanoide do Godot (Hips, Spine,
LeftUpperArm...). Para isso o .glb precisa ser importado com o mapa de ossos dos rigs Mixamo/Meshy
(assets/characters/mixamo_bone_map.tres). Este script copia as configurações de importação de uma animação que já
funciona (tools/characters/animations/male_idle.glb.import) para cada .glb dessas pastas que ainda não tem o mapa.

Antes: o .glb do Meshy (rig da API) passa por tools/characters/meshy_anim_source.py (nomes Mixamo, nó
Armature/Skeleton3D); o do site do Mixamo já vem assim. Depois: importar no Godot
(godot --path . --headless --editor --quit) e rodar o make_animations.gd.

Uso (da pasta mmo-client):  python3 tools/characters/animation_import.py
"""
import glob
import os
import re

CLIENT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEMPLATE = os.path.join(CLIENT, "tools/characters/animations/male_idle.glb.import")
BONE_MAP = "retarget/bone_map"


def main() -> None:
    template = open(TEMPLATE, encoding="utf-8").read()
    # Sem uid nem arquivos importados: o Godot gera os da cópia nova.
    template = re.sub(r'^(uid|path|dest_files)=.*\n', "", template, flags=re.M)
    written = 0
    for glb in sorted(glob.glob(os.path.join(CLIENT, "assets/itens/*/*/animation-*/*.glb"))):
        target = glb + ".import"
        if os.path.exists(target) and BONE_MAP in open(target, encoding="utf-8").read():
            continue
        res_path = "res://" + os.path.relpath(glb, CLIENT).replace(os.sep, "/")
        text = re.sub(r'^source_file=.*$', f'source_file="{res_path}"', template, flags=re.M)
        with open(target, "w", encoding="utf-8") as f:
            f.write(text)
        written += 1
        print(f"escrito {os.path.relpath(target, CLIENT)}")
    print(f"{written} arquivo(s) .import escritos")


if __name__ == "__main__":
    main()
