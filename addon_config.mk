meta:
	ADDON_NAME = ofxNozzle
	ADDON_DESCRIPTION = Cross-platform GPU texture sharing (Syphon/Spout alternative)
	ADDON_AUTHOR = 2bit
	ADDON_TAGS = "texture" "sharing" "gpu" "syphon" "spout"

common:
	ADDON_INCLUDES = libs/nozzle/include

osx:
	ADDON_CFLAGS = -fno-exceptions -fno-rtti
	ADDON_LDFLAGS = -framework Metal -framework IOSurface -framework Foundation -framework OpenGL
	ADDON_LIBS = libs/nozzle/lib/osx/libnozzle.a
	ADDON_SOURCES_EXCLUDE = src/%.cpp
	ADDON_SOURCES = src/ofxNozzleSender.mm src/ofxNozzleReceiver.mm src/ofxNozzleInterop.mm

macos:
	ADDON_CFLAGS = -fno-exceptions -fno-rtti
	ADDON_LDFLAGS = -framework Metal -framework IOSurface -framework Foundation -framework OpenGL
	ADDON_LIBS = libs/nozzle/lib/osx/libnozzle.a
	ADDON_SOURCES_EXCLUDE = src/%.cpp
	ADDON_SOURCES = src/ofxNozzleSender.mm src/ofxNozzleReceiver.mm src/ofxNozzleInterop.mm

linux64:
	ADDON_SOURCES_EXCLUDE = src/%.mm

linux:
	ADDON_SOURCES_EXCLUDE = src/%.mm

vs:
	ADDON_SOURCES_EXCLUDE = src/%.mm

msys2:
	ADDON_SOURCES_EXCLUDE = src/%.mm
