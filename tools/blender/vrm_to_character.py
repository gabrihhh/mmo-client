#!/usr/bin/env python3
"""Personagem do VRoid Studio (.vrm) → corpo do jogo ([ART-12]).

    python3 tools/blender/vrm_to_character.py <arquivo.vrm> <male|female> [--tris N] [--saida pasta]

Lê o mapa humanoide do VRM (VRM 0.x ou 1.0), roda o Blender (`blender_vrm_to_character.py`) e grava
`<saida>/<corpo>.glb` (padrão: assets/characters/<corpo>_anime/): esqueleto Mixamo de 24 ossos, uma malha, origem nos
pés, olhando para +Z, na MESMA altura do corpo atual (masculino 1,80 m, feminino 1,75 m) e com no máximo N triângulos.
"""
import argparse
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

CLIENT = Path(__file__).resolve().parents[2]
WORK = CLIENT.parent / "workspace-blender" / ".tmp_claude"
# Altura (m) do corpo atual de cada tipo: o novo fica igual (câmera, alcance e mapa não mudam).
HEIGHT = {"male": 1.80, "female": 1.75}
# Teto padrão de triângulos do corpo inteiro (sem roupas/itens); ver [ART-05].
DEFAULT_TRIS = 6000


def humanoid_bones(vrm: Path) -> dict[str, str]:
    """Mapa osso humanoide → nome do nó, do JSON do glTF (VRMC_vrm 1.0 ou VRM 0.x)."""
    data = vrm.read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + length])
    ext = gltf.get("extensions", {})
    nodes = gltf["nodes"]
    if "VRMC_vrm" in ext:
        bones = ext["VRMC_vrm"]["humanoid"]["humanBones"]
        return {k: nodes[v["node"]]["name"] for k, v in bones.items()}
    if "VRM" in ext:
        return {b["bone"]: nodes[b["node"]]["name"] for b in ext["VRM"]["humanoid"]["humanBones"] if b.get("node", -1) >= 0}
    raise SystemExit("ERRO: o arquivo não é VRM (sem extensão VRMC_vrm/VRM)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("vrm", type=Path)
    parser.add_argument("body", choices=sorted(HEIGHT))
    parser.add_argument("--tris", type=int, default=DEFAULT_TRIS)
    parser.add_argument("--saida", type=Path)
    args = parser.parse_args()
    out_dir = (args.saida or CLIENT / "assets" / "characters" / f"{args.body}_anime").resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    # O Blender só aceita .glb; o VRM é um glb com extensões a mais.
    glb = WORK / f"vrm_{args.body}.glb"
    shutil.copyfile(args.vrm, glb)
    humanoid = WORK / f"vrm_{args.body}.json"
    humanoid.write_text(json.dumps({"bones": humanoid_bones(args.vrm)}))
    out = out_dir / f"{args.body}.glb"
    script = Path(__file__).resolve().parent / "blender_vrm_to_character.py"
    result = subprocess.run(["blender", "-b", "--python", str(script), "--", str(glb), str(humanoid), str(out),
                             str(HEIGHT[args.body]), str(args.tris)], capture_output=True, text=True)
    lines = [l for l in result.stdout.splitlines() + result.stderr.splitlines()
             if l.startswith(("VRM→", "SALVO", "ERRO")) or "Error" in l]
    print("\n".join(lines))
    if result.returncode != 0 or not out.exists():
        sys.exit(1)


if __name__ == "__main__":
    main()
