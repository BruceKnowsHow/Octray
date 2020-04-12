// Packing functions for sending midTexCoord through the shadow depth buffer
// Outputs a float in the range (-1.0, 1.0), which is what gl_Position.z takes in
const vec3 B = vec3(0.0, 12.0, 12.0);
float packTexcoord(vec2 coord) {
	float matID = floor(255.0)*0;
	
	coord.rg = floor(coord.rg * exp2(B.gb));
	
	float result = 0.0;
	
	result += matID;
	result += coord.r * exp2(B.r);
	result += coord.g * exp2(B.r + B.g);
	
	result = exp2(B.r + B.g + B.b) - result; // Flip the priority ordering of textures. This causes the top-grass texture to have priority over side-grass
	result = result / exp2(B.r + B.g + B.b - 1.0) - 1.0; // Compact into range (-1.0, 1.0)
	
	return result;
}

// The unpacking function takes a float in the range (0.0, 1.0), since this is what is read from the depth buffer
vec2 unpackTexcoord(float enc) {
	enc *= exp2(B.r + B.g + B.b); // Expand from range (-1.0, 1.0)
	enc  = exp2(B.r + B.g + B.b) - enc; // Undo the priority flip
	
	vec2 coord;
	float matID = mod(floor(enc), exp2(B.r));
	coord.r = mod(floor(enc / exp2(B.r      )), exp2(B.g));
	coord.g = mod(floor(enc / exp2(B.r + B.g)), exp2(B.b));
	
	return coord * (exp2(-B.gb));
}

vec3 RT_hsv(vec3 c) {
	const vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 RT_rgb(vec3 c) {
	const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

uint RT_f32tof16(float val) {
	uint f32 = floatBitsToUint(val);
	int exponent = clamp(int((f32 >> 23u) & 0xFFu) - 127 + 31, 0, 63);

	return uint(exponent << 10u) | ((f32 & 0x007FFFFFu) >> 13u);
}

float RT_f16tof32(uint val) {
	int exponent = int((val & 0xFC00u) >> 10) - 31;
	
	float scale = float(1 << abs(exponent));
	      scale = (exponent < 0) ? 1.0 / scale : scale;

	float decimal = 1.0 + float(val & 0x03FFu) / float(1 << 10);

	return scale * decimal;
}

float RT_pack2x1(vec2 v) {
	const uint mask0 = (1 << 16) - 1;
	const uint mask1 = ~mask0;
	
	uint ret = RT_f32tof16(v.x) | (RT_f32tof16(v.y) << 16);
	
	return uintBitsToFloat(ret);
}

vec2 RT_unpack2x1(float v) {
	const uint mask0 = (1 << 16) - 1;
	const uint mask1 = ~mask0;
	
	uint t = floatBitsToUint(v);
	
	return vec2(RT_f16tof32(t & mask0), RT_f16tof32(t >> 16));
}

vec2 RT_packColor(vec3 col) {
	return vec2(col.r, RT_pack2x1(col.gb));
}

vec3 RT_unpackColor(vec2 col) {
	return vec3(col.r, RT_unpack2x1(col.g));
}

vec2 RT_EncodeNormalSnorm(vec3 normal) {
	normal = normalize(normal);
	normal.y = uintBitsToFloat((floatBitsToUint(normal.y) & (~1)) | (floatBitsToUint(normal.z) >> 31));
	return normal.xy;
}

vec3 RT_DecodeNormalSnorm(vec2 norm) {
	float z = 1.0 - 2.0*float(floatBitsToInt(norm.y) & (1));
	norm.y = uintBitsToFloat((floatBitsToUint(norm.y)) & (~1));
	z *= sqrt(1.0- dot(norm, norm));
	
	return vec3(norm, z+1e-35);
}
