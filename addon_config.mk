meta:
	ADDON_NAME = ofxNozzle
	ADDON_DESCRIPTION = Cross-platform GPU texture sharing (Syphon/Spout alternative)
	ADDON_AUTHOR = 2bit
	ADDON_TAGS = "texture" "sharing" "gpu" "syphon" "spout"

common:
	ADDON_INCLUDES = src libs/nozzle/include libs/nozzle/libs/plog/include libs/nozzle/src
	ADDON_SOURCES_EXCLUDE = libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tools/%

osx:
	ADDON_CFLAGS = -DNOZZLE_PLATFORM_MACOS=1
	ADDON_CFLAGS += -DNOZZLE_HAS_METAL=1
	ADDON_CFLAGS += -DNOZZLE_HAS_OPENGL=1
	ADDON_FRAMEWORKS = Metal IOSurface Foundation OpenGL
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += src/platform/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/linux/%

vs:
	ADDON_CFLAGS = /DNOZZLE_PLATFORM_WINDOWS=1
	ADDON_CFLAGS += /DNOZZLE_HAS_D3D11=1
	ADDON_CFLAGS += /DNOZZLE_HAS_OPENGL=1
	ADDON_LDFLAGS = opengl32.lib d3d11.lib dxgi.lib bcrypt.lib
	ADDON_SOURCES_EXCLUDE += src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/linux/%

msys2:
	ADDON_SOURCES_EXCLUDE += src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/linux/%

linux64:
	ADDON_CFLAGS = -DNOZZLE_PLATFORM_LINUX=1
	ADDON_CFLAGS += -DNOZZLE_HAS_DMA_BUF=1
	ADDON_CFLAGS += -DNOZZLE_HAS_OPENGL=1
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_INCLUDES += /usr/include/libdrm
	ADDON_SOURCES_EXCLUDE += src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%

linux:
	ADDON_CFLAGS = -DNOZZLE_PLATFORM_LINUX=1
	ADDON_CFLAGS += -DNOZZLE_HAS_DMA_BUF=1
	ADDON_CFLAGS += -DNOZZLE_HAS_OPENGL=1
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_INCLUDES += /usr/include/libdrm
	ADDON_SOURCES_EXCLUDE += src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%

linuxarmv6l:
	ADDON_CFLAGS = -DNOZZLE_PLATFORM_LINUX=1
	ADDON_CFLAGS += -DNOZZLE_HAS_DMA_BUF=1
	ADDON_CFLAGS += -DNOZZLE_HAS_OPENGL=1
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_INCLUDES += /usr/include/libdrm
	ADDON_SOURCES_EXCLUDE += src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%

linuxarmv7l:
	ADDON_CFLAGS = -DNOZZLE_PLATFORM_LINUX=1
	ADDON_CFLAGS += -DNOZZLE_HAS_DMA_BUF=1
	ADDON_CFLAGS += -DNOZZLE_HAS_OPENGL=1
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_INCLUDES += /usr/include/libdrm
	ADDON_SOURCES_EXCLUDE += src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%

linuxaarch64:
	ADDON_CFLAGS = -DNOZZLE_PLATFORM_LINUX=1
	ADDON_CFLAGS += -DNOZZLE_HAS_DMA_BUF=1
	ADDON_CFLAGS += -DNOZZLE_HAS_OPENGL=1
	ADDON_LDFLAGS = -lEGL -lgbm -ldrm -lGL
	ADDON_INCLUDES += /usr/include/libdrm
	ADDON_SOURCES_EXCLUDE += src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%

emscripten:
	ADDON_SOURCES_EXCLUDE += src/platform/macos/%
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%

ios:
	ADDON_FRAMEWORKS = Metal IOSurface Foundation
	ADDON_SOURCES_EXCLUDE += src/platform/win/%
	ADDON_SOURCES_EXCLUDE += src/platform/linux/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/linux/%
