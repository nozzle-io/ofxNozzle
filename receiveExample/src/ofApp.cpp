#include "ofApp.h"
#include <array>
#include <cmath>

void ofApp::setup() {
    receiver.setup("nozzle-send-example");
}

void ofApp::draw() {
    ofBackground(0);

    if (receiver.receive()) {
        receiver.draw(0, 0, ofGetWidth(), ofGetHeight());

        if (readback_mode) {
            frame_count++;
            if (frame_count % 60 == 1) {
                sample_and_report();
            }
        }
    }

    ofSetColor(255);
    int y = 20;
    std::string status = receiver.isConnected() ? "connected" : "waiting...";
    ofDrawBitmapString("nozzle receiveExample [" + status + "]", 20, y);
    y += 20;

    if (readback_mode) {
        ofDrawBitmapString("[READBACK ON] sampling every 60 frames", 20, y);
    } else {
        ofDrawBitmapString("press 'r' to toggle readback", 20, y);
    }
}

void ofApp::sample_and_report() {
    auto &tex = receiver.getTexture();
    int w = static_cast<int>(tex.getWidth());
    int h = static_cast<int>(tex.getHeight());

    if (w <= 0 || h <= 0) return;

    ofPixels pixels;
    tex.readToPixels(pixels);
    if (pixels.size() == 0) return;

    struct sample_point {
        const char *name;
        int x, y;
        uint8_t expect_r, expect_g, expect_b;
    };

    std::array<sample_point, 5> points = {{
        {"TL",     8,     8,     255,   0,   0},
        {"TR", w - 9,     8,       0, 255,   0},
        {"BL",     8, h - 9,       0,   0, 255},
        {"BR", w - 9, h - 9,     255, 255, 255},
        {"CC", w/2,   h/2,       0, 255, 255},
    }};

    ofLogNotice("readback") << "--- " << w << "x" << h << " ---";
    for (auto &pt : points) {
        int px = std::max(0, std::min(pt.x, w - 1));
        int py = std::max(0, std::min(pt.y, h - 1));
        ofColor c = pixels.getColor(px, py);
        bool match = (std::abs(static_cast<int>(c.r) - pt.expect_r) < 16 &&
                      std::abs(static_cast<int>(c.g) - pt.expect_g) < 16 &&
                      std::abs(static_cast<int>(c.b) - pt.expect_b) < 16);
        ofLogNotice("readback")
            << pt.name
            << " (" << px << "," << py << ")"
            << " got=(" << static_cast<int>(c.r) << "," << static_cast<int>(c.g) << "," << static_cast<int>(c.b) << "," << static_cast<int>(c.a) << ")"
            << " want=(" << static_cast<int>(pt.expect_r) << "," << static_cast<int>(pt.expect_g) << "," << static_cast<int>(pt.expect_b) << ",255)"
            << (match ? " OK" : " MISMATCH");
    }
}

void ofApp::keyPressed(int key) {
    if (key == 'r') {
        readback_mode = !readback_mode;
    }
}
