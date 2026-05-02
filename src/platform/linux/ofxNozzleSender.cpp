// ofxNozzleSender_linux.cpp - Linux: GL FBO → glReadPixels → DMA-BUF mmap → nozzle publish

#include "ofMain.h"

#include "ofxNozzleSender.h"

#include <nozzle/nozzle.hpp>
#include <nozzle/backends/linux.hpp>

#include "ofLog.h"

#include <sys/mman.h>
#include <unistd.h>
#include <vector>

struct ofxNozzleSender::Impl {
    std::string name_{};
    int width_{0};
    int height_{0};
    int gl_internal_format_{GL_RGBA8};
    bool setup_{false};

    GLuint fbo_id_{0};
    GLuint gl_texture_{0};
    GLint saved_fbo_{0};
    GLint saved_viewport[4]{};

    nozzle::sender sender_{};
    std::vector<uint8_t> pixel_buffer_{};

    ~Impl() {
        close();
    }

    void close() {
        if (!setup_) {
            return;
        }
        setup_ = false;

        sender_ = nozzle::sender{};

        if (gl_texture_ != 0) {
            glDeleteTextures(1, &gl_texture_);
            gl_texture_ = 0;
        }

        if (fbo_id_ != 0) {
            glDeleteFramebuffers(1, &fbo_id_);
            fbo_id_ = 0;
        }

        pixel_buffer_.clear();
        pixel_buffer_.shrink_to_fit();
    }

    static nozzle::texture_format gl_format_to_nozzle(uint32_t gl_format) {
        switch (gl_format) {
            case GL_BGRA8_EXT: return nozzle::texture_format::bgra8_unorm;
            case GL_RGBA8:     return nozzle::texture_format::rgba8_unorm;
            case GL_RGBA16F:   return nozzle::texture_format::rgba16_float;
            default:           return nozzle::texture_format::rgba8_unorm;
        }
    }

    static uint32_t gl_format_bytes_per_pixel(uint32_t gl_format) {
        switch (gl_format) {
            case GL_RGBA16F: return 8;
            default:         return 4;
        }
    }

    static GLenum gl_read_format(uint32_t gl_format) {
        switch (gl_format) {
            case GL_RGBA16F: return GL_RGBA;
            case GL_RGBA8:   return GL_RGBA;
            default:         return GL_BGRA;
        }
    }

    static GLenum gl_read_type(uint32_t gl_format) {
        switch (gl_format) {
            case GL_RGBA16F: return GL_HALF_FLOAT;
            case GL_RGBA8:   return GL_UNSIGNED_BYTE;
            default:         return GL_UNSIGNED_BYTE;
        }
    }
};

ofxNozzleSender::ofxNozzleSender() = default;
ofxNozzleSender::~ofxNozzleSender() = default;
ofxNozzleSender::ofxNozzleSender(ofxNozzleSender &&) noexcept = default;
ofxNozzleSender &ofxNozzleSender::operator=(ofxNozzleSender &&) noexcept = default;

