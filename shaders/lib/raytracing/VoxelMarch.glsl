#if !defined VOXELMARCH_GLSL
#define VOXELMARCH_GLSL

#include "/../shaders/lib/settings/shadows.glsl"
#include "/../shaders/lib/raytracing/WorldToVoxelCoord.glsl"

float Lookup(vec3 position, int LOD) {
	return texelFetch(shadowtex0, VoxelToTextureSpace(position, LOD), 0).x;
}

vec4 Lookup(sampler2D samplr, vec3 position, int LOD) {
	return texelFetch(samplr, VoxelToTextureSpace(position, LOD), 0);
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

float VoxelMarch(inout vec3 pos, vec3 rayDir, out vec3 plane) {
	pos += abs(pos) * rayDir / 1024.0;
	
	vec3 pos0 = WorldToVoxelSpace(pos);
	pos  = pos0;
	
	vec3 stepDir = sign(rayDir);
	vec3 tDelta  = 1.0 / abs(rayDir);
	
	vec3 tMax0 = ((stepDir * 0.5 + 0.5) - mod(pos0, 1.0)) / rayDir;
	vec3 tMax  = tMax0;
	
	vec3 muls = vec3(0.0);
	
	float t = 0.0;
	
	// http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.42.3443&rep=rep1&type=pdf
	while (t++ < 128 && all(lessThan(abs(pos.xyz - vec3(shadowRadius, 128, shadowRadius)), vec3(shadowRadius, 128.0, shadowRadius)))) {
		float lookup = Lookup(pos, 0);
		
		if (lookup < 1.0) { pos = pos0+dot(plane,tMax)*rayDir; return lookup; }
		
		plane = fMin(tMax);
		muls = muls + plane;
		
		tMax = tMax0 + tDelta * muls;
		pos = pos0 + stepDir * muls;
	}
	
	return -1e35;
}

vec3 StepThroughVoxel(vec3 vPos, vec3 rayDir, out vec3 plane) {
	vec3 dirPositive = (sign(rayDir) * 0.5 + 0.5); // +1.0 when going in a positive direction, 0.0 otherwise.
	vec3 tDelta  = 1.0 / rayDir;
	tDelta = clamp(tDelta, -10000.0, 10000.0);

	vec3 tMax = (floor(vPos) - vPos + dirPositive)*tDelta;
	float L = fMin(tMax, plane);
	return vPos + rayDir * L;
}

bool DataIsHit(float data) {
	return data < 1.0;
}

bool OutOfBounds(vec3 point, const vec3 bound0, const vec3 bound2) {
	const vec3 mid =    (bound0 + bound2) / 2.0; // middle of bounds
	const vec3 rad = abs(bound2 - bound0) / 2.0; // radius of bounds
	
	vec3 distanceFromCenter = abs(point - mid);
	
	return any(greaterThan(distanceFromCenter, rad));
}

struct VoxelMarchIn {
	vec3  wPos;
	vec3  rayDir;
	float LOD;
};

// Return structure for the VoxelMarch function
struct VoxelMarchOut {
	bool  hit  ;
	vec3  wPos ;
	vec3  vPos ;
	vec3  plane;
	float data ; // Data actually stored at that point in the shadow map.
	int   steps;
};

const int globalMaxSteps = 1024;
int voxelMarchGlobalSteps = 0;

VoxelMarchOut VoxelMarch(VoxelMarchIn VMI) {
	vec3 pos = VMI.wPos;
	vec3 rayDir = VMI.rayDir;
	float LOD = VMI.LOD;
	
	VoxelMarchOut VMO;
	
	if (voxelMarchGlobalSteps >= globalMaxSteps) {
		VMO.hit = false;
		return VMO;
	}
	
	VMO.steps = 0;
	
	VMO.wPos = VMI.wPos;
//	VMO.wPos += (abs(VMO.wPos) + 1.0) * sign(rayDir) / 4096.0; // Slightly perturb pos along rayDir. This prevents erroneous hit detection when starting on a voxel's surface and marching away from it.
	
	VMO.vPos = WorldToVoxelSpace(VMO.wPos);
	
	while (LOD > 0) { // March the LOD down until there is not a hit, or the LOD is 0
		VMO.data = Lookup(VMO.vPos, int(LOD));
		if (!DataIsHit(VMO.data)) break;
		--LOD;
	}
	
	if (LOD == 0) { // If we just marched down to LOD=0, check if we still hit something. If so, the ray originates from inside geometry and we return.
		VMO.data = Lookup(VMO.vPos, int(LOD));
		if (DataIsHit(VMO.data)) {
			VMO.hit = true;
			VMO.wPos = VoxelToWorldSpace(VMO.vPos);
			VMO.plane = vec3(0.0);
			return VMO;
		}
	}
	
	vec3 stepDir = sign(rayDir);
	vec3 dirPositive = (stepDir * 0.5 + 0.5); // +1.0 when going in a positive direction, 0.0 otherwise.
	vec3 tDelta  = 1.0 / rayDir;
	tDelta = intBitsToFloat(floatBitsToInt(tDelta) | int(5));
	
	vec3 bound = exp2(LOD) * floor(VMO.vPos * exp2(-LOD) + dirPositive);
	
	vec3 pos0 = VMO.vPos;
	vec3 P0 = intBitsToFloat(floatBitsToInt(VMO.vPos) + ivec3(mix(vec3(-2), vec3(2), dirPositive)));
	
	vec3 plane = vec3(0.0); // Example: If taking a step in the Y direction, plane will be = vec3(0.0, 1.0, 0.0).
	
	// Based on: http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.42.3443&rep=rep1&type=pdf
	// LOD accelerated (makes large-volume queries to make big steps through empty space)
	while (++VMO.steps <= globalMaxSteps && ++voxelMarchGlobalSteps < globalMaxSteps) { // This is where the majority of work happens, so it's a bit optimized and difficult to understand.
		vec3 tMax = (bound - pos0)*tDelta;
		float L = fMin(tMax, plane);
		float oldPos = dot(VMO.vPos, plane);
		VMO.vPos = P0 + rayDir * L;
	//	if (VMO.steps % 30 == frameCounter % 30) show(VoxelToWorldSpace(VMO.vPos) / 100.0)
		if (any(greaterThan(abs(VMO.vPos - vec2(128, shadowRadius).yxy), vec2(128, shadowRadius).yxy))) { break; }
		
		LOD += abs(int(dot(VMO.vPos,plane)*exp2(-LOD-1)) - int(oldPos*exp2(-LOD-1)));
		LOD  = min(LOD, 7);
		
		VMO.data = Lookup(floor(VMO.vPos), int(LOD));
		float hit = clamp(1e35 - VMO.data*1e35, 0.0, 1.0);
		
		LOD -= (hit);
		if (LOD < 0) break;
		
		vec3 a = exp2(LOD) * floor(VMO.vPos*exp2(-LOD)+dirPositive);
		vec3 b = bound + stepDir * ((1.0 - hit) * exp2(LOD));
		vec3 oldBound = bound;
		bound = mix(a, b, plane);
	}
	
	if (LOD < 0) {
		VMO.hit = true;
		VMO.wPos = VoxelToWorldSpace(VMO.vPos);
		VMO.plane = plane * sign(-rayDir);
		return VMO;
	} else {
		VMO.hit = false;
		VMO.wPos = VoxelToWorldSpace(VMO.vPos);
		VMO.plane = plane * sign(-rayDir);
		VMO.data = -1e35;
		return VMO;
	}
}

struct RayQueueStruct {
    VoxelMarchIn VMI;
	vec3 priorTransmission;
	uint rayType;
};

const uint  PRIMARY_RAY_TYPE = (1 << 0);
const uint SUNLIGHT_RAY_TYPE = (1 << 1);
const uint  AMBIENT_RAY_TYPE = (1 << 2);
const uint SPECULAR_RAY_TYPE = (1 << 3);

#define RAYMARCH_QUEUE_BANDWIDTH 4 // [1 2 4 8 16]
#define MAX_RAYMARCH_BOUNCES 4 // [0 1 2 3 4 5 6 7 8 9 10 16]
const int rayQueueCapacity = max(min(RAYMARCH_QUEUE_BANDWIDTH, MAX_RAYMARCH_BOUNCES), 1);
RayQueueStruct[rayQueueCapacity] voxelMarchQueue;

int  rayQueueStart   = 0; // Index of the occupied front of the queue
int  rayQueueEnd     = 0; // Index of the unnoccupied back of the queue
int  rayQueueSize    = 0;
bool queueOutOfSpace = false;

bool IsQueueFull()  { return rayQueueSize == rayQueueCapacity; }
bool IsQueueEmpty() { return rayQueueSize == 0; }

float sum3(vec3 a) { return a.x + a.y + a.z; }

#include "/../shaders/lib/Tonemap.glsl"


#define EXPOSURE 0.00 // [-3.00 -2.66 -2.33 -2.00 -1.66 -1.33 -1.00 -0.66 -0.33 0.00 0.33 0.66 1.00 1.33 1.66 2.00 2.33 2.66 3.00]
#define SUN_BRIGHTNESS 1.000 // [0.000 0.100 0.125 0.250 0.375 0.500 0.625 0.750 0.875 1.000 1.125 2.500 3.75 5.000 6.250 7.500 8.750 10.00 100.0]

const float exposure = exp2(EXPOSURE);
const vec3 skyBrightness = vec3(0.4) * exposure;
const vec3 sunBrightness = vec3(1.0) * exposure * exp2(SUN_BRIGHTNESS - 1.0);
const vec3 emissiveSphereBrightness = vec3(0.0, 0.0, 1.0) * exposure;
const vec3 emissiveBrightness = vec3(4.0) * exposure;
const vec3 specularBrightess = vec3(1.0) * exposure;
const vec3 brightestThing = max(max(max(max(skyBrightness*40.0, sunBrightness), emissiveSphereBrightness), emissiveBrightness), specularBrightess);

bool EnoughLightToBePerceptable(vec3 possibleAdditionalColor, vec3 currentColor) {
	const vec3 lum = vec3(0.2125, 0.7154, 0.0721)*0+1; // luminance coefficient
	
//	return any(greaterThan(possibleAdditionalColor, vec3(1.0 / 255.0) / lum));
	
	vec3 delC = Tonemap(possibleAdditionalColor + currentColor) - Tonemap(currentColor);
	return any(greaterThan(delC, (1.0 / 255.0) / lum));
}

void RayQueuePushBack(RayQueueStruct elem, vec3 totalColor) {
	queueOutOfSpace = queueOutOfSpace || IsQueueFull();
	if (queueOutOfSpace) return;
	if (!EnoughLightToBePerceptable(elem.priorTransmission*brightestThing, totalColor)) return;
	voxelMarchQueue[rayQueueEnd % rayQueueCapacity] = elem;
	++rayQueueEnd;
	++rayQueueSize;
	return;
}

RayQueueStruct RayQueuePopFront() {
	RayQueueStruct res = voxelMarchQueue[rayQueueStart % rayQueueCapacity];
	++rayQueueStart;
	--rayQueueSize;
	return res;
}

#endif
