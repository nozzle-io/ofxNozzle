#pragma once

// Ensure nozzle OpenGL interop is enabled for all platforms
#if !defined(NOZZLE_HAS_OPENGL)
#define NOZZLE_HAS_OPENGL
#endif

// Auto-detect platform backend
#if defined(_WIN32) || defined(_WIN64)
  #if !defined(NOZZLE_HAS_D3D11)
  #define NOZZLE_HAS_D3D11
  #endif
#elif defined(__APPLE__)
  #if !defined(NOZZLE_HAS_METAL)
  #define NOZZLE_HAS_METAL
  #endif
#elif defined(__linux__)
  #if !defined(NOZZLE_HAS_DMA_BUF)
  #define NOZZLE_HAS_DMA_BUF
  #endif
#endif
