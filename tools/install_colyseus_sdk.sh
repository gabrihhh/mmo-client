#!/usr/bin/env bash
# Baixa e instala o SDK oficial do Colyseus para Godot em addons/colyseus.
# A versão é fixada para bater com o servidor (mmo-server usa colyseus ^0.18).
#
# Uso: tools/install_colyseus_sdk.sh
# Windows: baixe o .zip manualmente (URL abaixo) e extraia a pasta "addons" na raiz do projeto.
set -euo pipefail

VERSION="0.18.9"
URL="https://github.com/colyseus/native-sdk/releases/download/godot-v${VERSION}/colyseus-godot-${VERSION}.zip"

cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Baixando Colyseus Godot SDK ${VERSION}..."
curl -fL --progress-bar -o "$tmp/sdk.zip" "$URL"
unzip -q "$tmp/sdk.zip" -d "$tmp/x"

rm -rf addons/colyseus
mkdir -p addons
mv "$tmp/x/addons/colyseus" addons/colyseus
echo "Instalado em addons/colyseus (versão $(grep -o '[0-9.]*' addons/colyseus/version.json))."
