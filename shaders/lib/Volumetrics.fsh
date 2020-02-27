#if !defined VOLUMETRICS_FSH
#define VOLUMETRICS_FSH

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
    a = VoxelToWorldSpace(a);
    b = VoxelToWorldSpace(b);
    
	vec3 worldPoint = cameraPosition + mat3(gbufferModelViewInverse) * vec3(0,0,0);
	
	vec2 points = rsi2(a + cameraPosition - worldPoint, normalize(b - a), 1.0);
	if (points.x > points.y) return 0;
	float od = max(0.0, points.y - max(0.0, points.x));
	if (points.x < 0.0 && distance(a,b) < points.y) return distance(a,b);
	if (points.x < 0.0) return od;
	if (distance(a,b) > length(points.y)) return od;
	if (points.x < distance(a,b) && distance(a,b) < points.y) return distance(a,b) - points.x;
	if (distance(a,b) < length(points.x)) return 0;
	
	return od*100;
}

void VOLUMETRICS(vec3 a, vec3 b, inout vec3 inScatter, inout vec3 outScatter, vec3 sunDir, bool transmit) {
	// float od = rsi3(a, b);
    // od = distance(a,b);
    // outScatter = vec3(1);
    //
    // od = clamp(1-exp(-distance(a,b)/10.0), 0.0, 1.0);
    //
    // vec2 hash = vec2(WangHash(69155*(frameCounter + 1)*int(gl_FragCoord.x*gl_FragCoord.y)), WangHash(13*(frameCounter + 1)));
    //
    // vec3 c = mix(a, b, hash.x) / 50.0;
    //
    // VoxelMarchOut VMO = VoxelMarch(b * hash.x, sunDir);
    //
    // vec3 clou = (c * vec3(1.0,2.0,1.0)+cameraPosition/100.0*hash.x);
    //
    // od *= float(!VMO.hit) * distance(a,b) / 10000.0;
    // // od *= float(!VMO.hit) * pow(calculateCloudShape(clou, vec3(0), 4), 4.0) * clamp((140.0 - clou.y) / 20.0, 0.0, 1.0);
    //
    // vec3 pene;
    //
    // inScatter = vec3(1.0,0.8,0.6) * od * 200.0;
    // inScatter = od * GetSunAndSkyIrradiance(kPoint(c), -normalize(a-b), sunDir, pene) * calculateCloudPhase(dot(normalize(b-a), sunDir))*50.0;
    // inScatter = vec3(18, 34, 59)/255.0 * od * 100.0;
    // inScatter = vec3(1,0.8,0.6) * od;
    // outScatter = vec3(1)*(1-od);
    // outScatter = outScatter;
}

#endif
