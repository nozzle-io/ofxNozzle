#include "ofApp.h"

void ofApp::run() {
    ofLogNotice() << "=== ofxNozzle tests ===";

    {
        ofxNozzleSender sender;
        ofxTest(sender.setup("test-sender", 256, 256), "sender basic: setup succeeds");
        ofxTest(sender.isSetup(), "sender basic: isSetup after setup");
        sender.close();
        ofxTest(!sender.isSetup(), "sender basic: !isSetup after close");
    }

    {
        ofxNozzleSender sender;
        sender.setup("test-dims", 640, 480);
        ofxTestEq(static_cast<int>(sender.getWidth()), 640, "sender dims: width");
        ofxTestEq(static_cast<int>(sender.getHeight()), 480, "sender dims: height");
        sender.close();
    }

    {
        ofxNozzleSender sender;
        sender.setup("test-move", 256, 256);
        ofxNozzleSender moved = std::move(sender);
        ofxTest(moved.isSetup(), "sender move: moved-from is valid");
        moved.close();
    }

    {
        ofxNozzleReceiver receiver;
        ofxTest(receiver.setup("nonexistent-sender-xyz"), "receiver no sender: setup succeeds");
        ofxTest(!receiver.isConnected(), "receiver no sender: not connected");
        ofxTest(!receiver.receive(), "receiver no sender: receive returns false");
        receiver.close();
    }

}
