#if !defined SKY_GLSL
#define SKY_GLSL

#define CLOUDS_2D
#define CLOUD_HEIGHT_2D   512  // [384 512 640 768]
#define CLOUD_COVERAGE_2D 0.5  // [0.3 0.4 0.5 0.6 0.7]
#define CLOUD_SPEED_2D    1.00 // [0.25 0.50 1.00 2.00 4.00]

#if (!defined gbuffers_water)
const float noiseResInverse = 1.0 / noiseTextureResolution;
#endif


#include "PrecomputeSky.glsl"

float csmooth(float x) {
	return x * x * (3.0 - 2.0 * x);
}

vec2 csmooth2(vec2 x) {
	return x * x * (3.0 - 2.0 * x);
}

float GetNoise(vec2 coord) {
	const vec2 madd = vec2(0.5 * noiseResInverse);
	vec2 whole = floor(coord);
	coord = whole + csmooth2(coord - whole);
	
	return texture2D(noisetex, coord * noiseResInverse + madd).x;
}

vec2 GetNoise2D(vec2 coord) {
	const vec2 madd = vec2(0.5 * noiseResInverse);
	vec2 whole = floor(coord);
	coord = whole + csmooth2(coord - whole);
	
	return texture2D(noisetex, coord * noiseResInverse + madd).xy;
}

float GetCoverage(float clouds, float coverage) {
	return csmooth(clamp((coverage + clouds - 1.0) * 1.1 - 0.0, 0.0, 1.0));
}

float CloudFBM(vec2 coord, out mat4x2 c, vec3 weights, float weight) {
	float time = CLOUD_SPEED_2D * frameTimeCounter * 0.01;
	
	c[0]    = coord * 0.007;
	c[0]   += GetNoise2D(c[0]) * 0.3 - 0.15;
	c[0].x  = c[0].x * 0.25 + time;
	
	float cloud = -GetNoise(c[0]);
	
	c[1]    = c[0] * 2.0 - cloud * vec2(0.5, 1.35);
	c[1].x += time;
	
	cloud += GetNoise(c[1]) * weights.x;
	
	c[2]  = c[1] * vec2(9.0, 1.65) + time * vec2(3.0, 0.55) - cloud * vec2(1.5, 0.75);
	
	cloud += GetNoise(c[2]) * weights.y;
	
	c[3]   = c[2] * 3.0 + time;
	
	cloud += GetNoise(c[3]) * weights.z;
	
	cloud  = weight - cloud;
	
	cloud += GetNoise(c[3] * 3.0 + time) * 0.022;
	cloud += GetNoise(c[3] * 9.0 + time * 3.0) * 0.014;
	
	return cloud * 0.63;
}

vec3 sunlightColor = vec3(1.0, 1.0, 1.0);
vec3 skylightColor = vec3(0.6, 0.8, 1.0);

vec3 Compute2DCloudPlane(vec3 wPos, vec3 wDir, inout vec3 transmit, float sunglow) {
	const float cloudHeight = CLOUD_HEIGHT_2D;
	
	wPos += cameraPosition;
	
//	visibility = pow(visibility, 10.0) * abs(wDir.y);
	
	if (wDir.y <= 0.0 != wPos.y >= cloudHeight) return vec3(0.0);
	
	
	vec3 oldTransmit = transmit;
	
	const float coverage = CLOUD_COVERAGE_2D * 1.12;
	const vec3  weights  = vec3(0.5, 0.135, 0.075);
	const float weight   = weights.x + weights.y + weights.z;
	
	vec2 coord = wDir.xz * ((cloudHeight - wPos.y) / wDir.y) + wPos.xz;
	
	mat4x2 coords;
	
	float cloudAlpha = CloudFBM(coord, coords, weights, weight);
	cloudAlpha = GetCoverage(cloudAlpha, coverage) * abs(wDir.y) * 4.0;
	
	vec2 lightOffset = sunDir.xz * 0.2;
	
	float sunlight;
	sunlight  = -GetNoise(coords[0] + lightOffset)            ;
	sunlight +=  GetNoise(coords[1] + lightOffset) * weights.x;
	sunlight +=  GetNoise(coords[2] + lightOffset) * weights.y;
	sunlight +=  GetNoise(coords[3] + lightOffset) * weights.z;
	sunlight  = GetCoverage(weight - sunlight, coverage);
	sunlight  = pow(1.3 - sunlight, 5.5);
//	sunlight *= mix(pow(cloudAlpha, 1.6) * 2.5, 2.0, sunglow);
//	sunlight *= mix(10.0, 1.0, sqrt(sunglow));
	
	vec3 directColor  = sunlightColor * 2.5;
//	     directColor *= 1.0 + pow(sunglow, 10.0) * 10.0 / (sunlight * 0.8 + 0.2);
//	     directColor *= mix(vec3(1.0), vec3(0.4, 0.5, 0.6), timeNight);
	
	vec3 ambientColor = mix(skylightColor, directColor, 0.15) * 0.1;
	
	vec3 trans;
	directColor = 0.5*PrecomputedSky(vec3(0, 1+ATMOSPHERE.bottom_radius,0), sunDir, 0.0, sunDir, trans);
	
	ambientColor = 0.2*PrecomputedSky(vec3(0, 1+ATMOSPHERE.bottom_radius,0), vec3(0,1,0), 0.0, sunDir, trans);
	
	vec3 cloud = mix(ambientColor, directColor, sunlight) * 2.0;
	
	transmit *= clamp(1.0 - cloudAlpha, 0.0, 1.0);
	
	return cloud * cloudAlpha * oldTransmit * 5.0;
}
#ifndef CLOUDS_2D
	#define Compute2DCloudPlane(wPos, wDir, transmit, sunglow) vec3(0.0)
