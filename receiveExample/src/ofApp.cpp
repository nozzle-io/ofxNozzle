#include "ofApp.h"

void ofApp::setup() {
    receiver.setup("nozzle-send-example");
}

void ofApp::draw() {
    ofBackground(0);

    if (receiver.receive()) {
        receiver.draw(0, 0, ofGetWidth(), ofGetHeight());
    }

    ofSetColor(255);
    std::string status = receiver.isConnected() ? "connected" : "waiting...";
    ofDrawBitmapString("nozzle receiveExample [" + status + "]", 20, 20);
}
