#!/usr/bin/env python3
"""Puxa um item do jogo para o Blender ([ART-09]): "puxa o head do healer para o Blender".

Para cada corpo, monta o personagem no Godot com o item vestido, em repouso (tools/blender/item_to_glb.gd), e põe a
malha no .blend (tools/blender/blender_import_item.py) como `<slot>-<nome>-<corpo>` na coleção
Itens/<conjunto>/<slot>, exatamente onde o item fica no jogo (o masculino ao lado dele). Serve de base para remodelar;
depois volta com tools/blender/export_items.py. Objeto com o mesmo nome já no .blend não é tocado.

Blender aberto: o arquivo é alterado no disco; no Blender, File → Revert para ver (sem salvar antes, senão perde).

Uso (da pasta mmo-client):
  python3 tools/blender/item_to_blender.py healer_circlet            # os dois corpos
  python3 tools/blender/item_to_blender.py healer_circlet --body female
"""
import argparse
import os
import re
import subprocess
import sys

CLIENT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORKSPACE = os.path.normpath(os.path.join(CLIENT, "..", "workspace-blender"))
INNER = os.path.join(CLIENT, "tools", "blender", "blender_import_item.py")
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_items import blender_cmd  # noqa: E402


def item_folder(item_id: str) -> tuple:
    """(slot, nome) do item, pela tabela ItemModels._FOLDERS (res://assets/itens/<slot>/<nome>)."""
    src = open(os.path.join(CLIENT, "scripts", "items", "item_models.gd"), encoding="utf-8").read()
    match = re.search(r'"%s":\s*"res://assets/itens/([^/"]+)/([^/"]+)"' % re.escape(item_id), src)
    if match is None:
        sys.exit(f"item desconhecido: {item_id} (ver ItemModels._FOLDERS)")
    return match.group(1), match.group(2)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("item_id", help="id do item no jogo (ex.: healer_circlet)")
    parser.add_argument("--body", choices=["male", "female"], action="append", help="padrão: os dois")
    parser.add_argument("--blend", default=os.path.join(WORKSPACE, "testes.blend"))
    parser.add_argument("--set", dest="item_set", help="coleção do conjunto (padrão: o nome da pasta do item)")
    args = parser.parse_args()
    slot, name = item_folder(args.item_id)
    item_set = args.item_set or name.split("-")[0]
    pairs = []
    temps = []
    for body in args.body or ["female", "male"]:
        out = os.path.join(WORKSPACE, f"_tmp_{slot}-{name}-{body}.glb")
        run = subprocess.run(["godot", "--path", CLIENT, "--headless", "--script", "res://tools/blender/item_to_glb.gd",
                              "--", args.item_id, body, out], capture_output=True, text=True, timeout=600)
        if not os.path.exists(out):
            print(run.stdout[-1500:], run.stderr[-1500:])
            sys.exit(f"o Godot não exportou {args.item_id} ({body})")
        temps.append(out)
        pairs += [out, f"{slot}-{name}-{body}", body]
    run = subprocess.run(blender_cmd() + ["-b", os.path.abspath(args.blend), "--python", INNER, "--", item_set, slot] + pairs,
                         capture_output=True, text=True)
    for line in run.stdout.splitlines():
        if line.startswith(("IMPORTADO", "AVISO", "ERRO", "SALVO")):
            print(line)
    for t in temps:
        os.remove(t)
        if os.path.exists(t + ".import"):
            os.remove(t + ".import")
    if "SALVO" not in run.stdout:
        print(run.stderr[-2000:])
        sys.exit("o .blend não foi salvo")


if __name__ == "__main__":
    main()