bool ofxNozzleSender::setup(
    const std::string &name, int width, int height, int glInternalFormat)
{
    if (impl_ && impl_->setup_) {
        ofLogWarning("ofxNozzleSender") << "already set up, closing previous";
        close();
    }

    if (name.empty()) {
        ofLogError("ofxNozzleSender") << "name must not be empty";
        return false;
    }
    if (width <= 0 || height <= 0) {
        ofLogError("ofxNozzleSender") << "dimensions must be positive";
        return false;
    }

    if (!glGetCurrentContext()) {
        ofLogError("ofxNozzleSender") << "no GL context available";
        return false;
    }

    impl_ = std::make_unique<Impl>();
    impl_->name_ = name;
    impl_->width_ = width;
    impl_->height_ = height;
    impl_->gl_internal_format_ = glInternalFormat;

    glGenTextures(1, &impl_->gl_texture_);
    glBindTexture(GL_TEXTURE_2D, impl_->gl_texture_);
    glTexImage2D(GL_TEXTURE_2D, 0, glInternalFormat, width, height, 0,
                 Impl::gl_read_format(glInternalFormat),
                 Impl::gl_read_type(glInternalFormat), nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);

    glGenFramebuffers(1, &impl_->fbo_id_);
    glBindFramebuffer(GL_FRAMEBUFFER, impl_->fbo_id_);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, impl_->gl_texture_, 0);

    GLenum fbo_status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    if (fbo_status != GL_FRAMEBUFFER_COMPLETE) {
        ofLogError("ofxNozzleSender") << "FBO is not complete: 0x"
            << std::hex << fbo_status;
        glDeleteFramebuffers(1, &impl_->fbo_id_);
        impl_->fbo_id_ = 0;
        glDeleteTextures(1, &impl_->gl_texture_);
        impl_->gl_texture_ = 0;
        impl_.reset();
        return false;
    }

    uint32_t bpp = Impl::gl_format_bytes_per_pixel(glInternalFormat);
    impl_->pixel_buffer_.resize(
        static_cast<size_t>(width) * static_cast<size_t>(height) * bpp);

    nozzle::sender_desc sender_desc{};
    sender_desc.name = name;
    sender_desc.application_name = "openFrameworks";
    sender_desc.ring_buffer_size = 3;

    auto sender_result = nozzle::sender::create(sender_desc);
    if (!sender_result.ok()) {
        ofLogError("ofxNozzleSender") << "sender::create failed: "
            << sender_result.error().message;
        glDeleteFramebuffers(1, &impl_->fbo_id_);
        impl_->fbo_id_ = 0;
        glDeleteTextures(1, &impl_->gl_texture_);
        impl_->gl_texture_ = 0;
        impl_.reset();
        return false;
    }
    impl_->sender_ = std::move(sender_result.value());
    impl_->setup_ = true;

    ofLogNotice("ofxNozzleSender") << "setup: " << name
        << " " << width << "x" << height;
    return true;
}

void ofxNozzleSender::close() {
    if (impl_) {
        impl_->close();
    }
}

void ofxNozzleSender::begin() {
    if (!impl_ || !impl_->setup_) {
        ofLogError("ofxNozzleSender") << "begin() called but not set up";
        return;
    }

    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &impl_->saved_fbo_);
    glGetIntegerv(GL_VIEWPORT, impl_->saved_viewport);

    glBindFramebuffer(GL_FRAMEBUFFER, impl_->fbo_id_);
    glViewport(0, 0, impl_->width_, impl_->height_);
}

void ofxNozzleSender::end() {
    if (!impl_ || !impl_->setup_) {
        ofLogError("ofxNozzleSender") << "end() called but not set up";
        return;
    }

    glBindFramebuffer(GL_FRAMEBUFFER, impl_->saved_fbo_);
    glViewport(
        impl_->saved_viewport[0],
        impl_->saved_viewport[1],
        impl_->saved_viewport[2],
        impl_->saved_viewport[3]);
}

bool ofxNozzleSender::publish() {
    if (!impl_ || !impl_->setup_) {
        ofLogError("ofxNozzleSender") << "publish() called but not set up";
        return false;
    }

    glFlush();

    glBindFramebuffer(GL_FRAMEBUFFER, impl_->fbo_id_);
    glReadPixels(
        0, 0, impl_->width_, impl_->height_,
        Impl::gl_read_format(impl_->gl_internal_format_),
        Impl::gl_read_type(impl_->gl_internal_format_),
        impl_->pixel_buffer_.data());
    glBindFramebuffer(GL_FRAMEBUFFER, impl_->saved_fbo_);

    auto nozzle_format = Impl::gl_format_to_nozzle(impl_->gl_internal_format_);
    nozzle::texture_desc tex_desc{};
    tex_desc.width = static_cast<uint32_t>(impl_->width_);
    tex_desc.height = static_cast<uint32_t>(impl_->height_);
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

    uint32_t bpp = Impl::gl_format_bytes_per_pixel(impl_->gl_internal_format_);
    uint32_t expected_stride = static_cast<uint32_t>(impl_->width_) * bpp;
    uint32_t dmabuf_stride = static_cast<uint32_t>(dmabuf_size) /
        static_cast<uint32_t>(impl_->height_);

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
        for (int y = 0; y < impl_->height_; ++y) {
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

int ofxNozzleSender::getWidth() const {
    return impl_ ? impl_->width_ : 0;
}

int ofxNozzleSender::getHeight() const {
    return impl_ ? impl_->height_ : 0;
}

bool ofxNozzleSender::isSetup() const {
    return impl_ && impl_->setup_;
}
