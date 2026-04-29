#include "ofMain.h"
#include "ofApp.h"

int main() {
    ofGLWindowSettings settings;
    settings.setSize(1, 1);
    auto window = std::make_shared<ofAppNoWindow>(settings);
    ofRunApp(window, std::make_shared<ofApp>());
}
