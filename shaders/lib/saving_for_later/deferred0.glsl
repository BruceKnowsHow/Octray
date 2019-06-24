/***********************************************************************/
#if defined vsh

noperspective out vec2 texcoord;

void main() {
	texcoord    = gl_Vertex.xy;
	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

#include "/../shaders/lib/debug.glsl"
#include "/../shaders/lib/encoding.glsl"
#include "/../shaders/lib/settings/buffers.glsl"
#include "/../shaders/lib/settings/shadows.glsl"

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D depthtex0;
uniform sampler2D shadowcolor0;
uniform sampler2D shadow;
uniform sampler2D noisetex;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 sunVector;
uniform vec3 lightVector;

uniform vec2 viewSize;

uniform float frameTimeCounter;

noperspective in vec2 texcoord;

vec3 GetWorldSpacePosition(vec2 coord, float depth) {
	vec4 pos = vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	pos = gbufferProjectionInverse * pos;
	pos /= pos.w;
	pos.xyz = mat3(gbufferModelViewInverse) * pos.xyz;
	
	return pos.xyz;
}

/* DRAWBUFFERS:0 */
#include "/../shaders/lib/exit.glsl"

void main() {
	float depth = textureLod(depthtex0, texcoord, 0).x;
	if (depth >= 1.0) discard;
	
	vec2 tCoord = textureLod(colortex1, texcoord, 0).st;
	
	vec3 vColor   = textureLod(colortex2, texcoord, 0).rgb;
	
	vec3  color   = textureLod(colortex5, tCoord, 0).rgb * vColor;
	vec3 normal   = textureLod(colortex6, tCoord, 0).rgb;
	vec3 specular = textureLod(colortex7, tCoord, 0).rgb;
	
	vec3 vNormal = DecodeNormal(textureRaw(colortex3, texcoord).r);
	float LOD = textureQueryLod(colortex6, tCoord).x;
	vec3 wPos = GetWorldSpacePosition(texcoord, depth); // Origin at eye
	show(LOD)
//	show(texture(colortex5, tCoord))
	gl_FragData[0] = vec4(color, 1.0);
	
	exit();
}

#endif
/***********************************************************************/
