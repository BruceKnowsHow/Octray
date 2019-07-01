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

uniform sampler2D colortex1;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D noisetex;

// Do these weird declarations so that optifine doesn't create extra buffers
#define smemin2 colortex2
#define smemin3 colortex3
#define smemin4 colortex4
uniform sampler2D smemin2;
uniform sampler2D smemin3;
uniform sampler2D smemin4;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec3 shadowLightPosition;

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

vec3 GetWorldSpacePosition(vec2 coord, float depth) {
	vec4 pos = vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	pos = gbufferProjectionInverse * pos;
	pos /= pos.w;
	pos.xyz = mat3(gbufferModelViewInverse) * pos.xyz;
	
	return pos.xyz;
}

#include "/../shaders/lib/raytracing/VoxelMarch.glsl"

vec3 textureAniso(sampler2D samplr, vec2 coord, ivec2 texSize, vec2 LOD) {
	vec2 c = coord / atlasSize;
	
	vec2 p = vec2(lessThan(coord.xy, coord.yx));
	
	return textureLod(samplr, coord, LOD.x).rgb;
	
	return vec3(0.0);
}

#include "/../shaders/lib/raytracing/ComputeRaytracedReflections.glsl"

/* DRAWBUFFERS:0 */
#include "/../shaders/lib/exit.glsl"


void main() {
	if (isEyeInWater > 0) { // Underwater
		// Render terrain layer & mask
		// Where visible, render cloud layer & behind-visibility
		// Where visible, render back-sky layer
		
		// We need to save the terrain depth for later
		
	} else if (cameraPosition.y > 256.0) { // Inside cloud volume
		// Note: "layer" means color variable
		// Render cloud layer & behind-visibility
		// Where visible, render terrain layer & mask
		// Where visible, render back-sky layer
		// Blend color = clouds + terrain
		// Blend color = color + back-sky
		
	} else { // Above water & below clouds
		// Render terrain layer & mask
		// Where visible, render cloud layer & behind-visibility
		// Where visible, render back-sky layer
		
		// Entity + Terrain Handling:
		// 
	}
	
	
	float depth0 = textureLod(depthtex0, texcoord, 0).x;
	if (depth0 >= 1.0) { gl_FragData[0] = SKY; return; } // Immediately deal with sky
	
	
	vec3 diffuse  = textureLod(colortex6, texcoord, 0).rgb;
	vec3 normal   = DecodeNormal(textureLod(colortex7, texcoord, 0).rg);
	vec2 specular = unpack2x8(textureLod(colortex7, texcoord, 0).b);
	
	vec3 flatNormal = mat3(gbufferModelViewInverse) * DecodeNormal(textureLod(colortex1, texcoord, 0).rg);
	
	vec3 wPos = GetWorldSpacePosition(texcoord, depth0); // Origin at eye
	
//	vec3 lastDir = vec3(0.0);
//	vec3 marchPos = vec3(0.0);
//	float lookup = VoxelMarch(marchPos, normalize(wPos), lastDir, 7);
	
	float sunlight = ComputeSunlight(wPos, normal, flatNormal, light);
	
	vec3 currPos = wPos;
	vec3 rayDir = reflect(normalize(currPos), normal);
	vec3 plane = abs(flatNormal);
	show(normalize(currPos))
	float alpha = (1.0-dot(normalize(currPos), plane * sign(currPos))) * (specular.x);
	vec3 color = diffuse * sunlight * (1.0 - alpha);
	
	ComputeReflections(color, currPos, rayDir, plane, alpha, colortex2, colortex3, colortex4);
	
	gl_FragData[0].rgb = color;
	
	exit();
}

#endif
/***********************************************************************/
