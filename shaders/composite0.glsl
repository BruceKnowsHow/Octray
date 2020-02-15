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

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform sampler2D noisetex;

// Do these weird declarations so that optifine doesn't create extra buffers
#define SKY_SAMPLER colortex7
#define TEX_SAMPLER depthtex1
#define NORMAL_SAMPLER depthtex2
#define SPECULAR_SAMPLER shadowtex1

uniform sampler3D SKY_SAMPLER;
uniform sampler2D TEX_SAMPLER;
uniform sampler2D NORMAL_SAMPLER;
uniform sampler2D SPECULAR_SAMPLER;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferPreviousProjection;

uniform vec3 sunPosition;

uniform ivec2 atlasSize;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform vec2 viewSize;

uniform float far;

uniform float frameTimeCounter;
uniform int frameCounter;

uniform int isEyeInWater;

uniform bool accum;

noperspective in vec2 texcoord;

#include "lib/debug.glsl"
#include "lib/utility.glsl"
#include "lib/encoding.glsl"
#include "lib/settings/buffers.glsl"
#include "lib/settings/shadows.glsl"

ivec2 itexcoord = ivec2(texcoord * viewSize);

vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);

#include "lib/WangHash.glsl"

vec2 TAAHash() {
	return (WangHash(uvec2(frameCounter*2, frameCounter*2 + 1)) - 0.5) / viewSize;
}

// vec2 tc = texcoord + vec2(WangHash(uvec2(gl_FragCoord.xy) * (frameCounter + 1))) / viewSize;
vec2 tc = texcoord - TAAHash()*float(accum);

vec3 GetWorldSpacePosition(vec2 coord, float depth) {
	vec4 pos = vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	pos = gbufferProjectionInverse * pos;
	pos /= pos.w;
	pos.xyz = mat3(gbufferModelViewInverse) * pos.xyz;
	
	return pos.xyz;
}

#include "lib/PBR.glsl"

#include "lib/sky.glsl"
#include "lib/PrecomputeSky.glsl"

#include "lib/Tonemap.glsl"
#include "lib/raytracing/VoxelMarch.glsl"

#include "lib/Volumetrics.fsh"


vec3 CosineSampleHemisphere(vec2 Xi, out float pdf) {
	float r = sqrt(Xi.x);
	float theta = Xi.y * PI * 2.0;

	float x = r * cos(theta);
	float y = r * sin(theta);

	pdf = sqrt(max(1.0 - Xi.x, 0));

	return vec3(x, y, pdf);
}

float DistributionGGX(vec3 N, vec3 H, float a) {
	float a2     = a*a;
	float NdotH  = max(dot(N, H), 0.0);
	float NdotH2 = NdotH*NdotH;
	
	float nom    = a2;
	float denom  = (NdotH2 * (a2 - 1.0) + 1.0);
	denom        = PI * denom * denom;
	
	return nom / denom;
}

float GeometrySchlickGGX(float NdotV, float k) {
	float nom   = NdotV;
	float denom = NdotV * (1.0 - k) + k;
	
	return nom / denom;
}
  
