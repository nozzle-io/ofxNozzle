// ofxNozzleSender.mm - macOS: publishTexture → nozzle::gl::publish_gl_texture()

#include "ofxNozzleSender.h"

#include <nozzle/nozzle.hpp>
#include <nozzle/backends/opengl.hpp>

#include "ofLog.h"
#include "ofAppRunner.h"
#include "ofAppGLFWWindow.h"
#include "GLFW/glfw3.h"
#include <OpenGL/OpenGL.h>

namespace {

const char *gl_format_name(int fmt) {
    switch (fmt) {
        case GL_RED:            return "GL_RED";
        case GL_RG:             return "GL_RG";
        case GL_RGB:            return "GL_RGB";
        case GL_RGBA:           return "GL_RGBA";
        case GL_BGRA:           return "GL_BGRA";
        case GL_R8:             return "GL_R8";
        case GL_RG8:            return "GL_RG8";
        case GL_RGB8:           return "GL_RGB8";
        case GL_RGBA8:          return "GL_RGBA8";
        case GL_BGRA8_EXT:      return "GL_BGRA8_EXT";
        case GL_SRGB8_ALPHA8:   return "GL_SRGB8_ALPHA8";
        case GL_R16:            return "GL_R16";
        case GL_RG16:           return "GL_RG16";
        case GL_RGBA16:         return "GL_RGBA16";
        case GL_R16F:           return "GL_R16F";
        case GL_RG16F:          return "GL_RG16F";
        case GL_RGBA16F:        return "GL_RGBA16F";
        case GL_R32F:           return "GL_R32F";
        case GL_RG32F:          return "GL_RG32F";
        case GL_RGBA32F:        return "GL_RGBA32F";
        default:                return "unknown";
    }
}

std::string gl_format_str(int fmt) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%s (0x%x)", gl_format_name(fmt), fmt);
    return buf;
}

int normalize_gl_format(int gl_fmt) {
    switch (gl_fmt) {
        case GL_RGBA:    return GL_RGBA8;
        case GL_RGB:     return GL_RGBA8;
        case GL_RGB8:    return GL_RGBA8;
#ifdef GL_BGRA
        case GL_BGRA:    return GL_BGRA8_EXT;
#endif
        default:         return gl_fmt;
    }
}

bool is_supported_gl_format(int gl_fmt) {
    switch (gl_fmt) {
        case GL_R8:
        case GL_RG8:
        case GL_RGBA8:
        case GL_BGRA8_EXT:
        case GL_SRGB8_ALPHA8:
        case GL_R16:
        case GL_RG16:
        case GL_RGBA16:
        case GL_R16F:
        case GL_RG16F:
        case GL_RGBA16F:
        case GL_R32F:
        case GL_RG32F:
        case GL_RGBA32F:
            return true;
        default:
            return false;
    }
}

nozzle::texture_format gl_format_to_nozzle(int gl_fmt) {
    switch (gl_fmt) {
        case GL_R8:            return nozzle::texture_format::r8_unorm;
        case GL_RG8:           return nozzle::texture_format::rg8_unorm;
        case GL_RGBA8:         return nozzle::texture_format::rgba8_unorm;
        case GL_BGRA8_EXT:     return nozzle::texture_format::bgra8_unorm;
        case GL_SRGB8_ALPHA8:  return nozzle::texture_format::rgba8_srgb;
        case GL_R16:           return nozzle::texture_format::r16_unorm;
        case GL_RG16:          return nozzle::texture_format::rg16_unorm;
        case GL_RGBA16:        return nozzle::texture_format::rgba16_unorm;
        case GL_R16F:          return nozzle::texture_format::r16_float;
        case GL_RG16F:         return nozzle::texture_format::rg16_float;
        case GL_RGBA16F:       return nozzle::texture_format::rgba16_float;
        case GL_R32F:          return nozzle::texture_format::r32_float;
        case GL_RG32F:         return nozzle::texture_format::rg32_float;
        case GL_RGBA32F:       return nozzle::texture_format::rgba32_float;
        default:               return nozzle::texture_format::rgba8_unorm;
    }
}

} // namespace

struct ofxNozzleSender::Impl {
    std::string name_{};
    bool setup_{false};
    nozzle::sender sender_{};
    int last_published_gl_format_{-1};

    ~Impl() { close(); }

    void close() {
        if (!setup_) {
            return;
        }
        setup_ = false;
        sender_ = nozzle::sender{};
    }
};

