#if !defined VOXELMARCH_GLSL
#define VOXELMARCH_GLSL

#include "../settings/shadows.glsl"
#include "WorldToVoxelCoord.glsl"

// Return structure for the VoxelMarch function
struct VoxelMarchOut {
	bool  hit  ;
	vec3  vPos ;
	vec3  plane;
	ivec2 vCoord;
};

struct RayQueueStruct {
	vec3 vPos;
	vec3 rayDir;
	vec3 priorTransmission;
	uint rayInfo;
};

const uint  PRIMARY_RAY_TYPE = (1 <<  8);
const uint SUNLIGHT_RAY_TYPE = (1 <<  9);
const uint  AMBIENT_RAY_TYPE = (1 << 10);
const uint SPECULAR_RAY_TYPE = (1 << 11);

const uint INTERIOR_RAY_ATTR = (1 << 16);

const uint RAY_DEPTH_MASK = (1 << 8) - 1;
const uint RAY_TYPE_MASK  = ((1 << 16) - 1) & (~RAY_DEPTH_MASK);
const uint RAY_ATTR_MASK  = ((1 << 24) - 1) & (~RAY_DEPTH_MASK) & (~RAY_TYPE_MASK);

#define RayPush(x, y) RayPushBack(x, y)
#define RayPop() RayPopBack()

#define MAX_RAYS 64
#define MAX_RAY_DEPTH 3 // [1 2 3 4 5 6 7 8 9 10]
#define RAYMARCH_QUEUE_BANDWIDTH (MAX_RAY_DEPTH + 1)
const int rayQueueCapacity = RAYMARCH_QUEUE_BANDWIDTH;
RayQueueStruct[rayQueueCapacity] voxelMarchQueue;

int  rayQueueFront   = rayQueueCapacity*100; // Index of the occupied front of the queue
int  rayQueueBack    = rayQueueFront; // Index of the unnoccupied back of the queue
int  rayQueueSize    = 0;
bool queueOutOfSpace = false;

bool IsQueueFull()  { return rayQueueSize == rayQueueCapacity; }
bool IsQueueEmpty() { return rayQueueSize == 0; }

#include "../Tonemap.glsl"

uint PackRayInfo(uint rayDepth, const uint RAY_TYPE) {
	return rayDepth | RAY_TYPE;
}

uint PackRayInfo(uint rayDepth, const uint RAY_TYPE, uint RAY_ATTR) {
	return rayDepth | RAY_TYPE | RAY_ATTR;
}

uint GetRayType(uint rayInfo) {
	return rayInfo & RAY_TYPE_MASK;
}

bool IsRayType(uint rayInfo, const uint RAY_TYPE) {
	return (rayInfo & RAY_TYPE) != 0;
}

uint GetRayAttr(uint rayInfo) {
	return rayInfo & RAY_ATTR_MASK;
}

bool HasRayAttr(uint rayInfo, const uint RAY_ATTR) {
	return (rayInfo & RAY_ATTR) != 0;
}

uint GetRayDepth(uint rayInfo) {
	return rayInfo & RAY_DEPTH_MASK;
}

void RayPushBack(RayQueueStruct elem, vec3 totalColor) {
	if (GetRayDepth(elem.rayInfo) > MAX_RAY_DEPTH) return;
	queueOutOfSpace = queueOutOfSpace || IsQueueFull();
	if (queueOutOfSpace) return;
	if (!EnoughLightToBePerceptable(elem.priorTransmission*brightestThing, totalColor)) return;
	
	voxelMarchQueue[rayQueueBack % rayQueueCapacity] = elem;
	++rayQueueBack;
	++rayQueueSize;
	return;
}

RayQueueStruct RayPopFront() {
	RayQueueStruct res = voxelMarchQueue[rayQueueFront % rayQueueCapacity];
	++rayQueueFront;
	--rayQueueSize;
	return res;
}

RayQueueStruct RayPopBack() {
	--rayQueueBack;
	RayQueueStruct res = voxelMarchQueue[rayQueueBack % rayQueueCapacity];
	--rayQueueSize;
	return res;
}


float fMin(vec3 a, out vec3 val) {
	float ret = min(a.x, min(a.y, a.z));
	vec2 c = 1.0 - clamp((a.xy - ret) * 1e35, 0.0, 1.0);
	val = vec3(c.xy, 1.0 - c.x - c.y);
	return ret;
}

