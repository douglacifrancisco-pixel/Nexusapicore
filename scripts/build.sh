#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANGLE="$ROOT/Angle"
LTW="$ROOT/ltw_source"
OUT="$ROOT/output"

ANGLE_REPO="https://github.com/douglacifrancisco-pixel/Angle.git"
LTW_REPO="https://github.com/douglacifrancisco-pixel/LTW-to-angle-vulkan-.git"
LTW_BRANCH="feature/angle-vulkan-integration"

: "${ANDROID_NDK:=${ANDROID_NDK_HOME:-}}"

if [ -z "$ANDROID_NDK" ]; then
    echo "ERRO: ANDROID_NDK não está definido."
    exit 1
fi

echo "==> Nexusapicore"
echo "==> NDK: $ANDROID_NDK"

rm -rf "$ANGLE" "$LTW" "$ROOT/build_output"
mkdir -p "$OUT"

echo "==> Clonando ANGLE..."
git clone --recursive "$ANGLE_REPO" "$ANGLE"

echo "==> Clonando LTW..."
git clone --recursive --branch "$LTW_BRANCH" "$LTW_REPO" "$LTW"

echo "==> Configurando ANGLE..."
cd "$ANGLE"

gn gen out/Static --args='import("//args/android_arm64_static.gn")'

echo "==> Compilando ANGLE..."
autoninja -C out/Static libEGL libGLESv2 libANGLE

echo "==> Verificando ANGLE..."
test -f out/Static/libEGL.a
test -f out/Static/libGLESv2.a
test -f out/Static/libANGLE.a

echo "==> Preparando LTW..."
cp -a "$LTW/ltw/src/main/tinywrapper" "$ROOT/build_output"

echo "==> Procurando integração estática..."
HEADER="$(find "$ANGLE" -name angle_static_integration.h -print -quit)"

if [ -z "$HEADER" ]; then
    echo "ERRO: angle_static_integration.h não encontrado."
    exit 1
fi

cp "$HEADER" "$ROOT/build_output/tinywrapper/"

echo "==> Build preparado."
echo "==> ANGLE: $ANGLE/out/Static"
echo "==> LTW:   $ROOT/build_output/tinywrapper"

echo
echo "ATENÇÃO:"
echo "A etapa de link final depende das dependências estáticas geradas pelo ANGLE."
echo "Por segurança, o script para aqui em vez de gerar uma lib incorreta."
