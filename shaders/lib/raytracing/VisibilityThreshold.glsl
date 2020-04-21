#include "/lib/Tonemap.glsl"

bool PassesVisibilityThreshold(vec3 absorb) {
	vec3 delC = Tonemap(absorb*brightestThing + totalColor) - Tonemap(totalColor);
	return any(greaterThan(delC, vec3(10.0 / 255.0)));
}