int idot(ivec3 a, ivec3 b) {
	return (a.x & b.x) | (a.y & b.y) | (a.z & b.z);
}

float fMin(vec3 a, out ivec3 val) {
	ivec3 ia = floatBitsToInt(a);
	val.xy = ((ia.xy - ia.yx) & (ia.xy - ia.zz)) >> 31;
	val.z = (-1) ^ val.x ^ val.y;
	
	return intBitsToFloat(idot(ia, val));
}

vec3 fMin(vec3 a) {
	vec3 val;
	fMin(a, val);
	return val;
}

vec3 StepThroughVoxel(vec3 vPos, vec3 rayDir, out vec3 plane) {
	vec3 dirPositive = (sign(rayDir) * 0.5 + 0.5); // +1.0 when going in a positive direction, 0.0 otherwise.
	vec3 tDelta  = 1.0 / rayDir;
	tDelta = clamp(tDelta, -10000.0, 10000.0);

	vec3 tMax = (floor(vPos) - vPos + dirPositive)*tDelta;
	float L = fMin(tMax, plane);
	
	return vPos + rayDir * L;
}

VoxelMarchOut VoxelMarch(vec3 vPos, vec3 wDir) {
	int LOD = 0;
	
	VoxelMarchOut VMO;
	
	VMO.vPos = vPos;
	
	vec3 stepDir = sign(wDir);
	ivec3 istepDir = ivec3(stepDir);
	vec3 dirPositive = (stepDir * 0.5 + 0.5); // +1.0 when going in a positive direction, 0.0 otherwise.
	ivec3 idirPositive = ivec3(dirPositive);
	vec3 tDelta  = 1.0 / wDir;
	
	vec3 pos0 = -VMO.vPos*tDelta;
	vec3 pos00 = VMO.vPos;
	vec3 P0 = VMO.vPos + stepDir / exp2(15)*0;
	
	// ivec3 bound = (((ivec3(VMO.vPos) >> LOD) ) << LOD) + idirPositive;
	ivec3 bound = ((ivec3(VMO.vPos) >> LOD) + idirPositive) << LOD;
	
	int t = 0;
	
	int offset = 0;
	int oldLOD = LOD;
	int up = 0;
	int down = 0;
	
	ivec3 ivPos = ivec3(VMO.vPos);
	ivec3 iplane = ivec3(0);
	
	// Based on: http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.42.3443&rep=rep1&type=pdf
	while (++t < 256 && LOD >= 0) {
		vec3 tMax = (bound*tDelta + pos0);
		float L = fMin(tMax, iplane);
		int oldPos = idot(ivPos, iplane);
		VMO.vPos = P0 + wDir * L;
		VMO.vPos = intBitsToFloat(((floatBitsToInt(VMO.vPos)+idirPositive-1) & (~iplane)) | ((floatBitsToInt(bound)+idirPositive-1) & iplane));
		ivPos = ivec3(VMO.vPos);
		int newPos = idot(ivPos, iplane);
		// Debug += 1.0 / 100.0;
		if (OutOfVoxelBounds(VMO.vPos)) { break; }
		
		up = abs((newPos >> (LOD+1)) - (oldPos >> (LOD+1)));
		LOD = min(LOD + up, 7);
		offset += (shadowVolume>>((LOD+down-1)*3))*(up-down);
		oldLOD = LOD;
		VMO.vCoord = VoxelToTextureSpace(ivPos, LOD, offset);
		// int miss = int(texture2D(shadowcolor0, (vec2(VMO.vCoord)+ 0.5)/shadowMapResolution, 0).x);
		int miss = int(texelFetch(shadowcolor0, VMO.vCoord, 0).x);
		down = 1-miss;
		LOD -= down;
		
		ivec3 a = ((ivPos >> LOD) + idirPositive) << LOD;
		ivec3 b = bound + istepDir * (miss << LOD);
		
		bound = (a & (~iplane)) | (b & iplane);
	}
	
	VMO.hit = LOD < 0;
	
	VMO.plane = vec3(-iplane) * sign(-wDir);
	
	if (!VMO.hit) {
		vec3 shadowVolume = vec2(shadowDiameter, 256).xyx * dirPositive;
		
		vec3 pllane = fMin((shadowVolume - P0)*tDelta);
		VMO.vPos = P0 + wDir * dot(tDelta, pllane) * dot(shadowVolume-P0, pllane);
		// VMO.plane = pllane * sign(-wDir);
	}
	
	return VMO;
}

