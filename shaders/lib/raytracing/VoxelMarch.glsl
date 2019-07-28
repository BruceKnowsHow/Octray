#if !defined VOXELMARCH_GLSL
#define VOXELMARCH_GLSL

#include "/../shaders/lib/settings/shadows.glsl"

#include "/../shaders/lib/raytracing/WorldToVoxelCoord.glsl"

float Lookup(vec3 position, int LOD) {
	return texelFetch(shadowtex0, WorldToVoxelCoord(position, LOD), 0).x;
}

float fMin(vec3 a, out vec3 val) {
	float ret = min(a.x, min(a.y, a.z));
	vec2 c = 1.0 - clamp((a.xy - ret) * 1e35, 0.0, 1.0);
	val = vec3(c.xy, 1.0 - c.x - c.y);
	return ret;
}	

float VoxelMarch(inout vec3 pos, vec3 rayDir, out vec3 plane, float LOD) {
	pos += (abs(pos) + 1.0) * sign(rayDir) / 4096.0;
	pos = Part1Transform(pos);
	
	while (LOD > 0 && Lookup(pos, int(LOD)) < 1.0) --LOD;
	if (LOD == 0 && Lookup(pos, 0) < 1.0) return Lookup(pos, 0);
	
	vec3 stepDir = sign(rayDir);
	vec3 dirPositive = (stepDir * 0.5 + 0.5);
	vec3 tDelta  = 1.0 / rayDir;
	
	vec3 bound = exp2(LOD) * floor(pos * exp2(-LOD) + dirPositive);
	
	vec3 pos0 = pos;
	vec3 P0 = intBitsToFloat(floatBitsToInt(pos) + ivec3(mix(vec3(-2), vec3(2), dirPositive)));
	
	int t = 0;
	
	while (t++ < 256) {
		vec3 tMax = (bound - pos0)*tDelta;
		float L = fMin(tMax, plane);
		float oldPos = dot(pos, plane);
		pos = P0 + rayDir * L;
		
		if (any(greaterThan(abs(pos - vec2(128, shadowRadius).yxy), vec2(128, shadowRadius).yxy))) { break; }
		
		LOD += (abs(int(dot(pos,plane)*exp2(-LOD-1)) - int(oldPos*exp2(-LOD-1))));
		LOD = min(LOD, 7);
		
		float lookup = Lookup(floor(pos), int(LOD));
		float hit = clamp(1e35 - lookup*1e35, 0.0, 1.0);
		
		LOD -= (hit);
		if (LOD < 0) return lookup;
		
		vec3 a = exp2(LOD) * floor(pos*exp2(-LOD)+dirPositive);
		vec3 b = bound + stepDir * ((1.0 - hit) * exp2(LOD));
		bound = mix(a, b, plane);
	}
	
	return -1e35;
}



float VoxelMarch(inout vec3 pos, vec3 rayDir, inout vec3 plane, float LOD, bool underwater) {
	return VoxelMarch(pos, rayDir, plane, LOD);
}

#endif
