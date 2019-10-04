#if !defined VOLUMETRIC_CLOUDS_GLSL
#define VOLUMETRIC_CLOUDS_GLSL


//#define VOLUMETRIC_CLOUDS
#define VC_QUALITY 24 //[5 10 15 20 24 32 64 128 256 512]
#define VC_SUNLIGHT_QUALITY 12 //[2 3 4 5 6 7 8 9 10 12 14 16 18 20 22 24 26 28 30 32 36 40 44 48 52 56 60 64]
#define VC_NOISE_OCTAVES 4 //[3 4 5 6 7]
#define VC_LOCAL_COVERAGE
//#define VC_SHADOWS
#define VC_MULTISCAT    //Simulates multiscattering.
#define VC_MULTISCAT_QUALITY 3  //[1 2 3 4 5 6 7 8]

#define volumetric_cloudThicknessMult 1.0 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0]
#define volumetric_cloudDensity 0.05  //[0.005 0.075 0.01 0.0125 0.015 0.0175 0.02 0.025 0.03 0.035 0.04 0.045 0.05 0.06 0.07 0.08 0.09 0.1]
#define volumetric_cloudHeight 1600.0   //[100.0 110.0 120.0 130.0 140.0 160.0 180.0 200.0 220.0 240.0 260.0 280.0 300.0 400.0 500.0 600.0 700.0 800.0 900.0 1000.0 1200.0 1400.0 1600.0 1800.0 2000.0 10000.0]
#define volumetric_cloudMinHeight volumetric_cloudHeight

const float volumetric_cloudThickness = 1500.0 * volumetric_cloudThicknessMult;
const float volumetric_cloudMaxHeight = volumetric_cloudMinHeight + volumetric_cloudThickness;

const float rNoiseTexRes = 1.0 / noiseTextureResolution;

const float rPI = 1.0 / PI;
const float rLOG2 = 1.0 / log(2.0);

const vec3 sunIlluminanceClouds = vec3(10.0);
const vec3 skyIlluminanceClouds = vec3(10.0) * SKY_SPECTRAL_RADIANCE_TO_LUMINANCE / SUN_SPECTRAL_RADIANCE_TO_LUMINANCE;

#define cubeSmooth(x) (x * x * (3.0 - 2.0 * x))

float CalculateDitherPattern() {
	const int[16] ditherPattern = int[16] (
		 0,  8,  2, 10,
		12,  4, 14,  6,
		 3, 11,  1,  9,
		15,  7, 13,  5);
	
	vec2 count = vec2(mod(gl_FragCoord.st, vec2(4.0)));
	
	int dither = ditherPattern[int(count.x) + int(count.y) * 4] + 1;
	
	return float(dither) / 17.0;
}

// No intersection if returned y component is < 0.0
vec2 rsi(vec3 position, vec3 direction, float radius) {
	float PoD = dot(position, direction);
	float radiusSquared = radius * radius;

	float delta = PoD * PoD + radiusSquared - dot(position, position);
	if (delta < 0.0) return vec2(-1.0);
		delta = sqrt(delta);

	return -PoD + vec2(-delta, delta);
}
	
float remap(float value, const float originalMin, const float originalMax, const float newMin, const float newMax) {
	return clamp((((value - originalMin) / (originalMax - originalMin)) * (newMax - newMin)) + newMin, 0.0, 1.0);
}

float calculate3DNoise(vec3 position){
	vec3 p = floor(position); 
	vec3 b = fract(position);
		b = cubeSmooth(b);

	vec2 uv = 17.0 * p.z + p.xy + b.xy;
	vec2 rg = texture(noisetex, (uv + 0.5) * rNoiseTexRes).xy;

	return mix(rg.x, rg.y, b.z);
}


float cFBM(vec3 x, vec3 shiftM, const float d, const float m, const int oct) {
	float v = 0.0;
	float a = 0.5;
	vec3 shift = vec3(100.0) * shiftM;

	for (int i = 0; i < oct; ++i) {
		v += a * calculate3DNoise(x);
		x = x * m + shift;
		a *= d;
	}
	return v;
}

float calculateScatterIntergral(float stepTransmittance, const float coeff){
	const float a = -1.0 / coeff;

	return stepTransmittance * a - a;
}

