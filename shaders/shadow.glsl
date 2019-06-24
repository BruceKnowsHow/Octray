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

in vec4 mc_Entity;
in vec4 at_tangent;
in vec4 mc_midTexCoord;

uniform sampler2D tex;

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

out vec3 vColor;
out vec2 midTexCoord;
out vec3 wPosition;
out vec3 vNormal;
out float blockID;
out float discardflag;

mat3 CalculateTBN() {
	vec3 tangent  = normalize(mat3(shadowModelViewInverse) * gl_NormalMatrix * at_tangent.xyz);
	vec3 normal   = normalize(mat3(shadowModelViewInverse) * gl_NormalMatrix * gl_Normal) ;
	vec3 binormal = cross(tangent, normal); // Orthogonalize binormal
	
	return mat3(tangent, binormal, normal);
}

void main() {
	discardflag = 0.0;
	discardflag += float(mc_Entity.x == 0.0);
	discardflag += float(mc_Entity.x == 1.0);
	
	if (discardflag > 0.0) {
		gl_Position = vec4(-1.0);
		return;
	}
	
	vColor  = gl_Color.rgb;
	blockID = mc_Entity.x;
	vNormal = normalize(mat3(shadowModelViewInverse) * gl_NormalMatrix * gl_Normal);
	midTexCoord = mc_midTexCoord.st;
	
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

in vec3 vColor[];
in vec2 midTexCoord[];
in vec3 wPosition[];
in vec3 vNormal[];
in float blockID[];
in float discardflag[];

out vec3 _vColor;
out vec2 _midTexCoord;
out float _discardflag;

#include "/../shaders/lib/raytracing/WorldToVoxelCoord.glsl"
#include "/../shaders/lib/encoding.glsl"

void main() {
	if (discardflag[0] + discardflag[1] + discardflag[2] > 0.0)
		return;
	
	#ifndef VOXELIZE
	for (int i = 0; i < 3; ++i) {
		gl_Position = gl_in[i].gl_Position;
		_vColor = vColor[i];
		_midTexCoord = midTexCoord[i];
		EmitVertex();
	}
	
	return;
	#endif
	
	
	vec3 triCentroid = (wPosition[0] + wPosition[1] + wPosition[2]) / 3.0 - vNormal[0] / 2.0;
	
	_vColor = vColor[0];
	_midTexCoord = midTexCoord[0];
	
	if (any(greaterThan(abs(triCentroid.xz), vec2(shadowRadius))))
		return;
	
	vec2 coord = WorldToVoxelCoord(Part1Transform(triCentroid, 0), 0) + 0.5;
	coord /= shadowMapResolution;
	
	// Can pass an unsigned integer range [0, 2^23 - 1]
	float depth = packTexcoord(midTexCoord[0]);
	gl_Position = vec4(coord * 2.0 - 1.0, depth, 1.0);
	
	EmitVertex();
	
	
	
	for (int i = 1; i <= 7; ++i) {
		coord = WorldToVoxelCoord(Part1Transform(triCentroid, i), i) + 0.5;
		coord /= shadowMapResolution;
		
		depth = -1.0;
		if (i == 1) depth = packVertColor(vColor[0]);
		
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

#ifdef GSH_ACTIVE
	#define vColor _vColor
	#define midTexCoord _midTexCoord
#endif

in vec3 vColor;
in vec2 midTexCoord;

//#include "/../shaders/lib/exit.glsl"

void main() {
//	gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0);
//	gl_FragDepth = gl_FragCoord.z;
	
//	gl_FragDepth = 0.3;
	
//	exit();
}

#endif
/***********************************************************************/