#endif

#define STARS true // [true false]
#define REFLECT_STARS false // [true false]
#define ROTATE_STARS false // [true false]
#define STAR_SCALE 1.0 // [0.5 1.0 2.0 4.0]
#define STAR_BRIGHTNESS 1.00 // [0.25 0.50 1.00 2.00 4.00]
#define STAR_COVERAGE 1.000 // [0.950 0.975 1.000 1.025 1.050]

void CalculateStars(inout vec3 color, vec3 worldDir, float visibility, const bool isReflection) {
	if (!STARS) return;
	if (!REFLECT_STARS && isReflection) return;
	
//	float alpha = STAR_BRIGHTNESS * 2000.0 * pow(clamp(worldDir.y, 0.0, 1.0), 2.0) * timeNight * pow(visibility, 50.0);
	float alpha = STAR_BRIGHTNESS * 2000.0 * pow(clamp(worldDir.y, 0.0, 1.0), 2.0) * pow(visibility, 50.0);
	if (alpha <= 0.0) return;
	
	vec2 coord;
	
//	if (ROTATE_STARS) {
//		vec3 shadowCoord     = mat3(shadowViewMatrix) * worldDir;
//		     shadowCoord.xz *= sign(sunVector.y);
//
//		coord  = vec2(atan(shadowCoord.x, shadowCoord.z), acos(shadowCoord.y));
//		coord *= 3.0 * STAR_SCALE * noiseScale;
//	} else
//		coord = worldDir.xz * (2.5 * STAR_SCALE * (2.0 - worldDir.y) * noiseScale);
		coord = worldDir.xz * (2.5 * STAR_SCALE * (2.0 - worldDir.y));
	
	float noise  = texture2D(noisetex, coord * 0.5).r;
	      noise += texture2D(noisetex, coord).r * 0.5;
	
	float star = clamp(noise - 1.3 / STAR_COVERAGE, 0.0, 1.0);
	
	color += star * alpha;
}


vec3 ComputeFarSpace(vec3 wDir, vec3 transmit, const bool primary) {
	// return vec3(0.0);
	
	vec2 coord = wDir.xz * (2.5 * STAR_SCALE * (2.0 - wDir.y));
	
	float noise  = texture(noisetex, coord * 0.5).r;
	      noise += texture(noisetex, coord).r * 0.5;
	
	float star = clamp(noise - 1.3 / STAR_COVERAGE, 0.0, 1.0);
	
	return vec3(star) * 10.0 * transmit;
}

vec3 ComputeSunspot(vec3 wDir, inout vec3 transmit) {
	float radius = 0.54;
	
	float sunspot = float(acos(dot(wDir, sunDir)) < radians(radius) + 0*0.9999567766);
	vec3 color = vec3(float(sunspot) * 1.0 / radius / radius) * transmit;
	
	transmit *= 1.0 - sunspot;
	
	return color;
}

vec3 ComputeClouds(vec3 wPos, vec3 wDir, inout vec3 transmit) {
	vec3 color = vec3(0.0);
	
	color += Compute2DCloudPlane(wPos, wDir, transmit, 0.0);
	
	return color;
}

vec3 ComputeBackSky(vec3 wPos, vec3 wDir, inout vec3 transmit, const bool primary) {
	vec3 color = vec3(0.0);
	
	vec3 myvec;
	color += ComputeSunspot(wDir, transmit) * float(primary) * GetSunAndSkyIrradiance(kPoint(wPos), wDir, sunDir, myvec)*1000.0;
	color += ComputeFarSpace(wDir, transmit, primary);
	
	return color;
}


vec3 CalculateNightSky(vec3 wDir) {
	const vec3 nightSkyColor = vec3(0.04, 0.04, 0.1)*0.1;
	
	float value = pow((dot(wDir, -sunDir) * 0.5 + 0.5), 2.0)*2.0 + 0.5;
	float horizon = (pow(1.0 - abs(wDir.y), 4.0));
	horizon = horizon*horizon * (3.0 - 2.0 * horizon);
	
	return nightSkyColor * value;
}

vec3 ComputeTotalSky(vec3 wPos, vec3 wDir, inout vec3 transmit, const bool primary) {
	vec3 color = vec3(0.0);
	
	// calculateVolumetricClouds(color, transmit, wPos, wDir, sunDir, vec2(0.0), 1.0, ATMOSPHERE.bottom_radius*1000.0, VC_QUALITY, VC_SUNLIGHT_QUALITY);
	color += CalculateNightSky(wDir)*transmit;
	// color += vec3(0.04, 0.04, 0.1)*0.01*transmit;
	color += PrecomputedSky(kCamera, wDir, 0.0, sunDir, transmit);
	color += ComputeBackSky(wPos, wDir, transmit, primary);
	
	return color;
}

#endif