float phaseG(float cosTheta, const float g){
	float gg = g * g;
	return rPI * (gg * -0.25 + 0.25) * pow(-2.0 * (g * cosTheta) + (gg + 1.0), -1.5);
}

float calculateCloudPhase(float vDotL){
	const float mixer = 0.5;

	float g1 = phaseG(vDotL, 0.8);
	float g2 = phaseG(vDotL, -0.5);

	return mix(g2, g1, mixer);
}

// Calculate cloud noise using FBM.
float calculateCloudShape(vec3 position, vec3 windDirection, const int octaves){
	const float d = 0.5;
	const float m = 3.0;
	float h = (d / m) / octaves;

	vec3 shiftMult = -windDirection * 0.013;

	float noise = cFBM(position, shiftMult, d, m, octaves);
		noise += h;

	return noise;
}

// Calculate cloud optical depth.
float calculateCloudOD(vec3 position, const int octaves){
	// Early out.
//	if (position.y > volumetric_cloudMaxHeight || position.y < volumetric_cloudMinHeight) return 0.0;

	float localCoverage = 1.0;

	#ifdef VC_LOCAL_COVERAGE
		localCoverage = texture2D(noisetex, (TIME * 50.0 + position.xz) * 0.000001).x;
		localCoverage = clamp(localCoverage * 3.0 - 0.75, 0.0, 1.0) * 0.5 + 0.5;
	#endif

	float wind = TIME * -0.025;
	vec3 windDirection = vec3(wind, 0.0, wind);

	vec3 cloudPos = position * 0.00045 + windDirection;

	float worldHeight = position.y - volumetric_cloudMinHeight;
	float normalizedHeight = worldHeight * (1.0 / volumetric_cloudThickness);
	float heightAttenuation = remap(normalizedHeight, 0.0, 0.2, 0.0, 1.0) * remap(normalizedHeight, 0.8, 1.0, 1.0, 0.0);

	float clouds = calculateCloudShape(cloudPos, windDirection, octaves);

	// Calculate the final cloudshape.
	clouds = clouds * heightAttenuation * localCoverage * 2.0 - (0.9 * heightAttenuation + normalizedHeight * 0.5 + 0.1);
	clouds *= normalizedHeight * normalizedHeight * 6.0;
	clouds = clamp(clouds, 0.0, 1.0);

	return clouds * (volumetric_cloudDensity);
}

// Approximation for in-scattering probability.
float calculatePowderEffect(float od){
	return 1.0 - exp(-od * 2.0);
}

float calculatePowderEffect(float od, float vDotL){
	return mix(calculatePowderEffect(od), 1.0, vDotL * 0.5 + 0.5);
}

float calculateCloudTransmittanceDepth(vec3 position, vec3 direction, const int steps){
	float rayLength = 25.0; // Starting ray length

	float od = 0.0;

	for (int i = 0; i < steps; ++i, position += direction * rayLength){
		od += calculateCloudOD(position, VC_NOISE_OCTAVES) * rayLength;

		rayLength *= 1.5;
	}

	return od;
}

float calculateCloudTransmittanceDepthSky(vec3 position){
	float gradient = min(volumetric_cloudMinHeight - position.y, volumetric_cloudMinHeight) * (1.0 / volumetric_cloudThicknessMult) * 0.0007;

	return gradient;
}


// Absorb sunlight through the clouds.
float calculateCloudTransmittance(float bn, float transmittanceDepth){
	return exp2(-transmittanceDepth * rLOG2 * bn);
}

// Calculate the total energy of the clouds.
void calculateCloudScattering(float scatterCoeff, float transmittance, float bn, float transmittanceDepth, float transmittanceDepthSky, float phase, float powder, inout float directScattering, inout float skylightScattering, const int dlSteps){

	directScattering += scatterCoeff * powder * phase * calculateCloudTransmittance(bn, transmittanceDepth) * transmittance;
	skylightScattering += scatterCoeff * calculateCloudTransmittance(bn, transmittanceDepthSky) * transmittance;
}

