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
uniform sampler3D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex0;
uniform sampler2D noisetex;

// Do these weird declarations so that optifine doesn't create extra buffers
#define CUSTOM5 colortex5
#define CUSTOM6 colortex6
#define CUSTOM7 colortex7

uniform sampler2D CUSTOM5;
uniform sampler2D CUSTOM6;
uniform sampler2D CUSTOM7;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;

uniform ivec2 atlasSize;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);

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

vec3 textureAniso(sampler2D samplr, vec2 coord, ivec2 texSize, vec2 LOD) {
	vec2 c = coord / atlasSize;
	
	vec2 p = vec2(lessThan(coord.xy, coord.yx));
	
	return textureLod(samplr, coord, LOD.x).rgb;
	
	return vec3(0.0);
}

#include "/../shaders/lib/raytracing/ComputeRaytracedReflections.glsl"
#include "/../shaders/lib/sky.glsl"
#include "/../shaders/lib/PrecomputeSky.glsl"
#include "/../shaders/lib/WaterFog.glsl"
#include "/../shaders/lib/Tonemap.glsl"

/* DRAWBUFFERS:0 */
#include "/../shaders/lib/exit.glsl"

void main() {
	if (isEyeInWater > 0) { // Underwater
		// Render terrain layer & mask with water fog
		// Where visible, render cloud layer & behind-visibility with water fog
		// Where visible, render back-sky layer with water fog
		
		float depth1 = textureLod(depthtex1, texcoord, 0).x;
		float depth0 = textureLod(depthtex0, texcoord, 0).x;
		
		vec3 wPos1 = GetWorldSpacePosition(texcoord, depth1);
		vec3 wPos0 = GetWorldSpacePosition(texcoord, depth0);
		
		vec3 diffuse = pow(unpack4x8(texelFetch(colortex1, itexcoord, 0).r).rgb, vec3(2.2));
		vec3 normal  = DecodeNormalU(texelFetch(colortex1, itexcoord, 0).g);
		vec2 spec    = unpack2x8(texelFetch(colortex1, itexcoord, 0).b);
		
		Mask mask;
		mask.isTranslucent = (depth1 != depth0);
		mask.isWater = (mask.isTranslucent) && (unpack2x8(texelFetch(colortex3, itexcoord, 0).g).g > 0.5);
		mask.isVoxelized = (spec.g > 0.5);
		mask.isEntity = (!mask.isVoxelized);
		
		float fog = WaterFogAmount(wPos0, wPos1*0);
		
		vec3 absorb = exp(fog / WATER_COLOR);
		
		if (NotEnoughLightToBeVisible(vec3(1.0) * absorb, absorb)) { gl_FragData[0].rgb = Tonemap(vec3(100.0)); exit(); return; }
		if (depth0 >= 1.0) { gl_FragData[0].rgb = Tonemap(ComputeTotalSky(vec3(0.0), normalize(wPos1), absorb)); exit(); return; }
		
		float sunlight = RaytraceSunlight(wPos1, normal);
		
		vec3 color = vec3(0.0);
		
		color = diffuse * sunlight;
		
		if (mask.isTranslucent) {
			color = texelFetch(colortex2, itexcoord, 0).rgb;
		}
		
		color *= absorb;
		
		gl_FragData[0].rgb = Tonemap(color);
		
	} else if (false && cameraPosition.y + gbufferModelViewInverse[3].y > 256.0) { // Inside cloud volume
		// Note: "layer" means color variable
		// Render cloud layer & behind-visibility
		// Where visible, render terrain layer & mask
		// Where visible, render back-sky layer
		// Blend color = clouds + terrain
		// Blend color = color + back-sky
		
		float depth1 = textureLod(depthtex1, texcoord, 0).x;
		vec3 wPos = GetWorldSpacePosition(texcoord, depth1); // Origin at eye
		vec3 wDir = normalize(wPos);
		
		vec3 absorb = vec3(1.0);
		vec3 color = ComputeClouds(vec3(0.0), wDir, absorb);
		
		if (depth1 < 1.0) { color += vec3(1,0,0) * absorb; absorb *= 0.0; } // Terrain
		
		if (absorb.r + absorb.g + absorb.b > 0.0) color += ComputeBackSky(wDir, absorb);
		
		gl_FragData[0].rgb = Tonemap(color);
		
	} else { // Above water & below clouds
		// Render terrain layer & mask
		// Where visible, render cloud layer & behind-visibility
		// Where visible, render back-sky layer
		
		float depth1 = textureLod(depthtex1, texcoord, 0).x;
		float depth0 = textureLod(depthtex0, texcoord, 0).x;
		
		vec3 wPos = GetWorldSpacePosition(texcoord, depth1); // Origin at eye
		vec3 wDir = normalize(wPos);
		vec3 absorb = vec3(1.0);
		
		if (depth0 >= 1.0) { gl_FragData[0].rgb = Tonemap(ComputeTotalSky(vec3(0.0), wDir, absorb)); exit(); return; } // Immediately deal with sky
		
		
		vec3 color = vec3(0.0);
		
		vec2 spec = unpack2x8(texelFetch(colortex1, itexcoord, 0).b);
		
		Mask mask;
		mask.isTranslucent = (depth1 != depth0);
		mask.isWater = (mask.isTranslucent) && (unpack2x8(texelFetch(colortex3, itexcoord, 0).g).g > 0.5);
		mask.isVoxelized = (spec.g > 0.5);
		mask.isEntity = (!mask.isVoxelized);
		
		if (mask.isTranslucent&&false) { // Flat terrain behind water
			color = texelFetch(colortex2, itexcoord, 0).rgb;
			
		} else { // Flat terrain infront of water, and opaque terrain behind it
			vec3 diffuse = pow(unpack4x8(texelFetch(colortex1, itexcoord, 0).r).rgb, vec3(2.2));
			vec3 normal  = DecodeNormalU(texelFetch(colortex1, itexcoord, 0).g);
			
			float sunlight = RaytraceSunlight(wPos, normal);
			
			vec3 currPos = wPos;
			vec3 rayDir = reflect(normalize(currPos), normal);
			
			float alpha = (1.0 + dot(normalize(currPos), normal)) * (spec.x);
			vec3 absorb = vec3(1.0);
			
			color = diffuse * sunlight * (1.0 - alpha);
			RaytraceColorFromDirection(color, currPos, rayDir, alpha, true, false, colortex5, colortex6, colortex7);
			
			vec3 kCamera = vec3(0.0, (cameraPosition.y)/1000.0 + ATMOSPHERE.bottom_radius, 0.0);
			vec3 kPoint  = kCamera + wPos/1000.0;
			
		//	vec3 transmittance = vec3(1.0);
			
		//	vec3 in_scatter = GetSkyRadianceToPoint(ATMOSPHERE, colortex0, colortex4, colortex4, kCamera, kPoint, 0.0, sunDir, transmittance);
		//	color = color * transmittance + in_scatter;
		//	color = mix(color, sky, pow(clamp(length(wPos / 512.0), 0.0, 1.0), 2.0));
		}
		
		gl_FragData[0].rgb = Tonemap(color);
	}
	
//	vec3 lastDir = vec3(0.0);
//	vec3 marchPos = vec3(0.0);
//	float lookup = VoxelMarch(marchPos, normalize(wPos), lastDir, 7);
	
	exit();
}

#endif
/***********************************************************************/
