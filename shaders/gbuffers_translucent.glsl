/***********************************************************************/
#if defined vsh

#include "/../shaders/lib/utility.glsl"
#include "/../shaders/lib/debug.glsl"

attribute vec4 mc_Entity;
attribute vec4 at_tangent;
attribute vec4 mc_midTexCoord;

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
	blockID = mc_Entity.x;
	
	discardflag = 0.0;
//	discardflag += float(!isVoxelized(blockID));
//	discardflag += float(isEntity(blockID));
	
	if (discardflag > 0.0) { gl_Position = vec4(-1.0); return; }
	
	
	vColor      = gl_Color;
	texcoord    = gl_MultiTexCoord0.st;
	midTexCoord = mc_midTexCoord.st;
	lmcoord     = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
	
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	wPosition = position.xyz;
	
	tbnMatrix = CalculateTBN();
	
	gl_Position = gbufferProjection * gbufferModelView * position;
}

#endif
/***********************************************************************/

/***********************************************************************/
#if defined fsh

#include "/../shaders/lib/debug.glsl"
#include "/../shaders/lib/encoding.glsl"

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D shadowtex0;
uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;
uniform vec2 viewSize;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

uniform ivec2 atlasSize;

uniform float frameTimeCounter;

in float discardflag;

in vec2 texcoord;
in vec2 lmcoord;

in vec4 vColor;
in vec3 wPosition;

in mat3 tbnMatrix;

flat in vec2 midTexCoord;
flat in float blockID;

#include "/../shaders/lib/settings/shadows.glsl"
#include "/../shaders/lib/raytracing/VoxelMarch.glsl"
#include "/../shaders/lib/raytracing/ComputeRaytracedReflections.glsl"
#include "/../shaders/lib/WaterWaves.fsh"

#include "/../shaders/block.properties"

/* DRAWBUFFERS:0 */
#include "/../shaders/lib/exit.glsl"

void main() {
	if (discardflag > 0.0) discard;
	
	vec4 diffuse = textureLod(tex, texcoord, 0);
	
	if (diffuse.a <= 0.0) discard;
	
	
	diffuse.rgb = diffuse.rgb * vColor.rgb * vColor.a;
	vec3 normal = tbnMatrix * normalize(textureLod(normals, texcoord, 0).rgb * 2.0 - 1.0);
	normal = tbnMatrix*GetWaveNormals(wPosition*0, tbnMatrix[2]);
	vec2 spec   = textureLod(specular, texcoord, 0).rg;
	
	vec3 color = diffuse.rgb*0;
	vec3 currPos = wPosition - gbufferModelViewInverse[3].xyz;
	vec3 rayDir = refract(normalize(currPos), normal*vec3(1,-1,1), 1.0 / 1.33);
	float alpha = (1.0-dot(normalize(currPos), tbnMatrix[2])) * (spec.x);
//	if (isWater(blockID)) alpha = 1.0;
	alpha = 1.0;
	vec3 flatNormal = abs(tbnMatrix[2]) * (currPos);
	
	ComputeReflections(color, currPos, rayDir, flatNormal, alpha, tex, normals, specular);
	
	gl_FragData[0] = vec4(color, 1.0);
//	gl_FragData[0] = vec4(texcoord, pack2x8(hsv(vColor.rgb).rg), 1.0);
//	gl_FragData[1] = vec4(EncodeNormalU(tbnMatrix), 0.0, 0.0, 1.0);
	
	exit();
}

#endif
/***********************************************************************/
