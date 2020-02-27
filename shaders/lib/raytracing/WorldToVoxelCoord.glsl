#if !defined WORLDTOVOXELCOORD_GLSL
#define WORLDTOVOXELCOORD_GLSL

#include "../settings/shadows.glsl"

const int shadowRadius   = int(shadowDistance);
const int shadowDiameter = 2 * shadowRadius;
const ivec3 shadowDimensions = ivec3(shadowDiameter, 256, shadowDiameter);

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
	return point > comp;
}

#if (defined gbuffers_shadow)
vec3 WtoV = vec2(0.0, floor(cameraPosition.y)).xyx + vec2(0.0, shadowRadius2).yxy;
#endif

#if (!defined gbuffers_shadow)
vec3 WtoV = vec2(0.0, floor(cameraPosition.y)).xyx + vec2(0.0, shadowRadius2).yxy + gbufferModelViewInverse[3].xyz + fract(cameraPosition);
#endif

// Voxel space is a simple translation of world space.
// The DDA marching function stays in voxel space inside its loop to avoid unnecessary transformations.
vec3 WorldToVoxelSpace(vec3 position) {
	return position + WtoV;
}

// When the DDA marching function has finished, its position output can be translated back to regular world space using this function.
vec3 VoxelToWorldSpace(vec3 position) {
	return position - WtoV;
}

const int shadowArea = shadowDimensions.x * shadowDimensions.z;
const int shadowVolume = shadowDimensions.y * shadowArea;

const int shadowArea2 = shadowDimensions2.x * shadowDimensions2.z;
const int shadowVolume2 = shadowDimensions2.y * shadowArea2;

uint GetVoxelID(uvec3 vPos, uint LOD, uint offset) {
	vPos = vPos >> LOD;
	vPos.x = vPos.x << (8 - LOD);
	vPos.z = vPos.z << (8 + uint(log2(shadowDimensions.x)) - (LOD + LOD));
	
	return vPos.x + vPos.y + vPos.z + offset;
}

uint GetVoxelID1(uvec3 vPos, uint LOD, uint offset) {
	vPos = vPos & (-((1 << LOD)));
	vPos.x = vPos.x << (8 - LOD);
	vPos.z = vPos.z << (8 + uint(log2(shadowDimensions.x)) - (LOD + LOD));
	
	return ((vPos.x + vPos.y + vPos.z) >> LOD) + offset;
}

uint GetVoxelID2(uvec3 vPos, uint LOD, uint offset) {
	
	vPos = vPos & (-((1 << LOD)));
	vPos.z = vPos.z << (uint(log2(shadowDimensions.x)) - LOD);
	vPos.y = vPos.y << (uint(log2(shadowDimensions.x))*2 - LOD*2);
	
	return ((vPos.x + vPos.y + vPos.z) >> LOD) + offset;
}

ivec2 VoxelToTextureSpace(uvec3 vPos, uint LOD, uint offset) {
	uint voxelID = GetVoxelID(vPos, LOD, offset);
	
	return ivec2(voxelID % shadowMapResolution, voxelID / shadowMapResolution);
}

#endif
