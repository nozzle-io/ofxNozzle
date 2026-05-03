// ofxNozzleSender.mm - Sender: GL draw target → IOSurface → nozzle publish

#include "ofMain.h"

#import <Metal/Metal.h>
#import <IOSurface/IOSurface.h>

#include "ofxNozzleSender.h"
#include "ofxNozzleInterop.h"

#include <nozzle/nozzle.hpp>
#include <nozzle/backends/metal.hpp>

#include "ofLog.h"
#include "ofAppRunner.h"
#include "ofAppGLFWWindow.h"
#include "GLFW/glfw3.h"
#include <OpenGL/OpenGL.h>

namespace {

void release_objc_ptr(void *ptr) {
#if __has_feature(objc_arc)
    if (ptr) {
        id obj = (__bridge_transfer id)ptr;
        (void)obj;
    }
#else
    if (ptr) {
        [(id)ptr release];
    }
#endif
}

} // namespace

struct ofxNozzleSender::Impl {
    std::string name_{};
    int width_{0};
    int height_{0};
    int gl_internal_format_{GL_BGRA8_EXT};
    bool setup_{false};
    bool use_texture_{true};

    void *mtl_device_{nullptr};
    ofxNozzleInteropResources interop_{};
    GLuint fbo_id_{0};
    GLint saved_fbo_{0};
    GLint saved_viewport[4]{};
    nozzle::sender sender_{};
    nozzle::texture nozzle_texture_{};
    ofTexture texture_{};

    ~Impl() {
        close();
    }

    void close() {
        if (!setup_) {
            return;
        }
        setup_ = false;

        texture_.clear();
        nozzle_texture_ = nozzle::texture{};
        sender_ = nozzle::sender{};

        if (fbo_id_ != 0) {
            glDeleteFramebuffers(1, &fbo_id_);
            fbo_id_ = 0;
        }

        release_objc_ptr(mtl_device_);
        mtl_device_ = nullptr;

        ofxNozzleReleaseInteropResources(interop_);
    }

    void init_texture_from_gl(uint32_t gl_tex, int w, int h, int gl_fmt) {
        texture_.setUseExternalTextureID(gl_tex);
        auto &td = texture_.texData;
        td.textureTarget = GL_TEXTURE_RECTANGLE_ARB;
        td.width = static_cast<float>(w);
        td.height = static_cast<float>(h);
        td.tex_w = static_cast<float>(w);
        td.tex_h = static_cast<float>(h);
        td.glInternalFormat = gl_fmt;
        texture_.setTextureWrap(GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE);
        texture_.setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);
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

    if (!CGLGetCurrentContext()) {
        ofLogError("ofxNozzleSender") << "no GL context available";
        return false;
    }

    impl_ = std::make_unique<Impl>();
    impl_->name_ = name;
    impl_->width_ = width;
    impl_->height_ = height;
    impl_->gl_internal_format_ = glInternalFormat;

    impl_->interop_ = ofxNozzleCreateIOSurface(width, height, glInternalFormat);
    if (!impl_->interop_.valid) {
        ofLogError("ofxNozzleSender") << "failed to create IOSurface";
        impl_.reset();
        return false;
    }

    uint32_t gl_tex = ofxNozzleCreateGLTextureFromIOSurface(
        impl_->interop_.io_surface, width, height, glInternalFormat);
    if (gl_tex == 0) {
        ofLogError("ofxNozzleSender") << "failed to create GL texture from IOSurface";
        ofxNozzleReleaseInteropResources(impl_->interop_);
        impl_.reset();
        return false;
    }
    impl_->interop_.gl_texture = gl_tex;

    glGenFramebuffers(1, &impl_->fbo_id_);
    glBindFramebuffer(GL_FRAMEBUFFER, impl_->fbo_id_);
    glFramebufferTexture2D(
        GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
        GL_TEXTURE_RECTANGLE_ARB, gl_tex, 0);

    GLenum fbo_status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    if (fbo_status != GL_FRAMEBUFFER_COMPLETE) {
        ofLogError("ofxNozzleSender") << "FBO is not complete: 0x" << std::hex << fbo_status;
        glDeleteFramebuffers(1, &impl_->fbo_id_);
        impl_->fbo_id_ = 0;
        ofxNozzleReleaseInteropResources(impl_->interop_);
        impl_.reset();
        return false;
    }

    impl_->init_texture_from_gl(gl_tex, width, height, glInternalFormat);

    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            ofLogError("ofxNozzleSender") << "failed to create Metal device";
            glDeleteFramebuffers(1, &impl_->fbo_id_);
            impl_->fbo_id_ = 0;
            ofxNozzleReleaseInteropResources(impl_->interop_);
            impl_.reset();
            return false;
        }
#if __has_feature(objc_arc)
        impl_->mtl_device_ = (__bridge_retained void *)device;
#else
        impl_->mtl_device_ = (void *)device;
