vec2 rotate(vec2 vector, float radians) {
	return vector *= mat2(
		cos(radians), -sin(radians),
		sin(radians),  cos(radians));
}

#define DEFORM_NONE 0
#define DEFORM_PLANET 1
#define DEFORM_ACID 2

#define DEFORM DEFORM_NONE // [DEFORM_PLANET DEFORM_NONE DEFORM_ACID]

vec3 DeformAcid(vec3 pos) {
    float time = 1000.0;
    
	float preRotation = time / 5.0;
	
	pos.xz = rotate(pos.xz, preRotation);
	
	vec3 ret = pos;
	
	float distance2D = dot(pos.xz, pos.xz) / 1000.0;
	
	ret.y += 5.0 * sin(distance2D * sin(time / 7.0));
	
	pos = ret;
	
	float om = sin(distance2D * sin(time / 13.0) / 5.0) * sin(time / 10.0);
	
	ret.xy = rotate(ret.xy, om);
	
	ret.xz = rotate(ret.xz, -preRotation);
	
	return ret;
}

vec3 DeformPlanet(vec3 pos) {
    #define PLANET_RADIUS 1.0 // [1/4f 2/4f 3/4f 1.0 1.5 2.0 3.0]
    
    vec3 ret = pos;
    
    float distance2D = dot(pos.xz, pos.xz);
    
    vec2 sphereAngle = ret.xz / (far * 2.0) * 3.14 / 2.0 / (PLANET_RADIUS);
    
    vec3 zFirst = ret;
    vec3 xFirst = ret;
    
    xFirst.yx = rotate(xFirst.yx, sphereAngle.x);
    xFirst.yz = rotate(xFirst.yz, sphereAngle.y);
    
    zFirst.yz = rotate(zFirst.yz, sphereAngle.y);
    zFirst.yx = rotate(zFirst.yx, sphereAngle.x);
    
    ret = mix(zFirst, xFirst, 0.5);
    
    // discardflag += float(any(!equal(sign(ret.xz), sign(pos.xz))));
    
    return ret;
}

#if DEFORM == DEFORM_PLANET
    #define Deform(x) DeformPlanet(x)
#elif DEFORM == DEFORM_ACID
    #define Deform(x) DeformAcid(x)
#else
    #define Deform(x) x
#endif
