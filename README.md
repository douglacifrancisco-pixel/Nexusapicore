# NexusAPICore

Biblioteca unificada **libltw_angle.so** que combina:
- **LTW** (OpenGL → OpenGL ES)
- **ANGLE** (OpenGL ES → Vulkan + EGL)

## FluxoMinecraft (OpenGL) → LTW → OpenGL ES → ANGLE → Vulkan

## Build

### Local (Termux)
```bash
./scripts/build_complete.sh
GitHub Actions
O workflow .github/workflows/build_complete.yml compila automaticamente.
Requisitos
- Android NDK
- CMake
- Ninja
- Git
Resultado
- build_final/libltw_angle.so (~30-50MB)
- Exporta todos os símbolos EGL e GL necessários
- Compatível com LWJGL 3.3.6
