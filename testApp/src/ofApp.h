#pragma once

#include "ofMain.h"
#include "ofxNozzle.h"

class ofApp : public ofBaseApp {
public:
    void setup() override;
    void exit() override;

private:
    bool test_sender_basic();
    bool test_sender_dimensions();
    bool test_sender_move();
    bool test_receiver_no_sender();
    bool test_send_receive();

    void log_result(const std::string &name, bool passed);
    int passed = 0;
    int failed = 0;
};
