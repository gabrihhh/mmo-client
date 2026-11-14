#!/usr/bin/env python3
"""Leva o mapa do Blender para o jogo ([ART-10]): "puxa o spawn.blend pro jogo".

1. Blender (tools/blender/blender_export_zone.py, lê o arquivo SALVO; pode estar aberto) grava:
   - cliente `assets/zones/<zona>/<zona>.glb` (o que se vê), `<zona>_height.png` (altura do chão, lida pelo
     ZoneTerrain.height_at) e `<zona>_map.png` (mapa do Menu);
   - servidor `src/zones/maps/<zona>.json` (monstros com tipo/nível/alcances e onde ficam os NPCs de teste).
2. Deixa as duas imagens importadas como Image (sem compressão: a altura vai codificada nos bytes) e importa no Godot.

Com o servidor no ar (./run.sh), o `tsx watch` recarrega sozinho com os monstros novos.
Depois: rodar o jogo, commit nos dois repos, tools/publish_update.sh android, teste no aparelho e push.

Uso (da pasta mmo-client):
  python3 tools/blender/export_zone.py                       # ../workspace-blender/spawn.blend → zone_1
  python3 tools/blender/export_zone.py --blend outro.blend --zone zone_2
"""
import argparse
import os
import subprocess
import sys

from export_items import blender_cmd, godot_import

CLIENT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SERVER = os.path.normpath(os.path.join(CLIENT, "..", "mmo-server"))
DEFAULT_BLEND = os.path.normpath(os.path.join(CLIENT, "..", "workspace-blender", "spawn.blend"))
INNER = os.path.join(CLIENT, "tools", "blender", "blender_export_zone.py")
## Imagens lidas pelo código como Image (bytes exatos), não como textura comprimida.
IMAGE_IMPORT = '[remap]\n\nimporter="image"\ntype="Image"\n'


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--blend", default=DEFAULT_BLEND)
    parser.add_argument("--zone", default="zone_1")
    args = parser.parse_args()
    blend = os.path.abspath(args.blend)
    if not os.path.exists(blend):
        sys.exit(f"não achei {blend}")
    run = subprocess.run(blender_cmd() + ["-b", blend, "--python", INNER, "--", CLIENT, SERVER, args.zone],
                         capture_output=True, text=True)
    exported = 0
    for line in run.stdout.splitlines():
        if line.startswith(("EXPORTADO", "AVISO", "ERRO")):
            print(line.replace(CLIENT + "/", "").replace(SERVER + "/", "mmo-server/"))
        exported += line.startswith("EXPORTADO")
    if run.returncode != 0 or exported < 4:
        print(run.stderr[-3000:])
        sys.exit("mapa NÃO exportado")
    folder = os.path.join(CLIENT, "assets", "zones", args.zone)
    for name in (f"{args.zone}_height.png", f"{args.zone}_map.png"):
        imp = os.path.join(folder, name + ".import")
        if not os.path.exists(imp) or 'importer="image"' not in open(imp, encoding="utf-8").read():
            with open(imp, "w", encoding="utf-8") as f:
                f.write(IMAGE_IMPORT)
    godot_import()
    print("Mapa no jogo. Rodar o jogo para conferir; publicar: tools/publish_update.sh android")


if __name__ == "__main__":
    main()
