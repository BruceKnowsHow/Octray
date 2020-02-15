#if !defined BLOOM_FSH
#define BLOOM_FSH

vec4 cubic(float x) {
	float x2 = x * x;
	float x3 = x2 * x;
	vec4 w;
	
	w.x =   -x3 + 3*x2 - 3*x + 1;
	w.y =  3*x3 - 6*x2       + 4;
	w.z = -3*x3 + 3*x2 + 3*x + 1;
	w.w =  x3;
	
	return w / 6.0;
}

vec3 BicubicTexture(sampler2D tex, vec2 coord) {
	coord *= viewSize;
	
	vec2 f = fract(coord);
	
	coord -= f;
	
	vec4 xcubic = cubic(f.x);
	vec4 ycubic = cubic(f.y);
	
	vec4 c = coord.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
	
	vec4 offset  = c + vec4(xcubic.yw, ycubic.yw) / s;
	     offset /= viewSize.xxyy;
	
	vec3 sample0 = texture2D(tex, offset.xz).rgb;
	vec3 sample1 = texture2D(tex, offset.yz).rgb;
	vec3 sample2 = texture2D(tex, offset.xw).rgb;
	vec3 sample3 = texture2D(tex, offset.yw).rgb;
	
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	
	return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

vec3 GetBloomTile(const int scale, vec2 offset) {
	vec2 coord  = texcoord;
	     coord /= scale;
	     coord += offset + 0.75/viewSize;
	
	return BicubicTexture(colortex1, coord);
	
	// return texture2D(colortex1, coord).rgb;
}

#define BLOOM_AMOUNT 0.15
#define BLOOM_CURVE 1.0

vec3 GetBloom(vec3 color) {
	vec3[8] bloom;
	
	// These arguments should be identical to those in composite2.fsh
	bloom[1] = GetBloomTile(  4, vec2(0.0                         ,                          0.0));
	bloom[2] = GetBloomTile(  8, vec2(0.0                         , 0.25     + 1/viewSize.y * 2.0));
	bloom[3] = GetBloomTile( 16, vec2(0.125    + 1/viewSize.x * 2.0, 0.25     + 1/viewSize.y * 2.0));
	bloom[4] = GetBloomTile( 32, vec2(0.1875   + 1/viewSize.x * 4.0, 0.25     + 1/viewSize.y * 2.0));
	bloom[5] = GetBloomTile( 64, vec2(0.125    + 1/viewSize.x * 2.0, 0.3125   + 1/viewSize.y * 4.0));
	bloom[6] = GetBloomTile(128, vec2(0.140625 + 1/viewSize.x * 4.0, 0.3125   + 1/viewSize.y * 4.0));
	bloom[7] = GetBloomTile(256, vec2(0.125    + 1/viewSize.x * 2.0, 0.328125 + 1/viewSize.y * 6.0));
	
	bloom[0] = vec3(0.0);
	
	for (uint index = 1; index <= 7; index++)
		bloom[0] += bloom[index];
	
	bloom[0] /= 7.0;
	
	return mix(color, min(pow(bloom[0], vec3(BLOOM_CURVE)), bloom[0]), BLOOM_AMOUNT);
}

#endif
