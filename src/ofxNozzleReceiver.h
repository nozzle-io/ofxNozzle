#pragma once

#include "ofxNozzleConfig.h"

#include <memory>
#include <string>

#include "ofTexture.h"
#include "ofGLBaseTypes.h"
#include "ofGraphicsBaseTypes.h"

class ofxNozzleReceiver : public ofBaseUpdates, public ofBaseDraws, public ofBaseHasTexture {
public:
	ofxNozzleReceiver();
	~ofxNozzleReceiver() override;

	ofxNozzleReceiver(const ofxNozzleReceiver &) = delete;
	ofxNozzleReceiver &operator=(const ofxNozzleReceiver &) = delete;
	ofxNozzleReceiver(ofxNozzleReceiver &&) noexcept;
	ofxNozzleReceiver &operator=(ofxNozzleReceiver &&) noexcept;

	bool setup(const std::string &name, float timeoutMs = 0);
	void close();

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

	bool isConnected() const;
	std::string getSenderName() const;

private:
	struct Impl;
	std::unique_ptr<Impl> impl_;
};
