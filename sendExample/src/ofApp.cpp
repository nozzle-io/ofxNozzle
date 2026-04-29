#include "ofApp.h"

void ofApp::setup() {
    sender.setup("nozzle-send-example", 1024, 768);
}

void ofApp::update() {
    hue += 0.5f;
    if (hue > 360.0f) hue -= 360.0f;
}

void ofApp::draw() {
    sender.begin();
    ofBackground(0);
    ofColor c;
    c.setHsb(static_cast<int>(hue) % 256, 200, 255);
    ofSetColor(c);
    ofDrawRectangle(100, 100, ofGetWidth() - 200, ofGetHeight() - 200);
    ofDrawBitmapString("nozzle sendExample", 20, 20);
    sender.end();
    sender.publish();

    ofSetColor(255);
    ofDrawBitmapString("Sending: " + std::to_string(ofGetWidth()) + "x" + std::to_string(ofGetHeight()), 20, ofGetHeight() - 20);
}
