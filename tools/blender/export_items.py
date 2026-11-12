#!/usr/bin/env python3
"""Leva para o jogo as peças sob medida feitas no Blender ([ART-08]): "coloca no jogo o chest-healer-female".

1. Exporta do .blend (padrão: ../workspace-blender/testes.blend) cada peça da coleção "Itens" chamada
   `<slot>-<nome>-<male|female>` para `assets/itens/<slot>/<nome>/<corpo>/<slot>-<nome>.glb`; sem o corpo no nome
   (`hand-healer`) vai para a pasta de todos os corpos, no espaço do próprio objeto. Shape keys viram blend shapes.
   (tools/blender/blender_export_items.py, roda dentro do Blender: cores pelos materiais, furos tapados).
2. Apaga o que sobrou da malha antiga na pasta do corpo (a cena `<slot>-<nome>.tscn` e texturas `<slot>-<nome>_*`):
   com a cena lá o jogo continuaria usando a malha antiga ([ART-08], `ItemModels.is_tailored`).
3. Importa no Godot e deixa a paleta (`<slot>-<nome>_palette.png`, N×1 pixels) sem compressão nem filtro: comprimida, as
   cores vizinhas se misturam. Apaga paletas antigas de exportações anteriores.

O Blender precisa estar FECHADO? Não: só lê o arquivo salvo (o que não foi salvo não vai). Peça nova de um item
que ainda não tem pasta → criar o item primeiro ([ART-08]).
Depois: conferir com tools/placeholders/preview_fit.gd, commit, tools/publish_update.sh android.

Uso (da pasta mmo-client):
  python3 tools/blender/export_items.py                         # todas as peças
  python3 tools/blender/export_items.py chest-healer-female     # só essas
  python3 tools/blender/export_items.py --blend outro.blend chest-healer-male
"""
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys

CLIENT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ITENS = os.path.join(CLIENT, "assets", "itens")
DEFAULT_BLEND = os.path.normpath(os.path.join(CLIENT, "..", "workspace-blender", "testes.blend"))
INNER = os.path.join(CLIENT, "tools", "blender", "blender_export_items.py")


def blender_cmd() -> list:
    """Blender instalado direto ou pelo Flatpak (o do Pop!_OS); o Flatpak não enxerga /tmp: caminhos ficam na home."""
    if shutil.which("blender"):
        return ["blender"]
    return ["flatpak", "run", "org.blender.Blender"]


def fix_palette(glb: str) -> bool:
    """Paleta do .glb glb: sem compressão (mode 0) e sem limite de tamanho; apaga paletas antigas."""
    base = os.path.splitext(glb)[0]
    keep = base + "_palette.png"
    for old in glob.glob(base + "_*.png") + glob.glob(base + "_*.jpg"):
        if old != keep:
            for f in (old, old + ".import"):
                if os.path.exists(f):
                    os.remove(f)
                    print(f"apagado {os.path.relpath(f, CLIENT)}")
    imp = keep + ".import"
    if not os.path.exists(imp):
        print(f"AVISO {os.path.relpath(imp, CLIENT)} não foi criado pelo Godot")
        return False
    text = open(imp, encoding="utf-8").read()
    new = re.sub(r"^compress/mode=.*$", "compress/mode=0", text, flags=re.M)
    new = re.sub(r"^process/size_limit=.*$", "process/size_limit=0", new, flags=re.M)
    new = re.sub(r"^mipmaps/generate=.*$", "mipmaps/generate=false", new, flags=re.M)
    if new != text:
        open(imp, "w", encoding="utf-8").write(new)
        return True
    return False


def godot_import() -> None:
    subprocess.run(["godot", "--path", CLIENT, "--headless", "--editor", "--quit"], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("names", nargs="*", help="objetos do Blender (<slot>-<nome>-<corpo>); vazio = todos")
    parser.add_argument("--blend", default=DEFAULT_BLEND)
    args = parser.parse_args()
    blend = os.path.abspath(args.blend)
    if not os.path.exists(blend):
        sys.exit(f"não achei {blend}")
    run = subprocess.run(blender_cmd() + ["-b", blend, "--python", INNER, "--", ITENS] + args.names,
                         capture_output=True, text=True)
    exported = []
    for line in run.stdout.splitlines():
        if line.startswith(("EXPORTADO", "AVISO", "ERRO")):
            print(line.replace(CLIENT + "/", ""))
        if line.startswith("EXPORTADO"):
            exported.append(line.split()[1])
    if run.returncode != 0 or not exported:
        print(run.stderr[-2000:])
        sys.exit("nada exportado")
    for glb in exported:
        # Malha antiga (Meshy) com cena .tscn: sem apagar, o jogo continua usando ela.
        scene = os.path.splitext(glb)[0] + ".tscn"
        if os.path.exists(scene):
            os.remove(scene)
            print(f"apagado {os.path.relpath(scene, CLIENT)} (malha antiga)")
    godot_import()
    changed = False
    for glb in exported:
        changed = fix_palette(glb) or changed
    if changed:
        godot_import()
    print(f"{len(exported)} peça(s) no jogo. Conferir: tools/placeholders/preview_fit.gd; publicar: tools/publish_update.sh android")


if __name__ == "__main__":
    main()
