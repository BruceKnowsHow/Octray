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
#include "/../shaders/lib/utility.glsl"
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
uniform sampler2D shadowtex0;
uniform sampler2D noisetex;

// Do these weird declarations so that optifine doesn't create extra buffers
#define smemin2 colortex2
#define smemin3 colortex3
#define smemin4 colortex4

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec3 shadowLightPosition;

vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

uniform ivec2 atlasSize;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 sunVector;
uniform vec3 lightVector;

uniform vec2 viewSize;

uniform float frameTimeCounter;
uniform int frameCounter;

uniform int isEyeInWater;

noperspective in vec2 texcoord;
ivec2 itexcoord = ivec2(texcoord * viewSize);

vec3 GetWorldSpacePosition(vec2 coord, float depth) {
	vec4 pos = vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	pos = gbufferProjectionInverse * pos;
	pos /= pos.w;
	pos.xyz = mat3(gbufferModelViewInverse) * pos.xyz;
	
	return pos.xyz;
}

#define WATER_COLOR (vec3(0.0, 0.5, 1.0)*0.3)

/* DRAWBUFFERS:0 */
#include "/../shaders/lib/exit.glsl"

void main() {
	float depth0 = textureLod(depthtex0, texcoord, 0).x;
	float depth1 = textureLod(depthtex1, texcoord, 0).x;
	
	vec3 color1 = texture(colortex0, texcoord).rgb;
	
	if (depth0 >= 1.0) { gl_FragData[0].rgb = color1; return; }
	
	vec3 color0 = (depth1 != depth0) ? texture(colortex2, texcoord).rgb : color1;
	
	bool isVoxelized = unpack2x8(texelFetch(colortex1, itexcoord, 0).b).g > 0.5;
	
	vec3 wPos1 = GetWorldSpacePosition(texcoord, depth1);
	vec3 wPos0 = GetWorldSpacePosition(texcoord, depth0);
	
	bool isWater = unpack2x8(texelFetch(colortex3, itexcoord, 0).g).g > 0.5;
	
	if (isVoxelized) {
		
	} else  {
		if (depth1 > depth0) { // Entity behind translucent
			float fog = 1.0 - clamp(exp2(-distance(wPos1, wPos0) * 0.5), 0.0, 1.0);
			
			color0 = mix(color1, color0, fog);
		}
	}
	
	gl_FragData[0].rgb = vec3(color0);
	
	exit();
}

#endif
/***********************************************************************/
