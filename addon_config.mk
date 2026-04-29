meta:
	ADDON_NAME = ofxNozzle
	ADDON_DESCRIPTION = Cross-platform GPU texture sharing (Syphon/Spout alternative)
	ADDON_AUTHOR = 2bit
	ADDON_TAGS = "texture" "sharing" "gpu" "syphon" "spout"

common:
	ADDON_INCLUDES = src libs/nozzle/include libs/nozzle/libs/plog/include
	ADDON_SOURCES_EXCLUDE = libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tools/%

osx:
	ADDON_DEFINES = NOZZLE_HAS_METAL NOZZLE_HAS_OPENGL
	ADDON_LDFLAGS = -framework Metal -framework IOSurface -framework Foundation -framework OpenGL
	ADDON_SOURCES_EXCLUDE = src/platform/win/%
	ADDON_SOURCES_EXCLUDE += src/platform/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/linux/%

vs:
	ADDON_DEFINES = NOZZLE_HAS_D3D11 NOZZLE_HAS_OPENGL
	ADDON_LDFLAGS = opengl32.lib d3d11.lib dxgi.lib bcrypt.lib
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/linux/%

msys2:
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/linux/%

linux64:
	ADDON_DEFINES = NOZZLE_HAS_DMA_BUF NOZZLE_HAS_OPENGL
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%

linux:
	ADDON_DEFINES = NOZZLE_HAS_DMA_BUF NOZZLE_HAS_OPENGL
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%

linuxarmv6l:
	ADDON_DEFINES = NOZZLE_HAS_DMA_BUF NOZZLE_HAS_OPENGL
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%

linuxarmv7l:
	ADDON_DEFINES = NOZZLE_HAS_DMA_BUF NOZZLE_HAS_OPENGL
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%

linuxaarch64:
	ADDON_DEFINES = NOZZLE_HAS_DMA_BUF NOZZLE_HAS_OPENGL
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%

emscripten:
	ADDON_SOURCES_EXCLUDE = src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%

ios:
	ADDON_SOURCES_EXCLUDE = src/platform/win/%
	ADDON_SOURCES_EXCLUDE += src/platform/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/linux/%
