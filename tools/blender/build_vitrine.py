#!/usr/bin/env python3
"""Monta a vitrine no testes.blend ([ART-09]): "cria um male e um female vestindo cada classe".

Para cada classe (mago, cavaleiro, atirador, assassino, curandeiro) e corpo, um boneco vestido com as peças de
Itens/<conjunto>/<parte>, em escada na diagonal, com a arma da classe em pé ao lado (coleção `vitrine`). As roupas e
os corpos da vitrine são cópias ligadas: editar a malha numa muda a original (a que vai para o jogo).
Faltando peças em Itens, puxe antes: python3 tools/blender/item_to_blender.py <item_id>.
Blender aberto com o testes.blend: NÃO rodar (gravaria por cima; feche e salve antes).

Uso (da pasta mmo-client):  python3 tools/blender/build_vitrine.py
"""
import os
import shutil
import subprocess
import sys

CLIENT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORKSPACE = os.path.normpath(os.path.join(CLIENT, "..", "workspace-blender"))
INNER = os.path.join(CLIENT, "tools", "blender", "blender_build_vitrine.py")
WEAPONS = ["arcane_staff", "knight_sword", "ranger_crossbow", "assassin_daggers"]
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_items import blender_cmd  # noqa: E402


def main() -> None:
    out = os.path.join(WORKSPACE, "_tmp_armas")  # dentro da home: o Blender do Flatpak não enxerga /tmp
    os.makedirs(out, exist_ok=True)
    subprocess.run(["godot", "--path", CLIENT, "--headless", "--script", "res://tools/blender/weapons_to_glb.gd", "--", out]
                   + WEAPONS, capture_output=True, text=True, timeout=600)
    run = subprocess.run(blender_cmd() + ["-b", os.path.join(WORKSPACE, "testes.blend"), "--python", INNER, "--", out],
                         capture_output=True, text=True)
    for line in run.stdout.splitlines():
        if line.startswith(("VITRINE", "AVISO", "SALVO")):
            print(line)
    shutil.rmtree(out, ignore_errors=True)
    if "SALVO" not in run.stdout:
        print(run.stderr[-2000:])
        sys.exit("o .blend não foi salvo")


if __name__ == "__main__":
    main()
