// ofxNozzleInterop.mm - IOSurface / OpenGL / Metal interop utilities

#include "ofMain.h"

#ifndef GL_BGRA8_EXT
#define GL_BGRA8_EXT 0x93A1
#endif

#import <IOSurface/IOSurface.h>
#import <Metal/Metal.h>
#import <OpenGL/CGLIOSurface.h>
#import <AppKit/AppKit.h>

#include "ofxNozzleInterop.h"

#include "ofLog.h"

static constexpr uint32_t kIOSurfaceAlignBytes = 64;

static uint32_t align_up(uint32_t value, uint32_t alignment) {
    return (value + alignment - 1) & ~(alignment - 1);
}

static bool gl_internal_format_to_iosurface_pixel_format(
    uint32_t gl_internal_format,
    uint32_t &out_iosurface_pf,
    uint32_t &out_bytes_per_element)
{
    switch (gl_internal_format) {
        case GL_BGRA8_EXT:
        case GL_RGBA8:
            // Always use BGRA for 8-bit IOSurface — CGLTexImageIOSurface2D
            // requires GL_RGBA8 internal format with GL_BGRA pixel format.
            out_iosurface_pf = 0x42475241; // kCVPixelFormatType_32BGRA
            out_bytes_per_element = 4;
            return true;
        case GL_RGBA16F:
            out_iosurface_pf = 0x52476841; // kCVPixelFormatType_64RGBAHalfFloat
            out_bytes_per_element = 8;
            return true;
        default:
            return false;
    }
}

static MTLPixelFormat nozzle_format_to_mtl(uint32_t nozzle_pixel_format) {
    switch (static_cast<uint32_t>(nozzle_pixel_format)) {
        case 1:  return MTLPixelFormatR8Unorm;          // r8_unorm
        case 2:  return MTLPixelFormatRG8Unorm;         // rg8_unorm
        case 3:  return MTLPixelFormatRGBA8Unorm;       // rgba8_unorm
        case 4:  return MTLPixelFormatBGRA8Unorm;       // bgra8_unorm
        case 5:  return MTLPixelFormatRGBA8Unorm_sRGB;  // rgba8_srgb
        case 6:  return MTLPixelFormatBGRA8Unorm_sRGB;  // bgra8_srgb
        case 7:  return MTLPixelFormatR16Unorm;         // r16_unorm
        case 8:  return MTLPixelFormatRG16Unorm;        // rg16_unorm
        case 9:  return MTLPixelFormatRGBA16Unorm;      // rgba16_unorm
        case 10: return MTLPixelFormatR16Float;         // r16_float
        case 11: return MTLPixelFormatRG16Float;        // rg16_float
        case 12: return MTLPixelFormatRGBA16Float;      // rgba16_float
        case 13: return MTLPixelFormatR32Float;         // r32_float
        case 14: return MTLPixelFormatRG32Float;        // rg32_float
        case 15: return MTLPixelFormatRGBA32Float;      // rgba32_float
        case 16: return MTLPixelFormatR32Uint;          // r32_uint
        case 17: return MTLPixelFormatRGBA32Uint;       // rgba32_uint
        case 18: return MTLPixelFormatDepth32Float;     // depth32_float
        default: return MTLPixelFormatInvalid;
    }
}

static uint32_t gl_format_to_nozzle_format(uint32_t gl_internal_format) {
    switch (gl_internal_format) {
        case GL_BGRA8_EXT: return 4; // bgra8_unorm
        case GL_RGBA8:     return 3; // rgba8_unorm
        case GL_RGBA16F:   return 12; // rgba16_float
        default:           return 3; // fallback to rgba8_unorm
    }
}

static void release_mtl_texture(void *ptr) {
    if (!ptr) return;
#if __has_feature(objc_arc)
    id obj = (__bridge_transfer id<MTLTexture>)ptr;
    (void)obj;
#else
    [(id<MTLTexture>)ptr release];
#endif
}

ofxNozzleInteropResources ofxNozzleCreateIOSurface(
    int width, int height, uint32_t gl_internal_format)
{
    ofxNozzleInteropResources result{};

    uint32_t iosurface_pf = 0;
    uint32_t bytes_per_element = 0;
    if (!gl_internal_format_to_iosurface_pixel_format(gl_internal_format, iosurface_pf, bytes_per_element)) {
        ofLogError("ofxNozzleInterop") << "unsupported GL internal format: " << gl_internal_format;
        return result;
    }

    uint32_t bytes_per_row = align_up(static_cast<uint32_t>(width) * bytes_per_element, kIOSurfaceAlignBytes);

    @autoreleasepool {
        NSDictionary *surface_props = @{
            (id)kIOSurfaceWidth:        @(static_cast<NSUInteger>(width)),
            (id)kIOSurfaceHeight:       @(static_cast<NSUInteger>(height)),
            (id)kIOSurfacePixelFormat:  @(iosurface_pf),
            (id)kIOSurfaceBytesPerRow:  @(bytes_per_row),
            (id)kIOSurfaceBytesPerElement: @(bytes_per_element),
        };

        IOSurfaceRef surface = IOSurfaceCreate((CFDictionaryRef)surface_props);
        if (!surface) {
            ofLogError("ofxNozzleInterop") << "failed to create IOSurface";
            return result;
        }

        result.io_surface = (void *)surface;
        result.iosurface_id = IOSurfaceGetID(surface);
        result.width = static_cast<uint32_t>(width);
        result.height = static_cast<uint32_t>(height);
        result.pixel_format = gl_format_to_nozzle_format(gl_internal_format);
        result.valid = true;
    }

    return result;
}

