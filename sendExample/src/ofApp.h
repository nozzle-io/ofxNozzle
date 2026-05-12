#pragma once

#include "ofMain.h"
#include "ofxNozzle.h"

class ofApp : public ofBaseApp {
public:
    void setup() override;
    void update() override;
    void draw() override;
    void keyPressed(int key) override;

private:
    void draw_smoke_pattern(int w, int h);

    ofFbo fbo;
    ofxNozzleSender sender;
    float hue = 0.0f;
    bool smoke_mode = false;
    int pattern_size = 0;
};
