#include "ofApp.h"

void ofApp::run() {
    ofLogNotice() << "=== ofxNozzle tests (headless) ===";

    {
        ofxNozzleSender sender;
        ofxTest(!sender.isSetup(), "sender default: not setup");
    }

    {
        ofxNozzleReceiver receiver;
        ofxTest(receiver.setup("nonexistent-sender-xyz"), "receiver no sender: setup succeeds");
        ofxTest(!receiver.isConnected(), "receiver no sender: not connected");
        receiver.update();
        ofxTest(!receiver.isConnected(), "receiver no sender: update does not connect");
        receiver.close();
    }
}
