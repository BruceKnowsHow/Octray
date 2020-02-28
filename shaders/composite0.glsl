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


#define BEEEEEEEN0
uniform sampler2D colortex2;
#define BEEEEEEEN1
uniform sampler2D colortex4;
#define BEEEEEEEN2
uniform sampler2D depthtex0;
#define BEEEEEEEN3
uniform sampler2D shadowtex0;
#define BEEEEEEEN4
uniform sampler2D shadowcolor0;
#define BEEEEEEEN5
uniform sampler2D shadowcolor1;
#define BEEEEEEEN6
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

#define GBUFFER0_SAMPLER colortex0
#define GBUFFER1_SAMPLER colortex1

uniform sampler2D GBUFFER0_SAMPLER;
uniform sampler2D GBUFFER1_SAMPLER;

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
#include "block.properties"

ivec2 itexcoord = ivec2(texcoord * viewSize);

#define FRAME_ACCUM 256
float timer = float(frameCounter % FRAME_ACCUM) / FRAME_ACCUM;

// vec3 sunDir = normalize(vec3(sin(timer*PI*0.3) + 0.5, 0.8, cos(timer*PI*0.3)));
vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);

#include "lib/WangHash.glsl"

#define TAA_JITTER

vec2 TAAHash() {
	return (WangHash(uvec2(frameCounter*2, frameCounter*2 + 1)) - 0.5) / viewSize;
}
#ifndef TAA_JITTER
	#define TAAHash() vec2(0.0)
#endif

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

