#!/bin/bash
set -e

echo "=== [1/4] Baixando ANGLE ==="
git clone --depth 1 --recurse-submodules=no https://github.com/douglacifrancisco-pixel/Angle

cd Angle

echo "=== [2/4] Aplicando patches ==="
for patch in ../patches/*.patch; do
    echo "  Aplicando: $(basename "$patch")"
    git apply "$patch" || git apply -3 "$patch" || {
        echo "❌ Falha em $(basename "$patch")"
        exit 1
    }
done

echo "=== [3/4] Inicializando submodules mínimos ==="
git submodule update --init \
    third_party/vulkan-headers/src \
    third_party/vulkan-loader/src

echo "✅ ANGLE pronto com patches"
