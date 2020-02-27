#if !defined TERRAINPARALLAX_FSH
#define TERRAINPARALLAX_FSH

// #define TERRAIN_PARALLAX
#define TERRAIN_PARALLAX_QUALITY 1.0
#define TEXTURE_PACK_RESOLUTION 16
#define TERRAIN_PARALLAX_INTENSITY 1.0
#define TERRAIN_PARALLAX_DISTANCE 16.0

vec2 ComputeParallaxCoordinate(vec2 coord, vec3 position, mat3 tbn, vec2 spriteSize, sampler2D heightmap) {
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
	
	vec2 textureRes = spriteSize;
	// textureRes.x = 10240.0;
	
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
#if !defined TERRAIN_PARALLAX
	#define ComputeParallaxCoordinate(coord, position, tbn, spriteSize, heightmap) (coord)
#endif

#endif
