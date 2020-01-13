#if !defined TONEMAP_GLSL
#define TONEMAP_GLSL

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
	color = color * ACESInputMat;
	color = RRTAndODTFit(color); // Apply RRT and ODT
	color = color * ACESOutputMat;
	color = pow(color, vec3(1.0 / 2.2));
	color = clamp(color, 0.0, 1.0);
	
	return color;
}

#endif
