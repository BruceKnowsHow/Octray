const int shadowRadius = int(shadowDistance);
const int shadowDiameter = 2 * shadowRadius;

vec3 Part1Transform(vec3 position, int LOD) {
	position.y += floor(cameraPosition.y);
	
//	position.xz += shadowRadius;
	
	return position;
}

vec3 Part1InvTransform(vec3 position) {
	position.y -= floor(cameraPosition.y);
	
	return position;
}

ivec2 WorldToVoxelCoord3(vec3 position, int LOD) { // Each 2x2x2 cell is flattened into an 8x1x1 line. 512 lines are layed out per 4096 row
	return ivec2(0);
}

ivec2 WorldToVoxelCoord0(vec3 position) { // Blocks are layed out one-dimensionally
	const int width = shadowMapResolution;
	const int widthl2 = int(log2(width));
	const ivec2 shift = ivec2(ceil(log2(shadowDiameter)) * vec2(1.0, 2.0));
	
	position.xz += shadowRadius;
	
	ivec3 b = ivec3(position);
	b.zy = b.zy << shift;
	
	int linenum = b.x + b.y + b.z;
	
	return ivec2(linenum % width, linenum >> widthl2);
}

ivec2 WorldToVoxelCoord0(vec3 position, int LOD) { // Blocks are layed out one-dimensionally
	const ivec2 lodOffset[8] = ivec2[8](
		ivec2(0, 0), ivec2(0, 4096), ivec2(0, 6144), ivec2(0, 7168),
		ivec2(0, 7680), ivec2(0, 7936), ivec2(0, 8064), ivec2(0, 8128));
	
	const int width = shadowMapResolution;
	const int widthl2 = int(log2(width));
	
	position.xz += shadowRadius;
	
	ivec3 pos = ivec3(position) >> LOD;
	
	ivec3 b = pos;
	b.zy = b.zy << ivec2((ceil(log2(shadowDiameter)) - LOD) * vec2(1.0, 2.0));
	
	int linenum = b.x + b.y + b.z;
	
	return ivec2(linenum % width, linenum >> widthl2) + lodOffset[LOD]*2;
}

ivec2 WorldToVoxelCoord1(vec3 position, int LOD) { // Each 16x16x16 chunk is laid out as a 4096x1 strip. Chunk strips are stacked on top of eachother.
	const ivec2 lodOffset[8] = ivec2[8](
		ivec2(0, 0), ivec2(0, 4096), ivec2(0, 6144), ivec2(0, 7168),
		ivec2(0, 7680), ivec2(0, 7936), ivec2(0, 8064), ivec2(0, 8128));
	
	
	position.xz += shadowRadius;
	
	position *= exp2(-LOD);
	
	ivec3 pos = ivec3(position);
	
	ivec3 a = pos % 16;
	a.yz = a.yz << ivec2(4, 8);
	
	ivec3 b = ivec3(position / 16.0);
	b.yz = b.yz << ivec2(4, 8);
	
	int linepos = a.x + a.y + a.z;
	int linenum = b.x + b.y + b.z;
	
	return ivec2(linepos, linenum) + lodOffset[LOD];
}

ivec2 WorldToVoxelCoord2(vec3 position, int LOD) { // Each 128x128 plane is layed out in a 16x16 grid
	const ivec2 lodOffset[8] = ivec2[8](
		ivec2(0, 0), ivec2(0, 4096), ivec2(2048, 4096), ivec2(2048 + 1024, 4096),
		ivec2(2048 + 1024 + 512, 4096), ivec2(2048 + 1024 + 512 + 256, 4096), ivec2(2048 + 1024 + 512 + 256 + 128, 4096), ivec2(2048 + 1024 + 512 + 256 + 128 + 64, 4096));
	
	position.xz += shadowRadius;
	
	ivec3 pos = ivec3(position);
	
	pos.y = pos.y >> LOD;
	
	pos.x += (pos.y % 16) * shadowDiameter;
	pos.z += int(position.y / 16) * shadowDiameter; // Can optimize this line to be: pos.z += int(position.y / 16) * shadowDiameter;
	pos.xz = pos.xz >> LOD;
	pos.xz += lodOffset[LOD];
	return pos.xz;
}

// Returns the position of the point in the texelFetch() shadow map.
// the position component for "height" must be floored.
ivec2 WorldToVoxelCoord3(vec3 position) {
	ivec3 pos = ivec3(position);
	
	pos.xz += shadowRadius;
	pos.x += shadowDiameter * (pos.y % 16);
	pos.z += shadowDiameter * (pos.y / 16);
	
	return pos.xz;
}

ivec2 WorldToVoxelCoord(vec3 position) {
	return WorldToVoxelCoord0(position);
}

ivec2 WorldToVoxelCoord(vec3 position, int LOD) {
	return WorldToVoxelCoord0(position, LOD);
	return WorldToVoxelCoord1(position, LOD);
	return WorldToVoxelCoord2(position, LOD);
}
