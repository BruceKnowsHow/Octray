#if !defined TONEMAP_GLSL
#define TONEMAP_GLSL

#define OVERALL_BRIGHTNESS          1.0 // [0.0 1/16 2/16 3/16 1/4 2/4 3/4 1.0 1.5 2.0 3.0 4.0 6.0 8.0 12.0 16.0]
#define SUNLIGHT_BRIGHTNESS         1.0 // [0.0 1/16 2/16 3/16 1/4 2/4 3/4 1.0 1.5 2.0 3.0 4.0 6.0 8.0 12.0 16.0]
#define SKY_BRIGHTNESS              1.0 // [0.0 1/16 2/16 3/16 1/4 2/4 3/4 1.0 1.5 2.0 3.0 4.0 6.0 8.0 12.0 16.0]
#define AMBIENT_BRIGHTNESS          1.0 // [0.0 1/16 2/16 3/16 1/4 2/4 3/4 1.0 1.5 2.0 3.0 4.0 6.0 8.0 12.0 16.0]
#define VIBRANCE                    1.2 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1]

#if (defined worldn1 || defined world1)
const float dimensionMultiplyer = 0.0; // Nether and end
#else
const float dimensionMultiplyer = 1.0;
#endif

const float exposure = 3.5 * OVERALL_BRIGHTNESS;

const vec3 sunBrightness = vec3(1.0) * dimensionMultiplyer * SUNLIGHT_BRIGHTNESS;
const vec3 skyBrightness = vec3(0.2) * dimensionMultiplyer / 3.14 * SKY_BRIGHTNESS;
const vec3 ambientBrightness = vec3(3.14) * AMBIENT_BRIGHTNESS;

const vec3 emissiveBrightness = vec3(0.4);
const vec3 specularBrightness = vec3(1.0);
const vec3 brightestThing = max(max(skyBrightness, sunBrightness), emissiveBrightness);

#include "utility.glsl"

#define Tonemap(x) ACESFitted(x)

vec3 ReinhardTonemap(vec3 color) {
	color = color / (1.0 + color);
	color = pow(color, vec3(1.0 / 2.2));
	
	color = clamp(color, 0.0, 1.0);
	
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
	color = color * exposure;
	color = color * ACESInputMat;
	color = RRTAndODTFit(color); // Apply RRT and ODT
	color = color * ACESOutputMat;
	color = pow(color, vec3(1.0 / 2.2));
	color = clamp(color, 0.0, 1.0);
	color = hsv(color);
	// color.g = pow(color.g, 0.8);
	color.g *= VIBRANCE;
	color = rgb(color);
	color = clamp(color, 0.0, 1.0);
	
	return color;
}

#endif
