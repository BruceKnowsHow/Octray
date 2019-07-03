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

float ComputeSunlight(vec3 wPos, vec3 normal, vec3 flatNormal, vec3 lightDir) {
	vec3 sunlightDir = abs(flatNormal);
	vec3 sunlightPos = wPos;
	float NdotL = clamp(dot(normal, lightDir), 0.0, 1.0) * float(dot(flatNormal, lightDir) > 0.0);
	float direct = (NdotL > 0.0) ? float(VoxelMarch(sunlightPos, lightDir, sunlightDir, 0) < -1.0) : 0.0;
	float sunlight = NdotL * direct + 0.4;
	
	return sunlight;
}

#define SKY (vec4(0.3, 0.6, 1.0, 1.0))

vec3 light = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

void ComputeReflections(inout vec3 color, inout vec3 currPos, inout vec3 rayDir, inout vec3 flatNormal,
                        inout float alpha, const bool doUnderwaterFog,
                        sampler2D texSampler, sampler2D normalSampler, sampler2D specSampler)
{
	for (int i = 0; i < 10; ++i) {
		if (alpha <= 0) return;
		
		vec3 old = currPos;
		
		float lookup = VoxelMarch(currPos, rayDir, flatNormal, 0);
		if (lookup == -1e35) { color += SKY.rgb * alpha; return; }
		
		mat3 tbn = GenerateTBN(flatNormal * sign(-rayDir));
		
		vec2 coord = (fract(currPos) * 2.0 - 1.0) * mat2x3(tbn);
		vec2 tCoord = GetTexCoord(coord.xy, lookup);
		
		vec3 diffuse  = textureLod(texSampler, tCoord, 0).rgb * unpackVertColor(Lookup(currPos, 1));
		vec3 normal   = tbn * normalize(textureLod(normalSampler, tCoord, 0).rgb * 2.0 - 1.0);
		vec3 spec = textureLod(specSampler, tCoord, 0).rgb;
		
		vec3 wPos = Part1InvTransform(currPos) - gbufferModelViewInverse[3].xyz - fract(cameraPosition);
		float sunlight = ComputeSunlight(wPos, normal, tbn[2], light);
		
		#if defined gbuffers_water
		spec.x = 0.0;
		#endif
		
		float iRef  = (1.0 - abs(dot(rayDir, normal))) * (spec.x);
		float iBase = 1.0 - iRef;
		
		vec3 C = diffuse * sunlight * iBase * alpha;
		
		#if defined gbuffers_water
		if (doUnderwaterFog && i == 0) C = mix(vec3(0.0, 0.5, 1.0)*0.3*alpha, C, clamp(exp2(-distance(wPos, old)*0.5), 0.0, 1.0));
		#endif
		
		color += C;
		
		alpha *= iRef;
		currPos = wPos;
		rayDir = reflect(rayDir, normal);
	}
	
	return;
}
