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

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec2 viewSize;

noperspective in vec2 texcoord;

vec3 GetWorldSpacePosition(vec2 coord, float depth) {
	vec4 pos = vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	pos = gbufferProjectionInverse * pos;
	pos /= pos.w;
	pos.xyz = mat3(gbufferModelViewInverse) * pos.xyz;
	
	return pos.xyz;
}

vec3 fog(vec3 color, vec3 pos0, vec3 pos1) {
	return color;
	
	float dist = distance(pos0, pos1);
	
	return color + dist / 100.0;
}

/* DRAWBUFFERS:0 */
#include "/../shaders/lib/exit.glsl"

void main() {
	float depth0 = texture(depthtex0, texcoord).x;
	float depth1 = depth0 < 1.0 ? texture(depthtex1, texcoord).x : 1.0;
	
	if (depth1 >= 1.0) {
		// sky
	}
	
	vec3 position0 = GetWorldSpacePosition(texcoord, depth0);
	vec3 position1 = position0;
	
	vec3 color = texture(colortex0, texcoord).rgb;
	
	if (depth0 != depth1) {
		
		position1 = GetWorldSpacePosition(texcoord, depth1);
		
		color = fog(color, position0, position1);
		color = fog(color, vec3(0.0), position0);
	} else {
		color = fog(color, vec3(0.0), position0);
	}
	
//	for (int i = 0; i < 300; ++i) {
//		color += textureLod(colortex0, texcoord + i * 0.01, 5).rgb;
//	}
	
	gl_FragData[0] = vec4(color, 1.0);
	
	exit();
}

#endif
/***********************************************************************/
