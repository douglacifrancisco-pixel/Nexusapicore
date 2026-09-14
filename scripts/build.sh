#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANGLE="$ROOT/Angle"
LTW="$ROOT/ltw"
OUT="$ROOT/output"
ANGLE_REPO="https://github.com/douglacifrancisco-pixel/Angle.git"
LTW_REPO="https://github.com/douglacifrancisco-pixel/LTW-to-angle-vulkan-.git"
LTW_BRANCH="feature/angle-vulkan-integration"

echo "== Nexusapicore =="
echo "ROOT:  $ROOT"
echo "ANGLE: $ANGLE"
echo "LTW:   $LTW"

rm -rf "$OUT"
mkdir -p "$OUT"

# ------------------------------------------------------------
# 1. ANGLE: NÃO usar --recursive.
# Evita o submodule privado chrome-internal.googlesource.com
# que fez o build anterior falhar.
# ------------------------------------------------------------
if [ ! -d "$ANGLE/.git" ]; then
    echo "== Clonando ANGLE sem submodules =="
    git clone --depth 1 --filter=blob:none --no-tags \
        "$ANGLE_REPO" "$ANGLE"
else
    echo "== ANGLE já existe; reutilizando =="
fi

cd "$ANGLE"

# ------------------------------------------------------------
# 2. Inicializar somente submodules públicos necessários.
# Não usar git submodule update --init --recursive.
# ------------------------------------------------------------
echo "== Verificando submodules ANGLE =="

git submodule sync --recursive || true

# O build Android Vulkan não precisa do GLES1 conform privado.
# Inicializamos apenas dependências públicas quando presentes.
for submodule in \
    third_party/Vulkan-Headers \
    third_party/vulkan-loader \
    third_party/angle_external_gn \
    third_party/abseil-cpp \
    third_party/googletest
do
    if git config -f .gitmodules --get-regexp "^submodule\..*\.path$" \
        | grep -q "[[:space:]]$submodule$"; then

        echo "Inicializando: $submodule"

        git submodule update --init --depth 1 "$submodule" || {
            echo "AVISO: não foi possível inicializar $submodule"
            echo "Continuando; ANGLE pode não precisar dele."
        }
    fi
done

# ------------------------------------------------------------
# 3. GN / depot_tools
# ------------------------------------------------------------
if ! command -v gn >/dev/null 2>&1; then
    echo "ERRO: gn não encontrado."
    echo "O GitHub Actions deve instalar depot_tools antes deste script."
    exit 1
fi

if ! command -v autoninja >/dev/null 2>&1; then
    echo "ERRO: autoninja não encontrado."
    echo "O GitHub Actions deve instalar depot_tools antes deste script."
    exit 1
fi

# ------------------------------------------------------------
# 4. Configuração oficial ANGLE ARM64 estática + Vulkan
# ------------------------------------------------------------
echo "== Gerando configuração ANGLE Static ARM64 Vulkan =="

rm -rf out/Static

gn gen out/Static --args='
import("//args/android_arm64_static.gn")
'

# ------------------------------------------------------------
# 5. Build das bibliotecas estáticas ANGLE
# ------------------------------------------------------------
echo "== Compilando ANGLE =="

autoninja -C out/Static \
    libEGL \
    libGLESv2 \
    libANGLE

# ------------------------------------------------------------
# 6. Verificação
# ------------------------------------------------------------
echo "== Bibliotecas ANGLE geradas =="

find out/Static -maxdepth 4 \
    \( -name "libEGL.a" -o -name "libGLESv2.a" -o -name "libANGLE.a" \) \
    -print

for f in \
    out/Static/obj/libEGL/libEGL.a \
    out/Static/obj/libGLESv2/libGLESv2.a \
    out/Static/obj/libANGLE/libANGLE.a
do
    if [ ! -f "$f" ]; then
        echo "ERRO: biblioteca não encontrada: $f"
        exit 1
    fi
done

# ------------------------------------------------------------
# 7. LTW
# ------------------------------------------------------------
cd "$ROOT"

if [ ! -d "$LTW/.git" ]; then
    echo "== Clonando LTW =="
    rm -rf "$LTW"
    git clone --depth 1 --no-tags \
        --branch "$LTW_BRANCH" \
        "$LTW_REPO" "$LTW"
else
    echo "== LTW já existe; reutilizando =="
fi

echo
echo "============================================================"
echo " ANGLE STATIC BUILD OK"
echo "============================================================"
echo
echo "Agora temos:"
echo "  ANGLE Vulkan ARM64 estático"
echo "  libEGL.a"
echo "  libGLESv2.a"
echo "  libANGLE.a"
echo
echo "O próximo passo é o link final LTW + ANGLE."
echo

# Não fingir que libegl_angle.so foi criado.
# O link final será feito após determinar as dependências
# estáticas exatas produzidas pelo build do ANGLE.
exit 0
