#!/usr/bin/env bash
# Abre o jogo numa janela de teste no PC. Ver mmo-docs [CLI-05].
#
# Uso: comandos/run-game/linux.sh [Nome] [argumentos extras do jogo]   (de qualquer pasta)
#   sem Nome   → abre na tela de login, como um jogador normal
#   com Nome   → entra direto como a conta de teste "Nome" (cria se não existir), com perfil próprio:
#                dá para abrir várias janelas ao mesmo tempo, uma por nome, sem uma derrubar a outra.
# Exemplos:
#   comandos/run-game/linux.sh
#   comandos/run-game/linux.sh Ana
#   comandos/run-game/linux.sh Bia --bot-fight=espada
# O servidor precisa estar no ar: ../mmo-server/comandos/start-server/linux.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

GODOT="${GODOT_PATH:-godot}"
command -v "$GODOT" >/dev/null 2>&1 || { echo "Godot não encontrado. Rode: comandos/setup-linux.sh"; exit 1; }

if ! curl -fs -m 2 http://localhost:2567/health >/dev/null 2>&1; then
  echo "AVISO: servidor local não respondeu (http://localhost:2567/health). Ligue: ../mmo-server/comandos/start-server/linux.sh"
fi

game_args=()
if [[ $# -gt 0 && "$1" != -* ]]; then
  game_args+=("--profile=$1" "--dev-user=$1")
  shift
fi
game_args+=("$@")

if (( ${#game_args[@]} > 0 )); then
  exec "$GODOT" --path . -- "${game_args[@]}"
fi
exec "$GODOT" --path .
