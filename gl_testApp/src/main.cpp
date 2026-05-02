#include "ofMain.h"
#include "ofAppGLFWWindow.h"
#include "ofApp.h"

int main() {
    ofInit();

    ofGLFWWindowSettings settings;
    settings.width = 256;
    settings.height = 256;
    settings.visible = false;
    settings.decorated = false;
    auto window = std::make_shared<ofAppGLFWWindow>(settings);

    auto app = std::make_shared<ofApp>();
    ofRunApp(window, app);
    return ofRunMainLoop();
}
