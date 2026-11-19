#!/usr/bin/env bash
# Abre o projeto no editor do Godot (solto do terminal). Ver mmo-docs [CLI-01].
# Uso: comandos/open-editor/linux.sh   (de qualquer pasta)
set -euo pipefail
cd "$(dirname "$0")/../.."

GODOT="${GODOT_PATH:-godot}"
command -v "$GODOT" >/dev/null 2>&1 || { echo "Godot não encontrado. Rode: comandos/setup-linux.sh"; exit 1; }

nohup "$GODOT" --path . --editor >/dev/null 2>&1 &
echo "Editor do Godot abrindo..."