float GeometrySmith(vec3 N, vec3 V, vec3 L, float k) {
	float NdotV = max(dot(N, V), 0.0);
	float NdotL = max(dot(N, L), 0.0);
	float ggx1 = GeometrySchlickGGX(NdotV, k);
	float ggx2 = GeometrySchlickGGX(NdotL, k);
	
	return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float CalculateSpecularComponent() {
	return 0.0;
}

mat3 ArbitraryTBN(vec3 normal) {
	mat3 ret;
	ret[2] = normal;
	ret[0] = normalize(vec3(sqrt(2), sqrt(3), sqrt(5)));
	ret[1] = normalize(cross(ret[0], ret[2]));
	ret[0] = cross(ret[1], ret[2]);
	
	return ret;
}

vec2 fCoord = vec2((ivec2(gl_FragCoord.xy) >> 6) << 6) + 1;

int screnline = (int(gl_FragCoord.x+111) >> 6)*4000 *  (int(gl_FragCoord.y+100) >> 6);
// int hashSeed = screnline;
// int hashSeed = int(pow(fCoord.x + (frameCounter % 8), 1.4) * (fCoord.y + frameCounter / 8));
int hashSeed = int(pow(gl_FragCoord.x, 1.4) * gl_FragCoord.y);
// int hashSeed = int(texture2D(noisetex, texcoord).r*255.0);

float PointLineDistance(vec3 point, vec3 linePoint, vec3 lineDir) {
	vec3 P = point - linePoint;
	return sqrt(dot(P,P)-dot(lineDir,P)*dot(lineDir,P));
}

#define SUNLIGHT_RAYS
//#define SPECULAR_RAYS
#define AMBIENT_RAYS

void ConstructRays(RayQueueStruct curr, VoxelMarchOut VMO, SurfaceStruct surface, vec3 totalColor, int i, bool interior) {
	vec3 inScatter = vec3(0.0), outScatter = vec3(1.0);
	
	VMO.vPos += VMO.plane * exp2(-14);
	
#ifdef AMBIENT_RAYS
	RayQueueStruct ambientray = curr;
	ambientray.rayInfo = PackRayInfo(GetRayDepth(curr.rayInfo) + 1, AMBIENT_RAY_TYPE, GetRayAttr(curr.rayInfo));
	ambientray.vPos = VMO.vPos;
	ambientray.rayDir = ArbitraryTBN(surface.normal) * CalculateConeVector(WangHash(hashSeed * (frameCounter + i*10+1 + 1)), radians(90.0), 32);
	ambientray.priorTransmission *= surface.diffuse.rgb * float(dot(ambientray.rayDir, VMO.plane) > 0.0);
	RayPush(ambientray, totalColor);
#endif
	
#ifdef SPECULAR_RAYS
	RayQueueStruct specular;
	specular.rayInfo = PackRayInfo(GetRayDepth(curr.rayInfo) + 1, SPECULAR_RAY_TYPE, GetRayAttr(curr.rayInfo));
	specular.vPos = VMO.vPos;
	specular.rayDir = reflect(curr.rayDir, surface.normal);
	float cosTheta = dot(specular.rayDir, surface.normal);
	vec3 H = normalize(surface.normal + specular.rayDir);
	float k = pow(surface.roughness + 1, 2) / 1.0;
	float D = DistributionGGX(surface.normal, H, surface.roughness);
	float G = GeometrySmith(surface.normal, -curr.rayDir, specular.rayDir, k);
	vec3 F = fresnelSchlick(cosTheta, vec3(surface.F0));
	specular.priorTransmission = curr.priorTransmission * F;
	RayPush(specular, totalColor);
#endif
	
#ifdef SUNLIGHT_RAYS
	vec3 randSunDir = ArbitraryTBN(sunDir)*CalculateConeVector(WangHash(hashSeed * (frameCounter + 1)), radians(0.54), 32);
	
	RayQueueStruct sunray = curr;
	sunray.rayInfo = PackRayInfo(GetRayDepth(curr.rayInfo) + 1, SUNLIGHT_RAY_TYPE, GetRayAttr(curr.rayInfo));
	sunray.vPos = VMO.vPos;
	sunray.rayDir = randSunDir;
	vec3 myvec;
	float sunlight = OrenNayarDiffuse(sunDir, curr.rayDir, surface.normal, 0.5, 1.0);
	// sunray.priorTransmission *= surface.diffuse.rgb * sunlight;
	sunray.priorTransmission = curr.priorTransmission * surface.diffuse.rgb * sunlight * GetSunAndSkyIrradiance(kPoint(VoxelToWorldSpace(VMO.vPos)), surface.normal, sunDir, myvec);
	RayPush(sunray, totalColor);
#endif
}

// #define USE_RASTER_ENGINE

/* DRAWBUFFERS:03 */
#include "lib/exit.glsl"

void main() {
	float depth = texelFetch(depthtex0, ivec2(tc * viewSize), 0).x;
	
	vec4 prevCol = max(texture(colortex0, texcoord).rgba, 0) * float(accum);
	
	vec3 wPos = GetWorldSpacePosition(tc, depth);
	vec3 wDir = normalize(wPos);
	
	vec3 totalColor = vec3(0.0);
	
#ifdef USE_RASTER_ENGINE
	{
		vec3 randSunDir = ArbitraryTBN(sunDir)*CalculateConeVector(WangHash(hashSeed * (frameCounter + 1)), radians(0.54), 32);
		vec3 inScatter = vec3(0.0), outScatter = vec3(1.0);
		// VOLUMETRICS(vec3(0), wPos, inScatter, outScatter, randSunDir);
	
		vec3 priorTransmission = outScatter;
	
		totalColor += inScatter;
	
		if (depth >= 1.0) {
			vec3 transmit = vec3(1.0);
			vec3 SKYY = ComputeTotalSky(vec3(0.0), wDir, transmit) * skyBrightness;
			totalColor += SKYY;
			gl_FragData[0] = vec4(totalColor, 1.0) + prevCol;
			exit();
			return;
		}
	
		vec4 diffuse, normal, spec;
		UnpackGBuffers(texelFetch(colortex2, ivec2(texcoord*viewSize), 0).xyz, diffuse, normal, spec);
	
		mat3 tbn = DecodeTBNU(texelFetch(colortex2, ivec2(texcoord*viewSize), 0).a);
		tbn[2] = texelFetch(colortex5, ivec2(texcoord*viewSize), 0).rgb;
		
		SurfaceStruct surface;
		surface.diffuse  = diffuse;
		surface.normals  = normal;
		surface.specular = spec;
	
		surface.tbn = tbn;
	
		surface.normal = surface.tbn * normalize(surface.normals.rgb * 2.0 - 1.0);
		
		surface.diffuse.rgb = pow(surface.diffuse.rgb, vec3(2.2));
	
		surface.emissive = surface.specular.a * 255.0 / 254.0 * float(surface.specular.a < 254.0 / 255.0);
	
		if (texelFetch(colortex4, ivec2(texcoord*viewSize), 0).r > 0.5)
			surface.emissive = 1.0;
	
		surface.roughness = 1 - surface.specular.r;
		surface.F0 = surface.specular.g * surface.specular.g;
	
		totalColor += (surface.diffuse.rgb * surface.emissive * priorTransmission * emissiveBrightness);
	
		RayQueueStruct curr;
		curr.vPos = WorldToVoxelSpace(vec3(0.0));
		curr.rayDir = wDir;
		curr.priorTransmission = vec3(1.0);
		curr.rayInfo = PackRayInfo(1, PRIMARY_RAY_TYPE);
	
		VoxelMarchOut VMO;
		VMO.hit = true;
		VMO.plane = tbn[2];
		VMO.vPos = WorldToVoxelSpace(wPos) +0* VMO.plane / 4096.0;
		
		
		ConstructRays(curr, VMO, surface, totalColor, 0, false);
	}
	
	vec4 diffuse, normal, spec;
	UnpackGBuffers(texelFetch(colortex2, ivec2(texcoord*viewSize), 0).xyz, diffuse, normal, spec);
	
	mat3 tbn = DecodeTBNU(texelFetch(colortex2, ivec2(texcoord*viewSize), 0).a);
	gl_FragData[1] = vec4(tbn * normal.xyz, length(wPos.xyz));
#else
	RayQueueStruct primary;
	primary.priorTransmission = vec3(1.0);
	primary.rayInfo = PackRayInfo(1, PRIMARY_RAY_TYPE);
	primary.vPos = WorldToVoxelSpace(vec3(0));
	// if (cameraPosition.y + gbufferModelViewInverse[3].y*1.0 > 256.0 && wDir.y < 0.0) {
	// 	primary.wPos += wDir / wDir.y * -(cameraPosition.y + gbufferModelViewInverse[3].y*1.0 - 255.9);
	// }
	
	primary.rayDir = wDir;
	RayPush(primary, totalColor);
#endif
	
	int i;
	for (i = 1; i < MAX_RAYS; ++i) {
	// for (i = 0; i < (prevCol.a <= 2 ? 2 : MAX_RAYS); ++i) {
		if (IsQueueEmpty()) break;
		
		RayQueueStruct curr = RayPop();
		
		if (HasRayAttr(curr.rayInfo, INTERIOR_RAY_ATTR)) {
			ivec2 vCoord = VoxelToTextureSpace(ivec3(curr.vPos), 0, 0);
			float depth = texelFetch(shadowtex0, vCoord, 0).x;
			
			vec2 spriteSize = exp2(round(texelFetch(shadowcolor0, vCoord, 0).xx * 255.0));
			vec3 plane;
			vec3 vPos = curr.vPos;
			vPos = StepThroughVoxel(vPos, curr.rayDir, plane);
			plane *= sign(-curr.rayDir);
			mat3 tbn = GenerateTBN(plane);
			vec2 coord = (fract(vPos) * 2.0 - 1.0) * mat2x3(tbn) * 0.5 + 0.5;
			vec2 tCoord = GetTexCoord(coord.xy, depth, spriteSize);
			vec4 diffuse = texture2D(TEX_SAMPLER, tCoord, 0);
			
			if (diffuse.a > 0)  { // interior hit
				if (IsRayType(curr.rayInfo, SUNLIGHT_RAY_TYPE)) continue;
				vPos += plane / 4096.0;
				
				VoxelMarchOut VMO;
				VMO.vPos = vPos;
				VMO.plane = plane;
				VMO.vCoord = vCoord;
				VMO.hit = true;
				
				SurfaceStruct surface = ReconstructSurface(curr, VMO);
				
				ConstructRays(curr, VMO, surface, totalColor, i, true);
				continue;
			}
			
			curr.rayInfo &= ~INTERIOR_RAY_ATTR;
		}
		
		VoxelMarchOut VMO = VoxelMarch(curr.vPos, curr.rayDir);
		
		vec3 randSunDir = ArbitraryTBN(sunDir)*CalculateConeVector(WangHash(hashSeed * (frameCounter + 1 + i*7)), radians(0.54), 32);
		
		vec3 inScatter = vec3(0.0), outScatter = vec3(1.0);
		// VOLUMETRICS(curr.wPos, VMO.wPos, inScatter, outScatter, randSunDir);
		
		int ID = int(texelFetch(shadowcolor1, VMO.vCoord, 0).a*255);
		
		if (VMO.hit && (ID==2||ID==3)) {
			int j = 0;
			vec2 spriteSize = exp2(round(texelFetch(shadowcolor0, VMO.vCoord, 0).xx * 255.0));
			float depth = texelFetch(shadowtex0, VMO.vCoord, 0).x;
			mat3 tbn = GenerateTBN(VMO.plane);
			vec2 coord = (fract(VMO.vPos) * 2.0 - 1.0) * mat2x3(tbn) * 0.5 + 0.5;
			vec2 tCoord = GetTexCoord(coord.xy, depth, spriteSize);
			vec4 diffuse = texture2D(TEX_SAMPLER, tCoord, 0);
			
			if (diffuse.a <= 0) { // exterior miss
				// Interior face
				VMO.vPos = StepThroughVoxel(VMO.vPos, curr.rayDir, VMO.plane);
				VMO.plane *= sign(-curr.rayDir);
				tbn = GenerateTBN(VMO.plane);
				coord = (fract(VMO.vPos) * 2.0 - 1.0) * mat2x3(tbn) * 0.5 + 0.5;
				tCoord = GetTexCoord(coord.xy, depth, spriteSize);
				diffuse = texture2D(TEX_SAMPLER, tCoord, 0);
				
				if (diffuse.a > 0)  { // interior hit
					VMO.vPos += VMO.plane / 4096.0;
					SurfaceStruct surface = ReconstructSurface(curr, VMO);
					curr.rayInfo |= INTERIOR_RAY_ATTR;
					
					if (IsRayType(curr.rayInfo, SUNLIGHT_RAY_TYPE)) {
						continue;
					}
					
					if (IsRayType(curr.rayInfo, PRIMARY_RAY_TYPE))
					ConstructRays(curr, VMO, surface, totalColor, i, true);
					
					continue;
				}
				
				curr.vPos = VMO.vPos + VMO.plane / 4096.0 ;
				RayPush(curr, totalColor);
				continue;
			}
		}
		
		if (IsRayType(curr.rayInfo, SUNLIGHT_RAY_TYPE)) {
			vec3 sunlight = float(!VMO.hit) * curr.priorTransmission;
			
			sunlight *= sunBrightness;
			
			totalColor += sunlight;
			continue;
		}
		
		totalColor += inScatter * curr.priorTransmission;
		curr.priorTransmission *= outScatter;
		
		if (IsRayType(curr.rayInfo, AMBIENT_RAY_TYPE))  {
			vec3 P = WorldToVoxelSpace(vec3(0));
			vec3 A = normalize(P - curr.vPos);
			vec3 B = normalize(P - VMO.vPos);
			
			// totalColor += vec3(255, 200, 100) / 255.0 * (heldBlockLightValue + heldBlockLightValue2) / 16.0 * curr.priorTransmission * float(rsi3(curr.vPos,VMO.vPos ) > 0);
		}
		
		if (!VMO.hit) {
			vec3 sky = ComputeTotalSky(VoxelToWorldSpace(VMO.vPos), curr.rayDir, curr.priorTransmission) * skyBrightness;
			
			if (IsRayType(curr.rayInfo, AMBIENT_RAY_TYPE)) sky *= ambientBrightness;
			
			totalColor += sky;
			continue;
		}
		
		SurfaceStruct surface = ReconstructSurface(curr, VMO);
		
		if (IsRayType(curr.rayInfo, AMBIENT_RAY_TYPE))  {
			surface.emissive *= ambientBrightness.r;
		}
		
		totalColor += (surface.diffuse.rgb * surface.emissive * curr.priorTransmission * emissiveBrightness);
		
		ConstructRays(curr, VMO, surface, totalColor, i, false);
	}
	
	totalColor = max(totalColor, vec3(0.0));
	
	gl_FragData[0] = vec4(totalColor, 1.0) + prevCol;
	
	exit();
}

#endif
/***********************************************************************/
