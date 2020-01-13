/***********************************************************************/
#if defined vsh

#include "/../shaders/lib/utility.glsl"
#include "/../shaders/lib/debug.glsl"

attribute vec3 mc_Entity;
attribute vec4 at_tangent;
attribute vec2 mc_midTexCoord;

uniform sampler2D tex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform int frameCounter;

out float discardflag;

out vec2 texcoord;
out vec2 lmcoord;

out vec4 vColor;
out vec3 wPosition;

out mat3 tbnMatrix;

flat out vec3 glnormal;

flat out vec2 midTexCoord;
flat out float blockID;

mat3 CalculateTBN() {
	vec3 tangent  = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * at_tangent.xyz);
	vec3 normal   = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal) ;
	vec3 binormal = cross(tangent, normal); // Orthogonalize binormal
	
	return mat3(tangent, binormal, normal);
}

#include "/../shaders/block.properties"

void main() {
	blockID = BackPortID(mc_Entity.x);
	
	tbnMatrix = CalculateTBN();
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	wPosition = position.xyz;
	
	discardflag = 0.0;
	discardflag += float(isWater(blockID)) * float(dot(wPosition - gbufferModelViewInverse[3].xyz, tbnMatrix[2]) > 0.0);
	discardflag += float(!isVoxelized(blockID));
//	discardflag += float(!isVoxelized(blockID) && !isWater(blockID));
//	discardflag += float(isEntity(blockID));
	
	if (discardflag > 0.0) { gl_Position = vec4(-1.0); return; }
	
	texcoord = gl_MultiTexCoord0.st;
	midTexCoord = mc_midTexCoord;
	
	gl_Position = gbufferProjection * gbufferModelView * position;
}

#endif
/***********************************************************************/

/***********************************************************************/
#if defined gsh

layout(triangles) in;
layout(triangle_strip, max_vertices = 8) out;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;

in float discardflag[];

in vec2 texcoord[];
in vec2 lmcoord[];

in vec4 vColor[];
in vec3 wPosition[];

in mat3 tbnMatrix[];

flat in vec2 midTexCoord[];
flat in float blockID[];

flat in vec3 glnormal[];

out float _discardflag;

out vec2 _texcoord;
out vec2 _lmcoord;

out vec4 _vColor;
out vec3 _wPosition;

out mat3 _tbnMatrix;

out vec3 vPos;

flat out vec2 _midTexCoord;
flat out float _blockID;

flat out vec2 vCoord;
flat out ivec2 sCoord;

flat out vec2[3] cornerTexCoord;
flat out vec3 _glnormal;


#include "/../shaders/lib/settings/shadows.glsl"
#include "/../shaders/lib/raytracing/WorldToVoxelCoord.glsl"
#include "/../shaders/lib/encoding.glsl"

void main() {
	if (discardflag[0] + discardflag[1] + discardflag[2] > 0.0)
		return;
	
	vec3 triCentroid = (wPosition[0] + wPosition[1] + wPosition[2]) / 3.0 - tbnMatrix[0][2] / 4096.0;
	
	if (any(greaterThan(abs(triCentroid.xz), vec2(shadowRadius - 4.0))))
		return;
	
	vec2 coord = VoxelToTextureSpace(WorldToVoxelSpace(triCentroid), 0) + 0.5;
	coord /= shadowMapResolution;
	
	for (int i = 0; i < 3; ++i) {
		_discardflag = discardflag[i];
		_texcoord = texcoord[i];
		_lmcoord = lmcoord[i];
		_vColor = vColor[i];
		_wPosition = wPosition[i];
		_tbnMatrix = tbnMatrix[i];
		_midTexCoord = midTexCoord[i];
		_blockID = blockID[i];
		gl_Position = gl_in[i].gl_Position;
		vCoord = coord;
		vPos = (WorldToVoxelSpace(triCentroid) + (-gbufferModelViewInverse[3].xyz + fract(cameraPosition*0)));
		sCoord = VoxelToTextureSpace(WorldToVoxelSpace(triCentroid) + (-gbufferModelViewInverse[3].xyz + fract(cameraPosition*0)), 0);
		cornerTexCoord = vec2[3](texcoord[0], texcoord[1], texcoord[2]);
		_glnormal = glnormal[i];
		EmitVertex();
	}
	
	EndPrimitive();
	
	
	
	
	
	// // Can pass an unsigned integer range [0, 2^23 - 1]
	// float depth = packTexcoord(midTexCoord[0]);
	// gl_Position = vec4(coord * 2.0 - 1.0, depth, 1.0);
	//
	// EmitVertex();
	//
	// for (int i = 1; i <= 7; ++i) {
	// 	coord = VoxelToTextureSpace(WorldToVoxelSpace(triCentroid), i) + 0.5;
	// 	coord /= shadowMapResolution;
	//
	// 	depth = -1.0;
	// 	if (i == 1) depth = packVertColor(vColor[0].rgb);
	//
	// 	gl_Position = vec4(coord * 2.0 - 1.0, depth, 1.0);
	// 	EmitVertex();
	// }
	//
	// EndPrimitive();
};

#endif
/***********************************************************************/

/***********************************************************************/
#if defined fsh

#include "/../shaders/lib/debug.glsl"
#include "/../shaders/lib/encoding.glsl"

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler3D gaux1;

uniform mat4 gbufferModelViewInverse;
uniform vec2 viewSize;
uniform ivec2 atlasSize;
uniform int frameCounter;

#define GSH_ACTIVE
#ifdef GSH_ACTIVE
	#define discardflag _discardflag
	#define texcoord _texcoord
	#define lmcoord _lmcoord
	#define vColor _vColor
	#define wPosition _wPosition
	#define tbnMatrix _tbnMatrix
	#define midTexCoord _midTexCoord
	#define blockID _blockID
	#define glnormal _glnormal
#endif

in float discardflag;

in vec2 texcoord;
in vec2 lmcoord;

in vec4 vColor;
in vec3 wPosition;

in mat3 tbnMatrix;

in vec3 vPos;

flat in vec2 midTexCoord;
flat in float blockID;

flat in vec2 vCoord;
flat in ivec2 sCoord;
flat in vec3 glnormal;

flat in vec2[3] cornerTexCoord;

/* DRAWBUFFERS:12 */
#include "/../shaders/lib/exit.glsl"

#include "/../shaders/block.properties"

void main() {
	if (discardflag > 0.0) discard;
	
	uint tbnIndex = 0;
	if (abs(tbnMatrix[2].x) > 0.5) tbnIndex = 0;
	else if (abs(tbnMatrix[2].y) > 0.5) tbnIndex = 1;
	else                           tbnIndex = 2;
	
	gl_FragData[0] = vec4(intBitsToFloat(sCoord), float(tbnIndex), 1.0);
	gl_FragData[1] = vec4(vPos, 1.0);
	
	vec2 spriteSize = abs(midTexCoord - cornerTexCoord[0]) * 2.0 * atlasSize;
	
	exit();
}

#endif
/***********************************************************************/
