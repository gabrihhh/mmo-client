#!/usr/bin/env bash
# Gera o APK (instalador) em build/mmo.apk e, se houver um aparelho no adb, instala.
# O APK só leva a tela do atualizador; o jogo vem do servidor (tools/publish_update.sh android).
# Ver mmo-docs [CLI-06] e [INFRA-08].
#
# Uso: tools/build_apk.sh [--install]
# Assinado com a keystore de DEBUG desta máquina (Editor Settings > Export > Android).
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT_PATH:-godot}"
OUT="build/mmo.apk"
mkdir -p build
rm -f "$OUT"

echo "Gerando $OUT (preset android-launcher)..."
"$GODOT" --path . --headless --export-debug android-launcher "$OUT" 2>&1 | grep -E "^ERROR" | grep -v "project icon" || true
[[ -s "$OUT" ]] || { echo "Falha: $OUT não foi gerado. Rode sem filtro para ver o erro:"; echo "  $GODOT --path . --headless --export-debug android-launcher $OUT"; exit 1; }
echo "APK: $OUT ($(du -h "$OUT" | cut -f1))"

if [[ "${1:-}" == "--install" ]]; then
  adb install -r "$OUT"
fi
