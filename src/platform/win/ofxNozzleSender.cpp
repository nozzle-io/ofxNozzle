// ofxNozzleSender.cpp - Windows: publishTexture → temp FBO → glReadPixels → D3D11 UpdateSubresource → nozzle publish

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <d3d11.h>
#include <dxgi.h>
#include "ofMain.h"

#include "ofxNozzleSender.h"

#include <nozzle/nozzle.hpp>
#include <nozzle/backends/d3d11.hpp>

#include "ofLog.h"

#include <vector>

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

nozzle::texture_format gl_format_to_nozzle(uint32_t gl_format) {
    switch (gl_format) {
        case GL_R8:            return nozzle::texture_format::r8_unorm;
        case GL_RG8:           return nozzle::texture_format::rg8_unorm;
        case GL_RGBA8:         return nozzle::texture_format::rgba8_unorm;
        case GL_BGRA8_EXT:     return nozzle::texture_format::bgra8_unorm;
        case GL_SRGB8_ALPHA8:  return nozzle::texture_format::rgba8_srgb;
        case GL_R16F:          return nozzle::texture_format::r16_float;
        case GL_RG16F:         return nozzle::texture_format::rg16_float;
        case GL_RGBA16F:       return nozzle::texture_format::rgba16_float;
        case GL_R32F:          return nozzle::texture_format::r32_float;
        case GL_RG32F:         return nozzle::texture_format::rg32_float;
        case GL_RGBA32F:       return nozzle::texture_format::rgba32_float;
        default:               return nozzle::texture_format::bgra8_unorm;
    }
}

uint32_t gl_format_bytes_per_pixel(uint32_t gl_format) {
    switch (gl_format) {
        case GL_R8:            return 1;
        case GL_RG8:           return 2;
        case GL_R16F:          return 2;
        case GL_R32F:          return 4;
        case GL_RG16F:         return 4;
        case GL_RG32F:         return 8;
        case GL_RGBA16F:       return 8;
        case GL_RGBA32F:       return 16;
        default:               return 4;
    }
}

uint32_t nozzle_format_to_dxgi(nozzle::texture_format fmt) {
    switch (fmt) {
        case nozzle::texture_format::r8_unorm:       return DXGI_FORMAT_R8_UNORM;
        case nozzle::texture_format::rg8_unorm:       return DXGI_FORMAT_R8G8_UNORM;
        case nozzle::texture_format::bgra8_unorm:     return DXGI_FORMAT_B8G8R8A8_UNORM;
        case nozzle::texture_format::rgba8_unorm:     return DXGI_FORMAT_R8G8B8A8_UNORM;
        case nozzle::texture_format::rgba8_srgb:      return DXGI_FORMAT_R8G8B8A8_UNORM;
        case nozzle::texture_format::bgra8_srgb:      return DXGI_FORMAT_B8G8R8A8_UNORM;
        case nozzle::texture_format::r16_float:       return DXGI_FORMAT_R16_FLOAT;
        case nozzle::texture_format::rg16_float:      return DXGI_FORMAT_R16G16_FLOAT;
        case nozzle::texture_format::rgba16_float:    return DXGI_FORMAT_R16G16B16A16_FLOAT;
        case nozzle::texture_format::r32_float:       return DXGI_FORMAT_R32_FLOAT;
        case nozzle::texture_format::rg32_float:      return DXGI_FORMAT_R32G32_FLOAT;
        case nozzle::texture_format::rgba32_float:    return DXGI_FORMAT_R32G32B32A32_FLOAT;
        case nozzle::texture_format::r32_uint:        return DXGI_FORMAT_R32_UINT;
        case nozzle::texture_format::rgba32_uint:     return DXGI_FORMAT_R32G32B32A32_UINT;
        case nozzle::texture_format::depth32_float:   return DXGI_FORMAT_R32_FLOAT;
        default: return DXGI_FORMAT_B8G8R8A8_UNORM;
    }
}

GLenum gl_read_format(uint32_t gl_format) {
    switch (gl_format) {
        case GL_R8:
        case GL_R16F:
        case GL_R32F:          return GL_RED;
        case GL_RG8:
        case GL_RG16F:
        case GL_RG32F:         return GL_RG;
        case GL_RGBA32F:
        case GL_RGBA16F:
        case GL_RGBA8:
        case GL_SRGB8_ALPHA8:  return GL_RGBA;
        default:               return GL_BGRA;
    }
}

