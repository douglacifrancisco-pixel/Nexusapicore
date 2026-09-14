#!/bin/bash
set -e

echo "=== [1/3] Baixando e patchando ANGLE ==="
./scripts/download_and_patch_angle.sh

echo "=== [2/3] Compilando ANGLE estático ==="
cd Angle
mkdir -p out/Static

# Criar configuração customizada
cat > args_custom.gn << 'GNEOF'
import("//args_android_armv80.gn")

# Configurações para LTW
angle_static_linking = true
angle_use_static_angle = true
angle_export_egl_symbols = true
angle_export_gles_symbols = true
angle_expose_non_conformant_extensions_and_versions = true
angle_build_tests = false
GNEOF

gn gen out/Static --args="import(\"//args_custom.gn\")"
ninja -C out/Static libEGL.a libGLESv2.a libANGLE.a
cd ..

echo "=== [3/3] Compilando LTW + ANGLE ==="
mkdir -p build
cd build

# Criar toolchain Android
cat > android-toolchain.cmake << 'CMAKEEOF'
set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 26)
set(CMAKE_ANDROID_ARCH_ABI arm64-v8a)
set(CMAKE_ANDROID_NDK $ENV{ANDROID_NDK})
set(CMAKE_ANDROID_STL_TYPE c++_static)
set(CMAKE_ANDROID_STL c++_static)
CMAKEEOF

# Build com CMake
cmake .. -DCMAKE_TOOLCHAIN_FILE=android-toolchain.cmake
cmake --build . --target ltw_angle

echo "✅ libltw_angle.so gerada em: build/"
