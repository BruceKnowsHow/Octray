#if !defined WORLDTOVOXELCOORD_GLSL
#define WORLDTOVOXELCOORD_GLSL


#include "/block.properties"

#define VOXELIZATION_DISTANCE 1 // [0 1 2]

#define MAX_RAY_BOUNCES 2 // [0 1 2 3 4 6 8 12 16 24 32 48 64]

#define SUNLIGHT_RAYS On // [On Off]
#define SPECULAR_RAYS Off // [On Off]
#define AMBIENT_RAYS On // [On Off]

#if (VOXELIZATION_DISTANCE == 0)
	const float shadowDistance           =  112;
	const int   shadowMapResolution      = 4096;
	const float shadowDistanceRenderMul  =    2.0;
#elif (VOXELIZATION_DISTANCE == 1)
	const float shadowDistance           =   232;
	const int   shadowMapResolution      = 8192;
	const float shadowDistanceRenderMul  =     2.0;
#elif (VOXELIZATION_DISTANCE == 2)
	const float shadowDistance           =   478;
	const int   shadowMapResolution      = 16384;
	const float shadowDistanceRenderMul  =     1.0;
#endif

const float shadowIntervalSize       =    0.000001;
const bool  shadowHardwareFiltering0 = false;

const int shadowRadius2   = int(min(shadowDistance, far));
const int shadowDiameter2 = 2 * shadowRadius2;
const ivec3 shadowDimensions2 = ivec3(shadowDiameter2, 256, shadowDiameter2);

bool OutOfVoxelBounds(vec3 point) {
	vec3 mid = shadowDimensions2 / 2.0;
	
	return any(greaterThanEqual(abs(point - mid), mid-vec3(0.001)));
}

bool OutOfVoxelBounds(uvec3 point) {
	return any(greaterThanEqual(point, uvec3(shadowDimensions2)));
}

bool OutOfVoxelBounds(uint point, uvec3 uplane) {
	uint comp = (uvec3(shadowDimensions2).x & uplane.x) | (uvec3(shadowDimensions2).y & uplane.y) | (uvec3(shadowDimensions2).z & uplane.z);
	return point >= comp;
}

// Voxel space is a simple translation of world space.
// The DDA marching function stays in voxel space inside its loop to avoid unnecessary transformations.
vec3 WorldToVoxelSpace(vec3 position) {
	vec3 WtoV = vec2(0.0, floor(cameraPosition.y)).xyx + vec2(0.0, shadowRadius2).yxy + gbufferModelViewInverse[3].xyz + fract(cameraPosition);
	return position + WtoV;
}

vec3 WorldToVoxelSpace_ShadowMap(vec3 position) {
	vec3 WtoV = vec2(0.0, floor(cameraPosition.y)).xyx + vec2(0.0, shadowRadius2).yxy;
	return position + WtoV;
}

// When the DDA marching function has finished, its position output can be translated back to regular world space using this function.
vec3 VoxelToWorldSpace(vec3 position) {
	vec3 WtoV = vec2(0.0, floor(cameraPosition.y)).xyx + vec2(0.0, shadowRadius2).yxy + gbufferModelViewInverse[3].xyz + fract(cameraPosition);
	return position - WtoV;
}

const int shadowArea2 = shadowDimensions2.x * shadowDimensions2.z;
const int shadowVolume2 = shadowDimensions2.y * shadowArea2;


ivec2 VoxelToTextureSpace2(uvec3 position, uint LOD) {
	const uint svv = (shadowVolume2*8)/7;
	const uint svvv = shadowVolume2*8;
	
	const uint L1 = uint(ceil((shadowDiameter2)));
	const uint L2 = uint(ceil((shadowArea2)));
	
	uvec3 b = uvec3(position) >> LOD;
	b.x = (b.x * L1) >> LOD;
	b.y = (b.y * L2) >> (LOD + LOD);
	
	uint linenum = uint(b.x + b.y + b.z) + (svv - (svvv >> int(LOD+LOD+LOD))/7);
	return ivec2(linenum % shadowMapResolution, linenum / shadowMapResolution);
}

uint GetVoxelID(uvec3 vPos, uint LOD, uint offset) {
	vPos = vPos >> LOD;
	vPos.x = vPos.x << (8 - LOD);
	vPos.z = vPos.z * uint(shadowDimensions2.x);
	vPos.z = vPos.z << 8;
	vPos.z = vPos.z >> (LOD + LOD);
	
	return vPos.x + vPos.y + vPos.z + offset;
}

uvec3 GetVoxelPosition(uint voxelID) {
	uvec3 uvPos;
	uvPos.y = voxelID % 256;
	uvPos.x = (voxelID / 256) % uint(shadowDimensions2.x);
	uvPos.z = (voxelID / 256) / uint(shadowDimensions2.x);
	
	return uvPos;
}

ivec2 VoxelToTextureSpace(uvec3 vPos, uint LOD, uint offset) {
	return VoxelToTextureSpace2(vPos, LOD);
	
	uint voxelID = GetVoxelID(vPos, LOD, offset);
	
	return ivec2(voxelID % shadowMapResolution, voxelID / shadowMapResolution);
}

ivec2 VoxelToTextureSpace(uvec3 vPos) {
	return VoxelToTextureSpace(vPos, 0, 0);
}


#endif
