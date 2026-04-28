meta:
	ADDON_NAME = ofxNozzle
	ADDON_DESCRIPTION = Cross-platform GPU texture sharing (Syphon/Spout alternative)
	ADDON_AUTHOR = 2bit
	ADDON_TAGS = "texture" "sharing" "gpu" "syphon" "spout"

common:
	ADDON_INCLUDES = libs/nozzle/include libs/plog/include

osx:
	ADDON_CFLAGS = -fno-exceptions -fno-rtti -DNOZZLE_HAS_METAL
	ADDON_LDFLAGS = -framework Metal -framework IOSurface -framework Foundation -framework OpenGL
	ADDON_SOURCES_EXCLUDE = src/%.cpp
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES = src/ofxNozzleSender.mm
	ADDON_SOURCES += src/ofxNozzleReceiver.mm
	ADDON_SOURCES += src/ofxNozzleInterop.mm
	ADDON_SOURCES += libs/nozzle/src/common/registry.cpp
	ADDON_SOURCES += libs/nozzle/src/common/sender.cpp
	ADDON_SOURCES += libs/nozzle/src/common/receiver.cpp
	ADDON_SOURCES += libs/nozzle/src/common/frame.cpp
	ADDON_SOURCES += libs/nozzle/src/common/texture.cpp
	ADDON_SOURCES += libs/nozzle/src/common/device.cpp
	ADDON_SOURCES += libs/nozzle/src/common/discovery.cpp
	ADDON_SOURCES += libs/nozzle/src/common/metadata.cpp
	ADDON_SOURCES += libs/nozzle/src/c_api/nozzle_c.cpp
	ADDON_SOURCES += libs/nozzle/src/backends/metal/metal_backend.mm
	ADDON_SOURCES += libs/nozzle/src/backends/metal/metal_texture.mm
	ADDON_SOURCES += libs/nozzle/src/backends/metal/metal_sync.mm

macos:
	ADDON_CFLAGS = -fno-exceptions -fno-rtti -DNOZZLE_HAS_METAL
	ADDON_LDFLAGS = -framework Metal -framework IOSurface -framework Foundation -framework OpenGL
	ADDON_SOURCES_EXCLUDE = src/%.cpp
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES = src/ofxNozzleSender.mm
	ADDON_SOURCES += src/ofxNozzleReceiver.mm
	ADDON_SOURCES += src/ofxNozzleInterop.mm
	ADDON_SOURCES += libs/nozzle/src/common/registry.cpp
	ADDON_SOURCES += libs/nozzle/src/common/sender.cpp
	ADDON_SOURCES += libs/nozzle/src/common/receiver.cpp
	ADDON_SOURCES += libs/nozzle/src/common/frame.cpp
	ADDON_SOURCES += libs/nozzle/src/common/texture.cpp
	ADDON_SOURCES += libs/nozzle/src/common/device.cpp
	ADDON_SOURCES += libs/nozzle/src/common/discovery.cpp
	ADDON_SOURCES += libs/nozzle/src/common/metadata.cpp
	ADDON_SOURCES += libs/nozzle/src/c_api/nozzle_c.cpp
	ADDON_SOURCES += libs/nozzle/src/backends/metal/metal_backend.mm
	ADDON_SOURCES += libs/nozzle/src/backends/metal/metal_texture.mm
	ADDON_SOURCES += libs/nozzle/src/backends/metal/metal_sync.mm

linux64:
	ADDON_SOURCES_EXCLUDE = src/%.mm

linux:
	ADDON_SOURCES_EXCLUDE = src/%.mm

vs:
	ADDON_SOURCES_EXCLUDE = src/%.mm

msys2:
	ADDON_SOURCES_EXCLUDE = src/%.mm
