#include "/../shaders/lib/utility.glsl"

float EncodeNormal(vec3 normal) {
	normal = clamp(normal, -1.0, 1.0);
	normal.xy = vec2(atan(normal.x, normal.z), acos(normal.y)) / PI;
	normal.x += 1.0;
	normal.xy = round(normal.xy * 2048.0);
	normal.y = min(normal.y, 2047.0);
	
	uvec2 enc = uvec2(normal.xy);
	enc.x = enc.x & 4095;
	enc.y = enc.y << uint(12);
	
	return uintBitsToFloat(enc.x + enc.y);
}

vec3 DecodeNormal(float enc) {
	uvec3 e = uvec3(floatBitsToUint(enc));
	e.y = e.y >> 12;
	e.xy = e.xy & uvec2(4095, 2047);
	
	vec4 normal;
	
	normal.xy   = e.xy;
	normal.xy  /= 2048.0;
	normal.x   -= 1.0;
	normal.xy  *= PI;
	normal.xwzy = vec4(sin(normal.xy), cos(normal.xy));
	normal.xz  *= normal.w;
	
	return normal.xyz;
}


// Packing functions for sending midTexCoord through the shadow depth buffer
// Outputs a float in the range [-1.0, 1.0], which is what gl_Position.z takes in
const vec2 tCoordBits = vec2(12.0, 11.0);
float packTexcoord(vec2 coord) {
	coord.rg = floor(coord.rg * exp2(tCoordBits));
	
	coord.r += coord.g * exp2(tCoordBits.x);
	
	coord.r = exp2(tCoordBits.x + tCoordBits.y) - coord.r; // Flip the priority ordering of textures. This causes the top-grass texture to have priority over side-grass
	
	return coord.r * exp2(-tCoordBits.x - tCoordBits.y + 1.0) - 1.0;
}

// The unpacking function takes a float in the range [0.0, 1.0], since this is what is read from the depth buffer
vec2 unpackTexcoord(float enc) {
	enc *= exp2(tCoordBits.x + tCoordBits.y);
	
	enc = exp2(tCoordBits.x + tCoordBits.y) - enc; // Undo the priority flip
	
	vec2 coord;
	coord.g = floor(enc * exp2(-tCoordBits.x));
	coord.r = mod(enc, exp2(tCoordBits.x));
	
	return coord * (exp2(-tCoordBits));
}


// Packing functions for sending vertex color through the shadow depth buffer
// Same constrains as mentioned above.
const vec3 vColorBits = vec3(8.0, 8.0, 7.0);
float packVertColor(vec3 color) {
	color = hsv(color);
	vec3 c = floor(color * (exp2(vColorBits) - 1.0));
	
	c.r += c.g * exp2(vColorBits.r);
	c.r += c.b * exp2(vColorBits.r + vColorBits.g);
	
	c.r = c.r * exp2(-vColorBits.r - vColorBits.g - vColorBits.b + 1.0) - 1.0;
	return c.r;
}

vec3 unpackVertColor(float enc) {
	vec3 c;
	
	c.r = enc * exp2(vColorBits.r + vColorBits.g + vColorBits.b);
	
	c.b = floor(c.r / exp2(vColorBits.r + vColorBits.g));
	c.g = floor(mod(c.r, exp2(vColorBits.r + vColorBits.g)) / exp2(vColorBits.r));
	c.r = mod(c.r, exp2(vColorBits.r));
	
	c /= exp2(vColorBits) - 1.0;
	return rgb(c);
}
