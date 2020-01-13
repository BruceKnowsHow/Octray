#if !defined WORLDTOVOXELCOORD_GLSL
#define WORLDTOVOXELCOORD_GLSL

#include "/../shaders/lib/settings/shadows.glsl"

const int shadowRadius = int(shadowDistance);
const int shadowDiameter = 2 * shadowRadius;

// Voxel space is a simple translation of world space.
// The DDA marching function stays in voxel space inside its loop to avoid unnecessary transformations.
vec3 WorldToVoxelSpace(vec3 position) {
	position.y += floor(cameraPosition.y);
	
	position.xz += shadowRadius;
	
	position.xz += mod(floor(cameraPosition.xz), 4.0);
	
	#ifndef gbuffers_shadow
	position += gbufferModelViewInverse[3].xyz*1.0 + fract(cameraPosition);
	#endif
	
	return position;
}

// When the DDA marching function has finished, its position output can be translated back to regular world space using this function.
vec3 VoxelToWorldSpace(vec3 position) {
	position.y -= floor(cameraPosition.y);
	position.xz -= shadowRadius;
	
	position.xz -= mod(floor(cameraPosition.xz), 4.0);
	
	#ifndef gbuffers_shadow
	position -= gbufferModelViewInverse[3].xyz*1.0 + fract(cameraPosition);
	#endif
	
	return position;
}

// Data is layed out in the shadow map in a 2D texture.
// This function transforms a position in voxel space into its corresponding position in that 2D texture.
ivec2 VoxelToTextureSpace(vec3 position, int LOD) { // Blocks are layed out one-dimensionally
	const float h0 = 256.0 * shadowDiameter * shadowDiameter / shadowMapResolution;
	const int shadowVolume = 256 * shadowDiameter * shadowDiameter;
	
	const ivec2 lodOffset[8] = ivec2[8](
		ivec2(0, 0), ivec2(0, h0), ivec2(0, h0*1.5), ivec2(0, h0*1.75),
		ivec2(0, h0*1.875), ivec2(0, h0*1.9375), ivec2(0, h0*1.96875), ivec2(0, h0*1.9921875));
	
	const int off[8] = int[8](0, shadowVolume, shadowVolume*3/2, shadowVolume*7/4, shadowVolume*15/8, shadowVolume*31/16, shadowVolume*63/32, shadowVolume*127/64);
	
	const int width = shadowMapResolution;
	const int widthl2 = int(log2(width));
	
	ivec3 b = ivec3(position) >> LOD;
	b.zy = b.zy << ivec2((ceil(log2(shadowDiameter)) - LOD) * vec2(1.0, 2.0));
	
	int linenum = b.x + b.y + b.z + off[LOD];
	
	return ivec2(linenum % width, linenum >> widthl2) ;
}

#endif
