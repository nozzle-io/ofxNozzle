#pragma once

#include "ofMain.h"
#include "ofxNozzle.h"

class ofApp : public ofBaseApp {
public:
    void setup() override;
    void update() override;
    void draw() override;

private:
    ofxNozzleSender sender;
    float hue = 0.0f;
};