float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a      = roughness*roughness;
    float a2     = a*a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;
	
    float num   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
	
    return num / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float num   = NdotV;
    float denom = NdotV * (1.0 - k) + k;
	
    return num / denom;
}
float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2  = GeometrySchlickGGX(NdotV, roughness);
    float ggx1  = GeometrySchlickGGX(NdotL, roughness);
	
    return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 GGXVNDFSample(vec3 Ve, float alpha, vec2 Xi) {
	// Section 3.2: transforming the view direction to the hemisphere configuration
	vec3 Vh = normalize(vec3(alpha * Ve.x, alpha * Ve.y, Ve.z));

	// Section 4.1: orthonormal basis (with special case if cross product is zero)
	float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
	vec3 T1 = lensq > 0.0 ? vec3(-Vh.y, Vh.x, 0.0) * inversesqrt(lensq) : vec3(1.0, 0.0, 0.0);
	vec3 T2 = cross(Vh, T1);

	// Section 4.2: parameterization of the projected area
	float r = sqrt(Xi.y);
	float phi = Xi.x * PI * 2.0;

	float s = 0.5 * (1.0 + Vh.z);

	float t1 = r * cos(phi);
	float t2 = r * sin(phi);
		  t2 = (1.0 - s) * sqrt(1.0 - t1 * t1) + s * t2;

	// Section 4.3: reprojection onto hemisphere
	vec3 Nh = t1 * T1 + t2 * T2 + sqrt(max(1.0 - t1 * t1 - t2 * t2, 0.0)) * Vh;

	// Section 3.4: transforming the normal back to the ellipsoid configuration
	return normalize(vec3(alpha * Nh.x, alpha * Nh.y, max(Nh.z, 0.0)));
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

// int screnline = (int(gl_FragCoord.x+111) >> 6)*4000 *  (int(gl_FragCoord.y+100) >> 6);
// int hashSeed = int(gl_WarpIDNV);
// int hashSeed = screnline * frameCounter + frameCounter;
// int hashSeed = int(pow(fCoord.x + (frameCounter % 8), 1.4) * (fCoord.y + frameCounter / 8));
int hashSeed = int(pow(gl_FragCoord.x, 1.4) * gl_FragCoord.y);
// int hashSeed = int(texture2D(noisetex, texcoord).r*255.0);

float PointLineDistance(vec3 point, vec3 linePoint, vec3 lineDir) {
	vec3 P = point - linePoint;
	return sqrt(dot(P,P)-dot(lineDir,P)*dot(lineDir,P));
}

#define SUNLIGHT_RAYS On
#define SPECULAR_RAYS Off
#define AMBIENT_RAYS On


float rand(float seed) {
    //seed += 50.0;
    
    float f = fract(sin(seed*3.14159265453)*59407.2751);
    
    f = fract(1.0 / (0.0000001 + 0.00001*f));
    
    return f;
}

vec3 randvec(float seed) {
    return vec3(
        rand(seed),
        rand(seed+12.23432),
        rand(seed+35.73423)
    ) - 0.5;
}

int linenumm = int(gl_FragCoord.x + gl_FragCoord.y*viewSize.x)*3 + frameCounter*3+1;

vec2 Nth_weyl(vec2 p0, int n) {
    
    // return fract(p0 + float(n)*vec2(0.754877669, 0.569840296));
    return fract(p0 + vec2(n*12664745, n*9560333)/exp2(24.));	// integer mul to avoid round-off
}

void ConstructRays(RayStruct curr, VoxelMarchOut VMO, SurfaceStruct surface, vec3 totalColor, int i, int blockID) {
	vec3 inScatter = vec3(0.0), outScatter = vec3(1.0);
	
	bool isMetal = surface.specular.g > 1/229.5;
	float roughness = pow(1.0 - surface.specular.r*0.9, 2.0);
	vec3 F0 = (isMetal) ? surface.diffuse.rgb : vec3(surface.specular.g);
	if (isMetal) surface.diffuse.rgb *= 0;
	
	if (AMBIENT_RAYS) {
		RayStruct ambientray = curr;
		ambientray.rayInfo = PackRayInfo(GetRayDepth(curr.rayInfo) + 1, AMBIENT_RAY_TYPE, GetRayAttr(curr.rayInfo));
		ambientray.vPos = VMO.vPos;
		float g = 1.32471795724474602596;
		float a1 = 1.0/g;
		float a2 = 1.0/(g*g);
		vec2 bene = mod(0.5 + pow(vec2(g), vec2(-1,-2))*gl_FragCoord.xy*vec2(5,7), vec2(1));
		ambientray.rayDir = ArbitraryTBN(surface.normal) * hemisphereSample_cos(Nth_weyl(texcoord * 40.0, (frameCounter+i)*0));
		// ambientray.rayDir = ArbitraryTBN(surface.normal) * hemisphereSample_cos(WangHash(ivec2(gl_FragCoord.xy+gl_FragCoord.xx+frameCounter)));
		vec2 uv1 = texture(noisetex, texcoord * viewSize / 256.0).rg;
		uv1 = mod(uv1 + floor(WangHash(frameCounter)*256)/256.0, vec2(1));
		ambientray.rayDir = ArbitraryTBN(surface.normal) * hemisphereSample_cos(uv1);
		// ambientray.rayDir = ArbitraryTBN(surface.normal) * CalculateConeVector(mod(0.5+linenumm*a1, 1.0), radians(90.0), 32);
		ambientray.priorTransmission *= surface.diffuse.rgb * float(dot(ambientray.rayDir, VMO.plane) > 0.0);
		ambientray.rayDir = ArbitraryTBN(surface.normal) * CalculateConeVector(WangHash(hashSeed * (frameCounter + i*10+1 + 1)), radians(90.0), 32);
		RayPushBack(ambientray, totalColor);
	}
	
	if (SPECULAR_RAYS) {
		RayStruct specular = curr;
		specular.rayInfo = PackRayInfo(GetRayDepth(curr.rayInfo) + 1, SPECULAR_RAY_TYPE, GetRayAttr(curr.rayInfo));
		specular.vPos = VMO.vPos;
		specular.rayDir = reflect(curr.rayDir, surface.normal);
		
		vec2 uv;
		uv.x = WangHash(hashSeed * (frameCounter + i*10+3 + 1));
		uv.y = WangHash(hashSeed * (frameCounter + i*10+4 + 1));
		
		specular.rayDir = ArbitraryTBN(specular.rayDir) * GGXVNDFSample(-curr.rayDir * surface.tbn, roughness*roughness, uv);
		// specular.rayDir = ArbitraryTBN(surface.normal) * CalculateConeVector(WangHash(hashSeed * (frameCounter + i*10+1 + 1)), radians(90.0), 32);
		
		float cosTheta = dot(specular.rayDir, surface.normal);
		vec3 H = normalize(-curr.rayDir + specular.rayDir);
		
		
		float NDF = DistributionGGX(surface.normal, H, roughness);
		
		float G = GeometrySmith(surface.normal, -curr.rayDir, specular.rayDir, roughness);
		
		vec3 F = fresnelSchlick(cosTheta, vec3(F0));
		
		
		// vec3 numerator = NDF * G * F;
		vec3 numerator = G * F;
		float denominator = 4.0 * max(dot(surface.normal, -curr.rayDir), 0.0) * max(dot(surface.normal, specular.rayDir), 0.0);
		vec3 spec = numerator / max(denominator, 0.001);
		
		vec3 kS = F;
		vec3 kD = (1.0 - kS) * float(!isMetal);
		
		float NdotL = max(dot(surface.normal, specular.rayDir), 0.0);
	    vec3 Li = (kD * surface.diffuse.rgb * 4.0  + spec) * NdotL;
		
		// vec3 H = normalize(surface.normal + specular.rayDir);
		// float k = pow(surface.roughness, 2) / 1.0;
		// float D = DistributionGGX(surface.normal, H, surface.roughness);
		// float G = GeometrySmith(surface.normal, -curr.rayDir, specular.rayDir, k);
		// vec3 F = fresnelSchlick(cosTheta, vec3(surface.F0));
		// specular.priorTransmission = curr.priorTransmission * (G) * (1-surface.roughness);
		specular.priorTransmission = curr.priorTransmission * Li;
		RayPushBack(specular, totalColor);
	}
	
	if (SUNLIGHT_RAYS) {
		vec3 randSunDir = ArbitraryTBN(sunDir)*CalculateConeVector(WangHash(hashSeed * (frameCounter + 1)), radians(0.54), 32);
		
		RayStruct sunray = curr;
		sunray.rayInfo = PackRayInfo(GetRayDepth(curr.rayInfo) + 1, SUNLIGHT_RAY_TYPE, GetRayAttr(curr.rayInfo));
		sunray.vPos = VMO.vPos;
		sunray.rayDir = randSunDir;
		vec3 myvec;
		float sunlight = OrenNayarDiffuse(sunDir, curr.rayDir, surface.normal, 0.5, 1.0);
		// sunray.priorTransmission *= surface.diffuse.rgb * sunlight;
		sunray.priorTransmission = curr.priorTransmission * surface.diffuse.rgb * sunlight * sunBrightness * GetSunAndSkyIrradiance(kPoint(VoxelToWorldSpace(VMO.vPos)), surface.normal, sunDir, myvec);
		RayPushBack(sunray, totalColor);
	}
}

#define USE_RASTER_ENGINE

/* DRAWBUFFERS:201 */
uniform bool DRAWBUFFERS_2;
#include "lib/exit.glsl"

vec3 BackProject(vec3 wPos) {
	vec3 ret = ((mat3(gbufferModelView) * wPos) * mat3(gbufferPreviousModelView)) + cameraPosition - previousCameraPosition;
	
	return ret;
}

void main() {
	float depth = texelFetch(depthtex0, ivec2(tc * viewSize), 0).x;
	
	vec4 prevCol = max(texture(colortex2, texcoord).rgba, 0) * float(accum);
	
	vec3 wPos = GetWorldSpacePosition(tc, depth);
	vec3 wDir = normalize(wPos);
	
	vec3 totalColor = vec3(0.0);
	
	float accumulate = float(distance((wPos), texture2D(colortex4, texcoord).rgb) < 0.01);
	
	prevCol *= float(accum);
	// prevCol *= accumulate;
	
#ifdef USE_RASTER_ENGINE
	for (int i = 0; i < 1; ++i) {
		if (depth >= 1.0) {
			vec3 transmit = vec3(1.0);
			vec3 SKYY = ComputeTotalSky(vec3(0.0), wDir, transmit, true) * skyBrightness;
			totalColor += SKYY;
			gl_FragData[0] = vec4(totalColor, 1.0) + prevCol;
			exit();
			return;
		}
	
		vec4 diffuse, normal, spec;
		UnpackGBuffers(texelFetch(GBUFFER0_SAMPLER, ivec2(tc*viewSize), 0).xyz, diffuse, normal, spec);
	
		mat3 tbn = DecodeTBNU(texelFetch(GBUFFER0_SAMPLER, ivec2(tc*viewSize), 0).a);
		
		int blockID = int(texelFetch(GBUFFER1_SAMPLER, ivec2(tc*viewSize), 0).r * 255.0);
		
		SurfaceStruct surface;
		surface.diffuse  = diffuse;
		surface.normals  = normal;
		surface.specular = spec;
		
		surface.tbn = tbn;
		
		surface.normal = surface.tbn * normalize(surface.normals.rgb * 2.0 - 1.0);
		
		if (isWater(blockID)) {
			surface.normal = surface.tbn * ComputeWaveNormals(wPos, wDir, surface.tbn[2]);
		}
		
		surface.diffuse.rgb = pow(surface.diffuse.rgb, vec3(2.2));
	
		surface.emissive = surface.specular.a * 255.0 / 254.0 * float(surface.specular.a < 254.0 / 255.0);
		
		if (isEmissive(blockID))
			surface.emissive = 1.0;
			
		totalColor += (surface.diffuse.rgb * surface.emissive * emissiveBrightness);
		
		RayStruct curr;
		curr.vPos = WorldToVoxelSpace(vec3(0.0));
		curr.rayDir = wDir;
		curr.priorTransmission = vec3(1.0);
		curr.rayInfo = PackRayInfo(0, PRIMARY_RAY_TYPE);
		curr.prevVolume = 1.0;
	
		VoxelMarchOut VMO;
		VMO.plane = tbn[2];
		VMO.vPos = WorldToVoxelSpace(wPos) + VMO.plane / 4096.0*0;
		
		if (isLeavesType(blockID) || isGlassType(blockID)) {
			float depth = texelFetch(shadowtex0, VoxelToTextureSpace(uvec3(VMO.vPos - VMO.plane / 2.0), 0, 0), 0).x;
			
			if (diffuse.a < 1) { // exterior miss
				RayStruct through = curr;
				through.vPos = VMO.vPos - VMO.plane / 4096.0;
				
				if (isGlassType(blockID)) {
					through.prevVolume = depth;
					through.transmission = (1 - diffuse.a) * mix(vec3(1.0), diffuse.rgb, diffuse.a > 0);
					through.priorTransmission *= (1 - diffuse.a);
					curr.priorTransmission *= (1 - diffuse.a);
				} else {
					through.priorTransmission *= (1 - diffuse.a) * mix(vec3(1.0), diffuse.rgb, diffuse.a > 0);
					curr.priorTransmission *= (1 - diffuse.a) * mix(vec3(1.0), diffuse.rgb, diffuse.a > 0);
				}
				
				RayPushBack(through, totalColor);
				continue;
				if (diffuse.a <= 0) continue;
			}
		}
		
		totalColor += surface.diffuse.rgb * vec3(255, 200, 100) / 255.0 * 1.0 * (heldBlockLightValue + heldBlockLightValue2) / 16.0 / (dot(wPos,wPos) + 0.5) * dot(surface.normal, -curr.rayDir);
		VMO.vPos += VMO.plane * exp2(-14);
		
		ConstructRays(curr, VMO, surface, totalColor, 0, blockID);
		
		gl_FragData[1].rgb = surface.normal;
		gl_FragData[2].rgb = wPos;
	}
	
#else
	RayStruct primary;
	primary.priorTransmission = vec3(1.0);
	primary.rayInfo = PackRayInfo(0, PRIMARY_RAY_TYPE);
	primary.vPos = WorldToVoxelSpace(vec3(0));
	if (cameraPosition.y + gbufferModelViewInverse[3].y*1.0 > 256.0 && wDir.y < 0.0) {
		primary.vPos += wDir / wDir.y * -(cameraPosition.y + gbufferModelViewInverse[3].y*1.0 - 255.9);
	}
	
	primary.rayDir = wDir;
	primary.prevVolume = 1.0;
	RayPushBack(primary, totalColor);
#endif
	
	int i;
	for (i = 1; i < MAX_RAYS; ++i) {
		if (IsQueueEmpty()) break;
		
		RayStruct curr = RayPopBack();
		
		VoxelMarchOut VMO = VoxelMarch(curr.vPos, curr.rayDir, curr.prevVolume);
		
		if (!VMO.hit) {
			totalColor += curr.priorTransmission * float(IsRayType(curr.rayInfo, SUNLIGHT_RAY_TYPE));
			if (IsRayType(curr.rayInfo, SUNLIGHT_RAY_TYPE)) continue;
			vec3 sky = ComputeTotalSky(VoxelToWorldSpace(VMO.vPos), curr.rayDir, curr.priorTransmission, IsRayType(curr.rayInfo, PRIMARY_RAY_TYPE));
			if (IsRayType(curr.rayInfo, AMBIENT_RAY_TYPE)) sky *= ambientBrightness;
			totalColor += sky * skyBrightness;
			continue;
		}
		
		if (curr.prevVolume < 1.0) {
			curr.prevVolume = 1.0;
			float d = distance(curr.vPos, VMO.vPos);
			
			curr.priorTransmission /= exp(d / exp(1.5) / curr.transmission);
			curr.vPos = VMO.vPos + VMO.plane / 4096.0;
			RayPushBack(curr, totalColor);
			continue;
		}
		
		int blockID = int(texelFetch(shadowcolor0, VMO.vCoord, 0).g*255);
		
		if (isLeavesType(blockID) || isGlassType(blockID)) {
			vec2 spriteSize = exp2(round(texelFetch(shadowcolor0, VMO.vCoord, 0).xx * 255.0));
			float depth = texelFetch(shadowtex0, VMO.vCoord, 0).x;
			mat3 tbn = GenerateTBN(VMO.plane);
			vec2 coord = (fract(VMO.vPos) * 2.0 - 1.0) * mat2x3(tbn) * 0.5 + 0.5;
			vec2 tCoord = GetTexCoord(coord.xy, depth, spriteSize);
			vec4 diffuse = textureLod(TEX_SAMPLER, tCoord, 0);
			
			if (diffuse.a < 1) { // exterior miss
				RayStruct through = curr;
				through.vPos = VMO.vPos - VMO.plane / 4096.0 ;
				
				if (isGlassType(blockID)) {
					through.prevVolume = depth;
					through.transmission = (1 - diffuse.a) * mix(vec3(1.0), diffuse.rgb, diffuse.a > 0);
					through.priorTransmission *= (1 - diffuse.a);
					curr.priorTransmission *= (1 - diffuse.a);
				} else {
					through.priorTransmission *= (1 - diffuse.a) * mix(vec3(1.0), diffuse.rgb, diffuse.a > 0);
					curr.priorTransmission *= (1 - diffuse.a) * mix(vec3(1.0), diffuse.rgb, diffuse.a > 0);
				}
				
				RayPushBack(through, totalColor);
				continue;
				if (diffuse.a <= 0) continue;
			}
		}
		
		if (IsRayType(curr.rayInfo, SUNLIGHT_RAY_TYPE)) continue;
		
		SurfaceStruct surface = ReconstructSurface(curr, VMO, blockID);
		
		if (IsRayType(curr.rayInfo, AMBIENT_RAY_TYPE))  {
			surface.emissive *= ambientBrightness.r;
		}
		
		if (IsRayType(curr.rayInfo, PRIMARY_RAY_TYPE))  {
			vec3 p = VoxelToWorldSpace(VMO.vPos);
			
			totalColor += surface.diffuse.rgb * vec3(255, 200, 100) / 255.0 * 1.0 * (heldBlockLightValue + heldBlockLightValue2) / 16.0 * curr.priorTransmission / (dot(p,p) + 0.5) * dot(surface.normal, -curr.rayDir);
		}
		
		totalColor += (surface.diffuse.rgb * surface.emissive * curr.priorTransmission * emissiveBrightness);
		VMO.vPos -= VMO.plane * exp2(-14);
		ConstructRays(curr, VMO, surface, totalColor, i, blockID);
	}
	
	totalColor = max(totalColor, vec3(0.0));
	
	gl_FragData[0] = vec4(totalColor, 1.0) + prevCol;
	
	exit();
}

#endif
/***********************************************************************/