struct SurfaceStruct {
	mat3 tbn;
	vec4 diffuse;
	
	vec3 normal;
	vec4 normals;
	float emissive;
	
	vec4 specular;
	float roughness;
	float F0;
	float metal;
	float porosity;
	float SSS;
	
	float isWater;
};

vec2 GetTexCoord(vec2 coord, float depth, vec2 spriteSize) {
	vec2 cornerTexCoord = unpackTexcoord(depth); // Coordinate of texture's starting corner in [0, 1] texture space
	vec2 coordInSprite = coord.xy * spriteSize / atlasSize; // Fragment's position within sprite space
	
	return cornerTexCoord + coordInSprite;
}

mat3 GenerateTBN(vec3 plane) {
	mat3 tbn;
	
	vec3 plane3 = abs(plane);
	
	tbn[0].z = -plane.x;
	tbn[0].y = 0.0;
	tbn[0].x = plane3.y + plane.z;
	
	tbn[1].x = 0.0;
	tbn[1].y = -plane3.x - plane3.z;
	tbn[1].z = plane3.y;
	
	tbn[2] = plane;
	
	return tbn;
}

#include "../TerrainParallax.fsh"

#include "../ComputeWaveNormals.fsh"

SurfaceStruct ReconstructSurface(RayQueueStruct curr, VoxelMarchOut VMO) {
	SurfaceStruct surface;
	surface.tbn = GenerateTBN(VMO.plane);
	
	vec2 spriteSize = exp2(round(texelFetch(shadowcolor0, VMO.vCoord, 0).xx * 255.0));
	
	vec2 coord = ((fract(VMO.vPos) * 2.0 ) * mat2x3(surface.tbn) - vec3(1)*mat2x3(surface.tbn)) * 0.5 + 0.5;
	float depth = texelFetch(shadowtex0, VMO.vCoord, 0).x;
	vec2 tCoord = GetTexCoord(coord.xy, depth, spriteSize);
	
	vec2 parCoord = ComputeParallaxCoordinate(tCoord, curr.rayDir, surface.tbn, spriteSize, NORMAL_SAMPLER);
	
	surface.diffuse  = texture2D(TEX_SAMPLER, parCoord, 0);
	surface.normals  = texture2D(NORMAL_SAMPLER, parCoord, 0);
	surface.specular = texture2D(SPECULAR_SAMPLER, parCoord, 0);
	
	surface.diffuse.rgb *= texelFetch(shadowcolor1, VMO.vCoord, 0).rgb;
	surface.diffuse.rgb = pow(surface.diffuse.rgb, vec3(2.2));
	
	surface.normal = surface.tbn * normalize(surface.normals.rgb * 2.0 - 1.0);
//	surface.normal = surface.tbn * vec3(surface.normals.xy, sqrt(max(1.0 - dot(surface.normals.xy, surface.normals.xy), 0.0)));
	surface.emissive = surface.specular.a * 255.0 / 254.0 * float(surface.specular.a < 254.0 / 255.0);
	
	if (texelFetch(shadowcolor0, VMO.vCoord, 0).g*255.0 > 0.5)
		surface.emissive = 1.0;
	
	// surface.roughness = 1 - surface.specular.r;
	// surface.F0 = surface.specular.g * surface.specular.g;
	// surface.metal = float(surface.specular.g > (229.0 / 255.0));
	// surface.porosity = surface.specular.b * 255.0 / 64.0 * float(surface.specular.b <= 64.0 / 255.0);
	// surface.SSS = (surface.specular.b - 64.0 / 255.0) * (255.0 / (255.0 - 64.0)) * float(64.0 / 255.0 < surface.specular.b);
	//
	if (int(texelFetch(shadowcolor1, VMO.vCoord, 0).a*255)==20) {
		surface.normal = surface.tbn * ComputeWaveNormals(VoxelToWorldSpace(VMO.vPos), curr.rayDir, surface.tbn[2]);
		surface.roughness = 0.01;
		surface.F0 = 0.01;
		surface.diffuse.rgb = vec3(0);
	}
	
	return surface;
}

#endif
