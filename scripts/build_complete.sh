#!/bin/bash
set -e

echo "============================================="
echo "NEXUSAPICORE: BUILD COMPLETO"
echo "============================================="

# =============================================
# 2. CLONAR REPOSITÓRIOS COMPLETOS
# =============================================
echo "=== [1/5] Clonando repositórios ==="

# Clonar ANGLE (completo, com submodules)
if [ ! -d "Angle" ]; then
    echo "  Clonando ANGLE..."
    git clone --recurse-submodules https://github.com/douglacifrancisco-pixel/Angle
else
    echo "  ANGLE já existe, atualizando..."
    cd Angle
    git pull
    git submodule update --init --recursive
    cd ..
fi

# Clonar LTW (completo, com submodules)
if [ ! -d "ltw_complete" ]; then
    echo "  Clonando LTW..."
    git clone --recurse-submodules https://github.com/douglacifrancisco-pixel/LTW-to-angle-vulkan- ltw_complete
else
    echo "  LTW já existe, atualizando..."
    cd ltw_complete
    git pull
    git submodule update --init --recursive
    cd ..
fi

echo "✅ Repositórios clonados"

# =============================================
# 3. APLICAR PATCHES NO ANGLE
# =============================================
echo "=== [2/5] Aplicando patches no ANGLE ==="
cd Angle

for patch in ../patches/*.patch; do
    if [ -f "$patch" ]; then
        echo "  Aplicando: $(basename "$patch")"
        git apply "$patch" || git apply -3 "$patch" || {
            echo "❌ Falha em $(basename "$patch")"
            exit 1
        }
    fi
done

cd ..
echo "✅ Patches aplicados"

# =============================================
# 4. COPIAR ARQUIVOS DO LTW PARA BUILD
# =============================================
echo "=== [3/5] Preparando LTW ==="

# Criar diretório de build do LTW
mkdir -p ltw_build/src/main/tinywrapper

# Copiar arquivos essenciais do LTW
cp -r ltw_complete/ltw/src/main/tinywrapper/* ltw_build/src/main/tinywrapper/

# Copiar CMakeLists.txt
cp ltw_complete/ltw/src/main/tinywrapper/CMakeLists.txt ltw_build/src/main/tinywrapper/

echo "✅ LTW preparado"

# =============================================
# 5. BUILD ANGLE ESTÁTICO
# =============================================
echo "=== [4/5] Compilando ANGLE (estático) ==="
cd Angle

# Criar configuração customizada para Android ARM64
cat > args_nexus_android.gn << 'GNEOF'
import("//args_android_armv80.gn")

# Configurações para NexusAPICore
angle_static_linking = true
angle_use_static_angle = true
angle_export_egl_symbols = true
angle_export_gles_symbols = true
angle_expose_non_conformant_extensions_and_versions = true
angle_build_tests = false
angle_enable_vulkan = true
angle_enable_gl = false
angle_enable_d3d11 = false
angle_enable_metal = false
angle_enable_null = false
angle_enable_wgpu = false
angle_enable_swiftshader = false
GNEOF

# Gerar build
mkdir -p out/Static
gn gen out/Static --args="import(\"//args_nexus_android.gn\")"

# Compilar bibliotecas estáticas
ninja -C out/Static libEGL.a libGLESv2.a libANGLE.a

cd ..
echo "✅ ANGLE compilado"

# =============================================
# 6. BUILD LTW + ANGLE UNIFICADO
# =============================================
echo "=== [5/5] Compilando libltw_angle.so ==="

# Criar diretório de build final
mkdir -p build_final
cd build_final

# Criar CMakeLists.txt para build unificado
cat > CMakeLists.txt << 'CMAKEEOF'
cmake_minimum_required(VERSION 3.10.0)
project(ltw_angle_unified VERSION 1.0.0 LANGUAGES C CXX)

# Configuração Android ARM64
set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 26)
set(CMAKE_ANDROID_ARCH_ABI arm64-v8a)
set(CMAKE_ANDROID_NDK $ENV{ANDROID_NDK})
set(CMAKE_ANDROID_STL_TYPE c++_static)
set(CMAKE_ANDROID_STL c++_static)

# Caminhos
set(ANGLE_STATIC_DIR ${CMAKE_SOURCE_DIR}/../Angle/out/Static)
set(LTW_SOURCE_DIR ${CMAKE_SOURCE_DIR}/../ltw_build/src/main/tinywrapper)

# Bibliotecas ANGLE estáticas
set(ANGLE_LIBS
    ${ANGLE_STATIC_DIR}/libEGL.a
    ${ANGLE_STATIC_DIR}/libGLESv2.a
    ${ANGLE_STATIC_DIR}/libANGLE.a
)

# Fontes do LTW (todos os arquivos necessários)
file(GLOB LTW_SOURCES
    "${LTW_SOURCE_DIR}/*.c"
    "${LTW_SOURCE_DIR}/unordered_map/*.c"
)

# Criar biblioteca unificada
add_library(ltw_angle SHARED ${LTW_SOURCES})

# Linkar com ANGLE estático
target_link_libraries(ltw_angle ${ANGLE_LIBS})

# Incluir headers
target_include_directories(ltw_angle PRIVATE
    ${LTW_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/../Angle/include
    ${CMAKE_SOURCE_DIR}/../Angle/src
    ${CMAKE_SOURCE_DIR}/../ltw_complete/ltw/src/main/tinywrapper
)

# Configurações de otimização
target_link_options(ltw_angle PUBLIC
    -Wl,--version-script=${LTW_SOURCE_DIR}/version.script
    -ffunction-sections -fdata-sections -flto -Wl,--gc-sections
)

# Definições
target_compile_definitions(ltw_angle PRIVATE
    ANGLE_LTW_COMPATIBILITY=1
    ANGLE_EXPORT_EGL_SYMBOLS=1
    ANGLE_EXPORT_GLES_SYMBOLS=1
)
CMAKEEOF

# Configurar toolchain Android
cat > android-toolchain.cmake << 'TOOLCHAINEOF'
set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 26)
set(CMAKE_ANDROID_ARCH_ABI arm64-v8a)
set(CMAKE_ANDROID_NDK $ENV{ANDROID_NDK})
set(CMAKE_ANDROID_STL_TYPE c++_static)
set(CMAKE_ANDROID_STL c++_static)
TOOLCHAINEOF

# Compilar
cmake . -DCMAKE_TOOLCHAIN_FILE=android-toolchain.cmake
cmake --build . --target ltw_angle

echo ""
echo "============================================="
echo "✅ BUILD CONCLUÍDO COM SUCESSO!"
echo "============================================="
echo ""
echo "libltw_angle.so gerada em: build_final/"
echo "Tamanho:"
du -sh build_final/libltw_angle.so
echo ""
echo "Símbolos exportados:"
nm -D build_final/libltw_angle.so | grep -E "eglGetDisplay|eglInitialize|eglCreateContext|glGetString|glClear|glGenBuffers" | head -10
