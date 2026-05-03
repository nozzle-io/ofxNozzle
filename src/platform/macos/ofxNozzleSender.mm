// ofxNozzleSender.mm - Sender: GL FBO → nozzle::gl::publish_gl_texture()

#include "ofMain.h"

#include "ofxNozzleSender.h"

#include <nozzle/nozzle.hpp>
#include <nozzle/backends/opengl.hpp>

#include "ofLog.h"
#include "ofAppRunner.h"
#include "ofAppGLFWWindow.h"
#include "GLFW/glfw3.h"
#include <OpenGL/OpenGL.h>

namespace {

nozzle::texture_format gl_format_to_nozzle(int gl_fmt) {
    switch (gl_fmt) {
        case GL_BGRA8_EXT: return nozzle::texture_format::bgra8_unorm;
        case GL_RGBA8:     return nozzle::texture_format::rgba8_unorm;
        case GL_RGBA16F:   return nozzle::texture_format::rgba16_float;
        case GL_RGBA32F:   return nozzle::texture_format::rgba32_float;
        default:           return nozzle::texture_format::bgra8_unorm;
    }
}

GLenum internal_format_for_fbo(int gl_fmt) {
    switch (gl_fmt) {
        case GL_BGRA8_EXT:
        case GL_RGBA8:  return GL_RGBA8;
        case GL_RGBA16F: return GL_RGBA16F;
        case GL_RGBA32F: return GL_RGBA32F;
        default:        return GL_RGBA8;
    }
}

} // namespace

struct ofxNozzleSender::Impl {
    std::string name_{};
    int width_{0};
    int height_{0};
    int gl_internal_format_{GL_BGRA8_EXT};
    bool setup_{false};
    bool use_texture_{true};

    GLuint fbo_id_{0};
    GLuint gl_tex_{0};
    GLint saved_fbo_{0};
    GLint saved_viewport[4]{};
    nozzle::sender sender_{};
    ofTexture texture_{};
    nozzle::texture_format nozzle_format_{nozzle::texture_format::bgra8_unorm};

    ~Impl() { close(); }

    void close() {
        if (!setup_) {
            return;
        }
        setup_ = false;

        texture_.clear();
        sender_ = nozzle::sender{};

        if (fbo_id_ != 0) {
            glDeleteFramebuffers(1, &fbo_id_);
            fbo_id_ = 0;
        }
        if (gl_tex_ != 0) {
            glDeleteTextures(1, &gl_tex_);
            gl_tex_ = 0;
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

    if (!CGLGetCurrentContext()) {
        ofLogError("ofxNozzleSender") << "no GL context available";
        return false;
    }

    GLenum internal_fmt = internal_format_for_fbo(glInternalFormat);

    impl_ = std::make_unique<Impl>();
    impl_->name_ = name;
    impl_->width_ = width;
    impl_->height_ = height;
    impl_->gl_internal_format_ = glInternalFormat;
    impl_->nozzle_format_ = gl_format_to_nozzle(glInternalFormat);

    glGenTextures(1, &impl_->gl_tex_);
    glBindTexture(GL_TEXTURE_2D, impl_->gl_tex_);
    glTexImage2D(GL_TEXTURE_2D, 0, internal_fmt, width, height, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);

    glGenFramebuffers(1, &impl_->fbo_id_);
    glBindFramebuffer(GL_FRAMEBUFFER, impl_->fbo_id_);
    glFramebufferTexture2D(
        GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
        GL_TEXTURE_2D, impl_->gl_tex_, 0);

    GLenum fbo_status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    if (fbo_status != GL_FRAMEBUFFER_COMPLETE) {
        ofLogError("ofxNozzleSender") << "FBO is not complete: 0x"
            << std::hex << fbo_status;
        glDeleteTextures(1, &impl_->gl_tex_);
        impl_->gl_tex_ = 0;
        glDeleteFramebuffers(1, &impl_->fbo_id_);
        impl_->fbo_id_ = 0;
        impl_.reset();
        return false;
    }

    impl_->texture_.setUseExternalTextureID(impl_->gl_tex_);
    auto &td = impl_->texture_.texData;
    td.textureTarget = GL_TEXTURE_2D;
    td.width = static_cast<float>(width);
    td.height = static_cast<float>(height);
    td.tex_w = static_cast<float>(width);
    td.tex_h = static_cast<float>(height);
    td.glInternalFormat = glInternalFormat;
    impl_->texture_.setTextureWrap(GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE);
    impl_->texture_.setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);

    std::string app_name = "openFrameworks";

    nozzle::sender_desc sender_desc{};
    sender_desc.name = name;
    sender_desc.application_name = app_name;
    sender_desc.ring_buffer_size = 3;

    auto sender_result = nozzle::sender::create(sender_desc);
    if (!sender_result.ok()) {
        ofLogError("ofxNozzleSender") << "sender::create failed: "
            << sender_result.error().message;
        glDeleteTextures(1, &impl_->gl_tex_);
        impl_->gl_tex_ = 0;
        glDeleteFramebuffers(1, &impl_->fbo_id_);
        impl_->fbo_id_ = 0;
        impl_.reset();
        return false;
    }
    impl_->sender_ = std::move(sender_result.value());
    impl_->setup_ = true;

    ofLogNotice("ofxNozzleSender") << "setup: " << name << " "
        << width << "x" << height;
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

    nozzle::gl::gl_texture_desc gl_desc{};
    gl_desc.name = impl_->gl_tex_;
    gl_desc.target = GL_TEXTURE_2D;
    gl_desc.width = static_cast<uint32_t>(impl_->width_);
    gl_desc.height = static_cast<uint32_t>(impl_->height_);
    gl_desc.format = impl_->nozzle_format_;

    auto result = nozzle::gl::publish_gl_texture(impl_->sender_, gl_desc);
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
