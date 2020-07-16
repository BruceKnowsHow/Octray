#if !defined SKY_GLSL
#define SKY_GLSL

//#define CLOUDS_2D
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
	float time = CLOUD_SPEED_2D * frameTimeCounter * 0.01*0;
	
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
	
	vec2 lightOffset = sunDirection.xz * 0.2;
	
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
	
	vec3 ambientColor = mix(skylightColor, directColor, 0.0) * 0.1;
	
	vec3 trans = vec3(1);
	directColor = 2.0 * GetSunIrradiance(kPoint(wPos), sunDirection);
	ambientColor = 0.05*PrecomputedSky(kCamera, vec3(0,1,0), 0.0, sunDirection, trans);
	
	vec3 cloud = mix(ambientColor, directColor, sunlight) * 2.0;
	
	transmit *= clamp(1.0 - cloudAlpha, 0.0, 1.0)*0.5+0.5;
	
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

#define time frameTimeCounter

mat2 mm2(in float a){float c = cos(a), s = sin(a);return mat2(c,s,-s,c);}
mat2 m2 = mat2(0.95534, 0.29552, -0.29552, 0.95534);
float tri(in float x){return clamp(abs(fract(x)-.5),0.01,0.49);}
vec2 tri2(in vec2 p){return vec2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x)));}

float triNoise2d(in vec2 p, float spd)
{
    float z=1.8;
    float z2=2.5;
	float rz = 0.;
    p *= mm2(p.x*0.06);
    vec2 bp = p;
	for (float i=0.; i<5.; i++ )
	{
        vec2 dg = tri2(bp*1.85)*.75;
        dg *= mm2(time*spd);
        p -= dg/z2;

        bp *= 1.3;
        z2 *= .45;
        z *= .42;
		p *= 1.21 + (rz-1.0)*.02;
        
        rz += tri(p.x+tri(p.y))*z;
        p*= -m2;
	}
    return clamp(1./pow(rz*29., 1.3),0.,.55);
}

float hash21(in vec2 n){ return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453); }

vec4 aurora(vec3 ro, vec3 rd)
{
    vec4 col = vec4(0);
    vec4 avgCol = vec4(0);
    
    for(float i=0.;i<50.;i++)
    {
        float of = 0.006*hash21(gl_FragCoord.xy)*smoothstep(0.,15., i);
        float pt = ((.8+pow(i,1.4)*.002)-ro.y)/(rd.y*2.+0.4);
        pt -= of;
    	vec3 bpos = ro + pt*rd;
        vec2 p = bpos.zx;
        float rzt = triNoise2d(p, 0.06);
        vec4 col2 = vec4(0,0,0, rzt);
        col2.rgb = (sin(1.-vec3(2.15,-.5, 1.2)+i*0.043)*0.5+0.5)*rzt;
        avgCol =  mix(avgCol, col2, .5);
        col += avgCol*exp2(-i*0.065 - 2.5)*smoothstep(0.,5., i);
        
    }
    
    col *= (clamp(rd.y*15.+.4,0.,1.));
    
    return col*1.8;
}

vec3 ComputeFarSpace(vec3 wDir, vec3 transmit, const bool primary) {
	// return vec3(0.0);
	
	vec2 coord = wDir.xz * (2.5 * STAR_SCALE * (2.0 - wDir.y));
	
	float noise  = texture(noisetex, coord * 0.5).r;
	      noise += texture(noisetex, coord).r * 0.5;
	
	float star = clamp(noise - 1.3 / STAR_COVERAGE, 0.0, 1.0);
	
	return vec3(star) * 10.0 * transmit;
}

#define SUN_RADIUS 0.54 // [0.54 1.0 2.0 3.0 4.0 5.0 20.0]

vec3 ComputeSunspot(vec3 wDir, inout vec3 transmit) {
	float sunspot = float(acos(dot(wDir, sunDirection)) < radians(SUN_RADIUS) + 0*0.9999567766);
	vec3 color = vec3(float(sunspot) * 1.0 / SUN_RADIUS / SUN_RADIUS) * transmit;
	
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
	color += ComputeSunspot(wDir, transmit) * float(primary) * GetSunAndSkyIrradiance(kPoint(wPos), wDir, sunDirection, myvec)*1000.0;
	color += ComputeFarSpace(wDir, transmit, primary);
	
	return color;
}


vec3 CalculateNightSky(vec3 wDir) {
	const vec3 nightSkyColor = vec3(0.04, 0.04, 0.1)*0.1;
	
	float value = pow((dot(wDir, -sunDirection) * 0.5 + 0.5), 2.0)*2.0 + 0.5;
	float horizon = (pow(1.0 - abs(wDir.y), 4.0));
	horizon = horizon*horizon * (3.0 - 2.0 * horizon);
	
	return nightSkyColor * value;
}

vec3 ComputeTotalSky(vec3 wPos, vec3 wDir, inout vec3 transmit, const bool primary) {
	vec3 color = vec3(0.0);
	
	// calculateVolumetricClouds(color, transmit, wPos, wDir, sunDirection, vec2(0.0), 1.0, ATMOSPHERE.bottom_radius*1000.0, VC_QUALITY, VC_SUNLIGHT_QUALITY);
	color += ComputeClouds(wPos, wDir, transmit);
	color += CalculateNightSky(wDir)*transmit;
	
	// color += vec3(0.04, 0.04, 0.1)*0.01*transmit;
	color += PrecomputedSky(kCamera, wDir, 0.0, sunDirection, transmit);
	color += ComputeBackSky(wPos, wDir, transmit, primary);
	
	return color;
}

#endif