GLenum gl_read_type(uint32_t gl_format) {
    switch (gl_format) {
        case GL_R16F:
        case GL_RG16F:
        case GL_RGBA16F:       return GL_HALF_FLOAT;
        case GL_R32F:
        case GL_RG32F:
        case GL_RGBA32F:       return GL_FLOAT;
        case GL_R8:
        case GL_RG8:
        case GL_RGBA8:
        case GL_SRGB8_ALPHA8:
        default:               return GL_UNSIGNED_BYTE;
    }
}

} // namespace

struct ofxNozzleSender::Impl {
    std::string name_{};
    bool setup_{false};

    nozzle::sender sender_{};
    int last_published_gl_format_{-1};

    GLuint temp_fbo_{0};
    GLint saved_fbo_{0};
    std::vector<uint8_t> pixel_buffer_{};

    ~Impl() { close(); }

    void close() {
        if (!setup_) {
            return;
        }
        setup_ = false;

        sender_ = nozzle::sender{};

        if (temp_fbo_ != 0) {
            glDeleteFramebuffers(1, &temp_fbo_);
            temp_fbo_ = 0;
        }

        pixel_buffer_.clear();
        pixel_buffer_.shrink_to_fit();
    }

    bool ensure_temp_fbo() {
        if (temp_fbo_ != 0) {
            return true;
        }
        glGenFramebuffers(1, &temp_fbo_);
        return temp_fbo_ != 0;
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

    if (!wglGetCurrentContext()) {
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

    if (!impl_->ensure_temp_fbo()) {
        ofLogError("ofxNozzleSender") << "failed to create temp FBO";
        return false;
    }

    uint32_t bpp = gl_format_bytes_per_pixel(static_cast<uint32_t>(fmt));
    size_t buf_size = static_cast<size_t>(width) * static_cast<size_t>(height) * bpp;
    if (impl_->pixel_buffer_.size() < buf_size) {
        impl_->pixel_buffer_.resize(buf_size);
    }

    glFlush();

    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &impl_->saved_fbo_);

    glBindFramebuffer(GL_FRAMEBUFFER, impl_->temp_fbo_);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           target, textureID, 0);

    GLenum fbo_status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (fbo_status != GL_FRAMEBUFFER_COMPLETE) {
        ofLogError("ofxNozzleSender") << "temp FBO incomplete: 0x"
            << std::hex << fbo_status;
        glBindFramebuffer(GL_FRAMEBUFFER, impl_->saved_fbo_);
        return false;
    }

    glReadPixels(
        0, 0, width, height,
        gl_read_format(static_cast<uint32_t>(fmt)),
        gl_read_type(static_cast<uint32_t>(fmt)),
        impl_->pixel_buffer_.data());

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           target, 0, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, impl_->saved_fbo_);

    auto nozzle_format = gl_format_to_nozzle(static_cast<uint32_t>(fmt));
    nozzle::texture_desc tex_desc{};
    tex_desc.width = static_cast<uint32_t>(width);
    tex_desc.height = static_cast<uint32_t>(height);
    tex_desc.format = nozzle_format;

    auto frame_result = impl_->sender_.acquire_writable_frame(tex_desc);
    if (!frame_result.ok()) {
        ofLogError("ofxNozzleSender") << "acquire_writable_frame failed: "
            << frame_result.error().message;
        return false;
    }

    auto &writable = frame_result.value();
    auto &frame_tex = writable.get_texture();

    ID3D11Texture2D *d3d_tex = nozzle::d3d11::get_texture(frame_tex);
    if (!d3d_tex) {
        ofLogError("ofxNozzleSender") << "failed to get D3D11 texture from writable frame";
        return false;
    }

    D3D11_TEXTURE2D_DESC tex_desc_d3d{};
    d3d_tex->GetDesc(&tex_desc_d3d);
    ID3D11Device *device = nullptr;
    d3d_tex->GetDevice(&device);
    if (!device) {
        ofLogError("ofxNozzleSender") << "failed to get D3D11 device";
        return false;
    }
    ID3D11DeviceContext *ctx = nullptr;
    device->GetImmediateContext(&ctx);
    device->Release();

    if (ctx) {
        ctx->UpdateSubresource(
            d3d_tex, 0, nullptr,
            impl_->pixel_buffer_.data(),
            static_cast<uint32_t>(width) * bpp,
            0);
        ctx->Release();
    }

    auto commit_result = impl_->sender_.commit_frame(writable);
    if (!commit_result.ok()) {
        ofLogError("ofxNozzleSender") << "commit_frame failed: "
            << commit_result.error().message;
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
        ofLogError("ofxNozzleSender") << "set_metadata failed: "
            << result.error().message;
    }
}

bool ofxNozzleSender::isSetup() const {
    return impl_ && impl_->setup_;
}

std::string ofxNozzleSender::getName() const {
    return impl_ ? impl_->name_ : std::string{};
}
