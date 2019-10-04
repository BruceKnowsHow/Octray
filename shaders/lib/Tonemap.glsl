#if !defined TONEMAP_GLSL
#define TONEMAP_GLSL

#define Tonemap(x) ACESFitted(x)
#define TonemapDerivative(x) ACESFittedDerivative(x)


vec3 ReinhardTonemap(vec3 color) {
	color = color / (1.0 + color);
	color = pow(color, vec3(1.0 / 2.2));
	
	return color;
}

vec3 ReinhardDerivative(vec3 color) {
	// The slope of a Reinhard tone curve approaches infinity near 0.0 inputs, so bound the input at (1.0 / 255.0)
	color = max(color, 1.0 / 255.0);
	
	return (11.0 / 5.0) * pow(color, vec3(-6.0 / 11.0)) * pow(color + 1.0, vec3(-16.0 / 11.0));
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
	color = RRTAndODTFit(color); // Apply RRT and ODT
	color = color * ACESOutputMat;
	color = pow(color, vec3(1.0 / 2.2));
	
	return color;
}

vec3 ACESFittedDerivative(vec3 color) {
	return vec3(4.0);
}


// These functions are used to decide whether further rendering is necessary,
// or whether an early-return can be used to save computation.
//
// Many rendering operations are additive (e.g. successive bounces from a raytracer, visible light is accumulated).
// At each step, the amount of possible additional light is usually reduced by a transmittance multiplier "transmit".
// If the additional light from subsequent bounces will not lead to any perceptible difference, then we don't do any more bounces.
//
// "Perceptible difference" is based on whether the RGB difference is large enough to register on a 24-bit color output (after tonemapping is applied).
// If additional light will not add at-least (1.0 / 255.0) to the final brightness, the difference will not even register on-screen.
//
// Tonemap derivative information can be used because most tonemaps have a flat curve in bright areas.
// In most tonemaps, if colors are very bright, adding more color will do very little to the final picture.
// Likewise, in dark areas with a steep tone-curve, color-contribution is more visible, and an early-return is usually not desirable.
//
// If computing the tonemap derivatives is expensive, we can just use a constant upper-bound.
//
// This technique could be extended in the future to account for which color differences are more perceptible to humans, instead of monitors.

bool NotEnoughLightToBeVisible(vec3 possibleAdditionalColor, vec3 currentColor) {
	vec3 dFdc  = TonemapDerivative(currentColor); // Derivative (or slope) of tonemap at current color
	vec3 delta = possibleAdditionalColor * dFdc;
	
	return delta.r + delta.g + delta.b < (1.0 / 255.0);
}

// This overloaded version allows you to specify the minimum difference value for a pixel to be "perceptibly different".
// In visually busy areas (such as iterative raytraced reflections), a higher threshold may be tolerable.
bool NotEnoughLightToBeVisible(vec3 possibleAdditionalColor, vec3 currentColor, const float threshold) {
	vec3 dFdc  = TonemapDerivative(currentColor); // Derivative (or slope) of tonemap at current color
	vec3 delta = possibleAdditionalColor * dFdc;
	
	return delta.r + delta.g + delta.b < threshold;
}

#endif
