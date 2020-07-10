#if !defined VOXELMARCH_GLSL
#define VOXELMARCH_GLSL

#define VOXEL_INTERSECTION_TEX shadowtex0
#define VOXEL_ALBEDO_TEX       depthtex1
#define VOXEL_NORMALS_TEX      depthtex2
#define VOXEL_SPECULAR_TEX     shadowtex1

vec2 atlasSize = textureSize(VOXEL_ALBEDO_TEX, 0).xy;

#include "Voxelization.glsl"
#include "RT_TerrainParallax.fsh"
#include "RT_Encoding.glsl"

//#define SUBVOXEL_RAYTRACING

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
	
	bool insidePOM;
	vec3 tCoord;
	vec2 spriteScale;
	vec3 plane;
	
	bool subvoxel_hit;
	int blockID;
	vec2 cornerTexCoord;
};

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
#define RAY_STACK_CAPACITY (MAX_RAY_BOUNCES + 2)

RayStruct voxelMarchQueue[RAY_STACK_CAPACITY];

int  rayStackTop     = 0;
bool stackOutOfSpace = false;

bool IsStackFull()  { return rayStackTop == RAY_STACK_CAPACITY; }
bool IsStackEmpty() { return rayStackTop == 0; }

uint PackRayInfo(uint rayDepth, const uint RAY_TYPE) {
	return rayDepth | RAY_TYPE;
}

uint PackRayInfo(uint rayDepth, const uint RAY_TYPE, uint RAY_ATTR) {
	return rayDepth | RAY_TYPE | RAY_ATTR;
}

uint GetRayType(uint info) {
	return info & RAY_TYPE_MASK;
}

bool IsAmbientRay (RayStruct ray) { return ((ray.info & AMBIENT_RAY_TYPE)  != 0); }
bool IsSunlightRay(RayStruct ray) { return ((ray.info & SUNLIGHT_RAY_TYPE) != 0); }
bool IsPrimaryRay (RayStruct ray) { return ((ray.info & PRIMARY_RAY_TYPE)  != 0); }
bool IsSpecularRay(RayStruct ray) { return ((ray.info & SPECULAR_RAY_TYPE) != 0); }

uint GetRayAttr(uint info) {
	return info & RAY_ATTR_MASK;
}

bool HasRayAttr(uint info, const uint RAY_ATTR) {
	return (info & RAY_ATTR) != 0;
}

uint GetRayDepth(uint info) {
	return info & RAY_DEPTH_MASK;
}

#include "/lib/Tonemap.glsl"

bool PassesVisibilityThreshold(vec3 absorb) {
	vec3 delC = Tonemap(absorb*brightestThing + totalColor) - Tonemap(totalColor);
	return any(greaterThan(delC, vec3(10.0 / 255.0)));
}

void RayPush(RayStruct elem) {
	stackOutOfSpace = stackOutOfSpace || IsStackFull();
	if (stackOutOfSpace) return;
	if (!PassesVisibilityThreshold(elem.absorb)) { return;}
	
	voxelMarchQueue[rayStackTop % RAY_STACK_CAPACITY] = elem;
	++rayStackTop;
	return;
}

RayStruct RayPop() {
	--rayStackTop;
	RayStruct res = voxelMarchQueue[rayStackTop % RAY_STACK_CAPACITY];
	return res;
}

uint VM_steps = 0;

#define NONE 0
#define VM_STEPS_BW 1
#define VM_STEPS_LOD 2
#define VM_DIFFUSE 3
#define VM_WPOS 4
#define STACK_FULL 5

#define DEBUG_PRESET NONE // [NONE VM_STEPS_BW VM_STEPS_LOD VM_DIFFUSE VM_WPOS STACK_FULL]

#if (DEBUG_PRESET == VM_STEPS_BW)
void DEBUG_VM_ACCUM() {
	float val = float(VM_steps);
	show(val / 100.0);
	showval(val);
}
#else
	#define DEBUG_VM_ACCUM()
#endif

#if (DEBUG_PRESET == VM_STEPS_LOD)
void DEBUG_VM_ACCUM_LOD(uint LOD) {
	vec3 val = rgb(vec3(float(LOD)/8.0, 1, 1));
	inc(val / 40.0);
	incval(val);
}
#else
	#define DEBUG_VM_ACCUM_LOD(x)
#endif

#if (DEBUG_PRESET == VM_DIFFUSE)
void DEBUG_DIFFUSE_SHOW(vec3 color) {
	show(color);
}
#else
	#define DEBUG_DIFFUSE_SHOW(x)
#endif

#if (DEBUG_PRESET == VM_WPOS)
void DEBUG_WPOS_SHOW(vec3 vPos) {
	show(vPos);
}
#else
	#define DEBUG_WPOS_SHOW(x)
#endif

#if (DEBUG_PRESET == STACK_FULL)
void DEBUG_STACK_FULL() {
	show(stackOutOfSpace);
}
#else
	#define DEBUG_STACK_FULL()
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

