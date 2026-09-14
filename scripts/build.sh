#!/bin/bash
set -e

echo "============================================="
echo "NEXUSAPICORE: BUILD REAL"
echo "============================================="

# =============================================
# CLONAR REPOSITÓRIOS COMPLETOS COM TODAS AS DEPENDÊNCIAS
# =============================================
echo "=== [1/4] Clonando ANGLE com todas as dependências ==="
if [ ! -d "Angle" ]; then
    git clone --recurse-submodules https://github.com/douglacifrancisco-pixel/Angle
    cd Angle
    git submodule update --init --recursive
    cd ..
else
    echo "  ANGLE já existe, atualizando..."
    cd Angle
    git pull
    git submodule update --init --recursive
    cd ..
fi

echo "=== [2/4] Clonando LTW com todas as dependências ==="
if [ ! -d "ltw_source" ]; then
    git clone --recurse-submodules https://github.com/douglacifrancisco-pixel/LTW-to-angle-vulkan- ltw_source
    cd ltw_source
    git submodule update --init --recursive
    cd ..
else
    echo "  LTW já existe, atualizando..."
    cd ltw_source
    git pull
    git submodule update --init --recursive
    cd ..
fi

# =============================================
# APLICAR PATCHES NO ANGLE
# =============================================
echo "=== [3/4] Aplicando patches no ANGLE ==="
cd Angle

# Patch 1: Habilitar link estático + exportar símbolos
cat > /tmp/patch1.patch << 'PATCH1'
diff --git a/gni/angle_static.gni b/gni/angle_static.gni
index 1234567..abcdefg 100644
--- a/gni/angle_static.gni
+++ b/gni/angle_static.gni
@@ -5,7 +5,7 @@
 declare_args() {
   angle_static_linking = false
+  angle_static_linking = true
   angle_export_egl_symbols = true
   angle_export_gles_symbols = true
+  angle_ltw_compatibility = true
-  angle_ltw_compatibility = false
 }
PATCH1
git apply /tmp/patch1.patch || git apply -3 /tmp/patch1.patch

# Patch 2: Forçar Vulkan-only
cat > /tmp/patch2.patch << 'PATCH2'
diff --git a/args_android_armv80.gn b/args_android_armv80.gn
index 1234567..abcdefg 100644
--- a/args_android_armv80.gn
+++ b/args_android_armv80.gn
@@ -20,7 +20,7 @@
 angle_enable_vulkan = true
 angle_enable_gl = false
-angle_expose_non_conformant_extensions_and_versions = false
+angle_expose_non_conformant_extensions_and_versions = true
PATCH2
git apply /tmp/patch2.patch || git apply -3 /tmp/patch2.patch

# Patch 3: Adicionar função de compatibilidade LTW
cat > src/libANGLE/angle_ltw_compat.cpp << 'CPPEOF'
#include <EGL/egl.h>
#include "libANGLE/Display.h"

extern "C" {
void angle_initialize() {
    angle::Display::Initialize();
}

void* angle_eglGetProcAddress(const char* procname) {
    return angle::eglGetProcAddress(procname);
}

void angle_set_expose_es32(bool expose) {
    angle::SetExposeES32ForTesting(expose);
}
}
CPPEOF

# Adicionar ao BUILD.gn do libANGLE
sed -i '/libangle_sources += \[/a\    \"src/libANGLE/angle_ltw_compat.cpp\",' src/libANGLE/BUILD.gn

cd ..
echo "✅ Patches aplicados"

# =============================================
# MODIFICAR LTW PARA LINK ESTÁTICO
# =============================================
echo "=== [4/4] Modificando LTW para link estático ==="
cd ltw_source/ltw/src/main/tinywrapper

# Backup do proc.c original
cp proc.c proc.c.bak

# Modificar proc.c - Remover dlopen
cat > proc.c << 'PROCEOF'
/**
 * Modified for NexusAPICore - Static ANGLE linking
 */
#include <EGL/egl.h>
#include <GLES3/gl31.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "proc.h"
#include "egl.h"
#include "libraryinternal.h"
#define GL_GLEXT_PROTOTYPES
#include "GL/gl.h"
#include "GL/glext.h"

INTERNAL eglMustCastToProperFunctionPointerType (*host_eglGetProcAddress)(const char *procname);
INTERNAL es3_functions_t es3_functions;

static void error_sysegl() {
    printf("LTWInit: Failed to load ANGLE\n");
    abort();
}

static void error_init(const char* functionName) {
    printf("LTWInit: Failed to load function \"%s\"\n", functionName);
    abort();
}

static void init_es3_proc() {
#define GLESFUNC(name, type) es3_functions.name = (type)host_eglGetProcAddress(#name); if(es3_functions.name == NULL) error_init(#name);
#include "es3_functions.h"
#undef GLESFUNC
#define GLESFUNC(name, type) es3_functions.name = (type)host_eglGetProcAddress(#name);
#include "es3_extended.h"
#undef GLESFUNC
}

__attribute__((constructor, used)) void proc_init(){
    // Link estático com ANGLE - não usa dlopen
    host_eglGetProcAddress = angle_eglGetProcAddress;

    // Inicializar ANGLE
    angle_initialize();

    // Forçar ES3.2 para Minecraft
    angle_set_expose_es32(true);

    init_egl();
    init_es3_proc();
}

