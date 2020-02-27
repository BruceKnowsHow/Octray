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

struct RayStruct {
	vec3 vPos;
	vec3 rayDir;
	vec3 priorTransmission;
	uint rayInfo;
	float prevVolume;
	vec3 transmission;
};

//#define COMPRESS_RAY_QUEUE

#ifdef COMPRESS_RAY_QUEUE
	struct RayQueueStruct {
		vec4 vPos;
		vec4 rayDir;
		float prevVolume;
		vec3 transmission;
	};
#else
	#define RayQueueStruct RayStruct
#endif

uint f32tof16(float val) {
	uint f32 = floatBitsToUint(val);
	int exponent = clamp(int((f32 >> 23u) & 0xFFu) - 127 + 31, 0, 63);

	return uint(exponent << 10u) | ((f32 & 0x007FFFFFu) >> 13u);
}

float f16tof32(uint val) {
	int exponent = int((val & 0xFC00u) >> 10) - 31;
	
	float scale = float(1 << abs(exponent));
	      scale = (exponent < 0) ? 1.0 / scale : scale;

	float decimal = 1.0 + float(val & 0x03FFu) / float(1 << 10);

	return scale * decimal;
}

float pack2x1(vec2 v) {
	const uint mask0 = (1 << 16) - 1;
	const uint mask1 = ~mask0;
	
	uint ret = f32tof16(v.x) | (f32tof16(v.y) << 16);
	
	return uintBitsToFloat(ret);
}

vec2 unpack2x1(float v) {
	const uint mask0 = (1 << 16) - 1;
	const uint mask1 = ~mask0;
	
	uint t = floatBitsToUint(v);
	
	return vec2(f16tof32(t & mask0), f16tof32(t >> 16));
}

vec2 packColor(vec3 col) {
	return vec2(col.r, pack2x1(col.gb));
}

vec3 unpackColor(vec2 col) {
	return vec3(col.r, unpack2x1(col.g));
}

vec2 EncodeNormalSnorm(vec3 normal) {
	normal = normalize(normal);
	normal.y = uintBitsToFloat((floatBitsToUint(normal.y) & (~1)) | (floatBitsToUint(normal.z) >> 31));
	return normal.xy;
}

vec3 DecodeNormalSnorm(vec2 norm) {
	float z = 1.0 - 2.0*float(floatBitsToInt(norm.y) & (1));
	norm.y = uintBitsToFloat((floatBitsToUint(norm.y)) & (~1));
	z *= sqrt(1.0- dot(norm, norm));
	
	return vec3(norm, z+1e-35);
}

const uint  PRIMARY_RAY_TYPE = (1 <<  8);
const uint SUNLIGHT_RAY_TYPE = (1 <<  9);
const uint  AMBIENT_RAY_TYPE = (1 << 10);
const uint SPECULAR_RAY_TYPE = (1 << 11);

const uint INTERIOR_RAY_ATTR = (1 << 16);

const uint RAY_DEPTH_MASK = (1 << 8) - 1;
const uint RAY_TYPE_MASK  = ((1 << 16) - 1) & (~RAY_DEPTH_MASK);
const uint RAY_ATTR_MASK  = ((1 << 24) - 1) & (~RAY_DEPTH_MASK) & (~RAY_TYPE_MASK);

#define MAX_RAYS 64
#define MAX_RAY_BOUNCES 2 // [0 1 2 3 4 6 8 12 16 24 32 48 64]
#define RAYMARCH_QUEUE_BANDWIDTH (MAX_RAY_BOUNCES + 2)

RayQueueStruct voxelMarchQueue[RAYMARCH_QUEUE_BANDWIDTH];


int  rayQueueFront   = RAYMARCH_QUEUE_BANDWIDTH*256; // Index of the occupied front of the queue
int  rayQueueBack    = rayQueueFront; // Index of the unnoccupied back of the queue
int  rayQueueSize    = 0;
bool queueOutOfSpace = false;

bool IsQueueFull()  { return rayQueueSize == RAYMARCH_QUEUE_BANDWIDTH; }
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

