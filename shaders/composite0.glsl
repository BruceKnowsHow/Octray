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
uniform sampler2D shadowcolor0;
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
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferPreviousProjection;

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;

uniform ivec2 atlasSize;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform int heldBlockLightValue;

vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);

uniform vec2 viewSize;

uniform float frameTimeCounter;
uniform int frameCounter;

uniform int isEyeInWater;

noperspective in vec2 texcoord;
ivec2 itexcoord = ivec2(texcoord * viewSize);

uint WangHash(uint seed) {
	seed = (seed ^ 61) ^ (seed >> 16);
	seed *= 9;
	seed = seed ^ (seed >> 4);
	seed *= 0x27d4eb2d;
	seed = seed ^ (seed >> 15);
	return seed;
}

uvec2 WangHash(uvec2 seed) {
	seed = (seed ^ 61) ^ (seed >> 16);
	seed *= 9;
	seed = seed ^ (seed >> 4);
	seed *= 0x27d4eb2d;
	seed = seed ^ (seed >> 15);
	return seed;
}

vec2 tc = texcoord + vec2(WangHash(uvec2(gl_FragCoord.xy) * (frameCounter + 1))) / 4294967296.0 / viewSize;
vec2 dith = vec2(WangHash(uvec2(gl_FragCoord.xy) * (frameCounter + 1))) / 4294967296.0;

vec3 GetWorldSpacePosition(vec2 coord, float depth) {
	vec4 pos = vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	pos = gbufferProjectionInverse * pos;
	pos /= pos.w;
	pos.xyz = mat3(gbufferModelViewInverse) * pos.xyz;
	
	return pos.xyz;
}

#include "/../shaders/lib/Tonemap.glsl"
#include "/../shaders/lib/raytracing/VoxelMarch.glsl"

#include "/../shaders/lib/sky.glsl"
#include "/../shaders/lib/WaterFog.glsl"
#include "/../shaders/lib/Tonemap.glsl"
#include "/../shaders/lib/sky.glsl"
#include "/../shaders/lib/PrecomputeSky.glsl"
#include "/../shaders/lib/WaterFog.glsl"

struct SurfaceStruct {
	mat3 tbn;
	vec4 diffuse;
	vec3 normal;
	vec4 normals;
	vec4 specular;
	float emissive;
};

vec2 GetTexCoord(vec2 coord, float lookup, vec3 vPos) {
	coord = coord * 0.5 + 0.5;
	
//	coord = clamp(coord, 2.0 / atlasSize*16.0, 1.0 - 2.0/atlasSize*16.0);
	
	vec2 T = Lookup(shadowcolor0, vPos, 0).xy;
	vec2 spriteSize = (exp2(round(T * 255.0))) / atlasSize;
	
	vec2 cornerTexCoord = unpackTexcoord(lookup); // Coordinate of texture's starting corner in [0, 1] texture space
	vec2 coordInSprite = coord.xy * spriteSize; // Fragment's position within sprite space
	vec2 tCoord = cornerTexCoord + coordInSprite;
	
	return tCoord;
}

mat3 GenerateTBN(vec3 normal) {
	mat3 tbn;
	tbn[2] = normal;
	     if (tbn[2].x >  0.5) tbn[0] = vec3( 0, 0,-1);
	else if (tbn[2].x < -0.5) tbn[0] = vec3( 0, 0, 1);
	else if (tbn[2].y >  0.5) tbn[0] = vec3( 1, 0, 0);
	else if (tbn[2].y < -0.5) tbn[0] = vec3( 1, 0, 0);
	else if (tbn[2].z >  0.5) tbn[0] = vec3( 1, 0, 0);
	else if (tbn[2].z < -0.5) tbn[0] = vec3(-1, 0, 0);
	tbn[1] = normalize(cross(tbn[0], tbn[2]));
	
	return tbn;
}

