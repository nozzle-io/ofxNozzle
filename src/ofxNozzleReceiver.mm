// ofxNozzleReceiver.mm - Receiver: nozzle frame → IOSurface → GL texture → ofTexture

#ifndef NOZZLE_HAS_METAL
#define NOZZLE_HAS_METAL
#endif

#include "ofMain.h"

#import <IOSurface/IOSurface.h>
#import <OpenGL/CGLIOSurface.h>

#include "ofxNozzleReceiver.h"
#include "ofxNozzleInterop.h"

#include <nozzle/nozzle.hpp>
#include <nozzle/backends/metal.hpp>

#include "ofLog.h"

#include <unordered_map>

struct ofxNozzleReceiver::Impl {
    std::string sender_name_{};
    float timeout_ms_{0};
    bool setup_{false};
    bool connected_{false};

    nozzle::receiver receiver_{};
    ofTexture texture_{};
    uint32_t current_iosurface_id_{0};
    int current_width_{0};
    int current_height_{0};

    // Cache: IOSurface ID → GLuint to avoid recreating GL textures every frame
    std::unordered_map<uint32_t, uint32_t> gl_texture_cache_{};

    ~Impl() {
        close();
    }

    void close() {
        if (!setup_) {
            return;
        }
        setup_ = false;
        connected_ = false;
        current_iosurface_id_ = 0;

        texture_.clear();

        for (auto &[id, tex] : gl_texture_cache_) {
            if (tex != 0) {
                glDeleteTextures(1, &tex);
            }
        }
        gl_texture_cache_.clear();

        receiver_ = nozzle::receiver{};
    }

    bool update_texture_from_frame(const nozzle::frame &frame) {
        const auto &tex = frame.get_texture();
        const auto &info = frame.info();

        if (!tex.valid()) {
            ofLogError("ofxNozzleReceiver") << "frame has invalid texture";
            return false;
        }

        // Get IOSurface from the nozzle texture
        void *surface_ptr = nozzle::metal::get_io_surface(tex);
        if (!surface_ptr) {
            ofLogError("ofxNozzleReceiver") << "texture has no IOSurface";
            return false;
        }

        IOSurfaceRef surface = (IOSurfaceRef)surface_ptr;
        uint32_t surface_id = IOSurfaceGetID(surface);

        int new_width = static_cast<int>(info.width);
        int new_height = static_cast<int>(info.height);

        // Determine GL internal format from nozzle texture format
        uint32_t gl_internal_format = GL_BGRA8_EXT;
        uint32_t gl_format = GL_BGRA;
        uint32_t gl_type = GL_UNSIGNED_INT_8_8_8_8_REV;

        switch (info.format) {
            case nozzle::texture_format::rgba8_unorm:
                gl_internal_format = GL_RGBA8;
                gl_format = GL_RGBA;
                gl_type = GL_UNSIGNED_BYTE;
                break;
            case nozzle::texture_format::bgra8_unorm:
                gl_internal_format = GL_BGRA8_EXT;
                gl_format = GL_BGRA;
                gl_type = GL_UNSIGNED_INT_8_8_8_8_REV;
                break;
            case nozzle::texture_format::rgba16_float:
                gl_internal_format = GL_RGBA16F;
                gl_format = GL_RGBA;
                gl_type = GL_HALF_FLOAT;
                break;
            default:
                // Fallback to BGRA
                break;
        }

        // Check if we already have a GL texture for this IOSurface
        uint32_t gl_tex = 0;
        auto cache_it = gl_texture_cache_.find(surface_id);
        if (cache_it != gl_texture_cache_.end()) {
            gl_tex = cache_it->second;
        } else {
            // Evict old textures if the cache is getting large (keep max 16)
            while (gl_texture_cache_.size() >= 16) {
                auto oldest = gl_texture_cache_.begin();
                if (oldest->second != 0) {
                    glDeleteTextures(1, &oldest->second);
                }
                gl_texture_cache_.erase(oldest);
            }

            // Create new GL texture from IOSurface
            gl_tex = ofxNozzleCreateGLTextureFromIOSurface(
                surface_ptr, new_width, new_height, gl_internal_format);
            if (gl_tex == 0) {
                ofLogError("ofxNozzleReceiver") << "failed to create GL texture from IOSurface";
                return false;
            }
            gl_texture_cache_[surface_id] = gl_tex;
        }

        // Update ofTexture using setUseExternalTextureID pattern
        if (current_iosurface_id_ != surface_id ||
            current_width_ != new_width ||
            current_height_ != new_height) {
            texture_.clear();
            texture_.setUseExternalTextureID(gl_tex);
            auto &td = texture_.texData;
            td.textureTarget = GL_TEXTURE_RECTANGLE_ARB;
            td.width = static_cast<float>(new_width);
            td.height = static_cast<float>(new_height);
            td.tex_w = static_cast<float>(new_width);
            td.tex_h = static_cast<float>(new_height);
            td.glInternalFormat = gl_internal_format;
            texture_.setTextureWrap(GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE);
            texture_.setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);
            current_iosurface_id_ = surface_id;
            current_width_ = new_width;
            current_height_ = new_height;
        } else {
            // Same surface — IOSurface content has changed, GL sees it automatically.
            // Just ensure the texture ID is current.
            texture_.setUseExternalTextureID(gl_tex);
            auto &td = texture_.texData;
            td.textureTarget = GL_TEXTURE_RECTANGLE_ARB;
            td.width = static_cast<float>(new_width);
            td.height = static_cast<float>(new_height);
            td.tex_w = static_cast<float>(new_width);
            td.tex_h = static_cast<float>(new_height);
            td.glInternalFormat = gl_internal_format;
        }

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

