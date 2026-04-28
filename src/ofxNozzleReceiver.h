#pragma once

#include <memory>
#include <string>

#include "ofTexture.h"

class ofxNozzleReceiver {
public:
    ofxNozzleReceiver();
    ~ofxNozzleReceiver();

    ofxNozzleReceiver(const ofxNozzleReceiver &) = delete;
    ofxNozzleReceiver &operator=(const ofxNozzleReceiver &) = delete;
    ofxNozzleReceiver(ofxNozzleReceiver &&) noexcept;
    ofxNozzleReceiver &operator=(ofxNozzleReceiver &&) noexcept;

    bool setup(const std::string &name, float timeoutMs = 0);
    void close();

    bool receive();
    const ofTexture &getTexture() const;
    void draw(float x, float y, float w, float h) const;
    void draw(float x, float y) const;

    bool isConnected() const;
    std::string getSenderName() const;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};
