meta:
	ADDON_NAME = ofxNozzle
	ADDON_DESCRIPTION = Cross-platform GPU texture sharing (Syphon/Spout alternative)
	ADDON_AUTHOR = 2bit
	ADDON_TAGS = "texture" "sharing" "gpu" "syphon" "spout"

common:
	ADDON_INCLUDES = libs/nozzle/include libs/nozzle/libs/plog/include

osx:
	ADDON_DEFINES = NOZZLE_HAS_METAL
	ADDON_LDFLAGS = -framework Metal -framework IOSurface -framework Foundation -framework OpenGL
	ADDON_SOURCES_EXCLUDE = src/%.cpp
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%
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
	ADDON_SOURCES += libs/nozzle/src/common/ipc.cpp
	ADDON_SOURCES += libs/nozzle/src/c_api/nozzle_c.cpp
	ADDON_SOURCES += libs/nozzle/src/backends/metal/metal_backend.mm
	ADDON_SOURCES += libs/nozzle/src/backends/metal/metal_texture.mm
	ADDON_SOURCES += libs/nozzle/src/backends/metal/metal_sync.mm

macos:
	ADDON_DEFINES = NOZZLE_HAS_METAL
	ADDON_LDFLAGS = -framework Metal -framework IOSurface -framework Foundation -framework OpenGL
	ADDON_SOURCES_EXCLUDE = src/%.cpp
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/d3d11/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%
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
	ADDON_SOURCES += libs/nozzle/src/common/ipc.cpp
	ADDON_SOURCES += libs/nozzle/src/c_api/nozzle_c.cpp
	ADDON_SOURCES += libs/nozzle/src/backends/metal/metal_backend.mm
	ADDON_SOURCES += libs/nozzle/src/backends/metal/metal_texture.mm
	ADDON_SOURCES += libs/nozzle/src/backends/metal/metal_sync.mm

linux64:
	ADDON_SOURCES_EXCLUDE = src/%.mm

linux:
	ADDON_SOURCES_EXCLUDE = src/%.mm

vs:
	ADDON_DEFINES = NOZZLE_HAS_D3D11
	ADDON_LDFLAGS = opengl32.lib d3d11.lib dxgi.lib bcrypt.lib
	ADDON_SOURCES_EXCLUDE = src/%.mm
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/metal/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/src/backends/opengl/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/tests/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/examples/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/build/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/cmake/%
	ADDON_SOURCES_EXCLUDE += libs/nozzle/libs/plog/%
	ADDON_SOURCES = src/ofxNozzleSender.cpp
	ADDON_SOURCES += src/ofxNozzleReceiver.cpp
	ADDON_SOURCES += libs/nozzle/src/common/registry.cpp
	ADDON_SOURCES += libs/nozzle/src/common/sender.cpp
	ADDON_SOURCES += libs/nozzle/src/common/receiver.cpp
	ADDON_SOURCES += libs/nozzle/src/common/frame.cpp
	ADDON_SOURCES += libs/nozzle/src/common/texture.cpp
	ADDON_SOURCES += libs/nozzle/src/common/device.cpp
	ADDON_SOURCES += libs/nozzle/src/common/discovery.cpp
	ADDON_SOURCES += libs/nozzle/src/common/metadata.cpp
	ADDON_SOURCES += libs/nozzle/src/common/ipc.cpp
	ADDON_SOURCES += libs/nozzle/src/c_api/nozzle_c.cpp
	ADDON_SOURCES += libs/nozzle/src/backends/d3d11/d3d11_backend.cpp
	ADDON_SOURCES += libs/nozzle/src/backends/d3d11/d3d11_texture.cpp
	ADDON_SOURCES += libs/nozzle/src/backends/d3d11/d3d11_sync.cpp

msys2:
	ADDON_SOURCES_EXCLUDE = src/%.mm
