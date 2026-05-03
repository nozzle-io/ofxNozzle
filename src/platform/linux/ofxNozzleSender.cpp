// ofxNozzleSender.cpp - Linux: publishTexture → temp FBO → glReadPixels → DMA-BUF mmap → nozzle publish

#include "ofxNozzleSender.h"

#include <nozzle/nozzle.hpp>
#include <nozzle/backends/linux.hpp>

#include "ofLog.h"

#include <GL/glx.h>
#include <sys/mman.h>
#include <unistd.h>
#include <vector>

namespace {

bool is_supported_gl_format(int gl_fmt) {
    switch (gl_fmt) {
        case GL_RGBA8:
        case GL_BGRA8_EXT:
        case GL_RGBA16F:
        case GL_RGBA32F:
            return true;
        default:
            return false;
    }
}

nozzle::texture_format gl_format_to_nozzle(uint32_t gl_format) {
    switch (gl_format) {
        case GL_BGRA8_EXT: return nozzle::texture_format::bgra8_unorm;
        case GL_RGBA8:     return nozzle::texture_format::rgba8_unorm;
        case GL_RGBA16F:   return nozzle::texture_format::rgba16_float;
        case GL_RGBA32F:   return nozzle::texture_format::rgba32_float;
        default:           return nozzle::texture_format::rgba8_unorm;
    }
}

uint32_t gl_format_bytes_per_pixel(uint32_t gl_format) {
    switch (gl_format) {
        case GL_RGBA16F: return 8;
        default:         return 4;
    }
}

GLenum gl_read_format(uint32_t gl_format) {
    switch (gl_format) {
        case GL_RGBA16F: return GL_RGBA;
        case GL_RGBA8:   return GL_RGBA;
        default:         return GL_BGRA;
    }
}

GLenum gl_read_type(uint32_t gl_format) {
    switch (gl_format) {
        case GL_RGBA16F: return GL_HALF_FLOAT;
        case GL_RGBA8:   return GL_UNSIGNED_BYTE;
        default:         return GL_UNSIGNED_BYTE;
    }
}

} // namespace

struct ofxNozzleSender::Impl {
    std::string name_{};
    bool setup_{false};

    nozzle::sender sender_{};

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

    if (!glXGetCurrentContext()) {
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
        td.glInternalFormat);
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

    if (!is_supported_gl_format(glInternalFormat)) {
        ofLogWarning("ofxNozzleSender") << "unsupported GL format: 0x"
            << std::hex << glInternalFormat;
        return false;
    }

    if (!impl_->ensure_temp_fbo()) {
        ofLogError("ofxNozzleSender") << "failed to create temp FBO";
        return false;
    }

    uint32_t bpp = gl_format_bytes_per_pixel(static_cast<uint32_t>(glInternalFormat));
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
        gl_read_format(static_cast<uint32_t>(glInternalFormat)),
        gl_read_type(static_cast<uint32_t>(glInternalFormat)),
        impl_->pixel_buffer_.data());

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           target, 0, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, impl_->saved_fbo_);

    auto nozzle_format = gl_format_to_nozzle(static_cast<uint32_t>(glInternalFormat));
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

    int dmabuf_fd = nozzle::dma_buf::get_dmabuf_fd(frame_tex);
    if (dmabuf_fd < 0) {
        ofLogError("ofxNozzleSender") << "failed to get DMA-BUF fd from writable frame";
        return false;
    }

    off_t dmabuf_size = lseek(dmabuf_fd, 0, SEEK_END);
    lseek(dmabuf_fd, 0, SEEK_SET);
    if (dmabuf_size <= 0) {
        ofLogError("ofxNozzleSender") << "failed to get DMA-BUF size";
        return false;
    }

    uint32_t expected_stride = static_cast<uint32_t>(width) * bpp;
    uint32_t dmabuf_stride = static_cast<uint32_t>(dmabuf_size) /
        static_cast<uint32_t>(height);

    void *mapped = mmap(nullptr, static_cast<size_t>(dmabuf_size),
                         PROT_WRITE, MAP_SHARED, dmabuf_fd, 0);
    if (mapped == MAP_FAILED) {
        ofLogError("ofxNozzleSender") << "mmap DMA-BUF failed";
        return false;
    }

    auto *dst = static_cast<uint8_t *>(mapped);
    auto *src = impl_->pixel_buffer_.data();

    if (dmabuf_stride == expected_stride) {
        std::memcpy(dst, src, static_cast<size_t>(dmabuf_size));
    } else {
        for (int y = 0; y < height; ++y) {
            std::memcpy(
                dst + static_cast<size_t>(y) * dmabuf_stride,
                src + static_cast<size_t>(y) * expected_stride,
                expected_stride);
        }
    }

    munmap(mapped, static_cast<size_t>(dmabuf_size));

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
