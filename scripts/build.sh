#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANGLE="$ROOT/Angle"
LTW="$ROOT/ltw"
OUT="$ROOT/output"

ANGLE_REPO="https://github.com/douglacifrancisco-pixel/Angle.git"
LTW_REPO="https://github.com/douglacifrancisco-pixel/LTW-to-angle-vulkan-.git"
LTW_BRANCH="feature/angle-vulkan-integration"

echo "============================================================"
echo " Nexusapicore"
echo "============================================================"
echo "ROOT:  $ROOT"
echo "ANGLE: $ANGLE"
echo "LTW:   $LTW"
echo

rm -rf "$OUT"
mkdir -p "$OUT"

# ------------------------------------------------------------
# 1. depot_tools
# ------------------------------------------------------------

if ! command -v gclient >/dev/null 2>&1; then
    echo "ERRO: gclient não encontrado."
    echo "depot_tools precisa estar no PATH."
    exit 1
fi

if ! command -v gn >/dev/null 2>&1; then
    echo "ERRO: gn não encontrado."
    exit 1
fi

if ! command -v autoninja >/dev/null 2>&1; then
    echo "ERRO: autoninja não encontrado."
    exit 1
fi

# ------------------------------------------------------------
# 2. ANGLE
#
# IMPORTANTE:
# Não usar --recursive.
# Não usar git submodule update --init --recursive.
#
# As dependências são controladas pelo DEPS/gclient.
# checkout_angle_internal permanece FALSE, portanto:
# third_party/gles1_conform NÃO será baixado.
# ------------------------------------------------------------

if [ ! -d "$ANGLE/.git" ]; then
    echo "== Clonando ANGLE sem submodules =="

    git clone \
        --depth 1 \
        --filter=blob:none \
        --no-tags \
        "$ANGLE_REPO" \
        "$ANGLE"
else
    echo "== ANGLE já existe =="
fi

# ------------------------------------------------------------
# 3. Configurar gclient
# ------------------------------------------------------------

echo "== Configurando gclient =="

cat > "$ROOT/.gclient" <<GCLIENT
solutions = [
  {
    "name": "Angle",
    "url": "$ANGLE_REPO",
    "managed": False,
    "custom_deps": {},
    "custom_vars": {
      "checkout_angle_internal": False,
      "checkout_angle_mesa": False,
      "checkout_angle_partition_alloc": False,
      "checkout_angle_cl_deps": False,
      "checkout_angle_dawn_deps": False,
      "checkout_angle_restricted_traces": False,
      "checkout_extra_traces": False,
    },
  },
]

target_os = ["android"]
GCLIENT

cd "$ROOT"

echo "== Sincronizando dependências públicas do ANGLE =="
echo "== checkout_angle_internal = FALSE =="

gclient sync \
    --no-history \
    --shallow

# ------------------------------------------------------------
# 4. Segurança adicional:
# garantir que o submodule privado não seja registrado como
# dependência ativa.
# ------------------------------------------------------------

cd "$ANGLE"

if git config -f .gitmodules --get-regexp "^submodule\\..*\\.path$" \
    | grep -q "third_party/gles1_conform$"; then

    echo "== Confirmado: gles1_conform existe no .gitmodules =="
    echo "== Mas checkout_angle_internal está FALSE =="
    echo "== Não será baixado. =="
fi

if [ -d "third_party/gles1_conform/.git" ]; then
    echo "ERRO: gles1_conform privado foi baixado."
    echo "Abortando para não continuar com dependência interna."
    exit 1
fi

# ------------------------------------------------------------
# 5. Gerar configuração oficial
# ------------------------------------------------------------

echo
echo "============================================================"
echo " ANGLE: Static ARM64 Vulkan"
echo "============================================================"

rm -rf out/Static

gn gen out/Static --args='
import("//args/android_arm64_static.gn")
'

# ------------------------------------------------------------
# 6. Mostrar configuração
# ------------------------------------------------------------

echo
echo "== GN args importantes =="

gn args out/Static --list | grep -E \
    "target_os|target_cpu|angle_static_linking|angle_use_static_angle|angle_enable_vulkan|angle_enable_gl|android_ndk_api_level"

# ------------------------------------------------------------
# 7. Compilar ANGLE
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Compilando ANGLE"
echo "============================================================"

autoninja -C out/Static \
    libEGL \
    libGLESv2 \
    libANGLE

# ------------------------------------------------------------
# 8. Localizar bibliotecas
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Bibliotecas ANGLE"
echo "============================================================"

find out/Static \
    -type f \
    \( \
        -name "libEGL.a" \
        -o -name "libGLESv2.a" \
        -o -name "libANGLE.a" \
    \) \
    -print

ANGLE_EGL="$(find out/Static -type f -name 'libEGL.a' | head -n1)"
ANGLE_GLES="$(find out/Static -type f -name 'libGLESv2.a' | head -n1)"
ANGLE_CORE="$(find out/Static -type f -name 'libANGLE.a' | head -n1)"

if [ -z "$ANGLE_EGL" ]; then
    echo "ERRO: libEGL.a não encontrada."
    exit 1
fi

if [ -z "$ANGLE_GLES" ]; then
    echo "ERRO: libGLESv2.a não encontrada."
    exit 1
fi

if [ -z "$ANGLE_CORE" ]; then
    echo "ERRO: libANGLE.a não encontrada."
    exit 1
fi

echo
echo "libEGL.a    = $ANGLE_EGL"
echo "libGLESv2.a = $ANGLE_GLES"
echo "libANGLE.a  = $ANGLE_CORE"

# ------------------------------------------------------------
# 9. Copiar libs para output temporariamente
# ------------------------------------------------------------

mkdir -p "$OUT/angle"

cp "$ANGLE_EGL" "$OUT/angle/"
cp "$ANGLE_GLES" "$OUT/angle/"
cp "$ANGLE_CORE" "$OUT/angle/"

# ------------------------------------------------------------
# 10. LTW
# ------------------------------------------------------------

cd "$ROOT"

if [ ! -d "$LTW/.git" ]; then
    echo
    echo "== Clonando LTW =="

    git clone \
        --depth 1 \
        --no-tags \
        --branch "$LTW_BRANCH" \
        "$LTW_REPO" \
        "$LTW"
else
    echo
    echo "== LTW já existe =="
fi

# ------------------------------------------------------------
# 11. Resultado
# ------------------------------------------------------------

echo
echo "============================================================"
echo " ANGLE STATIC BUILD OK"
echo "============================================================"
echo
echo "Gerado:"
echo "  $OUT/angle/libEGL.a"
echo "  $OUT/angle/libGLESv2.a"
echo "  $OUT/angle/libANGLE.a"
echo
echo "LTW:"
echo "  $LTW"
echo
echo "============================================================"
echo " Próxima etapa: LINK FINAL LTW + ANGLE"
echo "============================================================"

exit 0
