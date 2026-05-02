#include "ofApp.h"

void ofApp::run() {
    ofLogNotice() << "=== ofxNozzle tests (headless) ===";

    {
        ofxNozzleSender sender;
        ofxTest(!sender.setup("test-sender", 256, 256), "sender headless: setup fails without GL context");
        ofxTest(!sender.isSetup(), "sender headless: not setup after failed setup");
    }

    {
        ofxNozzleSender sender;
        ofxTestEq(sender.getWidth(), 0, "sender default: width is 0");
        ofxTestEq(sender.getHeight(), 0, "sender default: height is 0");
    }

    {
        ofxNozzleReceiver receiver;
        ofxTest(receiver.setup("nonexistent-sender-xyz"), "receiver no sender: setup succeeds");
        ofxTest(!receiver.isConnected(), "receiver no sender: not connected");
        ofxTest(!receiver.receive(), "receiver no sender: receive returns false");
        receiver.close();
    }
}
