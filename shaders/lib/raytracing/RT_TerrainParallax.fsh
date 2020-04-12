#if !defined TERRAINPARALLAX_FSH
#define TERRAINPARALLAX_FSH

// #define RT_TERRAIN_PARALLAX
#define TERRAIN_PARALLAX_QUALITY 1.0
#define TERRAIN_PARALLAX_INTENSITY 1.0 // [0.0 1/4.0 2/4.0 3/4.0 1.0 1.5 2.0 3.0 4.0]
#define TERRAIN_PARALLAX_DISTANCE 16.0
#define TERRAIN_PARALLAX_MAX_STEPS 100

vec3 ComputeParallaxCoordinate(vec3 tCoord, vec2 cornerTexCoord, vec3 tDir, vec2 spriteScale, out bool insidePOM, sampler2D heightmap) {
	float intensity = TERRAIN_PARALLAX_INTENSITY / 3.0;
	const float quality = TERRAIN_PARALLAX_QUALITY;
	
	vec3 step = tDir * vec3(vec2(0.03), 1.0) / quality * 0.01;
	step.x /= atlasSize.x / atlasSize.y;
	
	insidePOM = false;
	if (texture(heightmap, tCoord.xy + cornerTexCoord, 0).a >= 1.0) return tCoord;
	
	// tCoord.xy = mod(tCoord.xy, spriteScale);
	tCoord += step * RandNextF();
	
	float sampleHeight;
	
	uint i;
	for (i = 0; i < TERRAIN_PARALLAX_MAX_STEPS; ++i) {
		sampleHeight = 1.0 - (1.0 - texture(heightmap, mod(tCoord.xy, spriteScale) + cornerTexCoord, 0).a) * intensity;
		
		if (tCoord.z <= sampleHeight || tCoord.z > 1.0) break;
		
		tCoord.xy += step.xy * clamp((tCoord.z - sampleHeight)*100.0, 0.0, 1.0);
		tCoord.z += step.z;
	}
	
	insidePOM = (tDir.z < 0.0) ? i > 1 : tCoord.z < 1.0;
	
	tCoord -= step;
	tCoord.xy = mod(tCoord.xy, spriteScale);
	
	return tCoord;
}
#ifndef RT_TERRAIN_PARALLAX
	#define ComputeParallaxCoordinate1(tCoord, cornerTexCoord, tDir, spriteScale, insidePOM, samplr) vec3(tCoord.xy, 1.0)
#endif

#endif