#if defined COMPRESS_RAY_QUEUE
	RayQueueStruct PackRay(RayStruct ray) {
		RayQueueStruct ret;
		vec2 col = packColor(ray.priorTransmission);
		ret.vPos.xyz = ray.vPos;
		ret.vPos.w = col.r;
		ret.rayDir.xy = EncodeNormalSnorm(ray.rayDir);
		ret.rayDir.z = uintBitsToFloat(ray.rayInfo);
		ret.rayDir.w = col.g;
		ret.prevVolume = ray.prevVolume;
		ret.transmission = ray.transmission;
		return ret;
	}

	RayStruct UnpackRay(RayQueueStruct ray) {
		RayStruct ret;
		ret.vPos = ray.vPos.xyz;
		ret.rayDir = DecodeNormalSnorm(ray.rayDir.xy);
		ret.rayInfo = floatBitsToUint(ray.rayDir.z);
		ret.priorTransmission = unpackColor(vec2(ray.vPos.w, ray.rayDir.w));
		ret.prevVolume = ray.prevVolume;
		ret.transmission = ray.transmission;
		return ret;
	}
#else
	#define   PackRay(elem) (elem)
	#define UnpackRay(elem) (elem)
#endif

void RayPushBack(RayStruct elem, vec3 totalColor) {
	if (GetRayDepth(elem.rayInfo) > MAX_RAY_BOUNCES) return;
	queueOutOfSpace = queueOutOfSpace || IsQueueFull();
	if (queueOutOfSpace) return;
	if (!EnoughLightToBePerceptable(elem.priorTransmission*brightestThing, totalColor)) return;
	
	voxelMarchQueue[rayQueueBack % RAYMARCH_QUEUE_BANDWIDTH] = PackRay(elem);
	++rayQueueBack;
	++rayQueueSize;
	return;
}

void RayPushFront(RayStruct elem, vec3 totalColor) {
	if (GetRayDepth(elem.rayInfo) > MAX_RAY_BOUNCES) return;
	queueOutOfSpace = queueOutOfSpace || IsQueueFull();
	if (queueOutOfSpace) return;
	if (!EnoughLightToBePerceptable(elem.priorTransmission*brightestThing, totalColor)) return;
	
	--rayQueueFront;
	voxelMarchQueue[rayQueueFront % RAYMARCH_QUEUE_BANDWIDTH] = PackRay(elem);
	++rayQueueSize;
	return;
}

RayStruct RayPopFront() {
	RayStruct res = UnpackRay(voxelMarchQueue[rayQueueFront % RAYMARCH_QUEUE_BANDWIDTH]);
	++rayQueueFront;
	--rayQueueSize;
	return res;
}

RayStruct RayPopBack() {
	--rayQueueBack;
	RayStruct res = UnpackRay(voxelMarchQueue[rayQueueBack % RAYMARCH_QUEUE_BANDWIDTH]);
	--rayQueueSize;
	return res;
}


#define BinaryDot(a, b) ((a.x & b.x) | (a.y & b.y) | (a.z & b.z))
#define BinaryMix(a, b, c) ((a & (~c)) | (b & c))

float MinComp(vec3 v, out vec3 minCompMask) {
	float minComp = min(v.x, min(v.y, v.z));
	minCompMask.xy = 1.0 - clamp((v.xy - minComp) * 1e35, 0.0, 1.0);
	minCompMask.z = 1.0 - minCompMask.x - minCompMask.y;
	return minComp;
}

float MinComp(vec3 v, out uvec3 minCompMask) {
	ivec3 ia = floatBitsToInt(v);
	ivec3 iCompMask;
	iCompMask.xy = ((ia.xy - ia.yx) & (ia.xy - ia.zz)) >> 31;
	iCompMask.z = (-1) ^ iCompMask.x ^ iCompMask.y;
	
	minCompMask = uvec3(iCompMask);
	
	return intBitsToFloat(BinaryDot(ia, iCompMask));
}

vec3 MinCompMask(vec3 v) {
	vec3 minCompMask;
	MinComp(v, minCompMask);
	return minCompMask;
}