#define a 0.5
#define b 0.15
#define c 0.85
void calculateCloudScattering(vec3 position, vec3 wLightVector, float od, float vDotL, float transmittance, float stepTransmittance, inout float directScattering, inout float skylightScattering, const int dlSteps, const int msSteps){
	// Scattering intergral.
	float scatterCoeff = calculateScatterIntergral(stepTransmittance, 1.0);

	// Depth for directional transmittance
	float transmittanceDepth = calculateCloudTransmittanceDepth(position, wLightVector, dlSteps);
	float transmittanceDepthSky = calculateCloudTransmittanceDepthSky(position);

	// Approximate inscattering probability
	float powder = calculatePowderEffect(transmittanceDepth, vDotL);
		  powder *= calculatePowderEffect(od, vDotL);

	#ifdef VC_MULTISCAT
		for (int i = 0; i < msSteps; ++i) {

			float n = float(i);

			float an = pow(a, n);
			float bn = pow(b, n);
			float cn = pow(c, n);

			// Calculate the cloud phase.
			float phase = calculateCloudPhase(vDotL * cn);
			scatterCoeff = scatterCoeff * an;

			calculateCloudScattering(scatterCoeff, transmittance, bn, transmittanceDepth, transmittanceDepthSky, phase, powder, directScattering, skylightScattering, dlSteps);
		}
	#else
		calculateCloudScattering(scatterCoeff, transmittance, 1.0, transmittanceDepth, transmittanceDepthSky, 1.0, powder, directScattering, skylightScattering, dlSteps);
	#endif
}

void swap(inout float a1, inout float b1) {
	float temp = a1;
	a1 = b1;
	b1 = temp;
}

