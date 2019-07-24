#ifndef WORLDTOVOXELCOORD_GLSL
#define WORLDTOVOXELCOORD_GLSL

const int shadowRadius = int(shadowDistance);
const int shadowDiameter = 2 * shadowRadius;

vec3 Part1Transform(vec3 position) {
	position.y += floor(cameraPosition.y);
	
	position.xz += shadowRadius;
	
	position.xz += mod(floor(cameraPosition.xz), 4.0);
	
	#ifndef gbuffers_shadow
	position += gbufferModelViewInverse[3].xyz + fract(cameraPosition);
	#endif
	
	return position;
}

vec3 Part1InvTransform(vec3 position) {
	position.y -= floor(cameraPosition.y);
	position.xz -= shadowRadius;
	
	position.xz -= mod(floor(cameraPosition.xz), 4.0);
	
	#ifndef gbuffers_shadow
	position -= gbufferModelViewInverse[3].xyz + fract(cameraPosition);
	#endif
	
	return position;
}

ivec2 WorldToVoxelCoord0(vec3 position, int LOD) { // Blocks are layed out one-dimensionally
	const ivec2 lodOffset[8] = ivec2[8](
		ivec2(0, 0), ivec2(0, 4096), ivec2(0, 6144), ivec2(0, 7168),
		ivec2(0, 7680), ivec2(0, 7936), ivec2(0, 8064), ivec2(0, 8128));
	
	const int width = shadowMapResolution;
	const int widthl2 = int(log2(width));
	
	ivec3 b = ivec3(position) >> LOD;
	b.zy = b.zy << ivec2((ceil(log2(shadowDiameter)) - LOD) * vec2(1.0, 2.0));
	
	int linenum = b.x + b.y + b.z;
	
	return ivec2(linenum % width, linenum >> widthl2) + lodOffset[LOD]*2;
}

ivec2 WorldToVoxelCoord(vec3 position, int LOD) {
	return WorldToVoxelCoord0(position, LOD);
}

#endif
