# ofxNozzle

> This codebase is currently in its AI-slob prototyping phase: the code runs on momentum, vibes, and plausible intent.
> Proper debugging will be introduced once demand graduates from hypothetical to measurable.

openFrameworks addon for GPU texture sharing via [nozzle](https://github.com/nozzle-io/nozzle) — a cross-platform alternative to Syphon (macOS) and Spout (Windows).

Shares textures between processes on the same machine using platform-native GPU interop: Metal/IOSurface on macOS, D3D11 on Windows, DMA-BUF on Linux.

## Disclaimer / Notice

This library is currently a work in progress and contains many incomplete features and unverified implementations.
Although it may appear usable at first glance, it may not function correctly.

Please use it with the understanding that no guarantees are made regarding its behavior, and perform debugging, validation, and review as needed.
If you encounter problems, please do not become angry; instead, contributions in the form of Issues or Pull Requests would be greatly appreciated.

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
    ofFbo fbo;
    ofxNozzleSender sender;

    void setup() override {
        fbo.allocate(1920, 1080, GL_RGBA);
        sender.setup("myTextureStream");
    }

    void draw() override {
        fbo.begin();
        ofBackground(0);
        // draw your content here
        fbo.end();
        sender.publishTexture(fbo.getTexture());
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
| `setup(name)` | Initialize sender with a name |
| `close()` | Release resources |
| `publishTexture(const ofTexture&)` | Publish ofTexture to shared texture |
| `publishTexture(GLuint, GLenum, int, int, int)` | Publish raw GL texture |
| `setMetadata(key, value)` | Attach metadata to published frames |
| `isSetup()` | Check if initialized |
| `getName()` | Get sender name |

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

## Supported GL Formats

### Sender GL Formats

The sender supports 14 GL internal formats:

| GL Internal Format | nozzle format |
|---------------------|---------------|
| `GL_R8` | `r8_unorm` |
| `GL_RG8` | `rg8_unorm` |
| `GL_RGBA8` | `rgba8_unorm` |
| `GL_BGRA8_EXT` | `bgra8_unorm` |
| `GL_SRGB8_ALPHA8` | `rgba8_srgb` |
| `GL_R16` | `r16_unorm` |
| `GL_RG16` | `rg16_unorm` |
| `GL_RGBA16` | `rgba16_unorm` |
| `GL_R16F` | `r16_float` |
| `GL_RG16F` | `rg16_float` |
| `GL_RGBA16F` | `rgba16_float` |
| `GL_R32F` | `r32_float` |
| `GL_RG32F` | `rg32_float` |
| `GL_RGBA32F` | `rgba32_float` |

Unsized formats (`GL_RGBA`, `GL_BGRA`, `GL_RGB`) and 3-channel formats (`GL_RGB8`) are normalized to their 4-channel RGBA equivalents automatically.

### Receiver GL Formats

The receiver correctly handles 4 nozzle formats when creating GL textures:

| nozzle format | GL Internal Format | GL Format | GL Type |
|---------------|---------------------|-----------|---------|
| `rgba8_unorm` | `GL_RGBA8` | `GL_RGBA` | `GL_UNSIGNED_BYTE` |
| `bgra8_unorm` | `GL_BGRA8_EXT` | `GL_BGRA` | `GL_UNSIGNED_INT_8_8_8_8_REV` |
| `rgba16_float` | `GL_RGBA16F` | `GL_RGBA` | `GL_HALF_FLOAT` |
| `rgba32_float` | `GL_RGBA32F` | `GL_RGBA` | `GL_FLOAT` |

Other formats received from senders will fall back to `GL_BGRA8_EXT`, which may produce incorrect rendering.

## Architecture

All Objective-C types are hidden behind pimpl. Headers are pure C++.

```
Sender flow:
  User's ofTexture → publishTexture() → nozzle core → shared state

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

Third-party dependencies:

- [nozzle](https://github.com/nozzle-io/nozzle) — MIT
