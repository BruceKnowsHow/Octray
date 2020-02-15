/***********************************************************************/
#if defined vsh

#include "lib/utility.glsl"
#include "lib/debug.glsl"

attribute vec3 mc_Entity;
attribute vec4 at_tangent;
attribute vec2 mc_midTexCoord;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform int frameCounter;
uniform vec2 viewSize;

uniform bool accum;

out float discardflag;
out vec2 texcoord;
out vec4 vColor;
out vec3 wPosition;
out mat3 tbnMatrix;
flat out int blockID;

mat3 CalculateTBN() {
	vec3 tangent  = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * at_tangent.xyz);
	vec3 normal   = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal) ;
	vec3 binormal = cross(tangent, normal); // Orthogonalize binormal
	
	return mat3(tangent, binormal, normal);
}

#include "block.properties"

#include "lib/WangHash.glsl"

vec2 TAAHash() {
	return (WangHash(uvec2(frameCounter*2, frameCounter*2 + 1)) - 0.5) / viewSize;
}

void main() {
	blockID = BackPortID(int(mc_Entity.x));
	
	tbnMatrix = CalculateTBN();
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	// position.xyz = rotate(vec3(1,0,0), position.z / 500.0) * position.xyz;
	
	wPosition = position.xyz;
	
	discardflag = 0.0;
#if UNHANDLED_BLOCKS >= 2
	discardflag += float(!isVoxelized(blockID));
#endif

	if (discardflag > 0.0) { gl_Position = vec4(-1.0); return; }
	
	texcoord = gl_MultiTexCoord0.st;
	vColor = gl_Color;
	
	gl_Position = gbufferProjection * gbufferModelView * position;
	gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
	gl_Position.xy += TAAHash() * gl_Position.w * float(accum);
	gl_Position.xy = gl_Position.xy * 2.0 - 1.0;
}

#endif
/***********************************************************************/

/***********************************************************************/
#if defined gsh

layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform float far;

in float discardflag[];
in vec2 texcoord[];
in vec4 vColor[];
in vec3 wPosition[];
in mat3 tbnMatrix[];
flat in int blockID[];

out float _discardflag;
out vec2 _texcoord;
out vec4 _vColor;
out vec3 _wPosition;
out mat3 _tbnMatrix;
flat out int _blockID;


#include "lib/settings/shadows.glsl"
#include "lib/raytracing/WorldToVoxelCoord.glsl"
#include "lib/encoding.glsl"

void main() {
	if (discardflag[0] + discardflag[1] + discardflag[2] > 0.0)
		return;
	
	vec3 triCentroid = (wPosition[0] + wPosition[1] + wPosition[2]) / 3.0 - tbnMatrix[0][2] / 4096.0;
	
	if (any(greaterThan(abs(triCentroid.xz), vec2(shadowRadius - 4.0))))
		return;
	
	for (int i = 0; i < 3; ++i) {
		_discardflag = discardflag[i];
		_texcoord = texcoord[i];
		_vColor = vColor[i];
		_wPosition = wPosition[i];
		_tbnMatrix = tbnMatrix[i];
		_blockID = blockID[i];
		gl_Position = gl_in[i].gl_Position;
		EmitVertex();
	}
	
	EndPrimitive();
};

#endif
/***********************************************************************/

/***********************************************************************/
#if defined fsh

layout (depth_greater) out float gl_FragDepth;

#include "lib/debug.glsl"
#include "lib/encoding.glsl"

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

uniform mat4 gbufferModelViewInverse;
uniform vec2 viewSize;
uniform ivec2 atlasSize;
uniform int frameCounter;

#define GSH_ACTIVE
#if (defined GSH_ACTIVE)
	#define discardflag _discardflag
	#define texcoord _texcoord
	#define vColor _vColor
	#define wPosition _wPosition
	#define tbnMatrix _tbnMatrix
	#define blockID _blockID
#endif

in float discardflag;
in vec2 texcoord;
in vec4 vColor;
in vec3 wPosition;
in mat3 tbnMatrix;
flat in int blockID;

/* DRAWBUFFERS:245 */
#include "lib/exit.glsl"

#include "block.properties"

void main() {
	if (discardflag > 0.0) discard;
	
	vec4 diffuse = texture(tex, texcoord) * vec4(vColor.rgb, 1.0);
	vec4 normal = texture(normals, texcoord);
	vec4 spec = texture(specular, texcoord);
	
	if (diffuse.a < 0.1) discard;
	
	gl_FragData[0] = vec4(PackGBuffers(diffuse, normal, spec).xyz, EncodeTBNU(tbnMatrix));
	gl_FragData[1] = vec4(float(isEmissive(blockID)), 0.0, 0.0, 0.0);
	gl_FragData[2] = vec4(tbnMatrix[2], 0.0);
	
	exit();
}

#endif
/***********************************************************************/
