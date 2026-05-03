#pragma once

#include "ofxNozzleConfig.h"
#include <memory>
#include <string>
#include "ofTexture.h"

#ifndef GL_BGRA8_EXT
#define GL_BGRA8_EXT 0x93A1
#endif

class ofxNozzleSender {
public:
    ofxNozzleSender();
    ~ofxNozzleSender();

    ofxNozzleSender(const ofxNozzleSender &) = delete;
    ofxNozzleSender &operator=(const ofxNozzleSender &) = delete;
    ofxNozzleSender(ofxNozzleSender &&) noexcept;
    ofxNozzleSender &operator=(ofxNozzleSender &&) noexcept;

    bool setup(const std::string &name);
    void close();

    bool publishTexture(const ofTexture &tex);
    bool publishTexture(GLuint textureID, GLenum target, int width, int height,
                        int glInternalFormat = GL_RGBA8);

    void setMetadata(const std::string &key, const std::string &value);
    bool isSetup() const;
    std::string getName() const;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};