__attribute__((used)) eglMustCastToProperFunctionPointerType glXGetProcAddress(const char *procname) {
    return eglGetProcAddress(procname);
}

extern void* resolve_stub(const char* procname);

eglMustCastToProperFunctionPointerType eglGetProcAddress(const char *procname) {
    if(!strncmp(procname, "egl", 3)) {
        if(!strcmp("eglCreateContext", procname)) return (eglMustCastToProperFunctionPointerType) eglCreateContext;
        if(!strcmp("eglDestroyContext", procname)) return (eglMustCastToProperFunctionPointerType) eglDestroyContext;
        if(!strcmp("eglMakeCurrent", procname)) return (eglMustCastToProperFunctionPointerType) eglMakeCurrent;
    }
    if(strncmp(procname, "gl", 2) != 0) goto fallback;
#define GLESOVERRIDE(name)                                        \
    if(!strcmp(procname, #name)) {                                \
        return (eglMustCastToProperFunctionPointerType) name;     \
    }
#include "es3_overrides.h"
#undef GLESOVERRIDE
    eglMustCastToProperFunctionPointerType function;
fallback:
    function = host_eglGetProcAddress(procname);
    if(function == NULL) {
        function = resolve_stub(procname);
    }
    return function;
}
PROCEOF

# Modificar egl.c - Forçar ES3.2
sed -i '/void find_esversion(context_t\* context) {/a\    // FORÇAR ES3.2 para Minecraft\n    context->es32 = true;\n    context->es31 = true;'

cd ../../../..

# =============================================
# BUILD ANGLE ESTÁTICO
# =============================================
echo "=== [5/6] Compilando ANGLE (estático) ==="
cd Angle
mkdir -p out/Static

# Usar configuração existing args_android_armv80.gn
gn gen out/Static --args="import(\"//args_android_armv80.gn\")" \
    --args="angle_static_linking=true" \
    --args="angle_use_static_angle=true" \
    --args="angle_build_tests=false"

ninja -C out/Static libEGL.a libGLESv2.a libANGLE.a
cd ..

# =============================================
# BUILD LTW + ANGLE UNIFICADO
# =============================================
echo "=== [6/6] Compilando libltw_angle.so ==="
mkdir -p build_output
cd build_output

# Criar CMakeLists.txt que resolve TODAS as dependências
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
set(LTW_SOURCE_DIR ${CMAKE_SOURCE_DIR}/../ltw_source/ltw/src/main/tinywrapper)

# Bibliotecas ANGLE estáticas
set(ANGLE_LIBS
    ${ANGLE_STATIC_DIR}/libEGL.a
    ${ANGLE_STATIC_DIR}/libGLESv2.a
    ${ANGLE_STATIC_DIR}/libANGLE.a
)

# Fontes do LTW - TODOS os arquivos .c
file(GLOB LTW_SOURCES
    "${LTW_SOURCE_DIR}/*.c"
    "${LTW_SOURCE_DIR}/unordered_map/*.c"
    "${LTW_SOURCE_DIR}/glsl_optimizer/src/*.cpp"
    "${LTW_SOURCE_DIR}/glsl_optimizer/src/compiler/*.cpp"
    "${LTW_SOURCE_DIR}/glsl_optimizer/src/compiler/glsl/*.cpp"
    "${LTW_SOURCE_DIR}/glsl_optimizer/src/compiler/glsl/*.h"
    "${LTW_SOURCE_DIR}/vgpu_shaderconv/*.c"
)

# Criar biblioteca unificada
add_library(ltw_angle SHARED ${LTW_SOURCES})

# Linkar com ANGLE estático
target_link_libraries(ltw_angle ${ANGLE_LIBS})

# Incluir TODOS os headers necessários
target_include_directories(ltw_angle PRIVATE
    ${LTW_SOURCE_DIR}
    ${LTW_SOURCE_DIR}/GL
    ${LTW_SOURCE_DIR}/glsl_optimizer/include
    ${LTW_SOURCE_DIR}/glsl_optimizer/include/GL
    ${LTW_SOURCE_DIR}/glsl_optimizer/include/GLES2
    ${LTW_SOURCE_DIR}/glsl_optimizer/include/GLES3
    ${LTW_SOURCE_DIR}/glsl_optimizer/include/KHR
    ${CMAKE_SOURCE_DIR}/../Angle/include
    ${CMAKE_SOURCE_DIR}/../Angle/src
    ${CMAKE_SOURCE_DIR}/../Angle/src/libANGLE
    ${CMAKE_SOURCE_DIR}/../Angle/src/libGLESv2
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

# Usar toolchain do Android NDK
cmake . -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake
cmake --build . --target ltw_angle

echo ""
echo "============================================="
echo "✅ BUILD CONCLUÍDO COM SUCESSO!"
echo "============================================="
echo ""
echo "libltw_angle.so gerada em: $(pwd)/libltw_angle.so"
echo "Tamanho:"
du -sh libltw_angle.so
echo ""
echo "Símbolos exportados (EGL):"
nm -D libltw_angle.so | grep -E "^[0-9a-f]+ T egl" | head -5
echo ""
echo "Símbolos exportados (GL):"
nm -D libltw_angle.so | grep -E "^[0-9a-f]+ T gl" | head -5
