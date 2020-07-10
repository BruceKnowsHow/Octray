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

uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
#define SHADOW_DEPTH shadowtex0
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;
#define SKY_SAMPLER colortex7 // Do these definitions so that optifine doesn't create extra buffers
uniform sampler3D SKY_SAMPLER;
#define DEPTHTEX1 depthtex1
uniform sampler2D DEPTHTEX1;
#define DEPTHTEX2 depthtex2
uniform sampler2D DEPTHTEX2;
#define SHADOWTEX1 shadowtex1
uniform sampler2D SHADOWTEX1;
#define GBUFFER0_SAMPLER colortex0
uniform sampler2D GBUFFER0_SAMPLER;
#define GBUFFER1_SAMPLER colortex1
uniform sampler2D GBUFFER1_SAMPLER;
uniform mat4  gbufferPreviousModelView;
uniform mat4  gbufferModelView;
uniform mat4  gbufferModelViewInverse;
uniform mat4  gbufferPreviousProjection;
uniform mat4  gbufferPreviousProjectionInverse;
uniform mat4  gbufferProjection;
uniform mat4  gbufferProjectionInverse;
uniform vec3  cameraPosition;
uniform vec3  previousCameraPosition;
uniform vec3  sunDirection;
uniform vec2  viewSize;
uniform float far;
uniform float near;
uniform float frameTimeCounter;
uniform int   heldBlockLightValue;
uniform int   heldBlockLightValue2;
uniform int   frameCounter;
uniform int   isEyeInWater;
uniform bool  accum;

noperspective in vec2 texcoord;

const bool colortex2MipmapEnabled = true;
const bool depthtex0MipmapEnabled = true;

#include "../../lib/debug.glsl"
#include "../../lib/utility.glsl"
#include "../../lib/encoding.glsl"
#include "../../lib/settings/buffers.glsl"
#include "../../lib/Random.glsl"
#include "../../lib/PBR.glsl"
#include "../../lib/sky.glsl"
#include "../../lib/PrecomputeSky.glsl"

vec2 tc = texcoord - TAAHash()*float(accum);

vec3 GetWorldSpacePosition(vec2 coord, float depth) {
	vec4 pos = vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	pos = gbufferProjectionInverse * pos;
	pos /= pos.w;
	pos.xyz = mat3(gbufferModelViewInverse) * pos.xyz;
	
	return pos.xyz;
}

mat3 ArbitraryTBN(vec3 normal) {
	mat3 ret;
	ret[2] = normal;
	ret[0] = normalize(vec3(sqrt(2), sqrt(3), sqrt(5)));
	ret[1] = normalize(cross(ret[0], ret[2]));
	ret[0] = cross(ret[1], ret[2]);
	
	return ret;
}

const float glassIOR = 1.0;
vec3 totalColor = vec3(0.0);

int RAY_COUNT;

#include "../../lib/raytracing/VoxelMarch.glsl"