#define TERRAIN_PARALLAX
#define TERRAIN_PARALLAX_QUALITY 1.0
#define TEXTURE_PACK_RESOLUTION 16
#define TERRAIN_PARALLAX_INTENSITY 1.0
#define TERRAIN_PARALLAX_DISTANCE 16.0

vec2 ComputeParallaxCoordinate(vec2 coord, vec3 position, mat3 tbn, sampler2D heightmap) {
#if !defined TERRAIN_PARALLAX
// #if !defined TERRAIN_PARALLAX || !defined gbuffers_terrain
	return coord;
#endif
	
//	LOD = textureQueryLod(tex, coord).x;
//	atlasSize
	const float parallaxDist = TERRAIN_PARALLAX_DISTANCE;
	const float distFade     = parallaxDist / 3.0;
	const float MinQuality   = 0.5;
	const float maxQuality   = 1.5;
	
	float intensity = clamp((parallaxDist - length(position) * 90.0 / 90.0) / distFade, 0.0, 1.0) * 0.85 * TERRAIN_PARALLAX_INTENSITY;
	intensity = TERRAIN_PARALLAX_INTENSITY;
	// float intensity = clamp((parallaxDist - length(position) * FOV / 90.0) / distFade) * 0.85 * TERRAIN_PARALLAX_INTENSITY;
	
	if (intensity < 0.01) { return coord; }
	
//	float quality = clamp(radians(180.0 - FOV) / max1(pow(length(position), 0.25)), MinQuality, maxQuality, 0.0, 1.0) * TERRAIN_PARALLAX_QUALITY;
//	float quality = clamp(radians(180.0 - 90.0) / max(pow(length(position), 0.25), 1.0), MinQuality, maxQuality) * TERRAIN_PARALLAX_QUALITY;
	float quality = TERRAIN_PARALLAX_QUALITY;
	
	vec3 tangentRay = normalize(position) * tbn;

	vec2 textureRes = vec2(TEXTURE_PACK_RESOLUTION);
	
	if (atlasSize.x != atlasSize.y) {
		tangentRay.x *= 0.5;
		textureRes.y *= 2.0;
	}
	
	vec4 tileScale   = vec4(atlasSize.x / textureRes, textureRes / atlasSize.x);
	vec2 tileCoord   = fract(coord * tileScale.xy);
	vec2 atlasCorner = floor(coord * tileScale.xy) * tileScale.zw;
	
	float stepCoeff = -tangentRay.z * 100.0 * clamp(intensity, 0.0, 1.0);
	
	vec3 step    = tangentRay * vec3(0.01, 0.01, 1.0 / intensity) / quality * 0.03;
	// vec3 step    = tangentRay * vec3(0.01, 0.01, 1.0 / intensity) / quality * 0.03 * sqrt(length(position));
	     step.z *= stepCoeff;
	
	vec3  sampleRay    = vec3(0.0, 0.0, stepCoeff);
	float sampleHeight = textureLod(heightmap, coord, 0).a * stepCoeff;
	
	if (sampleRay.z <= sampleHeight) return coord;
	
	for (uint i = 0; sampleRay.z > sampleHeight && i < 150; i++) {
		sampleRay.xy += step.xy * clamp(sampleRay.z - sampleHeight, 0.0, 1.0);
		sampleRay.z += step.z;
		
		sampleHeight = texture(heightmap, fract(sampleRay.xy * tileScale.xy + tileCoord) * tileScale.zw + atlasCorner, 0).a * stepCoeff;
	}
	
	return fract(sampleRay.xy * tileScale.xy + tileCoord) * tileScale.zw + atlasCorner;
}


