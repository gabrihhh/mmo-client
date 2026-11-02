#!/usr/bin/env bash
# Publica uma atualização do jogo para UMA plataforma: exporta o .pck, coloca na pasta de updates do
# servidor e atualiza o manifesto (versão + 1). Os aparelhos baixam na próxima vez que abrirem o app.
# Ver mmo-docs [INFRA-08].
#
# Uso: tools/publish_update.sh <android|desktop> [pasta_de_updates]   (padrão: ../mmo-server/updates)
# Variável MIN_LAUNCHER_VERSION: versão mínima do APK exigida (padrão 1). Suba quando mudar o
# scripts/boot/updater.gd ou algo que só um APK novo traz (permissões, versão do Godot...).
set -euo pipefail

PLATFORM="${1:-}"
case "$PLATFORM" in
  android|desktop) ;;
  *) echo "Uso: $0 <android|desktop> [pasta_de_updates]"; exit 1 ;;
esac

cd "$(dirname "$0")/.."
UPDATES_DIR="$(realpath -m "${2:-../mmo-server/updates}")/$PLATFORM"
PRESET="game-$PLATFORM"
GODOT="${GODOT_PATH:-godot}"
MIN_LAUNCHER_VERSION="${MIN_LAUNCHER_VERSION:-1}"
OUT="build/game-$PLATFORM.pck"

mkdir -p build "$UPDATES_DIR"

# Versão atual = a do manifesto publicado (0 se ainda não houver).
current=0
if [[ -f "$UPDATES_DIR/manifest.json" ]]; then
  current="$(grep -o '"version": *[0-9]*' "$UPDATES_DIR/manifest.json" | grep -o '[0-9]*$')"
fi
version=$((current + 1))

echo "Exportando o pacote do jogo (preset $PRESET)..."
rm -f "$OUT"
"$GODOT" --path . --headless --export-pack "$PRESET" "$OUT" >/dev/null 2>&1 || true
[[ -s "$OUT" ]] || { echo "Falha: $OUT não foi gerado (rode o comando acima sem >/dev/null para ver o erro)."; exit 1; }

pack="game-$version.pck"
cp "$OUT" "$UPDATES_DIR/$pack"
sha="$(sha256sum "$UPDATES_DIR/$pack" | cut -d' ' -f1)"
size="$(stat -c %s "$UPDATES_DIR/$pack")"

# Escreve o manifesto num arquivo temporário e troca de uma vez (nunca fica meio escrito).
cat > "$UPDATES_DIR/manifest.json.tmp" <<JSON
{
  "version": $version,
  "url": "/updates/$PLATFORM/$pack",
  "sha256": "$sha",
  "size": $size,
  "minLauncherVersion": $MIN_LAUNCHER_VERSION
}
JSON
mv "$UPDATES_DIR/manifest.json.tmp" "$UPDATES_DIR/manifest.json"

# Mantém só a versão atual e a anterior.
find "$UPDATES_DIR" -name 'game-*.pck' ! -name "$pack" ! -name "game-$current.pck" -delete

echo "Publicado ($PLATFORM): versão $version ($pack, $size bytes, sha256 $sha)"
