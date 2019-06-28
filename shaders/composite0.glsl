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

noperspective in vec2 texcoord;

vec3 GetWorldSpacePosition(vec2 coord, float depth) {
	vec4 pos = vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	pos = gbufferProjectionInverse * pos;
	pos /= pos.w;
	pos.xyz = mat3(gbufferModelViewInverse) * pos.xyz;
	
	return pos.xyz;
}

#include "/../shaders/lib/raytracing/VoxelMarch.glsl"

/* DRAWBUFFERS:0 */
#include "/../shaders/lib/exit.glsl"

void main() {
	/*
	vec3 c = textureLod(colortex1, texcoord, 0).xxx;
	
	int g = 3 + int(c.r);
	
	for (int i = 0; i < 500; ++i) {
		c.r = c.r + c.g + g;
		g = g + g + i;
		
	//	if (c.r > 0.0) c.r += 1.0;
	//	if (g.r > g.g) g.r += -1;
		
	//	g = g + floatBitsToInt(c.r); // 270
	//	c.r = c.r + intBitsToFloat(g); // 260
	//	c.r = c.r + float(g); // 245
	//	c.r = clamp(c.r * 0.01, 0.0, 1.0); // 242
	//	c.r = max(c.r, 0.0); // 226
	//	g = clamp(g, 0, 1); // 213
	//	c.r = trunc(c.r); // 200
	//	g = g + int(c.r); // 193
	//	c.r = ternary max0 // 157
		
	//	g = g + i; // 288
	//	c.r = c.r + i; // 279
	//	c.r = c.r * c.g * c.b; // 257
	//	c.r = c.r + float(g); // 257
	//	g = g >> 1; // 230
	//	g = g * i; // 213
	//	g = g + int(c.r); // 201
	//	g = g / 2; // 68
	//	g = g / g; // 45
		
	//	346
	//	c.r = c.r * c.g * c.b; // 259
	//	c.r = clamp(c.r * c.g * c.b, 0.0, 1.0); // 236
	}
	
	c.r += g;
	
	gl_FragData[0] = vec4(c, 1.0);
	return;
	*/
	
	#define SKY vec4(0.2, 0.5, 1.0, 1.0)
	
	float depth0 = textureLod(depthtex0, texcoord, 0).x;
	if (depth0 >= 1.0) {
		gl_FragData[0] = SKY;
		return;
	}
	
	
	mat3 tbnMatrix = DecodeNormalU(texelFetch(colortex5, ivec2(texcoord*viewSize), 0).r);
	
	vec2 tCoord = textureLod(colortex1, texcoord, 0).st;
//	vec2 tCoord = cornerTexCoord + coordInSprite;
	
	vec3 vColor = rgb(vec3(unpack2x8(texelFetch(colortex1, ivec2(texcoord*viewSize), 0).b), 1.0));
	
	vec3  color   =  textureLod(colortex2, tCoord, 0).rgb * vColor;// * vColor;
	vec3 normal   = (textureLod(colortex3, tCoord, 0).rgb * 2.0 - 1.0) * tbnMatrix;
	vec3 specular =  textureLod(colortex4, tCoord, 0).rgb;
	
	
	vec3 wPos = GetWorldSpacePosition(texcoord, depth0); // Origin at eye
	
	vec3 lastDir = vec3(0.0);
	vec3 marchPos = VoxelMarch(vec3(0.0), normalize(wPos), lastDir, 7);
//	vec3 marchPos = vec3(0.0);
	
	vec3 rayDir = reflect(normalize(wPos), normal);
	vec3 plane = lastDir;
	vec3 currPos = Part1InvTransform(marchPos) - gbufferModelViewInverse[3].xyz - fract(cameraPosition);
	
	vec3 C = vec3(0.0);
	float alpha = 1.0;
	
	for (int i = 0; i < 1; ++i) {
		currPos = VoxelMarch(currPos, rayDir, plane, 0);
		if (currPos.z == -1e35) { C = SKY.rgb*alpha; break; }
		
		vec3 benin = Part1InvTransform(currPos) - gbufferModelViewInverse[3].xyz - fract(cameraPosition);
		
		vec3 coord = fract(currPos);
		
		coord.xy = (abs(plane.y) > 0.5) ? (coord.xz) : ((abs(plane.x) > 0.5) ? coord.zy :  coord.xy);
	//	coord.xy = (abs(plane.y) > 0.5) ? (coord.xz) : ((abs(plane.x) > 0.5) ? coord.xy :  coord.zy);
		
		vec2 midTexCoord = unpackTexcoord(Lookup(currPos, 0));
		vec2 spriteSize = 64.0 / atlasSize; // Sprite size in [0, 1] texture space
		vec2 cornerTexCoord = midTexCoord - 0.5 * spriteSize; // Coordinate of texture's starting corner in [0, 1] texture space
		vec2 coordInSprite = coord.xy * spriteSize; // Fragment's position within sprite space
		vec2 tCoord = cornerTexCoord + coordInSprite;
		
		C += textureLod(colortex2, tCoord, 0).rgb * unpackVertColor(Lookup(currPos, 1)) * alpha;
		alpha *= 1.0-dot(normalize(benin), plane*sign(benin));
		
		currPos = benin;
		rayDir = reflect(rayDir, plane * sign(rayDir));
	}
	
	vec3 sunlightDir = lastDir;
	vec3 light = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
	float sunlight = 1.0 - 0.5 * float(VoxelMarch(wPos, light, sunlightDir, 0).z > -1e34);
//	float sunlight = 1.0;
	
	vec2 midTexCoord = unpackTexcoord(Lookup(marchPos, 0));
	
	vec3 coord = (fract(wPos + fract(cameraPosition + gbufferModelViewInverse[3].xyz)) * 2.0 - 1.0) * tbnMatrix * 0.5 + 0.5;
	
	vec2 spriteSize = 16.0 / atlasSize; // Sprite size in [0, 1] texture space
	vec2 cornerTexCoord = midTexCoord - 0.5 * spriteSize; // Coordinate of texture's starting corner in [0, 1] texture space
	vec2 coordInSprite = coord.xy * spriteSize; // Fragment's position within sprite space
	
	gl_FragData[0].rgb = color;
	gl_FragData[0].rgb = (C+color)/2.0;
	gl_FragData[0].rgb = mix(color*sunlight, C, pow(1.0+dot(normalize(wPos), tbnMatrix[2]), 2.0));
//	gl_FragData[0].rgb = mix(color*sunlight, C, 1.0);
	
//	show(texelFetch(shadowtex0, ivec2(texcoord * shadowMapResolution), 0).x < 1.0)
//	show(texelFetch(shadowtex0, ivec2(texcoord * shadowMapResolution/vec2(16.0, 256.0)), 0).x < 1.0)
	
	exit();
}

#endif
/***********************************************************************/
