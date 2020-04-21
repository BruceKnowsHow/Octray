#if !defined VOXELMARCH_GLSL
#define VOXELMARCH_GLSL

#define VOXEL_INTERSECTION_TEX shadowtex0
#define VOXEL_ALBEDO_TEX depthtex1
#define VOXEL_NORMALS_TEX depthtex2
#define VOXEL_SPECULAR_TEX shadowtex1

#include "WorldToVoxelCoord.glsl"
#include "RT_TerrainParallax.fsh"
#include "RT_Encoding.glsl"

// Return structure for the VoxelMarch function
struct VoxelMarchOut {
	uint  hit  ;
	vec3  vPos ;
	vec3  plane;
	float data;
	ivec2 vCoord;
};

struct SurfaceStruct {
	mat3 tbn;
	
	float depth;
	vec4 voxelData;
	
	vec4 albedo;
	vec4 normals;
	vec4 specular;
	
	vec3 normal;
	
	int blockID;

	bool hasSpecularMap;
	
	float roughness;
	float reflectance;
	float emission;
	
	mat2x3 metalIOR;
};

struct RayStruct {
	vec3 vPos;
	vec3 wDir;
	vec3 absorb;
	uint info;
	float prevVolume;
	int accumIndex;
	
	#if defined RT_TERRAIN_PARALLAX
		bool insidePOM;
		vec3 tCoord;
		vec2 spriteSize;
		vec2 cornerTexCoord;
		vec3 plane;
	#endif
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

#define DIFFUSE_ACCUM_INDEX 0
#define SPECULAR_ACCUM_INDEX 1

const uint  PRIMARY_RAY_TYPE = (1 <<  8);
const uint SUNLIGHT_RAY_TYPE = (1 <<  9);
const uint  AMBIENT_RAY_TYPE = (1 << 10);
const uint SPECULAR_RAY_TYPE = (1 << 11);

const uint RAY_DEPTH_MASK = (1 << 8) - 1;
const uint RAY_TYPE_MASK  = ((1 << 16) - 1) & (~RAY_DEPTH_MASK);
const uint RAY_ATTR_MASK  = ((1 << 24) - 1) & (~RAY_DEPTH_MASK) & (~RAY_TYPE_MASK);

#define MAX_RAYS 64
#define RAYMARCH_QUEUE_BANDWIDTH (MAX_RAY_BOUNCES + 2)

RayQueueStruct voxelMarchQueue[RAYMARCH_QUEUE_BANDWIDTH];

int  rayQueueFront   = RAYMARCH_QUEUE_BANDWIDTH*256; // Index of the occupied front of the queue
int  rayQueueBack    = rayQueueFront; // Index of the unnoccupied back of the queue
int  rayQueueSize    = 0;
bool queueOutOfSpace = false;

bool IsQueueFull()  { return rayQueueSize == RAYMARCH_QUEUE_BANDWIDTH; }
bool IsQueueEmpty() { return rayQueueSize == 0; }

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
		vec2 col = RT_packColor(ray.absorb);
		ret.vPos.xyz = ray.vPos;
		ret.vPos.w = col.r;
		ret.wDir.xy = RT_EncodeNormalSnorm(ray.wDir);
		ret.wDir.z = uintBitsToFloat(ray.info);
		ret.wDir.w = col.g;
		ret.prevVolume = ray.prevVolume;
		return ret;
	}

	RayStruct UnpackRay(RayQueueStruct ray) {
		RayStruct ret;
		ret.vPos = ray.vPos.xyz;
		ret.wDir = RT_DecodeNormalSnorm(ray.wDir.xy);
		ret.info = floatBitsToUint(ray.wDir.z);
		ret.absorb = RT_unpackColor(vec2(ray.vPos.w, ray.wDir.w));
		ret.prevVolume = ray.prevVolume;
		return ret;
	}
#else
	#define   PackRay(elem) (elem)
	#define UnpackRay(elem) (elem)
#endif

#include "VisibilityThreshold.glsl"

void RayPushBack(RayStruct elem) {
	queueOutOfSpace = queueOutOfSpace || IsQueueFull();
	if (queueOutOfSpace) return;
	if (!PassesVisibilityThreshold(elem.absorb)) { return;}
	
	voxelMarchQueue[rayQueueBack % RAYMARCH_QUEUE_BANDWIDTH] = PackRay(elem);
	++rayQueueBack;
	++rayQueueSize;
	return;
}

