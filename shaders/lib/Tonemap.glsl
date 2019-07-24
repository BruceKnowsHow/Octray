#ifndef TONEMAP_GLSL
#define TONEMAP_GLSL

#define Tonemap(x) Tonemap1(x)
#define TonemapThresholdF(x) Tonemap1ThresholdF(x)
#define TonemapThreshold(x) Tonemap1Threshold(x)

vec3 Tonemap1(vec3 color) {
	color = color / (1.0 + color);
	color = pow(color, vec3(1.0 / 2.2));
	
	return color;
}

float Tonemap1ThresholdF(vec3 color) {
	float f = max(color.r, max(color.g, color.b));
	
	f = pow(f, 1.2) / pow(f + 1.0, 3.2);
	
	return f * (11.0 / 5.0 / 255.0);
}

vec3 Tonemap1Threshold(vec3 color) {
	vec3 derivative = (5.0 / 11.0) / (pow(color, vec3(6.0 / 11.0)) * pow(color + 1.0, vec3(16.0 / 11.0)));
	
	return min(derivative, vec3(1.0));
}

bool NotEnoughLightToBeVisible(float possibleAdditionalColor, float currentColor) {
	float oneOverDerivative = (5.0 / 11.0) * pow(currentColor, 6.0 / 11.0) * pow(currentColor + 1.0, 16.0 / 11.0);
	
	return possibleAdditionalColor * min(oneOverDerivative, 1.0) < 1.0 / 255.0;
}

bool NotEnoughLightToBeVisible(vec3 possibleAdditionalColor, vec3 currentColor) {
	vec3 oneOverDerivative = (5.0 / 11.0) * pow(currentColor, vec3(6.0 / 11.0)) * pow(currentColor + 1.0, vec3(16.0 / 11.0));
	
	return all(lessThan(possibleAdditionalColor * min(oneOverDerivative, vec3(1.0)), vec3(1.0 / 255.0)));
}

#endif
