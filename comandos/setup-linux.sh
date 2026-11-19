#!/usr/bin/env bash
# Prepara uma máquina Linux para rodar o cliente do jogo (rodar uma vez; pode repetir sem medo).
# Ver mmo-docs [IA-03] e [CLI-01].
#
# Uso: comandos/setup-linux.sh   (de qualquer pasta; pede sudo para instalar pacotes)
#   1. pacotes básicos (curl, unzip) — apt (Ubuntu/Debian)
#   2. Godot 4.7.2 padrão (não .NET) em ~/.local/share/godot, atalho `godot` em ~/.local/bin
#      e GODOT_PATH no ~/.bashrc (usado pelos scripts e pelo MCP do Godot)
#   3. importa o projeto (gera a pasta .godot e acusa erros de script)
# Não inclui o que só quem gera APK precisa (JDK 17, Android SDK, export templates): ver [CLI-06].
# Depois: comandos/run-game/linux.sh   (o servidor precisa estar no ar: ../mmo-server/comandos/start-server/linux.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT_VERSION="4.7.2"
GODOT_DIR="$HOME/.local/share/godot"
GODOT_BIN="$GODOT_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"

step() { echo; echo "=== $* ==="; }

## True se o executável $1 é o Godot da versão certa.
is_right_godot() { [[ -x "$1" ]] && "$1" --version 2>/dev/null | grep -q "^${GODOT_VERSION}\.stable"; }

# --- 1. Pacotes básicos ---
step "1/3 Pacotes básicos"
if command -v apt-get >/dev/null 2>&1; then
  missing=()
  for pkg in curl unzip; do dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg"); done
  if (( ${#missing[@]} > 0 )); then
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
  else
    echo "ok"
  fi
else
  command -v curl >/dev/null && command -v unzip >/dev/null || { echo "Instale curl e unzip e rode de novo."; exit 1; }
fi

# --- 2. Godot ---
step "2/3 Godot ${GODOT_VERSION}"
godot_now="${GODOT_PATH:-$(command -v godot || true)}"
if [[ -n "$godot_now" ]] && is_right_godot "$godot_now"; then
  GODOT="$godot_now"
  echo "Já instalado: $GODOT"
else
  if ! is_right_godot "$GODOT_BIN"; then
    echo "Baixando $GODOT_URL ..."
    mkdir -p "$GODOT_DIR"
    tmp_zip="$(mktemp --suffix=.zip)"
    curl -fL "$GODOT_URL" -o "$tmp_zip"
    unzip -o -q "$tmp_zip" -d "$GODOT_DIR"
    rm -f "$tmp_zip"
    chmod +x "$GODOT_BIN"
  fi
  GODOT="$GODOT_BIN"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$GODOT" "$HOME/.local/bin/godot"
  echo "Instalado: $GODOT (atalho: ~/.local/bin/godot)"
fi
if ! grep -q "GODOT_PATH=" "$HOME/.bashrc" 2>/dev/null; then
  echo "export GODOT_PATH=\"$GODOT\"" >> "$HOME/.bashrc"
  echo "GODOT_PATH gravado no ~/.bashrc (abra um terminal novo para valer)."
fi
export GODOT_PATH="$GODOT"

# --- 3. Importar o projeto ---
step "3/3 Importando o projeto (pode demorar na primeira vez)"
"$GODOT" --path . --headless --editor --quit 2>&1 | grep -E "^(ERROR|SCRIPT ERROR)" || echo "ok, sem erros"

echo
echo "Pronto! Abrir o jogo: comandos/run-game/linux.sh   |   abrir o editor: comandos/open-editor/linux.sh"
