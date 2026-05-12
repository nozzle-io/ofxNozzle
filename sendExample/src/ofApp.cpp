#include "ofApp.h"

void ofApp::setup() {
    fbo.allocate(320, 240, GL_RGBA);
    sender.setup("nozzle-send-example");
}

void ofApp::update() {
    if (!smoke_mode) {
        hue += 0.5f;
        if (hue > 360.0f) hue -= 360.0f;
    }
}

void ofApp::draw() {
    if (smoke_mode) {
        int sizes[2] = {320, 641};
        int heights[2] = {240, 479};
        int idx = pattern_size % 2;
        int w = sizes[idx];
        int h = heights[idx];

        if (fbo.getWidth() != w || fbo.getHeight() != h) {
            fbo.allocate(w, h, GL_RGBA);
        }

        fbo.begin();
        draw_smoke_pattern(w, h);
        fbo.end();
    } else {
        fbo.begin();
        ofBackground(0);
        ofColor c;
        c.setHsb(static_cast<int>(hue) % 256, 200, 255);
        ofSetColor(c);
        ofDrawRectangle(100, 100, fbo.getWidth() - 200, fbo.getHeight() - 200);
        ofDrawBitmapString("nozzle sendExample", 20, 20);
        fbo.end();
    }

    sender.publishTexture(fbo.getTexture());

    ofSetColor(255);
    int y = 20;
    ofDrawBitmapString("Sending: " + std::to_string(static_cast<int>(fbo.getWidth())) + "x" + std::to_string(static_cast<int>(fbo.getHeight())), 20, y);
    y += 20;
    if (smoke_mode) {
        ofDrawBitmapString("[SMOKE] pattern " + std::string(pattern_size % 2 == 0 ? "320x240" : "641x479"), 20, y);
    } else {
        ofDrawBitmapString("[LIVE] press 's' for smoke pattern", 20, y);
    }
    y += 20;
    ofDrawBitmapString("'s' toggle smoke | '1' 320x240 | '2' 641x479", 20, y);
}

void ofApp::draw_smoke_pattern(int w, int h) {
    ofBackground(0, 0, 0, 255);

    ofSetColor(255);
    ofDrawRectangle(0, 0, w, 1);
    ofDrawRectangle(0, h - 1, w, 1);
    ofDrawRectangle(0, 0, 1, h);
    ofDrawRectangle(w - 1, 0, 1, h);

    int bw = (w - 6) / 4;
    int bh = (h - 6) / 4;

    ofSetColor(255, 0, 0, 255);
    ofDrawRectangle(2, 2, bw, bh);

    ofSetColor(0, 255, 0, 255);
    ofDrawRectangle(w - 2 - bw, 2, bw, bh);

    ofSetColor(0, 0, 255, 255);
    ofDrawRectangle(2, h - 2 - bh, bw, bh);

    ofSetColor(255, 255, 255, 255);
    ofDrawRectangle(w - 2 - bw, h - 2 - bh, bw, bh);

    int cx = w / 2;
    int cy = h / 2;
    int cs = 20;

    ofSetColor(255, 0, 255, 255);
    ofDrawRectangle(cx - cs * 3 / 2, cy - cs / 2, cs, cs);

    ofSetColor(0, 255, 255, 255);
    ofDrawRectangle(cx - cs / 2, cy - cs / 2, cs, cs);

    ofSetColor(255, 255, 0, 255);
    ofDrawRectangle(cx + cs / 2, cy - cs / 2, cs, cs);
}

void ofApp::keyPressed(int key) {
    if (key == 's') {
        smoke_mode = !smoke_mode;
        if (smoke_mode) {
            pattern_size = 0;
            fbo.allocate(320, 240, GL_RGBA);
        } else {
            fbo.allocate(1024, 768, GL_RGBA);
        }
    } else if (key == '1') {
        smoke_mode = true;
        pattern_size = 0;
        fbo.allocate(320, 240, GL_RGBA);
    } else if (key == '2') {
        smoke_mode = true;
        pattern_size = 1;
        fbo.allocate(641, 479, GL_RGBA);
    }
}
