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

out mat3 tbnMatrix;
out vec3 vColor;
out vec3 vNormal;
out vec3 wPosition;
out vec2 texcoord;
flat out vec2 flatTexcoord;
flat out vec2 midTexCoord;
out vec2 lmcoord;
out float discardflag;

mat3 CalculateTBN() {
	vec3 tangent  = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * at_tangent.xyz);
	vec3 normal   = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal) ;
	vec3 binormal = cross(tangent, normal); // Orthogonalize binormal
	
	return mat3(tangent, binormal, normal);
}

mat3 rotate(vec3 axis, float angle) {
	axis = normalize(axis);
	float s = sin(angle);
	float c = cos(angle);
    float oc = 1.0 - c;
	
	return mat3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,
	            oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
	            oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c);
}

void main() {
	discardflag = 0.0;
	discardflag += float(mc_Entity.x == 1.0);
	if (discardflag > 0.0) {
		gl_Position = vec4(-1.0);
		return;
	}
	
	vColor   = gl_Color.rgb;
	texcoord = gl_MultiTexCoord0.st;
	midTexCoord = mc_midTexCoord.st;
	lmcoord  = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
	vNormal = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal);
	
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

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform ivec2 atlasSize;

in mat3 tbnMatrix;
in vec3 vColor;
in vec2 texcoord;
flat in vec2 midTexCoord;
in vec3 wPosition;
in float discardflag;
//in vec2 lmcoord;

/* DRAWBUFFERS:15 */
#include "/../shaders/lib/exit.glsl"

void main() {
	if (discardflag > 0.0) discard;
	
//	if (textureLod(tex, texcoord, 0).a <= 0.1*0)
//		discard;
	
	gl_FragData[0] = vec4(texcoord.st, 0.0, 1.0);
	gl_FragData[1] = vec4(tbnMatrix[0], 1.0);
	
	exit();
}

#endif
/***********************************************************************/
