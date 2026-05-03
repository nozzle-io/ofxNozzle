// ofxNozzleReceiver_linux.cpp - Linux: nozzle frame → DMA-BUF mmap → CPU → GL texture → ofTexture

#include "ofMain.h"

#include "ofxNozzleReceiver.h"

#include <nozzle/nozzle.hpp>
#include <nozzle/backends/linux.hpp>
#include "ofLog.h"

#include <sys/mman.h>
#include <unistd.h>
#include <vector>

struct ofxNozzleReceiver::Impl {
    std::string sender_name_{};
    float timeout_ms_{0};
    bool setup_{false};
    bool connected_{false};
    bool use_texture_{true};

    nozzle::receiver receiver_{};
    ofTexture texture_{};
    GLuint gl_texture_{0};
    int current_width_{0};
    int current_height_{0};
    uint32_t current_bpp_{4};

    ~Impl() {
        close();
    }

    void close() {
        if (!setup_) {
            return;
        }
        setup_ = false;
        connected_ = false;

        texture_.clear();

        if (gl_texture_ != 0) {
            glDeleteTextures(1, &gl_texture_);
            gl_texture_ = 0;
        }

        receiver_ = nozzle::receiver{};
    }

    static uint32_t format_bytes_per_pixel(nozzle::texture_format fmt) {
        switch (fmt) {
            case nozzle::texture_format::rgba16_float:
            case nozzle::texture_format::rg32_float:
                return 8;
            case nozzle::texture_format::rgba32_float:
            case nozzle::texture_format::rgba32_uint:
                return 16;
            case nozzle::texture_format::r32_float:
            case nozzle::texture_format::r32_uint:
                return 4;
            default:
                return 4;
        }
    }

    static GLenum nozzle_format_to_gl_internal(nozzle::texture_format fmt) {
        switch (fmt) {
            case nozzle::texture_format::rgba8_unorm:  return GL_RGBA8;
            case nozzle::texture_format::bgra8_unorm:  return GL_RGBA8;
            case nozzle::texture_format::rgba16_float: return GL_RGBA16F;
            default: return GL_RGBA8;
        }
    }

    static GLenum nozzle_format_to_gl_format(nozzle::texture_format fmt) {
        switch (fmt) {
            case nozzle::texture_format::rgba8_unorm:  return GL_RGBA;
            case nozzle::texture_format::rgba16_float: return GL_RGBA;
            default: return GL_RGBA;
        }
    }

    static GLenum nozzle_format_to_gl_type(nozzle::texture_format fmt) {
        switch (fmt) {
            case nozzle::texture_format::rgba16_float: return GL_HALF_FLOAT;
            default: return GL_UNSIGNED_BYTE;
        }
    }

    bool update_texture_from_frame(const nozzle::frame &frame) {
        const auto &tex = frame.get_texture();
        const auto &info = frame.info();

        if (!tex.valid()) {
            ofLogError("ofxNozzleReceiver") << "frame has invalid texture";
            return false;
        }

        int new_width = static_cast<int>(info.width);
        int new_height = static_cast<int>(info.height);

        int dmabuf_fd = nozzle::dma_buf::get_dmabuf_fd(tex);
        if (dmabuf_fd < 0) {
            ofLogError("ofxNozzleReceiver") << "failed to get DMA-BUF fd from frame";
            return false;
        }

        off_t dmabuf_size = lseek(dmabuf_fd, 0, SEEK_END);
        lseek(dmabuf_fd, 0, SEEK_SET);
        if (dmabuf_size <= 0) {
            ofLogError("ofxNozzleReceiver") << "failed to get DMA-BUF size";
            return false;
        }

        uint32_t bpp = format_bytes_per_pixel(info.format);
        uint32_t expected_stride = static_cast<uint32_t>(new_width) * bpp;
        uint32_t dmabuf_stride = static_cast<uint32_t>(dmabuf_size) /
            static_cast<uint32_t>(new_height);

        void *mapped = mmap(nullptr, static_cast<size_t>(dmabuf_size),
                             PROT_READ, MAP_SHARED, dmabuf_fd, 0);
        if (mapped == MAP_FAILED) {
            ofLogError("ofxNozzleReceiver") << "mmap DMA-BUF failed";
            return false;
        }

        GLenum gl_internal = nozzle_format_to_gl_internal(info.format);
        GLenum gl_format = nozzle_format_to_gl_format(info.format);
        GLenum gl_type = nozzle_format_to_gl_type(info.format);

        bool needs_recreate = (gl_texture_ == 0 ||
                               current_width_ != new_width ||
                               current_height_ != new_height ||
                               current_bpp_ != bpp);

        if (needs_recreate) {
            if (gl_texture_ != 0) {
                glDeleteTextures(1, &gl_texture_);
                gl_texture_ = 0;
            }

            glGenTextures(1, &gl_texture_);
            glBindTexture(GL_TEXTURE_2D, gl_texture_);
            glTexImage2D(GL_TEXTURE_2D, 0, gl_internal,
                         new_width, new_height, 0,
                         gl_format, gl_type, nullptr);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glBindTexture(GL_TEXTURE_2D, 0);

            texture_.clear();
            texture_.setUseExternalTextureID(gl_texture_);
            auto &td = texture_.texData;
            td.textureTarget = GL_TEXTURE_2D;
            td.width = static_cast<float>(new_width);
            td.height = static_cast<float>(new_height);
            td.tex_w = static_cast<float>(new_width);
            td.tex_h = static_cast<float>(new_height);
            td.glInternalFormat = gl_internal;
            texture_.setTextureWrap(GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE);
            texture_.setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);

            current_width_ = new_width;
            current_height_ = new_height;
            current_bpp_ = bpp;
        }

