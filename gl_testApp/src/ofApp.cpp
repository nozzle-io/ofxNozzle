#include "ofApp.h"

void ofApp::run() {
    ofLogNotice() << "=== ofxNozzle GL tests ===";

    {
        ofxNozzleSender sender;
        ofxTest(sender.setup("gl-test-sender", 256, 256), "gl sender: setup");

        sender.begin();
        ofBackground(255, 0, 0);
        sender.end();
        ofxTest(true, "gl sender: begin/end without crash");

        sender.update();
        ofxTest(true, "gl sender: update without crash");

        ofxNozzleReceiver receiver;
        ofxTest(receiver.setup("gl-test-sender"), "gl receiver: setup");

        bool received = false;
        for (int i = 0; i < 100; i++) {
            receiver.update();
            if (receiver.isConnected() && receiver.getTexture().isAllocated()) {
                received = true;
                break;
            }
        }
        ofxTest(received, "gl roundtrip: frame received");
        ofxTest(receiver.isConnected(), "gl roundtrip: connected");

        receiver.close();
        sender.close();
    }
}
