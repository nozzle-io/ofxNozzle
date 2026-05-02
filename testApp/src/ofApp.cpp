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

    {
        ofxNozzleSender sender;
        ofxTest(sender.setup("test-roundtrip", 256, 256), "roundtrip: sender setup");

        sender.begin();
        ofBackground(255, 0, 0);
        sender.end();
        sender.publish();

        ofxNozzleReceiver receiver;
        ofxTest(receiver.setup("test-roundtrip"), "roundtrip: receiver setup");

        bool received = false;
        for (int i = 0; i < 100; i++) {
            if (receiver.receive()) {
                received = true;
                break;
            }
        }
        ofxTest(received, "roundtrip: frame received");
        ofxTest(receiver.isConnected(), "roundtrip: receiver connected");

        receiver.close();
        sender.close();
    }
}