        glBindTexture(GL_TEXTURE_2D, gl_texture_);
        auto *src = static_cast<const uint8_t *>(mapped);
        if (dmabuf_stride == expected_stride) {
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, new_width, new_height,
                            gl_format, gl_type, src);
        } else {
            for (int y = 0; y < new_height; ++y) {
                glTexSubImage2D(GL_TEXTURE_2D, 0, 0, y, new_width, 1,
                                gl_format, gl_type,
                                src + static_cast<size_t>(y) * dmabuf_stride);
            }
        }
        glBindTexture(GL_TEXTURE_2D, 0);

        munmap(mapped, static_cast<size_t>(dmabuf_size));

        return true;
    }
};

ofxNozzleReceiver::ofxNozzleReceiver() = default;
ofxNozzleReceiver::~ofxNozzleReceiver() = default;
ofxNozzleReceiver::ofxNozzleReceiver(ofxNozzleReceiver &&) noexcept = default;
ofxNozzleReceiver &ofxNozzleReceiver::operator=(ofxNozzleReceiver &&) noexcept = default;

bool ofxNozzleReceiver::setup(const std::string &name, float timeoutMs) {
    if (impl_ && impl_->setup_) {
        ofLogWarning("ofxNozzleReceiver") << "already set up, closing previous";
        close();
    }

    if (name.empty()) {
        ofLogError("ofxNozzleReceiver") << "sender name must not be empty";
        return false;
    }

    impl_ = std::make_unique<Impl>();
    impl_->sender_name_ = name;
    impl_->timeout_ms_ = timeoutMs;

    nozzle::receiver_desc recv_desc{};
    recv_desc.name = name;
    recv_desc.receive_mode_val = nozzle::receive_mode::latest_only;

    auto result = nozzle::receiver::create(recv_desc);
    if (!result.ok()) {
        ofLogNotice("ofxNozzleReceiver") << "sender \"" << name
            << "\" not found yet (will retry on receive): "
            << result.error().message;
        impl_->setup_ = true;
        impl_->connected_ = false;
        return true;
    }

    impl_->receiver_ = std::move(result.value());
    impl_->setup_ = true;
    impl_->connected_ = true;

    ofLogNotice("ofxNozzleReceiver") << "setup: connected to \"" << name << "\"";
    return true;
}

void ofxNozzleReceiver::close() {
    if (impl_) {
        impl_->close();
    }
}

void ofxNozzleReceiver::update() {
    if (!impl_ || !impl_->setup_) {
        ofLogError("ofxNozzleReceiver") << "update() called but not set up";
        return;
    }

    if (!impl_->connected_) {
        nozzle::receiver_desc recv_desc{};
        recv_desc.name = impl_->sender_name_;
        recv_desc.receive_mode_val = nozzle::receive_mode::latest_only;

        auto result = nozzle::receiver::create(recv_desc);
        if (!result.ok()) {
            return;
        }

        impl_->receiver_ = std::move(result.value());
        impl_->connected_ = true;
        ofLogNotice("ofxNozzleReceiver") << "connected to \""
            << impl_->sender_name_ << "\"";
    }

    if (!impl_->receiver_.is_connected()) {
        impl_->connected_ = false;
        impl_->receiver_ = nozzle::receiver{};
        ofLogWarning("ofxNozzleReceiver") << "sender disconnected";
        return;
    }

    nozzle::acquire_desc acquire{};
    acquire.timeout_ms = static_cast<uint64_t>(impl_->timeout_ms_);

    auto frame_result = impl_->receiver_.acquire_frame(acquire);
    if (!frame_result.ok()) {
        if (frame_result.error().code == nozzle::ErrorCode::Timeout ||
            frame_result.error().code == nozzle::ErrorCode::SenderClosed) {
            if (frame_result.error().code == nozzle::ErrorCode::SenderClosed) {
                impl_->connected_ = false;
                impl_->receiver_ = nozzle::receiver{};
            }
            return;
        }
        ofLogError("ofxNozzleReceiver") << "acquire_frame failed: "
            << frame_result.error().message;
        impl_->connected_ = false;
        impl_->receiver_ = nozzle::receiver{};
        return;
    }

    auto &frame = frame_result.value();
    impl_->update_texture_from_frame(frame);
    frame.release();
}

const ofTexture &ofxNozzleReceiver::getTexture() const {
    static const ofTexture empty_texture;
    return impl_ ? impl_->texture_ : empty_texture;
}

ofTexture &ofxNozzleReceiver::getTexture() {
    return impl_ ? impl_->texture_ : *const_cast<ofTexture *>(&std::as_const(*this).getTexture());
}

void ofxNozzleReceiver::draw(float x, float y, float w, float h) const {
    if (impl_ && impl_->texture_.isAllocated()) {
        impl_->texture_.draw(x, y, w, h);
    }
}

float ofxNozzleReceiver::getWidth() const {
    return impl_ ? static_cast<float>(impl_->current_width_) : 0.f;
}

float ofxNozzleReceiver::getHeight() const {
    return impl_ ? static_cast<float>(impl_->current_height_) : 0.f;
}

void ofxNozzleReceiver::setUseTexture(bool bUseTex) {
    if (impl_) {
        impl_->use_texture_ = bUseTex;
    }
}

bool ofxNozzleReceiver::isUsingTexture() const {
    return impl_ ? impl_->use_texture_ : true;
}

bool ofxNozzleReceiver::isConnected() const {
    return impl_ && impl_->connected_;
}

std::string ofxNozzleReceiver::getSenderName() const {
    if (!impl_ || !impl_->connected_) {
        return "";
    }
    auto info = impl_->receiver_.connected_info();
    return info.application_name;
}