    // Try to create receiver — sender may not exist yet
    auto result = nozzle::receiver::create(recv_desc);
    if (!result.ok()) {
        ofLogNotice("ofxNozzleReceiver") << "sender \"" << name
            << "\" not found yet (will retry on receive): "
            << result.error().message;
        // Don't fail setup — we'll retry in receive()
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

bool ofxNozzleReceiver::receive() {
    if (!impl_ || !impl_->setup_) {
        ofLogError("ofxNozzleReceiver") << "receive() called but not set up";
        return false;
    }

    // If not connected, try to reconnect
    if (!impl_->connected_) {
        nozzle::receiver_desc recv_desc{};
        recv_desc.name = impl_->sender_name_;
        recv_desc.receive_mode_val = nozzle::receive_mode::latest_only;

        auto result = nozzle::receiver::create(recv_desc);
        if (!result.ok()) {
            return false;
        }

        impl_->receiver_ = std::move(result.value());
        impl_->connected_ = true;
        ofLogNotice("ofxNozzleReceiver") << "connected to \"" << impl_->sender_name_ << "\"";
    }

    // Check if sender is still alive
    if (!impl_->receiver_.is_connected()) {
        impl_->connected_ = false;
        impl_->receiver_ = nozzle::receiver{};
        ofLogWarning("ofxNozzleReceiver") << "sender disconnected";
        return false;
    }

    nozzle::acquire_desc acquire{};
    acquire.timeout_ms = static_cast<uint64_t>(impl_->timeout_ms_);

    auto frame_result = impl_->receiver_.acquire_frame(acquire);
    if (!frame_result.ok()) {
        // Timeout or sender not producing frames yet — not an error
        if (frame_result.error().code == nozzle::ErrorCode::Timeout ||
            frame_result.error().code == nozzle::ErrorCode::SenderClosed) {
            if (frame_result.error().code == nozzle::ErrorCode::SenderClosed) {
                impl_->connected_ = false;
                impl_->receiver_ = nozzle::receiver{};
            }
            return false;
        }
        ofLogError("ofxNozzleReceiver") << "acquire_frame failed: " << frame_result.error().message;
        impl_->connected_ = false;
        impl_->receiver_ = nozzle::receiver{};
        return false;
    }

    auto &frame = frame_result.value();
    bool ok = impl_->update_texture_from_frame(frame);
    frame.release();

    return ok;
}

const ofTexture &ofxNozzleReceiver::getTexture() const {
    static const ofTexture empty_texture;
    return impl_ ? impl_->texture_ : empty_texture;
}

void ofxNozzleReceiver::draw(float x, float y, float w, float h) const {
    if (impl_ && impl_->texture_.isAllocated()) {
        impl_->texture_.draw(x, y, w, h);
    }
}

void ofxNozzleReceiver::draw(float x, float y) const {
    if (impl_ && impl_->texture_.isAllocated()) {
        impl_->texture_.draw(x, y);
    }
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