void RayPushFront(RayStruct elem) {
	queueOutOfSpace = queueOutOfSpace || IsQueueFull();
	if (queueOutOfSpace) return;
	if (!PassesVisibilityThreshold(elem.absorb)) return;
	
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
	show(float(VM_steps) * 0.01);
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

vec2 MinCompMask(vec2 v) {
	return (v.x < v.y) ? vec2(1,0) : vec2(0,1);
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
	
	uvec3 vvPos = uvPos;
	vec3 fPos = fract(vPos);
	
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
		if ( LOD >= 8 || OutOfVoxelBounds(newPos.z, uplane) || ++VM_steps >= 512 ) { break; }
		
		float tLength = BinaryDotF(distToBoundary, uplane);
		newPos.xy = GetNonMinComps(ivec3(floor(fPos + wDir * tLength)) + vvPos, uplane);
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

#include "UnpackPBR.glsl"

void MapID(int ID, out int index, out int vertCount) {
	if (ID == 8) {
		index = 0;
		vertCount = 4;
	}
}

const vec3 VAO[4][2] = vec3[4][2](
	vec3[2](vec3((16-4)/16.0, 0.5, 0.5), vec3(1,0,0)),
	vec3[2](vec3((16-12)/16.0, 0.5, 0.5), vec3(1,0,0)),
	vec3[2](vec3(0.5, 0.5, (16-4)/16.0), vec3(0,0,1)),
	vec3[2](vec3(0.5, 0.5, (16-12)/16.0), vec3(0,0,1))
);

SurfaceStruct ReconstructSurface(inout RayStruct curr, VoxelMarchOut VMO, inout bool rt) {
	curr.vPos = VMO.vPos - VMO.plane * exp2(-12);
	
	SurfaceStruct surface;
	surface.voxelData = vec4(texelFetch(shadowcolor0, VMO.vCoord, 0));
	surface.blockID = int(surface.voxelData.g*255);
	
	vec2 spriteSize = exp2(round(surface.voxelData.xx * 255.0));
	vec2 spriteScale = spriteSize / atlasSize;
	vec2 cornerTexCoord = unpackTexcoord(VMO.data);
	
	/*
	if (surface.blockID == 8) {
		vec3 fr = fract(curr.vPos);
		vec3 n = vec3(0);
		float t = 1e35;
		
		int start, end;
		MapID(surface.blockID, start, end);
		end += start;
		
		for (int i = start; i < end; ++i) {
			vec3 p0 = VAO[i][0];
			vec3 ni = VAO[i][1];
			
			float t_ = dot(p0-fr, ni) / dot(curr.wDir,ni);
			
			vec3 hitpoint = fr+curr.wDir*t_;
			
			if (t_ > 0 && all(lessThan(abs(hitpoint-0.5), vec3(0.5))) && t_ < t) {
				mat3 tbn = GenerateTBN(ni);
				
				vec2 tCoord = ((hitpoint * 2.0 - 1.0) * mat2x3(tbn)) * 0.5 + 0.5;
				
				ivec2 iCoord = ivec2((tCoord * spriteScale + cornerTexCoord) * atlasSize);
				
				vec4 albedo = texelFetch(VOXEL_ALBEDO_TEX, iCoord, 0);
				
				if (albedo.a > 0.1) {
					show(albedo)
					t = t_;
					n = ni;
				}
			}
		}
		
		rt = t == 1e35;
	}
	*/
	
	surface.depth = VMO.data;
	
	surface.tbn = GenerateTBN(VMO.plane);
	
	vec2 tCoord = ((fract(curr.vPos) * 2.0 - 1.0) * mat2x3(surface.tbn)) * 0.5 + 0.5;
	
	tCoord = tCoord * spriteScale;
	
	#if defined RT_TERRAIN_PARALLAX
		vec3 tDir = curr.wDir * surface.tbn;
		curr.tCoord = ComputeParallaxCoordinate(vec3(tCoord, 1.0), cornerTexCoord, tDir, spriteScale, curr.insidePOM, VOXEL_NORMALS_TEX);
		curr.plane = VMO.plane;
		curr.spriteSize = spriteSize;
		curr.cornerTexCoord = cornerTexCoord;
		
		tCoord = curr.tCoord.xy;
	#endif
	
	ivec2 iCoord = ivec2((mod(tCoord, spriteScale) + cornerTexCoord) * atlasSize);
	surface.albedo = texelFetch(VOXEL_ALBEDO_TEX, iCoord, 0);
	surface.normals = GetNormals(iCoord);
	surface.specular = GetSpecular(iCoord);
	
	DEBUG_DIFFUSE_SHOW(surface.albedo.rgb);
	DEBUG_WPOS_SHOW(VoxelToWorldSpace(VMO.vPos));
	
	surface.albedo.rgb *= RT_rgb(vec3(surface.voxelData.ba, 1.0));
	surface.albedo.rgb  = pow(surface.albedo.rgb, vec3(2.2));
	
	surface.normal = surface.tbn * normalize(surface.normals.rgb * 2.0 - 1.0);
	
	UnpackSpecularData(surface);

	return surface;
}

#endif
