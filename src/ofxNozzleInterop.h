#pragma once

#include <cstdint>
#include <string>

struct ofxNozzleInteropResources {
    void *io_surface{nullptr};
    void *mtl_texture{nullptr};
    uint32_t gl_texture{0};
    uint32_t iosurface_id{0};
    uint32_t width{0};
    uint32_t height{0};
    uint32_t pixel_format{0};
    bool valid{false};
};

ofxNozzleInteropResources ofxNozzleCreateIOSurface(int width, int height, uint32_t glInternalFormat);
uint32_t ofxNozzleCreateGLTextureFromIOSurface(void *io_surface, int width, int height, uint32_t glInternalFormat, uint32_t glFormat, uint32_t glType);
void *ofxNozzleCreateMetalTextureFromIOSurface(void *mtl_device, void *io_surface, int width, int height, uint32_t pixelFormat);
uint32_t ofxNozzleGetIOSurfaceID(void *io_surface);
void ofxNozzleReleaseInteropResources(ofxNozzleInteropResources &resources);
