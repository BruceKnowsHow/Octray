#if !defined SKY_GLSL
#define SKY_GLSL

#define CLOUDS_2D
#define CLOUD_HEIGHT_2D   512  // [384 512 640 768]
#define CLOUD_COVERAGE_2D 0.5  // [0.3 0.4 0.5 0.6 0.7]
#define CLOUD_SPEED_2D    1.00 // [0.25 0.50 1.00 2.00 4.00]

#ifndef gbuffers_water
const float noiseResInverse = 1.0 / noiseTextureResolution;
#endif

float csmooth(float x) {
	return x * x * (3.0 - 2.0 * x);
}

vec2 csmooth(vec2 x) {
	return x * x * (3.0 - 2.0 * x);
}

float GetNoise(vec2 coord) {
	const vec2 madd = vec2(0.5 * noiseResInverse);
	vec2 whole = floor(coord);
	coord = whole + csmooth(coord - whole);
	
	return texture2D(noisetex, coord * noiseResInverse + madd).x;
}

vec2 GetNoise2D(vec2 coord) {
	const vec2 madd = vec2(0.5 * noiseResInverse);
	vec2 whole = floor(coord);
	coord = whole + csmooth(coord - whole);
	
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

vec3 Compute2DCloudPlane(vec3 wPos, vec3 wDir, inout vec3 absorb, float sunglow) {
#ifndef CLOUDS_2D
	return vec3(0.0);
#endif
	
	const float cloudHeight = CLOUD_HEIGHT_2D;
	
	wPos += cameraPosition;
	
//	visibility = pow(visibility, 10.0) * abs(wDir.y);
	
	if (wDir.y <= 0.0 != wPos.y >= cloudHeight) return vec3(0.0);
	
	
	vec3 oldAbsorb = absorb;
	
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
	
	vec3 cloud = mix(ambientColor, directColor, sunlight) * 2.0;
	
	absorb *= clamp(1.0 - cloudAlpha, 0.0, 1.0);
	
	return cloud * cloudAlpha * oldAbsorb * 5.0;
}



#define PHYSICAL_ATMOSPHERE

vec2 AtmosphereDistances(vec3 worldPosition, vec3 worldDirection, const float atmosphereRadius, const vec2 radiiSquared) {
	// Considers the planet's center as the coordinate origin, as per convention
	
	float b  = -dot(worldPosition, worldDirection);
	float bb = b * b;
	vec2  c  = dot(worldPosition, worldPosition) - radiiSquared;
	
	vec2 delta   = sqrt(max(bb - c, 0.0)); // .x is for planet distance, .y is for atmosphere distance
	     delta.x = -delta.x; // Invert delta.x so we don't have to subtract it later
	
	if (worldPosition.y < atmosphereRadius) { // If inside the atmosphere, uniform condition
		if (bb < c.x || b < 0.0) return vec2(b + delta.y, 0.0); // If the earth is not visible to the ray, check against the atmosphere instead
		
		vec2 dist     = b + delta;
		vec3 hitPoint = worldPosition + worldDirection * dist.x;
		
		float horizonCoeff = dot(normalize(hitPoint), worldDirection);
		      horizonCoeff = exp2(horizonCoeff * 5.0);
		
		return vec2(mix(dist.x, dist.y, horizonCoeff), 0.0);
	} else {
		if (b < 0.0) return vec2(0.0);
		
		if (bb < c.x) return vec2(2.0 * delta.y, b - delta.y);
		
		return vec2((delta.y + delta.x) * 2.0, b - delta.y);
	}
}

vec3 ComputeAtmosphericSky(vec3 worldDirection, float visibility, inout vec3 absorb) {
	const float iSteps = 12;
	
	const vec3  OZoneCoeff    =  vec3(3.426, 8.298, 0.356) * 6e-7;
	const vec3  rayleighCoeff =  vec3(0.58, 1.35, 3.31) * 1e-5               * -1.0;
	const vec3  rayleighOZone = (vec3(0.58, 1.35, 3.31) * 1e-5 + OZoneCoeff) * -1.0;
	const float      mieCoeff = 7e-6 * -1.0;
	
	const float rayleighHeight = 8.0e3 * 0.25;
	const float      mieHeight = 1.2e3 * 2.0;
	
	const float     planetRadius = 6371.0e2;
	const float atmosphereRadius = 6471.0e2;
	
	const vec2 radiiSquared = vec2(planetRadius, atmosphereRadius) * vec2(planetRadius, atmosphereRadius);
	
	vec3 worldPosition = vec3(0.0, planetRadius + 1.061e3 + max(cameraPosition.y - 72, 0.0) * 40.0*0, 0.0);
	
	vec2 atmosphereDistances = AtmosphereDistances(worldPosition, worldDirection, atmosphereRadius, radiiSquared);
	
	if (atmosphereDistances.x <= 0.0) return vec3(0.0);
	
	float iStepSize  = atmosphereDistances.x / iSteps; // Calculate the step size of the primary ray
	vec3  iStep      = worldDirection * iStepSize;
	
	const vec2 scatterMUL = -1.0 / vec2(rayleighHeight, mieHeight);
	vec4  scatterADD = vec2(log2(iStepSize), 0.0).xxyy - planetRadius * scatterMUL.rgrg;
	
	
	vec3 iPos = worldPosition + worldDirection * (iStepSize * 0.5 + atmosphereDistances.y); // Calculate the primary ray sample position
	
	vec3 c = vec3(dot(iPos, iPos), dot(iPos, iStep) * 2.0, (iStepSize*iStepSize)); // dot(iStep, iStep)
	vec2 e = vec2(dot(iPos, sunDir), dot(iStep, sunDir));
	
	
	vec3 rayleigh = vec3(0.0); // Accumulators for Rayleigh and Mie scattering
	vec3 mie      = vec3(0.0);
	
	vec3 oldAbsorb = absorb;
	
	vec2 opticalDepth = vec2(0.0); // Optical depth accumulators
	
    // Sample the primary ray
	for (float i = 0; i < iSteps; i++) {
		float iPosLength2 = fma(fma(c.z, i, c.y), i, c.x);
		
		float b = fma(e.y, i, e.x); // b = dot(iPos, sunDir);
		float jStepSize = sqrt(fma(b, b, radiiSquared.y - iPosLength2)) - b; // jStepSize = sqrt(b*b + radiiSquared.y - dot(iPos, iPos)) - b;
		
		float jPosLength2 = fma(fma(jStepSize, 0.25, b), jStepSize, iPosLength2);
		
		vec4 opticalStep = exp2(sqrt(vec2(iPosLength2, jPosLength2)).xxyy * scatterMUL.rgrg + scatterADD); // Calculate the optical depth of the Rayleigh and Mie scattering for this step
		opticalDepth += opticalStep.rg;
		opticalStep.ba = opticalStep.ba * jStepSize + opticalDepth;
		
		vec3 attn = exp2(rayleighOZone * opticalStep.b + (mieCoeff * opticalStep.a));
		
		rayleigh += opticalStep.r * attn;
		mie      += opticalStep.g * attn;
		absorb	 *= attn;
    }
	
	// Calculate the Rayleigh and Mie phases
	float g = 0.9;
	float gg = g * g;
    float  mu = e.y / iStepSize; // dot(worldDirection, sunDir);
    float rayleighPhase = 1.5 * (1.0 + mu * mu);
    float      miePhase = rayleighPhase * (1.0 - gg) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg));
	
	mie = max(mie, 0.0);
	
    // Calculate and return the final color
    return -(rayleigh * rayleighPhase * rayleighCoeff + mie * miePhase * mieCoeff) * oldAbsorb;
}

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


