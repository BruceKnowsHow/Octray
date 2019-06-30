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

out vec3 vColor;
out vec3 wPosition;

out mat3 tbnMatrix;

flat out vec2 midTexCoord;

mat3 CalculateTBN() {
	vec3 tangent  = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * at_tangent.xyz);
	vec3 normal   = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal) ;
	vec3 binormal = cross(tangent, normal); // Orthogonalize binormal
	
	return mat3(tangent, binormal, normal);
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
uniform vec2 viewSize;

in float discardflag;

in vec2 texcoord;
in vec2 lmcoord;

in vec3 vColor;
in vec3 wPosition;

in mat3 tbnMatrix;

flat in vec2 midTexCoord;

/* DRAWBUFFERS:15 */
#include "/../shaders/lib/exit.glsl"

void main() {
	if (discardflag > 0.0) discard;
	if (textureLod(tex, texcoord, 0).a <= 0.1*0) discard;
	show(textureQueryLod(tex, texcoord).r/4.0)
	gl_FragData[0] = vec4(texcoord, pack2x8(hsv(vColor).rg), 1.0);
	gl_FragData[1] = vec4(EncodeNormalU(tbnMatrix), 0.0, 0.0, 1.0);
	
	exit();
}

#endif
/***********************************************************************/
