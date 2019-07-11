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
	color = pow(color, vec3(1.2)) * pow(color + 1.0, vec3(3.2));
	
	return color * (11.0 / 5.0) / 255.0;
} 

#endif
