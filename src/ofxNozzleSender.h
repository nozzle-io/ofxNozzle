#pragma once

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

    bool setup(const std::string &name, int width, int height, int glInternalFormat = GL_BGRA8_EXT);
    void close();

    void begin();
    void end();

    bool publish();

    void setMetadata(const std::string &key, const std::string &value);

    int getWidth() const;
    int getHeight() const;
    bool isSetup() const;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};
