#pragma once

#include "ofMain.h"
#include "ofxNozzle.h"

class ofApp : public ofBaseApp {
public:
    void setup() override;
    void draw() override;

private:
    ofxNozzleReceiver receiver;
};
