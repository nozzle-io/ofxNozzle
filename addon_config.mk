meta:
	ADDON_NAME = ofxNozzle
	ADDON_DESCRIPTION = Cross-platform GPU texture sharing (Syphon/Spout alternative)
	ADDON_AUTHOR = 2bit
	ADDON_TAGS = "texture" "sharing" "gpu" "syphon" "spout"

common:
	ADDON_INCLUDES = libs/nozzle/include libs/nozzle/libs/plog/include

# macOS (uses Metal/IOSurface backend + Objective-C++ interop)
osx:
	ADDON_DEFINES = NOZZLE_HAS_METAL
	ADDON_LDFLAGS = -framework Metal -framework IOSurface -framework Foundation -framework OpenGL
	ADDON_SOURCES_EXCLUDE = src/platform/win/%
	ADDON_SOURCES_EXCLUDE += src/platform/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%

# Windows (uses D3D11 backend)
vs:
	ADDON_DEFINES = NOZZLE_HAS_D3D11
	ADDON_LDFLAGS = opengl32.lib d3d11.lib dxgi.lib bcrypt.lib
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%

msys2:
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%

# Linux (uses DMA-BUF backend)
linux64:
	ADDON_DEFINES = NOZZLE_HAS_DMA_BUF
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%

linux:
	ADDON_DEFINES = NOZZLE_HAS_DMA_BUF
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%

linuxarmv6l:
	ADDON_DEFINES = NOZZLE_HAS_DMA_BUF
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%

linuxarmv7l:
	ADDON_DEFINES = NOZZLE_HAS_DMA_BUF
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%

linuxaarch64:
	ADDON_DEFINES = NOZZLE_HAS_DMA_BUF
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%

emscripten:
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%

ios:
	ADDON_SOURCES_EXCLUDE = src/platform/win/%
	ADDON_SOURCES_EXCLUDE += src/platform/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%
