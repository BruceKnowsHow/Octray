#if !defined ENCODING_GLSL
#define ENCODING_GLSL

#include "/../shaders/lib/utility.glsl"

vec2 EncodeNormal(vec3 normal) {
    return vec2(normal.xy * inversesqrt(normal.z * 8.0 + 8.0) + 0.5);
}

vec3 DecodeNormal(vec2 encodedNormal) {
	encodedNormal = encodedNormal * 4.0 - 2.0;
	float f = dot(encodedNormal, encodedNormal);
	float g = sqrt(1.0 - f * 0.25);
	return vec3(encodedNormal * g, 1.0 - f * 0.5);
}


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
	coord.r = mod(floor(enc / exp2(B.r)), exp2(B.g));
	coord.g = mod(floor(enc / exp2(B.r + B.g)), exp2(B.b));
	
	return coord * (exp2(-B.gb));
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

float EncodeTBNU(mat3 tbnMatrix) {
	vec3 tangent = tbnMatrix[0];
	vec3 normal = tbnMatrix[2];
	
	vec3 tanReferenceA = (dot(normalize(vec3(1,1,-1)), normal) < 0.0) ? normalize(vec3(1,-1,1)) : normalize(vec3(1,1,1));
	vec3 tanReference = normalize(cross(tanReferenceA, normal));
	
	float angle = acos(dot(tanReference, tangent));
	vec3 axis = normalize(cross(tanReference, tangent));
	
	normal = clamp(normal, -1.0, 1.0);
	normal.xy = vec2(atan(normal.x, normal.z), acos(normal.y)) / PI; // Range vec2([-1.0, 1.0], [0.0, 1.0])
	normal.x += 1.0; // Range [0.0, 2.0]
	normal.xy = round(normal.xy * 1024.0); // Range vec2([0.0, 2048.0], [0.0, 1024.0])
//	normal.y = min(normal.y, 1023.0); // Range [0.0, 1024.0)
	normal.y = mod(normal.y, 1024.0); // Range [0.0, 1024.0)
	
	uvec3 enc;
	enc.xy = uvec2(normal.xy);
	enc.x = enc.x & 2047; // Wrap around the value 2048
	enc.y = enc.y << 11;  // Multiply by 2048
	
	
	angle = acos(dot(tanReference, tangent))*sign(dot(tbnMatrix[0], tanReferenceA));
	angle /= PI;
	angle += 1.0;
	angle = round(angle * 1024.0);
//	angle = min(angle, 2047.0);
	angle = mod(angle, 2048.0);
	
	enc.z = uint(angle) << 21;
	
	return uintBitsToFloat(enc.x + enc.y + enc.z); // X occupies first 12 bits, Y occupies next 11 bits
}

mat3 DecodeTBNU(float enc) {
	uvec3 e = uvec3(floatBitsToUint(enc));
	e.yz = e.yz >> uvec2(11, 21);
	e.xy = e.xy & uvec2(2047, 1023);
	
	vec4 normal;
	
	normal.xy   = e.xy;
	normal.xy  /= 1024.0;
	normal.x   -= 1.0;
	normal.xy  *= PI;
	normal.xwzy = vec4(sin(normal.xy), cos(normal.xy));
	normal.xz  *= normal.w;
	
	
	vec3 tanReferenceA = (dot(normalize(vec3(1,1,-1)), normal.xyz) < 0.0) ? normalize(vec3(1,-1,1)) : normalize(vec3(1,1,1));
	vec3 tanReference = normalize(cross(tanReferenceA, normal.xyz));
	
	float angle = float(e.z);
	angle /= 1024.0;
	angle -= 1.0;
	angle *= PI;
	
	mat3 tbnMatrix;
	tbnMatrix[0] = tanReference * rotate(normal.xyz, angle);
	tbnMatrix[2] = normal.xyz;
	tbnMatrix[1] = normalize(cross(tbnMatrix[0], tbnMatrix[2]));
	
	return tbnMatrix;
}

float EncodeNormalU(vec3 normal) {
	normal = clamp(normal, -1.0, 1.0);
	normal.xy = vec2(atan(normal.x, normal.z), acos(normal.y)) / PI; // Range vec2([-1.0, 1.0], [0.0, 1.0])
	normal.x  = normal.x + 1.0; // Range [0.0, 2.0]
	normal.xy = round(normal.xy * 1024.0); // Range vec2([0.0, 2048.0], [0.0, 1024.0])
//	normal.y = min(normal.y, 1023.0); // Range [0.0, 1024.0)
//	normal.y = mod(normal.y, 1024.0); // Range [0.0, 1024.0)
	
	uvec2 enc = uvec2(normal.xy);
	enc.x =  enc.x & 2047; // Wrap around the value 2048
	enc.y = (enc.y & 1023) << 11;  // Multiply by 2048
	
	return uintBitsToFloat(enc.x + enc.y); // X occupies first 11 bits, Y occupies next 10 bits
}

vec3 DecodeNormalU(float enc) {
	uvec2 e = uvec2(floatBitsToUint(enc));
	e.y = e.y >> 11;
	e.xy = e.xy & uvec2(2047, 1023);
	
	vec4 normal;
	
	normal.xy   = e.xy;
	normal.xy  /= 1024.0;
	normal.x    = normal.x - 1.0;
	normal.xy  *= PI;
	normal.xwzy = vec4(sin(normal.xy), cos(normal.xy));
	normal.xz  *= normal.w;
	
	return normal.xyz;
}

float pack2x8(vec2 a) {
	a = round(clamp(a, 0.0, 1.0) * 255.0);
	return (a.x + a.y * 256.0) / (256.0*255.0);
}

vec2 unpack2x8(float enc) {
	enc *= 256.0*255.0;
	vec2 a;
	a.y = floor(enc / 256.0);
	a.x = enc - a.y*256.0;
	
	return a / 255.0;
}

float pack4x8(vec4 v) {
	v = round(clamp(v, 0.0, 1.0) * 255.0);
	uvec4 u = uvec4(v) << uvec4(0, 8, 16, 24);
	return uintBitsToFloat(u.r + u.g + u.b + u.a);
}

vec4 unpack4x8(float e) {
	uvec4 u = floatBitsToUint(e) >> uvec4(0, 8, 16, 24);
	return vec4(u % 256) / 255.0;
}



struct Mask {
	bool isWater;
	bool isVoxelized;
	bool isTranslucent;
	bool isEntity;
};

/*
float EncodeMaterialIDs(vec4 flags) {
	uvec4 u = uvec4(round(clamp(flags, 0.0, 1.0))) << uvec4(0, 1, 2, 3);
	return float(u.r + u.g + u.b + u.a) / 16.0;
}

vec4 DecodeMaterialIDs(float e) {
	uvec4 u = e * 16.0;
	return floor(mod(flags, 2.0));
}

float GetMaterialMask(float mask, float materialID) {
	return float(abs(materialID - mask) < 0.1);
}

Mask CalculateMasks(float materialIDs) {
	Mask mask;
	
	mask.materialIDs = materialIDs;
	mask.matIDs      = materialIDs;
	
	DecodeMaterialIDs(mask.matIDs, mask.bits);
	
	mask.translucent = GetMaterialMask(2, mask.matIDs);
	mask.emissive    = GetMaterialMask(3, mask.matIDs);
	mask.hand        = GetMaterialMask(5, mask.matIDs);
	
	mask.transparent = mask.bits.x;
	mask.water       = mask.bits.y;
	
	return mask;
}
*/

#endif
