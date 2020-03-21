#if !defined VOXELMARCH_GLSL
#define VOXELMARCH_GLSL

#define VOXEL_INTERSECTION_TEX shadowtex0
#define VOXEL_ALBEDO_TEX depthtex1
#define VOXEL_NORMALS_TEX depthtex2
#define VOXEL_SPECULAR_TEX shadowtex1

#include "../settings/shadows.glsl"
#include "WorldToVoxelCoord.glsl"

// Return structure for the VoxelMarch function
struct VoxelMarchOut {
	uint  hit  ;
	vec3  vPos ;
	vec3  plane;
	float data;
	ivec2 vCoord;
};

struct RayStruct {
	vec3 vPos;
	vec3 wDir;
	vec3 absorb;
	uint info;
	float prevVolume;
};

//#define COMPRESS_RAY_QUEUE

#ifdef COMPRESS_RAY_QUEUE
	struct RayQueueStruct {
		vec4 vPos;
		vec4 wDir;
		float prevVolume;
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

uint GetRayType(uint info) {
	return info & RAY_TYPE_MASK;
}

#define IsAmbientRay(ray) ((ray.info & AMBIENT_RAY_TYPE) != 0)
#define IsSunlightRay(ray) ((ray.info & SUNLIGHT_RAY_TYPE) != 0)
#define IsPrimaryRay(ray) ((ray.info & PRIMARY_RAY_TYPE) != 0)
#define IsSpecularRay(ray) ((ray.info & SPECULAR_RAY_TYPE) != 0)

uint GetRayAttr(uint info) {
	return info & RAY_ATTR_MASK;
}

bool HasRayAttr(uint info, const uint RAY_ATTR) {
	return (info & RAY_ATTR) != 0;
}

uint GetRayDepth(uint info) {
	return info & RAY_DEPTH_MASK;
}

#if defined COMPRESS_RAY_QUEUE
	RayQueueStruct PackRay(RayStruct ray) {
		RayQueueStruct ret;
		vec2 col = packColor(ray.absorb);
		ret.vPos.xyz = ray.vPos;
		ret.vPos.w = col.r;
		ret.wDir.xy = EncodeNormalSnorm(ray.wDir);
		ret.wDir.z = uintBitsToFloat(ray.info);
		ret.wDir.w = col.g;
		ret.prevVolume = ray.prevVolume;
		return ret;
	}

	RayStruct UnpackRay(RayQueueStruct ray) {
		RayStruct ret;
		ret.vPos = ray.vPos.xyz;
		ret.wDir = DecodeNormalSnorm(ray.wDir.xy);
		ret.info = floatBitsToUint(ray.wDir.z);
		ret.absorb = unpackColor(vec2(ray.vPos.w, ray.wDir.w));
		ret.prevVolume = ray.prevVolume;
		return ret;
	}
#else
	#define   PackRay(elem) (elem)
	#define UnpackRay(elem) (elem)
#endif

bool EnoughLightToBePerceptable(vec3 possibleAdditionalColor, vec3 currentColor) {
	vec3 delC = Tonemap(possibleAdditionalColor + currentColor) - Tonemap(currentColor);
	return any(greaterThan(delC, vec3(10.0 / 255.0)));
}

void RayPushBack(RayStruct elem, vec3 totalColor) {
	if (GetRayDepth(elem.info) > MAX_RAY_BOUNCES) return;
	queueOutOfSpace = queueOutOfSpace || IsQueueFull();
	if (queueOutOfSpace) return;
	if (!EnoughLightToBePerceptable(elem.absorb*brightestThing, totalColor)) { return;}
	
	voxelMarchQueue[rayQueueBack % RAYMARCH_QUEUE_BANDWIDTH] = PackRay(elem);
	++rayQueueBack;
	++rayQueueSize;
	return;
}

void RayPushFront(RayStruct elem, vec3 totalColor) {
	if (GetRayDepth(elem.info) > MAX_RAY_BOUNCES) return;
	queueOutOfSpace = queueOutOfSpace || IsQueueFull();
	if (queueOutOfSpace) return;
	if (!EnoughLightToBePerceptable(elem.absorb*brightestThing, totalColor)) return;
	
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

uint VM_steps = 0;

#define NONE 0
#define VM_STEPS_BW 1
#define VM_STEPS_LOD 2
#define VM_DIFFUSE 3
#define VM_WPOS 4
#define QUEUE_FULL 5

#define DEBUG_PRESET NONE // [NONE VM_STEPS_BW VM_STEPS_LOD VM_DIFFUSE VM_WPOS QUEUE_FULL]

void DEBUG_VM_ACCUM() {
	show(float(VM_steps) * 0.01)
}
#if !(DEBUG_PRESET == VM_STEPS_BW)
	#define DEBUG_VM_ACCUM()
#endif

void DEBUG_VM_ACCUM_LOD(uint LOD) {
	inc(rgb(vec3(float(LOD)/8.0, 1, 1)) / 40.0);
}
#if !(DEBUG_PRESET == VM_STEPS_LOD)
	#define DEBUG_VM_ACCUM_LOD(x)
#endif

void DEBUG_DIFFUSE_SHOW(vec3 color) {
	show(color);
}
#if !(DEBUG_PRESET == VM_DIFFUSE)
	#define DEBUG_DIFFUSE_SHOW(x)
#endif

void DEBUG_WPOS_SHOW(vec3 vPos) {
	show(vPos);
}
#if !(DEBUG_PRESET == VM_WPOS)
	#define DEBUG_WPOS_SHOW(x)
#endif

void DEBUG_QUEUE_FULL() {
	show(queueOutOfSpace);
}
#if !(DEBUG_PRESET == QUEUE_FULL)
	#define DEBUG_QUEUE_FULL()
#endif


#define BinaryDot(a, b) ((a.x & b.x) | (a.y & b.y) | (a.z & b.z))
#define BinaryMix(a, b, c) ((a & (~c)) | (b & c))

float BinaryDotF(vec3 v, uvec3 uplane) {
	uvec3 u = floatBitsToUint(v);
	return uintBitsToFloat(BinaryDot(u, uplane));
}

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

uvec3 GetMinCompMask(vec3 v) {
	ivec3 ia = floatBitsToInt(v);
	ivec3 iCompMask;
	iCompMask.xy = ((ia.xy - ia.yx) & (ia.xy - ia.zz)) >> 31;
	iCompMask.z = (-1) ^ iCompMask.x ^ iCompMask.y;
	
	return uvec3(iCompMask);
}

vec3 MinCompMask(vec3 v) {
	vec3 minCompMask;
	MinComp(v, minCompMask);
	return minCompMask;
}

vec3 StepThroughVoxel(vec3 vPos, vec3 wDir, out vec3 plane) {
	vec3 dirPositive = (sign(wDir) * 0.5 + 0.5); // +1.0 when going in a positive direction, 0.0 otherwise.

	vec3 tMax = (floor(vPos) - vPos + dirPositive) / wDir;
	float L = MinComp(tMax, plane);
	
	return vPos + wDir * L;
}

uvec2 GetNonMinComps(uvec3 xyz, uvec3 uplane) {
	return BinaryMix(xyz.xz, xyz.yy, uplane.xz);
}

vec2 GetNonMinComps(vec3 xyz, vec3 plane) {
	return mix(xyz.xz, xyz.yy, plane.xz);
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

VoxelMarchOut VoxelMarch(vec3 vPos, vec3 wDir, float volume) {
	// http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.42.3443&rep=rep1&type=pdf
	
	uvec3 dirIsPositive = uvec3(max(sign(wDir), 0));
	uvec3 boundary = uvec3(vPos) + dirIsPositive;
	uvec3 uvPos = uvec3(vPos);
	
	uint LOD = 0;
	uint lodOffset = 0;
	uint hit = 0;
	float data;
	ivec2 vCoord;
	
	while (true) {
		vec3 distToBoundary = (boundary - vPos) / wDir;
		uvec3 uplane = GetMinCompMask(distToBoundary);
		vec3 plane = vec3(-uplane);
		
		uvec3 isPos = SortMinComp(dirIsPositive, uplane);
		
		uint nearBound = GetMinComp(boundary, uplane);
		
		uvec3 newPos;
		newPos.z = nearBound + isPos.z - 1;
		if ( LOD >= 8 || OutOfVoxelBounds(newPos.z, uplane) || ++VM_steps >= 1024 ) { break; }
		
		float tLength = BinaryDotF(distToBoundary, uplane);
		newPos.xy = GetNonMinComps(uvec3(floor(fract(vPos) + wDir * tLength) + floor(vPos)), uplane);
		uint oldPos = GetMinComp(uvPos, uplane);
		uvPos = UnsortMinComp(newPos, uplane);
		
		DEBUG_VM_ACCUM();
		DEBUG_VM_ACCUM_LOD(LOD);
		
		uint shouldStepUp = uint((newPos.z >> (LOD+1)) != (oldPos >> (LOD+1))) * uint(LOD <= 6);
		LOD = (LOD + shouldStepUp) & 7;
		lodOffset += (shadowVolume2 >> ((LOD + (hit-1)) * 3)) * (shouldStepUp-hit);
		vCoord = VoxelToTextureSpace(uvPos, LOD, lodOffset);
		data = texelFetch(VOXEL_INTERSECTION_TEX, vCoord, 0).x;
		hit = uint(data != volume);
		uint miss = 1-hit;
		LOD -= hit;
		
		boundary.xy  = ((newPos.xy >> LOD) + isPos.xy) << LOD;
		boundary.z   = nearBound + miss * ((isPos.z * 2 - 1) << LOD);
		boundary     = UnsortMinComp(boundary, uplane);
	}
	
	VoxelMarchOut VMO;
	VMO.vCoord = vCoord;
	VMO.hit = hit;
	VMO.data = data;
	VMO.vPos = vPos + wDir * MinComp((boundary - vPos) / wDir, VMO.plane);
	VMO.plane *= sign(-wDir);
	
	return VMO;
}

struct SurfaceStruct {
	mat3 tbn;
	
	float depth;
	vec4 voxelData;
	
	vec4 albedo;
	vec4 normals;
	vec4 specular;
	
	vec3 normal;
	
	float emissive;
	
	int blockID;
	vec2 spriteSize;
	vec2 cornerTexCoord;
};

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

vec4 GetNormals(ivec2 coord) {
	return texelFetch(VOXEL_NORMALS_TEX, coord, 0);
}
#if (!defined MC_NORMAL_MAP)
	#define GetNormals(coord) vec4(0.5, 0.5, 1.0, 0.0)
#endif

vec4 GetSpecular(ivec2 coord) {
	return texelFetch(VOXEL_SPECULAR_TEX, coord, 0);
}
#if (!defined MC_SPECULAR_MAP)
	#define GetSpecular(coord) vec4(0.0, 0.0, 0.0, 0.0)
#endif

SurfaceStruct ReconstructSurface(RayStruct curr, VoxelMarchOut VMO) {
	SurfaceStruct surface;
	surface.voxelData = vec4(texelFetch(shadowcolor0, VMO.vCoord, 0));
	surface.blockID = int(surface.voxelData.g*255);
	
	surface.tbn = GenerateTBN(VMO.plane);
	
	surface.spriteSize = exp2(round(surface.voxelData.xx * 255.0));
	
	vec2 coord = ((fract(VMO.vPos) * 2.0 - 1.0) * mat2x3(surface.tbn)) * 0.5 + 0.5;
	surface.depth = VMO.data;
	surface.cornerTexCoord = unpackTexcoord(VMO.data);
	vec2 tCoord = surface.cornerTexCoord + coord.xy * surface.spriteSize / atlasSize;
	
	tCoord = ComputeParallaxCoordinate(tCoord, curr.wDir, surface.tbn, surface.spriteSize, VOXEL_NORMALS_TEX);
	
	ivec2 iCoord = ivec2(tCoord * atlasSize);
	
	surface.albedo   = texelFetch(VOXEL_ALBEDO_TEX, iCoord, 0);
	surface.normals  = GetNormals(iCoord);
	surface.specular = GetSpecular(iCoord);
	
	DEBUG_DIFFUSE_SHOW(surface.albedo.rgb);
	DEBUG_WPOS_SHOW(VoxelToWorldSpace(VMO.vPos));
	
	surface.albedo.rgb *= rgb(vec3(surface.voxelData.ba, 1.0));
	// surface.albedo.rgb *= surface.voxelData[1].rgb;
	surface.albedo.rgb  = pow(surface.albedo.rgb, vec3(2.2));
	
	surface.normal = surface.tbn * normalize(surface.normals.rgb * 2.0 - 1.0);
	surface.emissive = surface.specular.a * 255.0 / 254.0 * float(surface.specular.a < 254.0 / 255.0);
	
	if (isEmissive(surface.blockID))
		surface.emissive = 1.0;
	
	if (isWater(surface.blockID)) {
		surface.normal = surface.tbn * ComputeWaveNormals(VoxelToWorldSpace(VMO.vPos), curr.wDir, surface.tbn[2]);
	}
	
	return surface;
}

#endif
