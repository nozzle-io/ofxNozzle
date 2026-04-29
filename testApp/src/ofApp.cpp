#include "ofApp.h"
#include <cstdio>

void ofApp::log_result(const std::string &name, bool passed) {
    if (passed) {
        std::printf("  PASS: %s\n", name.c_str());
        this->passed++;
    } else {
        std::printf("  FAIL: %s\n", name.c_str());
        this->failed++;
    }
}

bool ofApp::test_sender_basic() {
    ofxNozzleSender sender;
    bool ok = sender.setup("test-sender", 256, 256);
    if (!ok) return false;
    if (!sender.isSetup()) return false;
    sender.close();
    return true;
}

bool ofApp::test_sender_dimensions() {
    ofxNozzleSender sender;
    sender.setup("test-dims", 640, 480);
    if (sender.getWidth() != 640) return false;
    if (sender.getHeight() != 480) return false;
    sender.close();
    return true;
}

bool ofApp::test_sender_move() {
    ofxNozzleSender sender;
    sender.setup("test-move", 256, 256);
    ofxNozzleSender moved = std::move(sender);
    if (!moved.isSetup()) return false;
    moved.close();
    return true;
}

bool ofApp::test_receiver_no_sender() {
    ofxNozzleReceiver receiver;
    bool ok = receiver.setup("nonexistent-sender-xyz");
    if (!ok) return false;
    if (receiver.isConnected()) return false;
    if (receiver.receive()) return false;
    receiver.close();
    return true;
}

bool ofApp::test_send_receive() {
    ofxNozzleSender sender;
    bool ok = sender.setup("test-roundtrip", 256, 256);
    if (!ok) return false;

    sender.begin();
    ofBackground(255, 0, 0);
    sender.end();
    sender.publish();

    ofxNozzleReceiver receiver;
    ok = receiver.setup("test-roundtrip");
    if (!ok) return false;

    bool received = false;
    for (int i = 0; i < 100; i++) {
        if (receiver.receive()) {
            received = true;
            break;
        }
    }
    if (!received) return false;
    if (!receiver.isConnected()) return false;

    receiver.close();
    sender.close();
    return true;
}

void ofApp::setup() {
    std::printf("=== ofxNozzle testApp ===\n\n");

    log_result("sender basic", test_sender_basic());
    log_result("sender dimensions", test_sender_dimensions());
    log_result("sender move", test_sender_move());
    log_result("receiver no sender", test_receiver_no_sender());
    log_result("send receive", test_send_receive());

    std::printf("\n%d passed, %d failed\n", passed, failed);
    std::printf("==========================\n");

    ofExit(failed > 0 ? 1 : 0);
}

void ofApp::exit() {}