SurfaceStruct ReconstructSurface(VoxelMarchOut VMO, VoxelMarchIn VMI) {
	SurfaceStruct surface;
	surface.tbn = GenerateTBN(VMO.plane);
	
	vec2 coord = (fract(VMO.vPos) * 2.0 - 1.0) * mat2x3(surface.tbn);
	vec2 tCoord = GetTexCoord(coord.xy, VMO.data, VMO.vPos);
	
	vec2 parCoord = ComputeParallaxCoordinate(tCoord, VMI.rayDir, surface.tbn, colortex6);
	
	surface.diffuse  = texture(colortex5, parCoord, 0);
	surface.normals  = texture(colortex6, parCoord, 0);
	surface.specular = texture(colortex7, parCoord, 0);
	
	// surface.diffuse  = textureLod(colortex5, tCoord, 0);
	// surface.normals  = textureLod(colortex6, tCoord, 0);
	// surface.specular = textureLod(colortex7, tCoord, 0);
	
	surface.diffuse.rgb *= unpackVertColor(Lookup(VMO.vPos, 1));
	surface.diffuse.rgb = pow(surface.diffuse.rgb, vec3(2.2));
	
	surface.normal = surface.tbn * normalize(surface.normals.rgb * 2.0 - 1.0);
//	surface.normal = surface.tbn * vec3(surface.normals.xy, sqrt(max(1.0 - dot(surface.normals.xy, surface.normals.xy), 0.0)));
	
	surface.emissive = surface.specular.a * 255.0 / 254.0 * float(surface.specular.a < 254.0 / 255.0);
	
	return surface;
}

vec3 CalculateConeVector(const float i, const float angularRadius, const int steps) {
	float x = i * 2.0 - 1.0;
	float y = i * float(steps) * 1.618 * 256.0;
	
	float angle = acos(x) * angularRadius / PI;
	float s = sin(angle);

	return vec3(cos(y) * s, sin(y) * s, cos(angle));
}

vec3 CosineSampleHemisphere(vec2 Xi) {
	float r = sqrt(Xi.x);
	float theta = PI * 2.0 * Xi.y;

	float x = r * cos(theta);
	float y = r * sin(theta);

	return vec3(x, y, sqrt(max(0.0, 1.0 - Xi.x)));
}

