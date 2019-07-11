#include "/../shaders/lib/settings/shadows.glsl"

#include "/../shaders/lib/raytracing/WorldToVoxelCoord.glsl"

float Lookup(vec3 position) {
	return texelFetch(shadowtex0, WorldToVoxelCoord(position), 0).x;
}

float Lookup(vec3 position, int LOD) {
//	return textureLod(shadowtex0, vec2(WorldToVoxelCoord(position, LOD) + 0.5)/shadowMapResolution, 0).x;
	return texelFetch(shadowtex0, WorldToVoxelCoord(position, LOD), 0).x;
}

float Lookup(vec3 position, int LOD, const bool b) {
	return textureLod(shadowtex0, WorldToVoxelCoord0(position, LOD, b), 0).x;
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

float fMin(vec3 a, out vec3 val) {
	float ret = min(a.x, min(a.y, a.z));
	vec2 c = 1.0 - clamp((a.xy - ret) * 1e35, 0.0, 1.0);
	val = vec3(c.xy, 1.0 - c.x - c.y);
	return ret;
}

const float epsilon = 1.0 / (512.0);
const float epsilon2 = 1.0 / 1024.0 / 4;

vec3 VoxelMarch(vec3 rayOrig, vec3 rayDir, out vec3 plane) {
	rayOrig += plane * abs(rayOrig) * sign(rayDir) * epsilon*0;
	
	vec3 pos0 = Part1Transform(rayOrig + gbufferModelViewInverse[3].xyz + fract(cameraPosition));
	vec3 pos  = pos0;
	
	vec3 stepDir = sign(rayDir);
	vec3 tDelta  = 1.0 / abs(rayDir);
	
	vec3 tMax0 = ((stepDir * 0.5 + 0.5) - mod(pos0, 1.0)) / rayDir;
	vec3 tMax  = tMax0;
	
	vec3 muls = vec3(0.0);
	
	float t = 0.0;
	
	// http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.42.3443&rep=rep1&type=pdf
	while (t++ < 128 && all(lessThan(abs(pos.xyz - vec3(shadowRadius, 128, shadowRadius)), vec3(shadowRadius, 128.0, shadowRadius)))) {
		float lookup = Lookup(pos);
		
		if (lookup < 1.0) return pos0+dot(plane,tMax)*rayDir;
		
		plane = fMin(tMax);
		muls = muls + plane;
		
		tMax = tMax0 + tDelta * muls;
		pos = pos0 + stepDir * muls;
	}
	
	return vec3(0.0, 0.0, -1e35);
}

vec3 VoxelMarchLOD(vec3 rayOrig, vec3 rayDir, inout vec3 plane, int LOD) {
	rayOrig += plane * abs(rayOrig) * sign(rayDir) * epsilon;
	
	vec3 pos0 = Part1Transform(rayOrig + gbufferModelViewInverse[3].xyz + fract(cameraPosition));
	vec3 pos  = pos0;
	
	vec3 stepDir = sign(rayDir);
	vec3 tDelta  = 1.0 / abs(rayDir);
	
	vec3 tMax0   = ((stepDir * 0.5 + 0.5) * exp2(LOD) - mod(pos0, exp2(LOD))) / rayDir;
	vec3 tMax    = tMax0;
	
	vec3 muls = vec3(0.0);
	
	float t = 0.0;
	
	while (t++ < 128 && all(lessThan(abs(pos.xyz - vec2(128, shadowRadius).yxy), vec2(128, shadowRadius).yxy))) {
		float lookup = Lookup(pos, LOD);
		
		if (lookup < 1.0) return pos0+dot(plane,tMax)*rayDir;
		
		plane = fMin(tMax) * exp2(LOD);
		muls = muls + plane;
		
		tMax = tMax0 + tDelta * muls;
		pos = pos0 + stepDir * muls;
	}
	
	return vec3(0.0, 0.0, -1e35);
}

float VoxelMarch(inout vec3 pos, vec3 rayDir, inout vec3 plane, float LOD, const bool underwater) {
	pos += (abs(pos) + 1.0) * sign(rayDir) / 4096.0;
	pos = Part1Transform(pos);
//	pos = intBitsToFloat(floatBitsToInt(pos) + ivec3(1024*64 * plane * (sign(rayDir * pos)*0.5+0.5+sign(rayDir * pos))));
	
	while (LOD > 0 && Lookup(pos, int(LOD)) < 1.0) --LOD; // March down to the LOD at which we don't hit anything
	if (LOD == 0 && Lookup(pos, 0) < 1.0) return Lookup(pos, 0); // If already inside a block, return
	
	vec3 stepDir = sign(rayDir);
	vec3 dirPositive = (stepDir * 0.5 + 0.5);
	vec3 tDelta  = 1.0 / rayDir;
	
	vec3 bound = exp2(LOD) * floor(pos * exp2(-LOD) + dirPositive); // FloorN(exp2(LOD)), or ceilN if positive stepdir
	
	vec3 scalePos0 = -pos * tDelta;
	vec3 pos0 = pos;
	vec3 P0 = intBitsToFloat(floatBitsToInt(pos) + ivec3(mix(vec3(-2), vec3(2), dirPositive)));
//	vec3 P0 = pos + ivec3(mix(vec3(-1.0), vec3(1.0), dirPositive)) / 4096.0 / 4.0;
//	vec3 P0 = pos + vec3(mix(vec3(-1.0), vec3(1.0), dirPositive)) / 4096.0 / 4.0 / 4.0 / 2.0;
	
	vec3 lodStep = vec3(floor(pos*exp2(-LOD-1)) == floor(pos*exp2(-LOD)));
	lodStep = mix(lodStep, 1.0-lodStep, 1.0-dirPositive)*0;
	
	int t = 0;
	
	while (t++ < 256) {
	//	vec3 tMax = bound*tDelta + scalePos0;
		vec3 tMax = (bound - pos0)*tDelta;
		float L = fMin(tMax, plane);
		float oldPos = dot(pos, plane);
		pos = P0 + rayDir * L;
		
	//	Debug += rgb(vec3(LOD/8.0, 1.0, 1.0))/64.0;
	//	Debug += 1.0 / 64.0;
		
		if (any(greaterThan(abs(pos - vec2(128, shadowRadius).yxy), vec2(128, shadowRadius).yxy))) { break; }
		
	//	if (underwater && distance(pos, pos0) > 16.0) break;
		
		LOD += (abs(int(dot(pos,plane)*exp2(-LOD-1)) - int(oldPos*exp2(-LOD-1))));
	//	if (dot(lodStep, plane) > 1.5) { ++LOD; lodStep = mix(lodStep, vec3(0.0), plane); }
		LOD = min(LOD, 7);
		
		float lookup = Lookup(floor(pos), int(LOD));
		float hit = clamp(1e35 - lookup*1e35, 0.0, 1.0);
		
		LOD -= (hit);
		lodStep += plane;
		lodStep = mix(lodStep, lodStep * (1.0 - hit), plane);
		if (LOD < 0) return lookup;
		
		vec3 a = exp2(LOD) * floor(pos*exp2(-LOD)+dirPositive);
	//	vec3 a = ((ivec3(pos) >> int(LOD)) << int(LOD)) + dirPositive*exp2(LOD);
		vec3 b = bound + stepDir * ((1.0 - hit) * exp2(LOD));
		bound = mix(a, b, plane);
	}
	
	return -1e35;
}
