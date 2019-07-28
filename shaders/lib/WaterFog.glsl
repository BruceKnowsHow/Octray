#if !defined WATERFOG_GLSL
#define WATERFOG_GLSL

#define WATER_COLOR (vec3(0.015, 0.04, 0.098))

float WaterFogAmount(vec3 pos1, vec3 pos2) {
	return -distance(pos1, pos2) / 200.0;
}

#endif