ofxNozzleSender::ofxNozzleSender() = default;
ofxNozzleSender::~ofxNozzleSender() = default;
ofxNozzleSender::ofxNozzleSender(ofxNozzleSender &&) noexcept = default;
ofxNozzleSender &ofxNozzleSender::operator=(ofxNozzleSender &&) noexcept = default;

bool ofxNozzleSender::setup(const std::string &name) {
    if (impl_ && impl_->setup_) {
        ofLogWarning("ofxNozzleSender") << "already set up, closing previous";
        close();
    }

    if (name.empty()) {
        ofLogError("ofxNozzleSender") << "name must not be empty";
        return false;
    }

    if (!CGLGetCurrentContext()) {
        ofLogError("ofxNozzleSender") << "no GL context available";
        return false;
    }

    impl_ = std::make_unique<Impl>();
    impl_->name_ = name;

    nozzle::sender_desc sender_desc{};
    sender_desc.name = name;
    sender_desc.application_name = "openFrameworks";
    sender_desc.ring_buffer_size = 3;

    auto sender_result = nozzle::sender::create(sender_desc);
    if (!sender_result.ok()) {
        ofLogError("ofxNozzleSender") << "sender::create failed: "
            << sender_result.error().message;
        impl_.reset();
        return false;
    }
    impl_->sender_ = std::move(sender_result.value());
    impl_->setup_ = true;

    ofLogNotice("ofxNozzleSender") << "setup: " << name;
    return true;
}

void ofxNozzleSender::close() {
    if (impl_) {
        impl_->close();
    }
}

bool ofxNozzleSender::publishTexture(const ofTexture &tex) {
    if (!impl_ || !impl_->setup_) {
        ofLogError("ofxNozzleSender") << "publishTexture() called but not set up";
        return false;
    }

    const auto &td = tex.getTextureData();
    return publishTexture(
        td.textureID, td.textureTarget,
        static_cast<int>(td.width), static_cast<int>(td.height),
        normalize_gl_format(td.glInternalFormat));
}

bool ofxNozzleSender::publishTexture(
    GLuint textureID, GLenum target, int width, int height, int glInternalFormat)
{
    if (!impl_ || !impl_->setup_) {
        ofLogError("ofxNozzleSender") << "publishTexture() called but not set up";
        return false;
    }

    if (textureID == 0) {
        ofLogError("ofxNozzleSender") << "invalid texture ID";
        return false;
    }

    if (width <= 0 || height <= 0) {
        ofLogError("ofxNozzleSender") << "dimensions must be positive";
        return false;
    }

    int fmt = normalize_gl_format(glInternalFormat);

    if (fmt != glInternalFormat && fmt != impl_->last_published_gl_format_) {
        ofLogNotice("ofxNozzleSender") << gl_format_str(glInternalFormat)
            << " normalized to " << gl_format_str(fmt);
        impl_->last_published_gl_format_ = fmt;
    }

    if (!is_supported_gl_format(fmt)) {
        ofLogWarning("ofxNozzleSender") << "unsupported GL format: "
            << gl_format_str(glInternalFormat);
        return false;
    }

    glFlush();

    nozzle::gl::gl_texture_desc gl_desc{};
    gl_desc.name = textureID;
    gl_desc.target = target;
    gl_desc.width = static_cast<uint32_t>(width);
    gl_desc.height = static_cast<uint32_t>(height);
    gl_desc.format = gl_format_to_nozzle(fmt);

    auto result = nozzle::gl::publish_gl_texture(impl_->sender_, gl_desc);
    if (!result.ok()) {
        ofLogError("ofxNozzleSender") << "publish failed: " << result.error().message;
        return false;
    }
    return true;
}

void ofxNozzleSender::setMetadata(const std::string &key, const std::string &value) {
    if (!impl_ || !impl_->setup_) {
        ofLogWarning("ofxNozzleSender") << "setMetadata() called but not set up";
        return;
    }

    nozzle::metadata_list metadata = {{key, value}};
    auto result = impl_->sender_.set_metadata(metadata);
    if (!result.ok()) {
        ofLogError("ofxNozzleSender") << "set_metadata failed: " << result.error().message;
    }
}

bool ofxNozzleSender::isSetup() const {
    return impl_ && impl_->setup_;
}

std::string ofxNozzleSender::getName() const {
    return impl_ ? impl_->name_ : std::string{};
}
