#if !defined VOXELIZATION_GLSL
#define VOXELIZATION_GLSL


#include "/BlockMappings.glsl"

#define VOXELIZATION_DISTANCE 1 // [0 1 2]

#define MAX_RAY_BOUNCES 2 // [0 1 2 3 4 6 8 12 16 24 32 48 64]

#if defined world0
	#define SUNLIGHT_RAYS
#endif

#define SPECULAR_RAYS
#define AMBIENT_RAYS

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

const int voxelRadius2   = int(shadowDistance);
const int voxelDiameter2 = 2 * voxelRadius2;
const ivec3 voxelDimensions2 = ivec3(voxelDiameter2, 256, voxelDiameter2);

const int voxelArea2 = voxelDimensions2.x * voxelDimensions2.z;
const int voxelVolume2 = voxelDimensions2.y * voxelArea2;

int voxelRadius   = int(min(shadowDistance, far));
int voxelDiameter = 2 * voxelRadius;
ivec3 voxelDimensions = ivec3(voxelDiameter, 256, voxelDiameter);

int voxelArea = voxelDimensions.x * voxelDimensions.z;
int voxelVolume = voxelDimensions.y * voxelArea;

bool OutOfVoxelBounds(vec3 point) {
	vec3 mid = voxelDimensions / 2.0;
	
	return any(greaterThanEqual(abs(point - mid), mid-vec3(0.001)));
}

bool OutOfVoxelBounds(uvec3 point) {
	return any(greaterThanEqual(point, uvec3(voxelDimensions)));
}

bool OutOfVoxelBounds(uint point, uvec3 uplane) {
	uint comp = (uvec3(voxelDimensions).x & uplane.x) | (uvec3(voxelDimensions).y & uplane.y) | (uvec3(voxelDimensions).z & uplane.z);
	return point >= comp;
}

// Voxel space is a simple translation of world space.
// The DDA marching function stays in voxel space inside its loop to avoid unnecessary transformations.
vec3 WorldToVoxelSpace(vec3 position) {
	vec3 WtoV = vec2(0.0, floor(cameraPosition.y)).xyx + vec2(0.0, voxelRadius).yxy + gbufferModelViewInverse[3].xyz + fract(cameraPosition);
	return position + WtoV;
}

vec3 WorldToVoxelSpace_ShadowMap(vec3 position) {
	vec3 WtoV = vec2(0.0, floor(cameraPosition.y)).xyx + vec2(0.0, voxelRadius).yxy;
	return position + WtoV;
}

// When the DDA marching function has finished, its position output can be translated back to regular world space using this function.
vec3 VoxelToWorldSpace(vec3 position) {
	vec3 WtoV = vec2(0.0, floor(cameraPosition.y)).xyx + vec2(0.0, voxelRadius).yxy + gbufferModelViewInverse[3].xyz + fract(cameraPosition);
	return position - WtoV;
}

ivec2 VoxelToTextureSpace(uvec3 position, uint LOD) {
	position = position >> LOD;
	position.x = (position.x * voxelDiameter2) >> LOD;
	position.y = (position.y * voxelArea2) >> (LOD*2);
	
	uint linenum = (position.x + position.y + position.z) + ((voxelVolume2*8) - ((voxelVolume2*8) >> int(LOD*3)))/7;
	return ivec2(linenum % shadowMapResolution, linenum / shadowMapResolution);
}

ivec2 VoxelToTextureSpace(uvec3 vPos) {
	return VoxelToTextureSpace(vPos, 0);
}


#endif
