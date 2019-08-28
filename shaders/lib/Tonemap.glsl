#if !defined TONEMAP_GLSL
#define TONEMAP_GLSL

#define Tonemap(x) ACESFitted(x)
#define TonemapThresholdF(x) Tonemap1ThresholdF(x)
#define TonemapThreshold(x) Tonemap1Threshold(x)

vec3 Tonemap1(vec3 color) {
	color = color / (1.0 + color);
	color = pow(color, vec3(1.0 / 2.2));
	
	return color;
}

vec3 Tonemap2(vec3 x) {
	float a = 2.51f;
	float b = 0.03f;
	float c = 2.43f;
	float d = 0.59f;
	float e = 0.14f;
	x = ((x*(a*x+b))/(x*(c*x+d)+e));
	x = pow(x, vec3(1.0 / 2.2));
	return x;
}

const mat3 ACESInputMat = mat3(
	0.59719, 0.35458, 0.04823,
	0.07600, 0.90834, 0.01566,
	0.02840, 0.13383, 0.83777
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
const mat3 ACESOutputMat = mat3(
	1.60475, -0.53108, -0.07367,
	-0.10208,  1.10813, -0.00605,
	-0.00327, -0.07276,  1.07602
);

vec3 RRTAndODTFit(vec3 v) {
	vec3 a = v * (v + 0.0245786f) - 0.000090537f;
	vec3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
	return a / b;
}

vec3 ACESFitted(vec3 color) {
	color = color * ACESInputMat;
	
	// Apply RRT and ODT
	color = RRTAndODTFit(color);
	
	color = color * ACESOutputMat;
	
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
	vec3 derivative = (11.0 / 5.0) * pow(currentColor, vec3(-6.0 / 11.0)) * pow(currentColor + 1.0, vec3(-16.0 / 11.0));
	vec3 oneOverDerivative = (5.0 / 11.0) * pow(currentColor, vec3(6.0 / 11.0)) * pow(currentColor + 1.0, vec3(16.0 / 11.0));
	
	return all(lessThan(possibleAdditionalColor / (min(derivative, vec3(1.0))), vec3(0.1 / 255.0)));
}

#endif
