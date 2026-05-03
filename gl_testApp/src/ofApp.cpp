#include "ofApp.h"

void ofApp::run() {
    ofLogNotice() << "=== ofxNozzle GL tests ===";

    {
        ofFbo fbo;
        fbo.allocate(256, 256, GL_RGBA);

        ofxNozzleSender sender;
        ofxTest(sender.setup("gl-test-sender"), "gl sender: setup");

        fbo.begin();
        ofBackground(255, 0, 0);
        fbo.end();
        ofxTest(sender.publishTexture(fbo.getTexture()), "gl sender: publishTexture");

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
