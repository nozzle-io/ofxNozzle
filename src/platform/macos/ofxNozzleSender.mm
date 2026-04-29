// ofxNozzleSender.mm - Sender: GL draw target → IOSurface → nozzle publish

#ifndef NOZZLE_HAS_METAL
#define NOZZLE_HAS_METAL
#endif

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

void *retain_objc_ptr(void *ptr) {
#if __has_feature(objc_arc)
    if (ptr) {
        id obj = (__bridge id)ptr;
        return (__bridge_retained void *)obj;
    }
    return ptr;
#else
    return ptr;
#endif
}

} // namespace

struct ofxNozzleSender::Impl {
    std::string name_{};
    int width_{0};
    int height_{0};
    int gl_internal_format_{GL_BGRA8_EXT};
    bool setup_{false};

    void *mtl_device_{nullptr};
    ofxNozzleInteropResources interop_{};
    GLuint fbo_id_{0};
    GLint saved_fbo_{0};
    GLint saved_viewport[4]{};
    nozzle::sender sender_{};
    nozzle::texture nozzle_texture_{};

    ~Impl() {
        close();
    }

    void close() {
        if (!setup_) {
            return;
        }
        setup_ = false;

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

    impl_ = std::make_unique<Impl>();
    impl_->name_ = name;
    impl_->width_ = width;
    impl_->height_ = height;
    impl_->gl_internal_format_ = glInternalFormat;

    // 1. Create IOSurface
    impl_->interop_ = ofxNozzleCreateIOSurface(width, height, glInternalFormat);
    if (!impl_->interop_.valid) {
        ofLogError("ofxNozzleSender") << "failed to create IOSurface";
        impl_.reset();
        return false;
    }

    // 2. Create GL texture from IOSurface
    uint32_t gl_tex = ofxNozzleCreateGLTextureFromIOSurface(
        impl_->interop_.io_surface, width, height, glInternalFormat);
    if (gl_tex == 0) {
        ofLogError("ofxNozzleSender") << "failed to create GL texture from IOSurface";
        ofxNozzleReleaseInteropResources(impl_->interop_);
        impl_.reset();
        return false;
    }
    impl_->interop_.gl_texture = gl_tex;

    // 3. Create FBO and attach the IOSurface-backed GL texture
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

    // 4. Create Metal device (retain for long-term storage as void*)
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

    // 5. Create Metal texture from same IOSurface
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

    // 6. Create nozzle::texture via wrap_texture
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

    // 7. Create nozzle sender
    std::string app_name = "openFrameworks";
    ofAppBaseWindow *win = ofGetWindowPtr();
    if (win) {
        GLFWwindow *window = (GLFWwindow *)win->getWindowContext();
        if (window) {
            const char *title = glfwGetWindowTitle(window);
            if (title && title[0] != '\0') {
                app_name = title;
            }
        }
    }

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

bool ofxNozzleSender::publish() {
    if (!impl_ || !impl_->setup_) {
        ofLogError("ofxNozzleSender") << "publish() called but not set up";
        return false;
    }

    glFlush();

    auto result = impl_->sender_.publish_external_texture(impl_->nozzle_texture_);
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

int ofxNozzleSender::getWidth() const {
    return impl_ ? impl_->width_ : 0;
}

int ofxNozzleSender::getHeight() const {
    return impl_ ? impl_->height_ : 0;
}

bool ofxNozzleSender::isSetup() const {
    return impl_ && impl_->setup_;
}
