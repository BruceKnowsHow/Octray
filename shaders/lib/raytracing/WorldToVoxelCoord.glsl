#if !defined WORLDTOVOXELCOORD_GLSL
#define WORLDTOVOXELCOORD_GLSL

#include "../settings/shadows.glsl"

bool OutOfVoxelBounds(vec3 point) {
	vec3 mid = shadowDimensions / 2.0;
	
	return any(greaterThanEqual(abs(point - mid), mid-vec3(0.001)));
}

#if (defined gbuffers_shadow)
vec3 WtoV = vec2(0.0, floor(cameraPosition.y)).xyx + vec2(0.0, shadowRadius).yxy;
#else
vec3 WtoV = vec2(0.0, floor(cameraPosition.y)).xyx + vec2(0.0, shadowRadius).yxy + gbufferModelViewInverse[3].xyz + fract(cameraPosition);
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

ivec2 VoxelToTextureSpace(ivec3 position, int LOD) {
	const int svv = (shadowVolume*8)/7;
	const int svvv = shadowVolume*8;
	
	const int width = shadowMapResolution;
	const int widthl2 = int(log2(width));
	
	const int L1 = int(ceil(log2(shadowDiameter)));
	const int L2 = int(ceil(log2(shadowArea)));
	
	ivec3 b = ivec3(position) >> LOD;
	b.x = (b.x << L1) >> LOD;
	b.y = (b.y << L2) >> (LOD + LOD);
	
	int linenum = b.x + b.y + b.z + (svv - (svvv >> (LOD+LOD+LOD))/7);
	return ivec2(linenum % width, linenum >> widthl2);
}

ivec2 VoxelToTextureSpace(ivec3 position, int LOD, int offset) {
	const int width = shadowMapResolution;
	const int widthl2 = int(log2(width));
	
	const int L1 = int(ceil(log2(shadowDiameter)));
	const int L2 = int(ceil(log2(shadowArea)));
	
	ivec3 b = position >> LOD;
	b.x = (b.x << L1) >> LOD;
	b.y = (b.y << L2) >> (LOD + LOD);
	
	int linenum = b.x + b.y + b.z + offset;
	return ivec2(linenum % width, linenum >> widthl2);
}

#endif
