# ofxNozzle

openFrameworks addon for GPU texture sharing via [nozzle](https://github.com/nozzle-io/nozzle) — a cross-platform alternative to Syphon (macOS) and Spout (Windows).

Shares textures between processes on the same machine using platform-native GPU interop: Metal/IOSurface on macOS, D3D11 on Windows, DMA-BUF on Linux.

## Platform Support

| Platform | Backend | Status |
|----------|---------|--------|
| macOS (Apple Silicon) | Metal/IOSurface | Supported |
| macOS (Intel) | Metal/IOSurface | Supported |
| Windows | D3D11 | Supported |
| Linux | DMA-BUF | Supported |

## Setup

Clone into your `addons/` directory:

```bash
cd <your_oF_project>/addons
git clone --recurse-submodules https://github.com/nozzle-io/ofxNozzle.git
```

The nozzle static library is bundled in `libs/nozzle/`. No separate build needed.

## Usage

### Sender

```cpp
#include "ofxNozzle.h"

class ofApp : public ofBaseApp {
    ofxNozzleSender sender;

    void setup() override {
        sender.setup("myTextureStream", 1920, 1080);
    }

    void draw() override {
        sender.begin();
        ofBackground(0);
        // draw your content here
        sender.end();
        sender.publish();
    }
};
```

### Receiver

```cpp
#include "ofxNozzle.h"

class ofApp : public ofBaseApp {
    ofxNozzleReceiver receiver;

    void setup() override {
        receiver.setup("myTextureStream");
    }

    void draw() override {
        if (receiver.receive()) {
            receiver.draw(0, 0);
        }
    }
};
```

## API Reference

### ofxNozzleSender

| Method | Description |
|--------|-------------|
| `setup(name, width, height, glFormat)` | Initialize sender. Default format: `GL_BGRA8_EXT` |
| `close()` | Release resources |
| `begin()` | Bind render target (call before drawing) |
| `end()` | Unbind render target |
| `publish()` | Publish current frame to shared texture |
| `setMetadata(key, value)` | Attach metadata to published frames |
| `getWidth()` / `getHeight()` | Texture dimensions |
| `isSetup()` | Check if initialized |

### ofxNozzleReceiver

| Method | Description |
|--------|-------------|
| `setup(name, timeoutMs)` | Connect to sender by name. Default timeout: 0 (non-blocking) |
| `close()` | Release resources |
| `receive()` | Poll for new frame. Returns `true` if frame available |
| `getTexture()` | Get the received texture as `ofTexture&` |
| `draw(x, y, w, h)` | Draw received texture at position/size |
| `draw(x, y)` | Draw at original size |
| `isConnected()` | Check if sender is alive |
| `getSenderName()` | Get connected sender's name |

## Architecture

```
Sender flow:
  GL FBO (begin/end) → IOSurface-backed GL texture → Metal texture → nozzle shared state

Receiver flow:
  nozzle acquire_frame → IOSurface → CGLTexImageIOSurface2D → cached GL texture → ofTexture
```

All Objective-C types are hidden behind pimpl. Headers are pure C++.

```
Sender flow:
  macOS:   GL FBO → IOSurface-backed GL texture → Metal texture → nozzle shared state
  Windows: GL FBO → glReadPixels → D3D11 texture → nozzle shared state
  Linux:   GL FBO → glReadPixels → DMA-BUF mmap → nozzle shared state

Receiver flow:
  macOS:   nozzle acquire_frame → IOSurface → CGLTexImageIOSurface2D → cached GL texture → ofTexture
  Windows: nozzle acquire_frame → D3D11 texture → glTexSubImage2D → cached GL texture → ofTexture
  Linux:   nozzle acquire_frame → DMA-BUF mmap → glTexSubImage2D → cached GL texture → ofTexture
```

## Requirements

- openFrameworks 0.12+
- macOS 12.0+ (Metal framework)
- Windows 10+ (D3D11)
- Linux (DRM/KMS, DMA-BUF)

## License

MIT
