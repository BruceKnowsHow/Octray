/***********************************************************************/
#if defined vsh

#include "/../shaders/lib/utility.glsl"
//#include "/../shaders/lib/debug.glsl"
#include "/../shaders/lib/settings/shadows.glsl"

/*
attribute vec4 mc_Entity;
attribute vec4 at_tangent;
attribute vec4 mc_midTexCoord;
*/

uniform sampler2D tex;
uniform sampler2D colortex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

in vec4 mc_Entity;
in vec4 at_tangent;
in vec4 mc_midTexCoord;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float frameTimeCounter;
uniform int frameCounter;

out vec4 vColor;
out vec2 midTexCoord;
out vec3 wPosition;
out vec3 vNormal;
out float discardflag;
out vec2 texcoord;

flat out float blockID;

#include "/../shaders/block.properties"

void main() {
	blockID = BackPortID(mc_Entity.x);
	
	discardflag = 0.0;
	
//	discardflag += float(frameCounter % 50 != 0);
	
	discardflag += float(isEntity(blockID));
	discardflag += float(!isVoxelized(blockID));
	
	if (discardflag > 0.0) { gl_Position = vec4(-1.0); return; }
	
	
	vColor  = gl_Color;
	
	vNormal = normalize(mat3(shadowModelViewInverse) * gl_NormalMatrix * gl_Normal);
	midTexCoord = mc_midTexCoord.st;
	texcoord = gl_MultiTexCoord0.st;
	
	vec4 position = shadowModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	wPosition = position.xyz + fract(cameraPosition);
	
	gl_Position = shadowProjection * shadowModelView * position;
	gl_Position = ftransform();
}


#endif
/***********************************************************************/

#define VOXELIZE

/***********************************************************************/
#if defined gsh

layout(triangles) in;

#ifdef VOXELIZE
layout(points, max_vertices = 8) out;
#else
layout(triangle_strip, max_vertices = 3) out;
#endif

#include "/../shaders/lib/settings/shadows.glsl"

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

uniform ivec2 atlasSize;

in vec4 vColor[];
in vec2 midTexCoord[];
in vec3 wPosition[];
in vec3 vNormal[];
in float discardflag[];
in vec2 texcoord[];

out vec4 _vColor;
out vec2 _midTexCoord;
out vec3 _vNormal;
out float _discardflag;

flat out vec2 spriteSize;

#include "/../shaders/lib/raytracing/WorldToVoxelCoord.glsl"
#include "/../shaders/lib/encoding.glsl"

void main() {
	if (discardflag[0] + discardflag[1] + discardflag[2] > 0.0)
		return;
	
	
	#ifndef VOXELIZE
	for (int i = 0; i < 3; ++i) {
		_vColor = vColor[i];
		_midTexCoord = midTexCoord[i];
		_vNormal = vNormal[i];
		_discardflag = discardflag[i];
		gl_Position = gl_in[i].gl_Position;
		EmitVertex();
	}
	
	EndPrimitive();
	#endif
	
	
	
	vec3 triCentroid = (wPosition[0] + wPosition[1] + wPosition[2]) / 3.0 - vNormal[0] / 4096.0;
	
	_vColor = vColor[0];
	_midTexCoord = midTexCoord[0];
	_vNormal = vNormal[0];
	
	if (any(greaterThan(abs(triCentroid.xz), vec2(shadowRadius - 4.0))))
		return;
	
	vec2 coord = VoxelToTextureSpace(WorldToVoxelSpace(triCentroid), 0) + 0.5;
	coord /= shadowMapResolution;
	
	// Can pass an unsigned integer range [0, 2^23 - 1]
	
	spriteSize = abs(midTexCoord[0] - texcoord[0]) * 2.0 * atlasSize;
	
	float depth = packTexcoord(midTexCoord[0] - spriteSize / atlasSize  / 2.0);
	gl_Position = vec4(coord * 2.0 - 1.0, depth, 1.0);
	
	EmitVertex();
	
	const float h0 = 256.0 * shadowDiameter * shadowDiameter / shadowMapResolution;

	const int width = shadowMapResolution;
	const int widthl2 = int(log2(width));

	ivec3 b = ivec3(WorldToVoxelSpace(triCentroid)) >> 0;
	b.zy = b.zy << ivec2((ceil(log2(shadowDiameter)) - 0) * vec2(1.0, 2.0));

	int linenum = b.x + b.y + b.z;

	coord = (ivec2(linenum % width, linenum >> widthl2) + ivec2(0, h0 * 2));
	coord = (coord + 0.5) / shadowMapResolution;
	gl_Position = vec4(coord * 2.0 - 1.0, depth, 1.0);
	EmitVertex();
	
	for (int i = 1; i <= 7; ++i) {
		coord = VoxelToTextureSpace(WorldToVoxelSpace(triCentroid), i) + 0.5;
		coord /= shadowMapResolution;
		
		depth = -1.0;
		if (i == 1) depth = packVertColor(vColor[0].rgb);
		
		gl_Position = vec4(coord * 2.0 - 1.0, depth, 1.0);
		EmitVertex();
	}
	
	EndPrimitive();
};

#endif
/***********************************************************************/

#define GSH_ACTIVE

/***********************************************************************/
#if defined fsh

//layout(early_fragment_tests) in;

//#include "/../shaders/lib/debug.glsl"

uniform sampler2D shadowcolor0;
uniform sampler2D colortex0;
uniform sampler2D gaux2;
uniform sampler2D shadowtex0;

uniform int frameCounter;
uniform int instanceId;


#ifdef GSH_ACTIVE
	#define vColor _vColor
	#define midTexCoord _midTexCoord
	#define vNormal _vNormal
#endif

in vec4 vColor;
in vec2 midTexCoord;
in vec3 vNormal;
flat in vec2 spriteSize;


//#include "/../shaders/lib/exit.glsl"

void main() {
//	gl_FragDepth = uintBitsToFloat((floatBitsToUint(gl_FragCoord.z) & (~15)) | 7);
//	gl_FragDepth = uintBitsToFloat((floatBitsToUint(gl_FragCoord.z) & (~15)) | 7);
	
	gl_FragData[0] = vec4(log2(spriteSize) / 255.0, 0.0, 1.0);
	// gl_FragData[0] = vec4(0.0,0.0,1.0, 1.0);
	// gl_FragData[0] = vec4(texture(gaux2, gl_FragCoord.st / 5800.0).rgb, 1.0);
	
//	exit();
}

#endif
/***********************************************************************/
