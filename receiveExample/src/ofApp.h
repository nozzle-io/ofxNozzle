#pragma once

#include "ofMain.h"
#include "ofxNozzle.h"

class ofApp : public ofBaseApp {
public:
    void setup() override;
    void draw() override;
    void keyPressed(int key) override;

private:
    void sample_and_report();

    ofxNozzleReceiver receiver;
    bool readback_mode = false;
    int frame_count = 0;
};