#endif
    }

    void *mtl_tex = ofxNozzleCreateMetalTextureFromIOSurface(
        impl_->mtl_device_,
        impl_->interop_.io_surface,
        width, height,
        impl_->interop_.pixel_format);
    if (!mtl_tex) {
        ofLogError("ofxNozzleSender") << "failed to create Metal texture from IOSurface";
        release_objc_ptr(impl_->mtl_device_);
        impl_->mtl_device_ = nullptr;
        glDeleteFramebuffers(1, &impl_->fbo_id_);
        impl_->fbo_id_ = 0;
        ofxNozzleReleaseInteropResources(impl_->interop_);
        impl_.reset();
        return false;
    }
    impl_->interop_.mtl_texture = mtl_tex;

    nozzle::metal::texture_wrap_desc wrap_desc{};
    wrap_desc.texture = mtl_tex;
    wrap_desc.io_surface = impl_->interop_.io_surface;
    wrap_desc.format = impl_->interop_.pixel_format;
    wrap_desc.width = static_cast<uint32_t>(width);
    wrap_desc.height = static_cast<uint32_t>(height);

    auto tex_result = nozzle::metal::wrap_texture(wrap_desc);
    if (!tex_result.ok()) {
        ofLogError("ofxNozzleSender") << "wrap_texture failed: " << tex_result.error().message;
        release_objc_ptr(mtl_tex);
        release_objc_ptr(impl_->mtl_device_);
        impl_->mtl_device_ = nullptr;
        glDeleteFramebuffers(1, &impl_->fbo_id_);
        impl_->fbo_id_ = 0;
        ofxNozzleReleaseInteropResources(impl_->interop_);
        impl_.reset();
        return false;
    }
    impl_->nozzle_texture_ = std::move(tex_result.value());

    std::string app_name = "openFrameworks";

    nozzle::sender_desc sender_desc{};
    sender_desc.name = name;
    sender_desc.application_name = app_name;
    sender_desc.ring_buffer_size = 3;

    auto sender_result = nozzle::sender::create(sender_desc);
    if (!sender_result.ok()) {
        ofLogError("ofxNozzleSender") << "sender::create failed: " << sender_result.error().message;
        impl_->nozzle_texture_ = nozzle::texture{};
        release_objc_ptr(mtl_tex);
        release_objc_ptr(impl_->mtl_device_);
        impl_->mtl_device_ = nullptr;
        glDeleteFramebuffers(1, &impl_->fbo_id_);
        impl_->fbo_id_ = 0;
        ofxNozzleReleaseInteropResources(impl_->interop_);
        impl_.reset();
        return false;
    }
    impl_->sender_ = std::move(sender_result.value());
    impl_->setup_ = true;

    ofLogNotice("ofxNozzleSender") << "setup: " << name << " " << width << "x" << height;
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

void ofxNozzleSender::update() {
    if (!impl_ || !impl_->setup_) {
        ofLogError("ofxNozzleSender") << "update() called but not set up";
        return;
    }

    glFlush();

    auto result = impl_->sender_.publish_external_texture(impl_->nozzle_texture_);
    if (!result.ok()) {
        ofLogError("ofxNozzleSender") << "publish failed: " << result.error().message;
    }
}

void ofxNozzleSender::draw(float x, float y, float w, float h) const {
    if (impl_ && impl_->texture_.isAllocated()) {
        impl_->texture_.draw(x, y, w, h);
    }
}

float ofxNozzleSender::getWidth() const {
    return impl_ ? static_cast<float>(impl_->width_) : 0.f;
}

float ofxNozzleSender::getHeight() const {
    return impl_ ? static_cast<float>(impl_->height_) : 0.f;
}

ofTexture &ofxNozzleSender::getTexture() {
    return impl_ ? impl_->texture_ : *const_cast<ofTexture *>(&std::as_const(*this).getTexture());
}

const ofTexture &ofxNozzleSender::getTexture() const {
    static const ofTexture empty_texture;
    return impl_ ? impl_->texture_ : empty_texture;
}

void ofxNozzleSender::setUseTexture(bool bUseTex) {
    if (impl_) {
        impl_->use_texture_ = bUseTex;
    }
}

bool ofxNozzleSender::isUsingTexture() const {
    return impl_ ? impl_->use_texture_ : true;
}

void ofxNozzleSender::resize(int width, int height) {
    if (!impl_ || !impl_->setup_) {
        ofLogError("ofxNozzleSender") << "resize() called but not set up";
        return;
    }

    auto name = impl_->name_;
    auto fmt = impl_->gl_internal_format_;
    close();
    setup(name, width, height, fmt);
}

void ofxNozzleSender::set(const ofTexture &tex) {
    if (!impl_ || !impl_->setup_) {
        ofLogError("ofxNozzleSender") << "set() called but not set up";
        return;
    }

    begin();
    ofClear(0, 0);
    ofSetColor(255);
    tex.draw(0, 0, getWidth(), getHeight());
    end();
}

void ofxNozzleSender::set(ofBaseHasTexture &tex) {
    set(tex.getTexture());
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
