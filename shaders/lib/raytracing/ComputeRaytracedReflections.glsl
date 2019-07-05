#ifndef COMPUTE_RAYTRACED_REFLECTIONS_GLSL
#define COMPUTE_RAYTRACED_REFLECTIONS_GLSL

mat3 GenerateTBN(vec3 normal) {
	mat3 tbn;
	tbn[2] = normal;
	     if (tbn[2].x >  0.5) tbn[0] = vec3( 0, 0,-1);
	else if (tbn[2].x < -0.5) tbn[0] = vec3( 0, 0, 1);
	else if (tbn[2].y >  0.5) tbn[0] = vec3( 1, 0, 0);
	else if (tbn[2].y < -0.5) tbn[0] = vec3( 1, 0, 0);
	else if (tbn[2].z >  0.5) tbn[0] = vec3( 1, 0, 0);
	else if (tbn[2].z < -0.5) tbn[0] = vec3(-1, 0, 0);
	tbn[1] = cross(tbn[0], tbn[2]);
	
	return tbn;
}

vec2 GetTexCoord(vec2 coord, float lookup) {
	coord = coord * 0.5 + 0.5;
	
	vec2 midTexCoord = unpackTexcoord(lookup);
	vec2 spriteSize = 64.0 / atlasSize; // Sprite size in [0, 1] texture space
	vec2 cornerTexCoord = midTexCoord - 0.5 * spriteSize; // Coordinate of texture's starting corner in [0, 1] texture space
	vec2 coordInSprite = coord.xy * spriteSize; // Fragment's position within sprite space
	vec2 tCoord = cornerTexCoord + coordInSprite;
	
	return tCoord;
}

float RaytraceSunlight(vec3 wPos, vec3 normal) {
	vec3 plane = vec3(0.0);
	float NdotL = clamp(dot(normal, sunDir), 0.0, 1.0) * float(dot(normal, sunDir) > 0.0);
	float direct = (NdotL > 0.0) ? float(VoxelMarch(wPos, sunDir, plane, 0, false) < -1.0) : 0.0;
	float sunlight = NdotL * direct + 0.4;
	
	return sunlight;
}

#include "/../shaders/lib/sky.glsl"

#define SKY_COLOR   (vec3(0.3, 0.6, 1.0))
#define WATER_COLOR (vec3(0.0, 0.5, 1.0)*0.3)

void RaytraceColorFromDirection(inout vec3 color, vec3 currPos, vec3 rayDir,
                        float alpha, const bool doSpecular, const bool underwaterMarch,
                        sampler2D texSampler, sampler2D normalSampler, sampler2D specSampler)
{
	for (int i = 0; i < 10; ++i) {
		if (alpha < 1.0 / 255.0) return;
		
		vec3 oldPos = currPos;
		vec3 plane = vec3(0.0);
		
		float lookup = VoxelMarch(currPos, rayDir, plane, 0, underwaterMarch);
		
		vec3 wPos = Part1InvTransform(currPos);
		float fog = 1.0 - clamp(exp2(-distance(wPos, oldPos) * 0.5), 0.0, 1.0);
		
		if (underwaterMarch && alpha*(1.0 - fog) < 1.0 / 255.0) { color += vec3(0.0, 0.5, 1.0)*0.3*alpha; return; }
		
		vec3 absorb = vec3(alpha);
		if (lookup == -1e35) { color += ComputeTotalSky(wPos, rayDir, absorb); return; }
		
		
		mat3 tbn = GenerateTBN(plane * sign(-rayDir));
		
		vec2 coord = (fract(currPos) * 2.0 - 1.0) * mat2x3(tbn);
		vec2 tCoord = GetTexCoord(coord.xy, lookup);
		
		vec3 diffuse  = textureLod(texSampler, tCoord, 0).rgb * unpackVertColor(Lookup(currPos, 1));
		vec3 normal   = tbn * normalize(textureLod(normalSampler, tCoord, 0).rgb * 2.0 - 1.0);
		vec3 spec = (doSpecular) ? textureLod(specSampler, tCoord, 0).rgb : vec3(0.0);
		
		float sunlight = RaytraceSunlight(wPos, normal);
		
		float iRef  = (1.0 - abs(dot(rayDir, normal))) * (spec.x);
		float iBase = 1.0 - iRef;
		
		vec3 C = diffuse * sunlight * iBase * alpha;
		
		if (underwaterMarch) C = mix(C, WATER_COLOR * alpha, fog);
		
		color += C;
		
		alpha *= iRef;
		currPos = wPos;
		rayDir = reflect(rayDir, normal);
	}
	
	return;
}

#endif
