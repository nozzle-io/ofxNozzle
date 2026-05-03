#pragma once

#include "ofxNozzleConfig.h"

#include <memory>
#include <string>

#include "ofTexture.h"
#include "ofGLBaseTypes.h"
#include "ofGraphicsBaseTypes.h"

#ifndef GL_BGRA8_EXT
#define GL_BGRA8_EXT 0x93A1
#endif

class ofxNozzleSender : public ofBaseUpdates, public ofBaseDraws, public ofBaseHasTexture {
public:
	ofxNozzleSender();
	~ofxNozzleSender() override;

	ofxNozzleSender(const ofxNozzleSender &) = delete;
	ofxNozzleSender &operator=(const ofxNozzleSender &) = delete;
	ofxNozzleSender(ofxNozzleSender &&) noexcept;
	ofxNozzleSender &operator=(ofxNozzleSender &&) noexcept;

	bool setup(const std::string &name, int width, int height, int glInternalFormat = GL_BGRA8_EXT);
	void close();

	void begin();
	void end();

	// ofBaseUpdates
	void update() override;

	// ofBaseDraws
	void draw(float x, float y, float w, float h) const override;
	float getWidth() const override;
	float getHeight() const override;

	// ofBaseHasTexture
	ofTexture &getTexture() override;
	const ofTexture &getTexture() const override;
	void setUseTexture(bool bUseTex) override;
	bool isUsingTexture() const override;

	void resize(int width, int height);
	void set(const ofTexture &tex);
	void set(ofBaseHasTexture &tex);

	void setMetadata(const std::string &key, const std::string &value);
	bool isSetup() const;

private:
	struct Impl;
	std::unique_ptr<Impl> impl_;
};