vec3 StepThroughVoxel(vec3 vPos, vec3 rayDir, out vec3 plane) {
	vec3 dirPositive = (sign(rayDir) * 0.5 + 0.5); // +1.0 when going in a positive direction, 0.0 otherwise.
	vec3 tDelta  = 1.0 / rayDir;
	tDelta = clamp(tDelta, -10000.0, 10000.0);

	vec3 tMax = (floor(vPos) - vPos + dirPositive)*tDelta;
	float L = MinComp(tMax, plane);
	
	return vPos + rayDir * L;
}

#define NONE 0
#define VM_STEPS_BW 1
#define VM_STEPS_LOD 2
#define VM_DIFFUSE 3
#define VM_WPOS 4

#define DEBUG_PRESET NONE // [NONE VM_STEPS_BW VM_STEPS_LOD VM_DIFFUSE VM_WPOS]

#define DEBUG_VM_ACCUM
#define DEBUG_DIFFUSE_SHOW
#define DEBUG_WPOS_SHOW

#if (DEBUG_PRESET == VM_STEPS_BW)
	#undef DEBUG_VM_ACCUM
	#define DEBUG_VM_ACCUM Debug += 1.0 / 64.0;
#elif (DEBUG_PRESET == VM_STEPS_LOD)
	#undef DEBUG_VM_ACCUM
	#define DEBUG_VM_ACCUM Debug += rgb(vec3(float(LOD)/8.0, 1, 1)) / 64.0;
#endif

#if (DEBUG_PRESET == VM_DIFFUSE)
	#undef DEBUG_DIFFUSE_SHOW
	#define DEBUG_DIFFUSE_SHOW show(surface.diffuse.rgb);
#endif

#if (DEBUG_PRESET == VM_WPOS)
	#undef DEBUG_WPOS_SHOW
	#define DEBUG_WPOS_SHOW show(VoxelToWorldSpace(VMO.vPos))
#endif

int VM_steps = 0;

uvec2 GetNonMinComps(uvec3 xyz, uvec3 uplane) {
	return BinaryMix(xyz.xz, xyz.yy, uplane.xz);
}

uint GetMinComp(uvec3 xyz, uvec3 uplane) {
	return BinaryDot(xyz, uplane);
}

uvec3 SortMinComp(uvec3 xyz, uvec3 uplane) {
	uvec3 ret;
	ret.xy = GetNonMinComps(xyz, uplane);
	ret.z  = xyz.x ^ xyz.y ^ xyz.z ^ ret.x ^ ret.y;
	return ret;
}

uvec3 UnsortMinComp(uvec3 uvw, uvec3 uplane) {
	uvec3 ret;
	ret.xz = BinaryMix(uvw.xy, uvw.zz, uplane.xz);
	ret.y = uvw.x ^ uvw.y ^ uvw.z ^ ret.x ^ ret.z;
	return ret;
}

