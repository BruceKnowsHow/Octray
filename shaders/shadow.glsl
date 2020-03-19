/***********************************************************************/
#if defined vsh

attribute vec3 mc_Entity;
attribute vec4 at_tangent;
attribute vec2 mc_midTexCoord;

uniform mat4 shadowModelViewInverse;
uniform float far;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

out vec4 vColor;
flat out vec2 midTexCoord;
out vec3 wPosition;
flat out vec3 vNormal;
out float discardflag;
out vec2 texcoord;

flat out int blockID;

#include "lib/utility.glsl"
#include "lib/settings/shadows.glsl"
#include "block.properties"

void main() {
	blockID = BackPortID(int(mc_Entity.x));
	
	discardflag = 0.0;
#if UNHANDLED_BLOCKS >= 1
	discardflag += int(!isVoxelized(blockID));
#endif
	if (discardflag > 0.0) { gl_Position = vec4(-1.0); return; }
	
	
	vColor  = gl_Color;
	
	vNormal = normalize(mat3(shadowModelViewInverse) * gl_NormalMatrix * gl_Normal);
	midTexCoord = mc_midTexCoord.st;
	texcoord = gl_MultiTexCoord0.st;
	
	wPosition = (shadowModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz;
	
	gl_Position = vec4(0.0);
}


#endif
/***********************************************************************/

#define VOXELIZE

/***********************************************************************/
#if defined gsh

layout(triangles) in;

#if (defined VOXELIZE)
layout(points, max_vertices = 8) out;
#else
layout(triangle_strip, max_vertices = 3) out;
#endif

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

uniform ivec2 atlasSize;
uniform float far;

in vec4 vColor[];
flat in vec2 midTexCoord[];
in vec3 wPosition[];
flat in vec3 vNormal[];
in float discardflag[];
in vec2 texcoord[];

flat in int blockID[];

flat out vec4 data0;
flat out vec4 data1;

#include "lib/settings/shadows.glsl"
#include "lib/raytracing/WorldToVoxelCoord.glsl"
#include "lib/encoding.glsl"
#include "block.properties"

void main() {
	if (discardflag[0] + discardflag[1] + discardflag[2] > 0.0) return;
	
	if (abs(dot(wPosition[0] - wPosition[1], wPosition[2] - wPosition[1])) < 0.001) return;
	
	#if (!defined VOXELIZE)
	for (int i = 0; i < 3; ++i) {
		gl_Position = gl_in[i].gl_Position;
		EmitVertex();
	}
	return;
	#endif
	
	vec3 triCentroid = (wPosition[0] + wPosition[1] + wPosition[2]) / 3.0 - vNormal[0] / 4096.0;
	triCentroid += fract(cameraPosition);
	
	vec3 vPos = WorldToVoxelSpace(triCentroid);
	
	if (OutOfVoxelBounds(vPos)) return;
	
	
	
	vec2 coord = VoxelToTextureSpace(uvec3(vPos)) + 0.5;
	coord /= shadowMapResolution;
	
	vec2 spriteSize = abs(midTexCoord[0] - texcoord[0]) * 2.0 * atlasSize;
	vec2 cornerTexCoord = midTexCoord[0] - abs(midTexCoord[0] - texcoord[0]);
	
	vec2 hs = hsv(vColor[0].rgb).rg;
	
	data0 = vec4(log2(spriteSize.x) / 255.0, blockID[0] / 255.0, hs);
	data1 = vec4(vColor[0].rgb, 0.0);
	
	// Can pass an unsigned integer range [0, 2^23 - 1]
	float depth = packTexcoord(cornerTexCoord);
	gl_Position = vec4(coord * 2.0 - 1.0, depth, 1.0);
	
	EmitVertex();
	
	int lodOffset = shadowVolume;
	
	for (int LOD = 1; LOD <= 7; ++LOD) {
		coord = VoxelToTextureSpace(uvec3(vPos), LOD, lodOffset) + 0.5;
		lodOffset += shadowVolume >> (LOD * 3);
		coord /= shadowMapResolution;
		
		depth = -1.0;
		
		gl_Position = vec4(coord * 2.0 - 1.0, depth, 1.0);
		EmitVertex();
	}
};

#endif
/***********************************************************************/

#define GSH_ACTIVE

/***********************************************************************/
#if defined fsh

// layout(early_fragment_tests) in;

flat in vec4 data0;
flat in vec4 data1;

void main() {
	gl_FragData[0] = data0;
	// gl_FragData[1] = data1;
}

#endif
/***********************************************************************/