vec3 hemisphereSample_cos(vec2 uv) {
    float phi = uv.y * 2.0 * PI;
    float cosTheta = sqrt(1.0 - uv.x);
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

vec2 rsi2(vec3 r0, vec3 rd, float sr) {
    // ray-sphere intersection that assumes
    // the sphere is centered at the origin.
    // No intersection when result.x > result.y
    float a = dot(rd, rd);
    float b = 2.0 * dot(rd, r0);
    float c = dot(r0, r0) - (sr * sr);
    float d = (b*b) - 4.0*a*c;
    if (d < 0.0) return vec2(1e5,-1e5);
    return vec2(
        (-b - sqrt(d))/(2.0*a),
        (-b + sqrt(d))/(2.0*a)
    );
}

float rsi3(vec3 a, vec3 b) {
	const vec3 worldPoint = vec3(0.0, 70.0 + (sin(frameTimeCounter) + 1.0) * 50.0*0, 0.0);
	
	vec2 points = rsi2(a + cameraPosition - worldPoint, normalize(b - a), 1.0);
	if (points.x > points.y) return 0;
	float od = max(0.0, points.y - max(0.0, points.x));
	if (points.x < 0.0 && distance(a,b) < points.y) return distance(a,b);
	if (points.x < 0.0) return od;
	if (distance(a,b) > length(points.y)) return od;
	if (points.x < distance(a,b) && distance(a,b) < points.y) return distance(a,b) - points.x;
	if (distance(a,b) < length(points.x)) return 0;
	
	return od;
}

float OrenNayarDiffuse(vec3 lightDirection, vec3 viewDirection, vec3 surfaceNormal, float roughness, float albedo) {
	float LdotV = dot(lightDirection, viewDirection);
	float NdotL = dot(lightDirection, surfaceNormal);
	float NdotV = dot(surfaceNormal, viewDirection);

	float s = LdotV - NdotL * NdotV;
	float t = mix(1.0, max(NdotL, NdotV), step(0.0, s));

	float sigma2 = roughness * roughness;
	float A = 1.0 + sigma2 * (albedo / (sigma2 + 0.13) + 0.5 / (sigma2 + 0.33));
	float B = 0.45 * sigma2 / (sigma2 + 0.09);

	return albedo * max(0.0, NdotL) * (A + B * s / t) / PI;
}

/* DRAWBUFFERS:0 */
#include "/../shaders/lib/exit.glsl"

void main() {
	float depth = texelFetch(depthtex0, ivec2(tc * viewSize), 0).x;
	vec3 wPos = GetWorldSpacePosition(tc, depth);
	vec3 wDir = normalize(wPos);
	
	uint tbnIndex = uint(texelFetch(colortex1, ivec2(tc * viewSize), 0).z);
	
	bool accum = true;
	accum = accum && all(equal(cameraPosition, previousCameraPosition));
	accum = accum && all(equal(gbufferPreviousModelView[0], gbufferModelView[0]));
	accum = accum && all(equal(gbufferPreviousModelView[3], gbufferModelView[3]));
	accum = accum && all(equal(gbufferProjection[0], gbufferPreviousProjection[0]));
	
	vec4 prevCol = max(texture(colortex0, texcoord).rgba, 0) * float(accum);
	
	vec3 totalColor = vec3(0.0);
	
	RayQueueStruct primary;
	primary.priorTransmission = vec3(1.0);
	primary.rayType = PRIMARY_RAY_TYPE;
	primary.VMI.wPos = (wPos - wDir* 2.0 * float(length(wPos) > 1.0))*0;
	if (cameraPosition.y + gbufferModelViewInverse[3].y*1.0 > 256.0 && wDir.y < 0.0) {
	//	primary.VMI.wPos += wDir / wDir.y * -(cameraPosition.y + gbufferModelViewInverse[3].y*1.0 - 256.1);
	}
	
	primary.VMI.rayDir = wDir;
	primary.VMI.LOD = 0;
	RayQueuePushBack(primary, totalColor);
	
	int i;
	for (i = 0; i < MAX_RAYMARCH_BOUNCES; ++i) {
		if (IsQueueEmpty()) break;
		
		RayQueueStruct curr = RayQueuePopFront();
		VoxelMarchOut VMO = VoxelMarch(curr.VMI);
		
		float od = rsi3(curr.VMI.wPos, VMO.wPos);
		vec3 out_scatter = vec3(exp(-od / 0.10));
		vec3 in_scatter = 1.0 - out_scatter;
		
		if (curr.rayType == SUNLIGHT_RAY_TYPE) {
			totalColor += float(!VMO.hit) * out_scatter * sunBrightness * curr.priorTransmission;
			continue;
		}
		
		totalColor += in_scatter * curr.priorTransmission * emissiveSphereBrightness;
		curr.priorTransmission *= out_scatter;
		
		if (!VMO.hit) {
			vec3 SKYY = vec3(1.5, 1.8, 2.0)*0+vec3(1,0,0)*0+skyBrightness;
			
			SKYY = ComputeTotalSky(VMO.wPos, curr.VMI.rayDir, curr.priorTransmission) * skyBrightness;
			if (curr.rayType == PRIMARY_RAY_TYPE) SKYY *= 0.1;
			totalColor += SKYY;
			continue;
		}
		
		if (curr.rayType == PRIMARY_RAY_TYPE) {
			out_scatter = curr.priorTransmission;
			in_scatter = SkyAtmosphereToPoint(curr.VMI.wPos, VMO.wPos, out_scatter);
			if (curr.rayType == PRIMARY_RAY_TYPE) in_scatter *= 0.4;
			totalColor += in_scatter * curr.priorTransmission * skyBrightness;
			curr.priorTransmission = out_scatter;
		}
		
		SurfaceStruct surface = ReconstructSurface(VMO, curr.VMI);
		
		// vec3 P = VMO.vPos;
		// vec3 outplane;
		// show(VoxelToWorldSpace(StepThroughVoxel(VMO.vPos, curr.VMI.rayDir, outplane))/10.0)
		
		RayQueueStruct sunray;
		float sunlight = clamp(dot(surface.normal, sunDir), 0.0, 1.0);
		sunray.rayType = SUNLIGHT_RAY_TYPE;
		sunray.VMI.wPos = VMO.wPos + VMO.plane / 4096.0;
		sunray.VMI.rayDir = sunDir;
		sunray.VMI.LOD = 0;
		sunlight = OrenNayarDiffuse(sunDir, curr.VMI.rayDir, surface.normal, 0.5, 1.0);
		sunray.priorTransmission = curr.priorTransmission * surface.diffuse.rgb * sunlight * sunBrightness;
		RayQueuePushBack(sunray, totalColor);
		
		int hashOffset = int(pow(gl_FragCoord.x, 1.4) * gl_FragCoord.y) * (frameCounter + 1 + i);
		vec2 uv = vec2(vec2(WangHash(hashOffset), WangHash(hashOffset * 2)) / 4294967296.0);
	//	uv.x = texture(noisetex, texcoord * viewSize / textureSize(noisetex, 0) + uv.x).x;
		// show(texture(noisetex, tc * viewSize / textureSize(noisetex, 0)   ).x)
	//	uv.x = texture(noisetex, texcoord * viewSize / textureSize(noisetex, 0)   ).x;
		
		vec3 irrationals = vec3(sqrt(1.0 / 5.0), sqrt(2.0), 1.61803398) * 1.0;
	//	uv.x = mod(uv.x + irrationals.x * mod(frameCounter*(i*3.15+1), 1024.0f), 1.0);
		// show(uv.x)
		vec3 norm = CalculateConeVector(uv.x, radians(90.0), 32);
		
		RayQueueStruct ambientray;
		ambientray.priorTransmission = curr.priorTransmission * (surface.diffuse.rgb);
		ambientray.rayType = AMBIENT_RAY_TYPE;
		ambientray.VMI.wPos = VMO.wPos + surface.tbn[2] / 4096.0;
		ambientray.VMI.rayDir = surface.tbn * norm;
	//	ambientray.priorTransmission *= clamp(dot(ambientray.VMI.rayDir, surface.normal), 0.0, 1.0);
		ambientray.priorTransmission *= OrenNayarDiffuse(ambientray.VMI.rayDir, curr.VMI.rayDir, surface.normal, 1.0, 1.0);
		ambientray.VMI.LOD = 0;
		RayQueuePushBack(ambientray, totalColor);
		
	//	totalColor += (surface.diffuse.rgb * curr.priorTransmission);
		totalColor += (surface.diffuse.rgb * surface.emissive * curr.priorTransmission * emissiveBrightness);
	//	totalColor += surface.diffuse.rgb * (1 / pow(distance(VMO.wPos, vec3(0,1.6,0)) , 2.0))*1000.0 * heldBlockLightValue * vec3(1.0, 0.5, 0.0) * curr.priorTransmission;
		
		RayQueueStruct specular;
		specular.priorTransmission = curr.priorTransmission * surface.diffuse.rgb * surface.specular.g * specularBrightess;
		specular.rayType = SPECULAR_RAY_TYPE;
		specular.VMI.wPos = VMO.wPos + surface.tbn[2] / 4096.0;
		specular.VMI.rayDir = reflect(curr.VMI.rayDir, surface.normal);
		specular.VMI.LOD = 0;
		RayQueuePushBack(specular, totalColor);
	}
	
	gl_FragData[0] = max(vec4(totalColor, 1.0) + prevCol, 0.0);
	
	exit();
}

#endif
/***********************************************************************/
