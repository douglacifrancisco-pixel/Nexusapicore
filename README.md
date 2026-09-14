# NexusAPICore

**Biblioteca unificada libltw_angle.so** que combina LTW + ANGLE para traduzir:
- OpenGL (Desktop) → OpenGL ES (via LTW)
- OpenGL ES → Vulkan (via ANGLE)
- EGL (via ANGLE)

## Fluxo Completo
Minecraft Java (OpenGL)
↓
LTW (OpenGL → OpenGL ES)
↓
ANGLE (OpenGL ES → Vulkan + EGL)
↓
Vulkan Driver

## Build

### Local (Termux/Android)
```bash
./scripts/build.sh
GitHub Actions
O workflow .github/workflows/build.yml compila automaticamente.
Requisitos
- Android NDK r26b+
- CMake 3.10+
- Ninja
- Git
Resultado
- build_output/libltw_angle.so (~30-50MB)
- Exporta todos os símbolos EGL e GL necessários
- Compatível com LWJGL 3.3.6 e Minecraft 1.21.11
- Funciona sem variáveis de ambiente
- Suporta OpenGL ES 3.2 sobre Vulkan
Estrutura
NexusAPICore/
├── scripts/
│   └── build.sh          # Script de build local
├── .github/workflows/
│   └── build.yml         # CI/CD automático
├── patches/             # Patches para ANGLE (opcional)
└── README.md
Nota: O build baixa automaticamente:
- Repositório ANGLE completo com todos os submodules
- Repositório LTW completo com todas as dependências (glsl_optimizer, vgpu_shaderconv)