void ConstructRays(RayStruct curr, SurfaceStruct surface) {
	if (GetRayDepth(curr.info) >= MAX_RAY_BOUNCES) return;
	
	bool isMetal = surface.specular.g > 1/229.5;
	float roughness = pow(1.0 - surface.specular.r, 2.0);
	vec3 F0 = (isMetal) ? surface.albedo.rgb : vec3(surface.specular.g);
	// if (isMetal) surface.albedo.rgb *= 0;
	
	if (IsAmbientRay(curr)) curr.absorb /= ambientBrightness;
	
	#ifdef AMBIENT_RAYS
		RayStruct ambientray = curr;
		ambientray.info = PackRayInfo(GetRayDepth(curr.info) + 1, AMBIENT_RAY_TYPE, GetRayAttr(curr.info));
		ambientray.wDir = ArbitraryTBN(surface.normal) * CalculateConeVector(RandNextF(), radians(90.0), 32);
		ambientray.absorb *= surface.albedo.rgb * ambientBrightness * float(dot(ambientray.wDir, surface.tbn[2]) > 0.0);
		RayPush(ambientray);
	#endif
	
	#ifdef SUNLIGHT_RAYS
		vec3 randSunDir = ArbitraryTBN(sunDirection)*CalculateConeVector(RandNextF(), radians(SUN_RADIUS), 32);
		
		RayStruct sunray = curr;
		sunray.info = PackRayInfo(GetRayDepth(curr.info) + 1, SUNLIGHT_RAY_TYPE, GetRayAttr(curr.info));
		sunray.wDir = randSunDir;
		float sunlight = OrenNayarDiffuse(sunDirection, curr.wDir, surface.normal, 0.5, 1.0);
		sunlight *= float(dot(surface.tbn[2], sunDirection) > 0.0) * mix(1.0, 3.0, float(GetRayDepth(curr.info) > 0));
		sunray.absorb = curr.absorb * surface.albedo.rgb * sunlight * sunBrightness * GetSunIrradiance(kPoint(VoxelToWorldSpace(curr.vPos)), sunDirection);
		RayPush(sunray);
	#endif
}

#define USE_RASTER_ENGINE
#ifdef USE_RASTER_ENGINE
	#define USE_RASTER_ENGINE_B On
#else
	#define USE_RASTER_ENGINE_B Off
#endif

// Returns true if no rays should be launched.
bool ConstructTransparentRays(inout RayStruct curr, SurfaceStruct surface) {
	if (GetRayDepth(curr.info) >= MAX_RAY_BOUNCES) return true;
	
	RayStruct through = curr;
	through.vPos -= surface.tbn[2] * exp2(-12);
	curr.vPos -= surface.tbn[2] * exp2(-12);
	
	through.info = PackRayInfo(GetRayDepth(curr.info) + 1, GetRayType(curr.info));
	
	// if (!isLeavesType(surface.blockID) && !isGlassType(surface.blockID) ) return false;
	
	/*
	vec3 plane;
	vec3 pos = StepThroughVoxel(through.vPos, through.wDir, plane);
	
	mat3 tbn = GenerateTBN(plane);
	
	vec2 coord = ((fract(pos) * 2.0 ) * mat2x3(tbn) - vec3(1)*mat2x3(tbn)) * 0.5 + 0.5;
	vec2 tCoord = surface.cornerTexCoord + coord.xy * surface.spriteSize / atlasSize;
	ivec2 iCoord = ivec2(tCoord * atlasSize);
	vec4 albedo = texelFetch(VOXEL_ALBEDO_TEX, iCoord, 0);
	
	through.absorb *= (1 - albedo.a);
	*/
	
	through.absorb *= (1 - surface.albedo.a);
	curr.absorb *= surface.albedo.a;
	
	RayPush(through);
	return surface.albedo.a <= 0;
}

void HandLight(RayStruct curr, SurfaceStruct surface) {
	if (IsPrimaryRay(curr)) {
		vec3 wPos = VoxelToWorldSpace(curr.vPos);

		totalColor += surface.albedo.rgb * vec3(255, 200, 100) / 255.0 * 1.0 * (heldBlockLightValue + heldBlockLightValue2) / 16.0 * curr.absorb / (dot(wPos,wPos) + 0.5) * dot(surface.normal, -curr.wDir);
	}
	
	totalColor += surface.albedo.rgb * float(isEmissive(surface.blockID)) * curr.absorb * emissiveBrightness;
}

struct FilterData {
	vec3 albedo;
	vec3 normal;
	float zPos;
};

/* DRAWBUFFERS:201 */
#include "../../lib/exit.glsl"

