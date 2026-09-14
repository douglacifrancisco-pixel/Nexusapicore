cmake_minimum_required(VERSION 3.10.0)
project(ltw_angle_unified VERSION 1.0.0 LANGUAGES C CXX)

# Configuração Android
set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 26)
set(CMAKE_ANDROID_ARCH_ABI arm64-v8a)
set(CMAKE_ANDROID_STL_TYPE c++_static)
set(CMAKE_ANDROID_STL c++_static)

# Caminhos
set(ANGLE_BUILD_DIR ${CMAKE_BINARY_DIR}/Angle/out/Static)
set(LTW_SOURCE_DIR ${CMAKE_SOURCE_DIR}/ltw/src/main/tinywrapper)

# Bibliotecas ANGLE estáticas
set(ANGLE_LIBS
    ${ANGLE_BUILD_DIR}/libEGL.a
    ${ANGLE_BUILD_DIR}/libGLESv2.a
    ${ANGLE_BUILD_DIR}/libANGLE.a
)

# Fontes LTW (apenas arquivos essenciais)
set(LTW_SOURCES
    ${LTW_SOURCE_DIR}/basevertex.c
    ${LTW_SOURCE_DIR}/blending.c
    ${LTW_SOURCE_DIR}/egl.c
    ${LTW_SOURCE_DIR}/framebuffer.c
    ${LTW_SOURCE_DIR}/env.c
    ${LTW_SOURCE_DIR}/glformats.c
    ${LTW_SOURCE_DIR}/license_notice.c
    ${LTW_SOURCE_DIR}/main.c
    ${LTW_SOURCE_DIR}/multidraw.c
    ${LTW_SOURCE_DIR}/of_buffer_copier.c
    ${LTW_SOURCE_DIR}/proc.c
    ${LTW_SOURCE_DIR}/query.c
    ${LTW_SOURCE_DIR}/shader_wrapper.c
    ${LTW_SOURCE_DIR}/string_utils.c
    ${LTW_SOURCE_DIR}/stubs.c
    ${LTW_SOURCE_DIR}/swizzle.c
    ${LTW_SOURCE_DIR}/vertexattrib.c
)

# Criar biblioteca unificada
add_library(ltw_angle SHARED ${LTW_SOURCES})

# Linkar com ANGLE estático
target_link_libraries(ltw_angle ${ANGLE_LIBS})

# Incluir headers
target_include_directories(ltw_angle PRIVATE
    ${LTW_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/Angle/include
    ${CMAKE_SOURCE_DIR}/Angle/src
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