uint32_t ofxNozzleCreateGLTextureFromIOSurface(
    void *io_surface, int width, int height, uint32_t gl_internal_format)
{
    if (!io_surface) {
        ofLogError("ofxNozzleInterop") << "io_surface is null";
        return 0;
    }

    IOSurfaceRef surface = (IOSurfaceRef)io_surface;

    GLuint gl_tex = 0;
    glGenTextures(1, &gl_tex);
    if (gl_tex == 0) {
        ofLogError("ofxNozzleInterop") << "failed to generate GL texture";
        return 0;
    }

    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, gl_tex);

    // CGLTexImageIOSurface2D does not accept GL_BGRA8_EXT as internal format.
    // Use GL_RGBA8 for all 8-bit formats (BGRA channel ordering via GL_BGRA format).
    GLenum gl_format = GL_BGRA;
    GLenum gl_type = GL_UNSIGNED_INT_8_8_8_8_REV;
    GLenum cgl_internal_format = GL_RGBA8;

    if (gl_internal_format == GL_RGBA16F) {
        gl_format = GL_RGBA;
        gl_type = GL_HALF_FLOAT;
        cgl_internal_format = GL_RGBA16F;
    }

    CGLError err = CGLTexImageIOSurface2D(
        CGLGetCurrentContext(),
        GL_TEXTURE_RECTANGLE_ARB,
        cgl_internal_format,
        static_cast<GLsizei>(width),
        static_cast<GLsizei>(height),
        gl_format,
        gl_type,
        surface,
        0);

    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);

    if (err != kCGLNoError) {
        ofLogError("ofxNozzleInterop") << "CGLTexImageIOSurface2D failed: " << CGLErrorString(err)
            << " (code=" << std::dec << err << ")"
            << " internal_format=0x" << std::hex << cgl_internal_format
            << " surface_pf=0x" << IOSurfaceGetPixelFormat(surface);
        glDeleteTextures(1, &gl_tex);
        return 0;
    }

    return gl_tex;
}

void *ofxNozzleCreateMetalTextureFromIOSurface(
    void *mtl_device, void *io_surface, int width, int height, uint32_t pixel_format)
{
    if (!mtl_device || !io_surface) {
        ofLogError("ofxNozzleInterop") << "mtl_device or io_surface is null";
        return nullptr;
    }

    @autoreleasepool {
#if __has_feature(objc_arc)
        id<MTLDevice> device = (__bridge id<MTLDevice>)mtl_device;
#else
        id<MTLDevice> device = (id<MTLDevice>)mtl_device;
#endif
        IOSurfaceRef surface = (IOSurfaceRef)io_surface;

        auto mtl_format = nozzle_format_to_mtl(pixel_format);
        if (mtl_format == MTLPixelFormatInvalid) {
            ofLogError("ofxNozzleInterop") << "unsupported pixel format: " << pixel_format;
            return nullptr;
        }

        MTLTextureDescriptor *tex_desc =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:mtl_format
                                                               width:static_cast<NSUInteger>(width)
                                                              height:static_cast<NSUInteger>(height)
                                                           mipmapped:NO];
        tex_desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
        tex_desc.resourceOptions = MTLResourceStorageModeShared;

        id<MTLTexture> texture = [device newTextureWithDescriptor:tex_desc
                                                        iosurface:surface
                                                              plane:0];
        if (!texture) {
            ofLogError("ofxNozzleInterop") << "failed to create Metal texture from IOSurface";
            return nullptr;
        }

#if __has_feature(objc_arc)
        return (__bridge_retained void *)texture;
#else
        return (void *)texture;
#endif
    }
}

uint32_t ofxNozzleGetIOSurfaceID(void *io_surface) {
    if (!io_surface) {
        return 0;
    }
    IOSurfaceRef surface = (IOSurfaceRef)io_surface;
    return IOSurfaceGetID(surface);
}

void ofxNozzleReleaseInteropResources(ofxNozzleInteropResources &resources) {
    if (resources.gl_texture != 0) {
        glDeleteTextures(1, &resources.gl_texture);
        resources.gl_texture = 0;
    }

    @autoreleasepool {
        release_mtl_texture(resources.mtl_texture);
        resources.mtl_texture = nullptr;

        if (resources.io_surface) {
            IOSurfaceRef surface = (IOSurfaceRef)resources.io_surface;
            CFRelease(surface);
            resources.io_surface = nullptr;
        }
    }

    resources.iosurface_id = 0;
    resources.valid = false;
}