void main() {
	vec3 wDir = normalize(GetWorldSpacePosition(tc, 1.0));
	vec4 prevCol = max(texture(colortex2, texcoord).rgba, 0) * float(accum)*0;
	
	FilterData filterData;
	filterData.albedo = vec3(1.0);
	filterData.normal = vec3(0.0);
	filterData.zPos = 0.0;
	
	gl_FragData[1] = vec4(filterData.normal, filterData.zPos);
	gl_FragData[2] = vec4(filterData.albedo, 0.0);
	
	if (USE_RASTER_ENGINE_B) {
		float depth = texelFetch(depthtex0, ivec2(tc * viewSize), 0).x;
		
		if (depth >= 1.0) {
			vec3 transmit = vec3(1.0);
			totalColor += ComputeTotalSky(vec3(0.0), wDir, transmit, true) * skyBrightness;
			gl_FragData[0] = vec4(totalColor, 1.0) + prevCol;
			exit();
			return;
		}
		
		// vec3 wPos = GetWorldSpacePosition(tc, depth);
		vec3 wPos = texture(colortex1, texcoord).gba;
		
		SurfaceStruct surface;
		UnpackGBuffers(texelFetch(GBUFFER0_SAMPLER, ivec2(tc*viewSize), 0).xyz, surface.albedo, surface.normals, surface.specular);
		surface.tbn = DecodeTBNU(texelFetch(GBUFFER0_SAMPLER, ivec2(tc*viewSize), 0).a);
		surface.blockID = int(texelFetch(GBUFFER1_SAMPLER, ivec2(tc*viewSize), 0).r * 255.0);
		
		RayStruct curr;
		curr.vPos = WorldToVoxelSpace(vec3(0.0));
		curr.wDir = wDir;
		curr.absorb = vec3(1.0);
		curr.info = PackRayInfo(0, PRIMARY_RAY_TYPE);
		curr.prevVolume = 1.0;
		curr.vPos = WorldToVoxelSpace(wPos) - surface.tbn[2] * exp2(-10)*0;
		
		ivec2 vCoord = VoxelToTextureSpace(uvec3(curr.vPos - surface.tbn[2] / 4.0));
		
		surface.depth = texelFetch(shadowtex0, vCoord, 0).x;
		
		#if defined RT_TERRAIN_PARALLAX
			if (isVoxelized(surface.blockID)) {
				vec4 voxelData = vec4(texelFetch(shadowcolor0, vCoord, 0));
				curr.spriteScale = exp2(round(voxelData.xx * 255.0)) / atlasSize;
				vec2 cornerTexCoord = unpackTexcoord(surface.depth);
				
				vec2 tCoord = ((fract(curr.vPos) * 2.0 - 1.0) * mat2x3(surface.tbn)) * 0.5 + 0.5;
				tCoord = tCoord * curr.spriteScale;
				
				vec3 tDir = curr.wDir * surface.tbn;
				curr.tCoord = ComputeParallaxCoordinate(vec3(tCoord, 1.0), cornerTexCoord, tDir, curr.spriteScale, curr.insidePOM, VOXEL_NORMALS_TEX);
				curr.plane = surface.tbn[2];
				curr.cornerTexCoord = cornerTexCoord;
				
				tCoord = curr.tCoord.xy;
				
				vec2 coord = mod(tCoord, curr.spriteScale) + cornerTexCoord;
				surface.albedo = textureLod(VOXEL_ALBEDO_TEX, coord, 0);
				surface.normals = GetNormals(coord);
				surface.specular = GetSpecular(coord);
				surface.albedo.rgb *= rgb(vec3(voxelData.ba, 1.0));
			}
		#endif
		
		surface.normal = surface.tbn * normalize(surface.normals.rgb * 2.0 - 1.0);
		surface.albedo.rgb = pow(surface.albedo.rgb, vec3(2.2));
		// surface.emissive = surface.specular.a * 255.0 / 254.0 * float(surface.specular.a < 254.0 / 255.0);
		// if (isEmissive(surface.blockID)) surface.emissive = 1.0;
		
		filterData.albedo = surface.albedo.rgb;
		filterData.normal = surface.normal;
		filterData.zPos = (wPos*mat3(gbufferModelViewInverse)).z;
		surface.albedo.rgb = vec3(1.0);
		
		if (!ConstructTransparentRays(curr, surface)) {
			HandLight(curr, surface);
			ConstructRays(curr, surface);
		}
	} else {
		RayStruct primary;
		primary.absorb = vec3(1.0);
		primary.info = PackRayInfo(0, PRIMARY_RAY_TYPE);
		primary.vPos = WorldToVoxelSpace(vec3(0));
		if (cameraPosition.y + gbufferModelViewInverse[3].y*1.0 > 256.0 && wDir.y < 0.0) {
			primary.vPos += wDir / wDir.y * -(cameraPosition.y + gbufferModelViewInverse[3].y*1.0 - 255.9);
		}
		
		primary.wDir = wDir;
		primary.prevVolume = 1.0;
		#ifdef RT_TERRAIN_PARALLAX
			primary.insidePOM = false;
		#endif
		RayPush(primary);
	}
	
	
	
	for (RAY_COUNT = 1; RAY_COUNT < MAX_RAYS; ++RAY_COUNT) {
		if (IsStackEmpty()) break;
		
		RayStruct curr = RayPop();
		
		#ifdef RT_TERRAIN_PARALLAX
			if (curr.insidePOM) {
				vec3 tDir = curr.wDir * GenerateTBN(curr.plane);
				
				curr.tCoord = ComputeParallaxCoordinate(curr.tCoord, curr.cornerTexCoord, tDir, curr.spriteScale, curr.insidePOM, VOXEL_NORMALS_TEX);
				
				if (curr.insidePOM) continue;
			}
		#endif
		
		#ifdef SUBVOXEL_RAYTRACING
			if (curr.subvoxel_hit) {
				mat3 tbn;
				vec2 tCoord;
				curr.subvoxel_hit = false;
				SubVoxelTrace(curr.blockID, curr.wDir, curr.cornerTexCoord, curr.spriteScale, curr.vPos, tbn, tCoord, curr.subvoxel_hit);
				if (curr.subvoxel_hit) {
					continue;
				}
			}
		#endif
		
		VoxelMarchOut VMO = VoxelMarch(curr.vPos, curr.wDir, curr.prevVolume);
		
		if (!bool(VMO.hit)) {
			if (IsSunlightRay(curr))
				totalColor += curr.absorb * float(IsSunlightRay(curr));
			else
				totalColor += ComputeTotalSky(VoxelToWorldSpace(VMO.vPos), curr.wDir, curr.absorb, IsPrimaryRay(curr)) * skyBrightness;
			
			continue;
		}
		
		SurfaceStruct surface = ReconstructSurface(curr, VMO);
		
		if (!curr.subvoxel_hit) {
			RayPush(curr);
			continue;
		}
		
		if (GetRayDepth(curr.info) == 0 || (!USE_RASTER_ENGINE_B && IsPrimaryRay(curr))) {
			filterData.albedo = mix(vec3(1.0), surface.albedo.rgb, surface.albedo.a);
			filterData.normal = surface.normal;
			filterData.zPos = (VoxelToWorldSpace(VMO.vPos)*mat3(gbufferModelViewInverse)).z;
			surface.albedo.rgb = vec3(1.0);
		}
		
		if (ConstructTransparentRays(curr, surface)) continue;
		
		if (IsSunlightRay(curr)) continue;
		
		HandLight(curr, surface);
		ConstructRays(curr, surface);
	}
	
	
	
	totalColor = max(totalColor, vec3(0.0));
	
	DEBUG_STACK_FULL();
	
	gl_FragData[0] = vec4(totalColor, 1.0) + prevCol;
	gl_FragData[1] = vec4(filterData.normal, filterData.zPos);
	gl_FragData[2] = vec4(filterData.albedo, 0.0);
	
	exit();
}

#endif
/***********************************************************************/
