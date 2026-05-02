#include "ofMain.h"
#include "ofApp.h"

int main() {
    ofGLFWWindowSettings settings;
    settings.setSize(256, 256);
    settings.visible = false;
    settings.decorated = false;
    auto window = ofCreateWindow(settings);

    auto app = std::make_shared<ofApp>();
    ofRunApp(window, app);
    return ofRunMainLoop();
}