void calculateVolumetricClouds(inout vec3 cloud, inout vec3 absorb, vec3 wPos, vec3 wDir, vec3 wLightVector, vec2 planetSphere, float dither, const float planetRadius, const int steps, const int dlSteps){
	#ifndef VOLUMETRIC_CLOUDS
		return;
	#endif
	
	dither = CalculateDitherPattern();
	
	vec3 cPos = wPos + cameraPosition;
	
	float vDotL = dot(wDir, wLightVector);
	
	// Marches per pixel.
	float rSteps = 1.0 / steps;

	const int msSteps = VC_MULTISCAT_QUALITY;
	
	planetSphere = rsi(vec3(0.0, planetRadius + cPos.y, 0.0), wDir, planetRadius);
	
	// Calculate the cloud spheres.
	vec2 bottomSphere = rsi(vec3(0.0, planetRadius + cPos.y, 0.0), wDir, planetRadius + volumetric_cloudMinHeight);
	vec2 topSphere = rsi(vec3(0.0, planetRadius + cPos.y, 0.0), wDir, planetRadius + volumetric_cloudMaxHeight);
	
	if (cPos.y < volumetric_cloudMinHeight && planetSphere.y > 0.0) { return; }
	if (cPos.y > volumetric_cloudMaxHeight && topSphere.x < 0.0) { return; }
	
	float startDistance;
	float endDistance;
	
	if (cPos.y < volumetric_cloudMinHeight) { // if under the cloud slice
		startDistance = bottomSphere.y;
		endDistance = topSphere.y;
	} else if (cPos.y > volumetric_cloudMinHeight && cPos.y < volumetric_cloudMaxHeight) { // if inside the cloud slice
		startDistance = 0.0;
		endDistance = (bottomSphere.x > 0.0) ? 0.0 : topSphere.y; // if lower boundary is visible, march there. Otherwise march to top boundary
	} else { // if above the cloud slice
		startDistance = topSphere.x;
		endDistance = bottomSphere.x;
		if (bottomSphere.x < 0.0) { startDistance = topSphere.x; endDistance = topSphere.y; }
	}
	
	vec3 startPosition = wDir * startDistance + cPos;
	vec3 endPosition = wDir   * endDistance + cPos;
	
	
	startPosition += vec3(0.0, planetRadius, 0.0);
	if (cPos.y < volumetric_cloudMinHeight)
		{ startPosition = startPosition * (planetRadius + volumetric_cloudMinHeight) / startPosition.y; }
	if (cPos.y > volumetric_cloudMinHeight && cPos.y < volumetric_cloudMaxHeight)
		{ startPosition = startPosition * (planetRadius + volumetric_cloudMinHeight) / startPosition.y; }
	if (cPos.y > volumetric_cloudMaxHeight)
		{ startPosition = startPosition * (planetRadius + ((bottomSphere.x < 0.0) ? volumetric_cloudMaxHeight : volumetric_cloudMaxHeight)) / startPosition.y; }
	startPosition -= vec3(0.0, planetRadius, 0.0);
	
	endPosition += vec3(0.0, planetRadius, 0.0);
	if (cPos.y < volumetric_cloudMinHeight)
		{ endPosition = endPosition * (planetRadius + volumetric_cloudMaxHeight) / endPosition.y; }
	if (cPos.y > volumetric_cloudMinHeight && cPos.y < volumetric_cloudMaxHeight)
		{ endPosition = endPosition * (planetRadius + volumetric_cloudMaxHeight) / endPosition.y; }
	if (cPos.y > volumetric_cloudMaxHeight)
		{ endPosition = endPosition * (planetRadius + ((bottomSphere.x < 0.0) ? volumetric_cloudMaxHeight : volumetric_cloudMinHeight)) / endPosition.y; }
	endPosition -= vec3(0.0, planetRadius, 0.0);
	
	// Calculate the ray increment and the ray position.
	vec3 increment = (endPosition - startPosition);
	
//	increment = normalize(increment) * min(length(increment), 1000000.0);
	increment *= rSteps;
	vec3 cloudPosition = increment * dither + startPosition;

	float rayLength = length(increment);

	float directScattering = 0.0;
	float skylightScattering = 0.0;
	
	// Calculate the cloud phase.
	#ifdef VC_MULTISCAT
		float phase = 1.0;
	#else
		float phase = calculateCloudPhase(vDotL);
	#endif

	vec3 cloudHitPos = vec3(0.0);
	float transmittance = 1.0;
	float totTrans = 0.0;

	float depthCompensation = sqrt(steps / (rayLength * 1.73205080757));	// 1.0 / sqrt(sqrt(3)) for alignment

	// Raymarching.
	for (int i = 0; i < steps; ++i, cloudPosition += increment){
		float od = calculateCloudOD(cloudPosition, VC_NOISE_OCTAVES) * rayLength;
		// Early out.
		if (od <= 0.0) continue;
		if (transmittance < 0.001) { transmittance = 0.0; break;}

		//cloudDepth = cloudDepth < rayDepth - cloudDepth && cloudDepth <= 0.0 ? rayDepth : cloudDepth;

		float stepTransmittance = exp2(-od * rLOG2);

		cloudHitPos += cloudPosition * transmittance;
		totTrans += transmittance;

		calculateCloudScattering(cloudPosition, wLightVector, od * depthCompensation, vDotL, transmittance, stepTransmittance, directScattering, skylightScattering, dlSteps, msSteps);
		
		transmittance *= stepTransmittance;
	}
	
	#if ShaderStage < 30
		#define colortex0 normals
		#define colortex4 gaux1
	#endif
	
	vec3 trans = vec3(1.0);
	
	// Light the scattering and sum them up.
	vec3 directLighting = directScattering * vec3(200.0);

	#ifndef VC_MULTISCAT
		directLighting *= phase;
	#endif
	
	trans = vec3(1.0);
	
	vec3 skyLighting = skylightScattering * GetSkyRadiance(ATMOSPHERE, colortex0, colortex4, colortex4, vec3(0, 1+ATMOSPHERE.bottom_radius,0), vec3(0,1,0), 0.0, sunDir, trans) * 0.25 * rPI;
	cloud = (directLighting + skyLighting) * PI;

	cloudHitPos /= totTrans;
	cloudHitPos -= cPos;

	vec3 skyCamera = vec3(0.0, (cameraPosition.y)/1000.0 + ATMOSPHERE.bottom_radius, 0.0) + wPos/1000.0;
	vec3 point = skyCamera + cloudHitPos/1000.0;
	
	
	
	vec3 transmittanceAP = vec3(1.0);
	vec3 in_scatter = GetSkyRadianceToPoint(ATMOSPHERE, colortex0, colortex4, colortex4, skyCamera, point, 0.0, wLightVector, transmittanceAP);
	
	if (any(isnan(in_scatter))) {
		in_scatter = vec3(0.0);
		transmittanceAP = vec3(1.0);
	}
	
	cloud = cloud * transmittanceAP + in_scatter * (1.0 - transmittance);
	absorb *= transmittance;
	
	return;
}

#undef a
#undef b
#undef c


#endif