VoxelMarchOut VoxelMarch(vec3 vPos, vec3 wDir, float prevVolume) {
	VoxelMarchOut VMO;
	
	uvec3 dirIsPositive = uvec3(max(sign(wDir), 0));
	uvec3 boundary = uvec3(vPos) + dirIsPositive;
	uvec3 uvPos = uvec3(vPos);
	
	uint LOD = 0;
	uint lodOffset = 0;
	uint prevLOD = 0;
	uint hit = 0;
	
	// Based on: http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.42.3443&rep=rep1&type=pdf
	while (true) {
		vec3 distToBoundary = (boundary - vPos) / wDir;
		uvec3 uplane;
		float L = MinComp(distToBoundary, uplane);
		
		uvec3 isPos = SortMinComp(dirIsPositive, uplane);
		uvec3 isNeg = isPos - 1;
		
		uint B = GetMinComp(boundary, uplane);
		
		uvec3 newPos;
		newPos.z = B + isNeg.z;
		if ( LOD >= 8 || newPos.z > GetMinComp(uvec3(shadowDimensions2), uplane) - 1 || ++VM_steps >= 256 ) { break; }
		newPos.xy = uvec2(uintBitsToFloat(GetNonMinComps(floatBitsToUint(vPos + wDir * L), uplane) + isNeg.xy));
		uint oldPos = GetMinComp(uvPos, uplane);
		uvPos = UnsortMinComp(newPos, uplane);
		
		DEBUG_VM_ACCUM;
		
		uint shouldStepUp = uint((newPos.z >> (LOD+1)) != (oldPos >> (LOD+1)));
		LOD = (LOD + shouldStepUp) & 7;
		lodOffset += (shadowVolume >> ((LOD + (hit-1)) * 3)) * (shouldStepUp-hit);
		prevLOD = LOD;
		VMO.vCoord = VoxelToTextureSpace(uvPos, LOD, lodOffset);
		float lookup = texelFetch(shadowtex0, VMO.vCoord, 0).x;
		hit = uint(lookup != prevVolume);
		uint miss = 1-hit;
		LOD -= hit;
		
		boundary.xy  = ((newPos.xy >> LOD) + isPos.xy) << LOD;
		boundary.z   = B + miss * (((isPos.z << 1) - 1) << LOD);
		boundary     = UnsortMinComp(boundary, uplane);
	}
	
	uvec3 uplane;
	VMO.vPos = vPos + wDir * MinComp((boundary - vPos) / wDir, uplane);
	VMO.hit = LOD > 8;
	VMO.plane = vec3(-uplane) * sign(-wDir);
	
	return VMO;
}

struct SurfaceStruct {
	mat3 tbn;
	vec4 diffuse;
	
	vec3 normal;
	vec4 normals;
	float emissive;
	
	vec4 specular;
	
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

vec4 GetNormals(vec2 coord) {
	return textureLod(NORMAL_SAMPLER, coord, 0);
}
#if (!defined MC_NORMAL_MAP)
	#define GetNormals(coord) vec4(0.5, 0.5, 1.0, 0.0)
#endif

vec4 GetSpecular(vec2 coord) {
	return textureLod(SPECULAR_SAMPLER, coord, 0);
}
#if (!defined MC_SPECULAR_MAP)
	#define GetSpecular(coord) vec4(0.0, 0.0, 0.0, 0.0)
#endif

SurfaceStruct ReconstructSurface(RayStruct curr, VoxelMarchOut VMO, int blockID) {
	SurfaceStruct surface;
	surface.tbn = GenerateTBN(VMO.plane);
	
	vec2 spriteSize = exp2(round(texelFetch(shadowcolor0, VMO.vCoord, 0).xx * 255.0));
	
	vec2 coord = ((fract(VMO.vPos) * 2.0 ) * mat2x3(surface.tbn) - vec3(1)*mat2x3(surface.tbn)) * 0.5 + 0.5;
	float depth = texelFetch(shadowtex0, VMO.vCoord, 0).x;
	vec2 tCoord = GetTexCoord(coord.xy, depth, spriteSize);
	
	vec2 parCoord = ComputeParallaxCoordinate(tCoord, curr.rayDir, surface.tbn, spriteSize, NORMAL_SAMPLER);
	
	surface.diffuse  = textureLod(TEX_SAMPLER, parCoord, 0);
	surface.normals  = GetNormals(parCoord);
	surface.specular = GetSpecular(parCoord);
	
	DEBUG_DIFFUSE_SHOW;
	DEBUG_WPOS_SHOW;
	
	surface.diffuse.rgb *= texelFetch(shadowcolor1, VMO.vCoord, 0).rgb;
	surface.diffuse.rgb = pow(surface.diffuse.rgb, vec3(2.2));
	
	surface.normal = surface.tbn * normalize(surface.normals.rgb * 2.0 - 1.0);
	surface.emissive = surface.specular.a * 255.0 / 254.0 * float(surface.specular.a < 254.0 / 255.0);
	
	if (isEmissive(blockID))
		surface.emissive = 1.0;
	
	if (isWater(blockID)) {
		surface.normal = surface.tbn * ComputeWaveNormals(VoxelToWorldSpace(VMO.vPos), curr.rayDir, surface.tbn[2]);
	}
	
	return surface;
}

#endif
