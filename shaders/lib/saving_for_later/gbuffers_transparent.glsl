/***********************************************************************/
#if defined vsh

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
out vec2 texcoord;
out vec2 lmcoord;

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
	vColor   = gl_Color.rgb;
	texcoord = gl_MultiTexCoord0.st;
	lmcoord  = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
	
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
//	if (abs(mc_Entity.x - 9.5) < 1.6 || !any(greaterThan(abs(normalize(gl_Normal)), vec3(0.99)))) {
//		gl_Position = vec4(-1.0);
//		return;
//	}
	
	tbnMatrix = CalculateTBN();
	
	vec3 sth = (tbnMatrix * vec3((texcoord - mc_midTexCoord.xy) * textureSize(tex, 0) / 16.0, 0.0));
	
	vec3 centerDir = tbnMatrix[2] * 0.5 + sth;
	
	vec3 center = position.xyz - centerDir;
	
	position.xyz += cameraPosition;
	
	if (abs(position.y - (65.5 + frameCounter / 16 % 16)) < 0.5) {
//	} else {
//		gl_Position = vec4(-1.0);
//		return;
	}
	
	position.xyz -= cameraPosition;
	
	gl_Position = gbufferProjection * gbufferModelView * position;
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

#include "/../shaders/lib/debug.glsl"
#include "/../shaders/lib/encoding.glsl"

uniform sampler2D tex;
uniform sampler2D normal;
uniform sampler2D specular;

in mat3 tbnMatrix;
in vec3 vColor;
in vec2 texcoord;
in vec2 lmcoord;

/* DRAWBUFFERS:0 */
#include "/../shaders/lib/exit.glsl"

void main() {
	vec4 diffuse = texture(tex, texcoord);
	
	diffuse.rgb *= vColor;
	
	gl_FragData[0] = diffuse.rgba;
	
	exit();
}

#endif
/***********************************************************************/
