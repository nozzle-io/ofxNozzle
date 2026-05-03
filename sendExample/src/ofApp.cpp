#include "ofApp.h"

void ofApp::setup() {
    fbo.allocate(1024, 768, GL_RGBA);
    sender.setup("nozzle-send-example");
}

void ofApp::update() {
    hue += 0.5f;
    if (hue > 360.0f) hue -= 360.0f;
}

void ofApp::draw() {
    fbo.begin();
    ofBackground(0);
    ofColor c;
    c.setHsb(static_cast<int>(hue) % 256, 200, 255);
    ofSetColor(c);
    ofDrawRectangle(100, 100, fbo.getWidth() - 200, fbo.getHeight() - 200);
    ofDrawBitmapString("nozzle sendExample", 20, 20);
    fbo.end();
    sender.publishTexture(fbo.getTexture());

    ofSetColor(255);
    ofDrawBitmapString("Sending: " + std::to_string(static_cast<int>(fbo.getWidth())) + "x" + std::to_string(static_cast<int>(fbo.getHeight())), 20, ofGetHeight() - 20);
}
