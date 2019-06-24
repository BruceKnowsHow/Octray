#include "/../shaders/lib/settings/shadows.glsl"

#include "/../shaders/lib/raytracing/WorldToVoxelCoord.glsl"

float Lookup(vec3 position) {
	return texelFetch(shadowtex0, WorldToVoxelCoord(position), 0).x;
}

float Lookup(vec3 position, int LOD) {
	return texelFetch(shadowtex0, WorldToVoxelCoord(position, LOD), 0).x;
}

vec3 fMin(vec3 a) {
	// Returns a unit vec3 denoting the minimum element of the parameter.
	// Example:
	// fMin( vec3(1.0, -2.0, 3.0) ) = vec3(0.0, 1.0, 0.0)
	// fMin( vec3(0.0,  0.0, 0.0) ) = vec3(0.0, 0.0, 1.0) <- defaults to Z
	
	vec2 b = clamp(clamp((a.yz - a.xy), 0.0, 1.0) * (a.zx - a.xy) * 1e35, 0.0, 1.0);
	return vec3(b.x, b.y, 1.0 - b.x - b.y);
	
	// Alternate version	
	// Note: this handles the situation where they're all equal differently
	// return vec3(lessThan(a.xyz, a.yzx) && lessThan(a.xyz, a.zxy));
}

vec3 VoxelMarch(vec3 rayOrig, vec3 rayDir, out vec3 lastStep, const bool fromSurface) {
	if (fromSurface)
		rayOrig += rayDir * abs(rayOrig) * 0.0005;
	
	vec3 adjOrig = rayOrig + gbufferModelViewInverse[3].xyz + fract(cameraPosition);
	
	vec3 pos0 = Part1Transform(adjOrig, 0);
	vec3 pos  = pos0;
	
	vec3 stepDir = sign(rayDir);
	vec3 tDelta  = 1.0 / abs(rayDir);
	
	vec3 tMax0 = ((stepDir * 0.5 + 0.5) - mod(pos0, 1.0)) / rayDir;
	vec3 tMax  = tMax0;
	
	vec3 muls = vec3(0.0);
	
	float t = 0.0;
	
	// http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.42.3443&rep=rep1&type=pdf
	while (all(lessThan(abs(pos.xyz - vec3(0, 128, 0)), vec3(shadowRadius, 128.0, shadowRadius)))) {
		float lookup = Lookup(pos);
		
		if (lookup < 1.0) return pos;
		
		lastStep = fMin(tMax);
		muls = muls + lastStep;
		
		tMax = tMax0 + tDelta * muls;
		pos = pos0 + stepDir * muls;
	}
	
	return vec3(0.0, 0.0, -1e35);
}

vec3 VoxelMarchLOD(vec3 rayOrig, vec3 rayDir, out vec3 lastStep, int LOD, const bool fromSurface) {
	if (fromSurface)
		rayOrig += rayDir * abs(rayOrig) * 0.0005;
	
	vec3 adjOrig = rayOrig + gbufferModelViewInverse[3].xyz + fract(cameraPosition);
	
	vec3 pos0 = Part1Transform(adjOrig, LOD);
	vec3 pos  = pos0;
	
	vec3 stepDir = sign(rayDir);
	vec3 tDelta  = 1.0 / abs(rayDir);
	
	vec3 tMax0   = ((stepDir * 0.5 + 0.5) * exp2(LOD) - mod(pos0, exp2(LOD))) / rayDir;
	vec3 tMax    = tMax0;
	
	vec3 muls = vec3(0.0);
	
	float t = 0.0;
	
	while (all(lessThan(abs(pos.xyz - vec3(0, 128, 0)), vec3(shadowRadius, 128.0, shadowRadius)))) {
		float lookup = Lookup(pos, LOD);
		
		if (lookup < 1.0) return pos;
		
		lastStep = fMin(tMax) * exp2(LOD);
		muls = muls + lastStep;
		
		tMax = tMax0 + tDelta * muls;
		pos = pos0 + stepDir * muls;
	}
	
	return vec3(0.0, 0.0, -1e35);
}

const float epsilon = 1.0 / (512.0);

vec3 VoxelMarch(vec3 rayOrig, vec3 rayDir, out vec3 plane, float LOD, const bool fromSurface) {
	if (fromSurface)
		rayOrig += rayDir * abs(rayOrig) * epsilon;
	
	vec3 pos0 = Part1Transform(rayOrig + gbufferModelViewInverse[3].xyz + fract(cameraPosition), int(LOD));
	vec3 pos  = pos0;
	
	while (LOD > 0 && Lookup(pos0, int(LOD)) < 1.0) --LOD; // March down to the LOD at which we don't hit anything
	if (LOD == 0 && Lookup(pos0, int(LOD)) < 1.0) return pos0; // If already inside a block, return
	
	vec3 stepDir = sign(rayDir);
	vec3 dirPositive = (stepDir * 0.5 + 0.5);
	vec3 tDelta  = 1.0 / abs(rayDir);
	
	vec3 bound = exp2(LOD) * floor(pos0 * exp2(-LOD) + dirPositive); // FloorN(exp2(LOD)), or ceilN if positive stepdir
	
	vec3 fPos0 = floor(pos0);
	
	int t = 0;
	
	while (t++ < 128) {
		vec3 tMax = abs(bound - pos0) * tDelta;
		plane = fMin(tMax);
		float L = uintBitsToFloat(floatBitsToUint(dot(tMax, plane)) + (1 << 10));
		vec3 B = pos0 + rayDir * L;
		vec3 currStep = abs(fPos0 - floor(B));
		float oldPos = dot(pos, plane);
		pos = pos0 + stepDir * currStep;
		
	//	Debug += 1.0 / 64.0;
		
		if (any(greaterThan(abs(pos - vec2(128, 0).yxy), vec2(128, shadowRadius).yxy))) { break; }
		
		LOD += (abs(int(dot(pos,plane)*exp2(-LOD-1)) - int(oldPos*exp2(-LOD-1))));
		LOD = min(LOD, 7);
		
		float lookup = Lookup(pos, int(LOD));
		float hit = clamp(1e35 - lookup*1e35, 0.0, 1.0);
		
		LOD -= (hit);
		if (LOD < 0) return pos;
		
		vec3 a = exp2(LOD) * (floor(B*exp2(-LOD)) + dirPositive);
		vec3 b = bound + stepDir * ((1.0 - hit) * exp2(LOD));
		bound = mix(a, b, plane);
	}
	
	return vec3(0.0, 0.0, -1e35);
}