vec3 ComputeFarSpace(vec3 wDir, vec3 absorb) {
	vec2 coord = wDir.xz * (2.5 * STAR_SCALE * (2.0 - wDir.y));
	
	float noise  = texture(noisetex, coord * 0.5).r;
	      noise += texture(noisetex, coord).r * 0.5;
	
	float star = clamp(noise - 1.3 / STAR_COVERAGE, 0.0, 1.0);
	
	return vec3(star) * 10.0 * absorb;
}

vec3 ComputeSunspot(vec3 wDir, inout vec3 absorb) {
	float sunspot = float(dot(wDir, sunDir) > 0.9994 + 0*0.9999567766);
	vec3 color = vec3(float(sunspot) * 500.0) * absorb;
	
	absorb *= 1.0 - sunspot;
	
	return color;
}

vec3 ComputeClouds(vec3 wPos, vec3 wDir, inout vec3 absorb) {
	vec3 color = vec3(0.0);
	
	color += Compute2DCloudPlane(wPos, wDir, absorb, 0.0);
	
	return color;
}

vec3 ComputeBackSky(vec3 wDir, inout vec3 absorb) {
	vec3 color  = vec3(0.0);
	
	color += ComputeAtmosphericSky(wDir, 1.0, absorb);
	color += ComputeSunspot(wDir, absorb);
	color += ComputeFarSpace(wDir, absorb);
	
	return color;
}

vec3 ComputeTotalSky(vec3 wPos, vec3 wDir, inout vec3 absorb) {
	vec3 color;
	
	color += ComputeClouds(wPos, wDir, absorb);
	color += ComputeBackSky(wDir, absorb);
	
	return color;
}

#endif