VoxelMarchOut VoxelMarch(vec3 vPos, vec3 wDir, float volume) {
	// http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.42.3443&rep=rep1&type=pdf
	
	uvec3 dirIsPositive = uvec3(max(sign(wDir), 0));
	uvec3 boundary = uvec3(vPos) + dirIsPositive;
	uvec3 uvPos = uvec3(vPos);
	
	uvec3 vvPos = uvPos;
	vec3 fPos = fract(vPos);
	
	uint LOD = 0;
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
		
		uint shouldStepUp = uint((newPos.z >> (LOD+1)) != (oldPos >> (LOD+1)));
		LOD = min(LOD + shouldStepUp, 7);
		vCoord = VoxelToTextureSpace(uvPos, LOD);
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

vec4 GetNormals(vec2 coord) {
	return textureLod(VOXEL_NORMALS_TEX, coord, 0);
}
#if (!defined MC_NORMAL_MAP)
	#define GetNormals(coord) vec4(0.5, 0.5, 1.0, 0.0)
#endif

vec4 GetSpecular(vec2 coord) {
	return textureLod(VOXEL_SPECULAR_TEX, coord, 0);
}
#if (!defined MC_SPECULAR_MAP)
	#define GetSpecular(coord) vec4(0.0, 0.0, 0.0, 0.0)
#endif

void MapID(int ID, out int index, out int vertCount) {
	if (ID == 8) index = 0, vertCount = 4;
	if (ID == 12) index = 4, vertCount = 1;
}

const vec3 VAO[10] = vec3[10](
	vec3((16-4)/16.0, 0.5, 0.5)    , vec3(1,0,0),
	vec3((16-12)/16.0, 0.5, 0.5)   , vec3(1,0,0),
	vec3(0.5, 0.5, (16-4)/16.0)    , vec3(0,0,1),
	vec3(0.5, 0.5, (16-12)/16.0)   , vec3(0,0,1),
	vec3(0.5, 15./16, (16-12)/16.0), vec3(0,1,0)
);

void SubVoxelTrace(int blockID, vec3 wDir, vec2 cornerTexCoord, vec2 spriteScale, inout vec3 vPos, inout mat3 TBN, inout vec2 tCoord, inout bool hit) {
	if (!isSubVoxel(blockID))
		return;
	
	vec3 fr = fract(vPos);
	vec3 n = vec3(0);
	float t = 1e35;
	
	vec3 vv = vPos;
	
	int start, end;
	MapID(blockID, start, end);
	end += start;
	
	for (int i = start; i < end; ++i) {
		vec3 p0 = VAO[i*2];
		vec3 ni = VAO[i*2+1] * sign(-wDir);
		
		float t_ = dot(p0-fr, ni) / dot(wDir,ni);
		
		vec3 hitpoint = fr+wDir*t_;
		// hitpoint.y += 1/16.;
		
		if (t_ > 0 && all(lessThan(abs(hitpoint-0.5), vec3(0.5))) && t_ < t) {
			mat3 tbn = GenerateTBN(ni);
			
			vec2 tempCoord = ((hitpoint * 2.0 - 1.0) * mat2x3(tbn)) * 0.5 + 0.5;
			
			vec2 coord = tempCoord * spriteScale + cornerTexCoord;
			
			vec4 albedo = textureLod(VOXEL_ALBEDO_TEX, coord, 0);
			
			if (albedo.a > 0.1) {
				t = t_;
				n = ni;
				
				vPos = vv + wDir*t_ + tbn[2] * exp2(-12);
				tCoord = tempCoord;
				TBN = tbn;
			}
		}
	}
	
	hit = t != 1e35;
}
#ifndef SUBVOXEL_RAYTRACING
	#define SubVoxelTrace(blockID, wDir, cornerTexCoord, spriteScale, vPos, TBN, tCoord, hit)
#endif

SurfaceStruct ReconstructSurface(inout RayStruct curr, VoxelMarchOut VMO) {
	curr.vPos = VMO.vPos - VMO.plane * exp2(-12);
	
	SurfaceStruct surface;
	surface.depth = VMO.data;
	surface.voxelData = vec4(texelFetch(shadowcolor0, VMO.vCoord, 0));
	surface.blockID = int(surface.voxelData.g*255);
	
	curr.spriteScale = exp2(round(surface.voxelData.xx * 255.0)) / atlasSize;
	curr.cornerTexCoord = unpackTexcoord(VMO.data);
	
	surface.tbn = GenerateTBN(VMO.plane);
	vec2 tCoord = ((fract(curr.vPos) * 2.0 - 1.0) * mat2x3(surface.tbn)) * 0.5 + 0.5;
	
	curr.subvoxel_hit = true;
	
	#ifdef SUBVOXEL_RAYTRACING
		curr.blockID = surface.blockID;
		SubVoxelTrace(curr.blockID, curr.wDir, curr.cornerTexCoord, curr.spriteScale, curr.vPos, surface.tbn, tCoord, curr.subvoxel_hit);
	#endif
	
	tCoord = tCoord * curr.spriteScale;
	
	#if defined RT_TERRAIN_PARALLAX
		vec3 tDir = curr.wDir * surface.tbn;
		curr.tCoord = ComputeParallaxCoordinate(vec3(tCoord, 1.0), curr.cornerTexCoord, tDir, curr.spriteScale, curr.insidePOM, VOXEL_NORMALS_TEX);
		curr.plane = VMO.plane;
		
		tCoord = curr.tCoord.xy;
	#endif
	
	curr.cornerTexCoord = ceil(curr.cornerTexCoord * atlasSize) / atlasSize; // cornerTexCoord encoding needs to be redone.
	
	tCoord = tCoord + curr.cornerTexCoord;
	surface.albedo = textureLod(VOXEL_ALBEDO_TEX, tCoord, 0);
	surface.normals = GetNormals(tCoord);
	surface.specular = GetSpecular(tCoord);
	
	DEBUG_DIFFUSE_SHOW(surface.albedo.rgb);
	DEBUG_WPOS_SHOW(VoxelToWorldSpace(VMO.vPos));
	
	surface.albedo.rgb *= RT_rgb(vec3(surface.voxelData.ba, 1.0));
	surface.albedo.rgb  = pow(surface.albedo.rgb, vec3(2.2));
	
	surface.normal = surface.tbn * normalize(surface.normals.rgb * 2.0 - 1.0);
	
	return surface;
}

#endif
