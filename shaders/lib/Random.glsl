#if !defined WANGHASH_GLSL
#define WANGHASH_GLSL

uint triple32(uint x) {
	// https://nullprogram.com/blog/2018/07/31/
    x ^= x >> 17;
    x *= 0xed5ad4bbu;
    x ^= x >> 11;
    x *= 0xac4c1b51u;
    x ^= x >> 15;
    x *= 0x31848babu;
    x ^= x >> 14;
    return x;
}

float WangHash(uint seed) {
	seed = (seed ^ 61) ^ (seed >> 16);
	seed *= 9;
	seed = seed ^ (seed >> 4);
	seed *= 0x27d4eb2d;
	seed = seed ^ (seed >> 15);
	return float(seed) / 4294967296.0;
}

vec2 WangHash(uvec2 seed) {
	seed = (seed ^ 61) ^ (seed >> 16);
	seed *= 9;
	seed = seed ^ (seed >> 4);
	seed *= 0x27d4eb2d;
	seed = seed ^ (seed >> 15);
	return vec2(seed) / 4294967296.0;
}

#if (ShaderStage >= 10)
	uint randState = triple32(uint(gl_FragCoord.x + viewSize.x * gl_FragCoord.y) + uint(viewSize.x * viewSize.y) * frameCounter);
	uint RandNext() { return randState = triple32(randState); }
	#define RandNext2() uvec2(RandNext(), RandNext())
	#define RandNext3() uvec3(RandNext2(), RandNext())
	#define RandNext4() uvec4(RandNext3(), RandNext())
	#define RandNextF() (float(RandNext()) / float(0xffffffffu))
	#define RandNext2F() (vec2(RandNext2()) / float(0xffffffffu))
	#define RandNext3F() (vec3(RandNext3()) / float(0xffffffffu))
	#define RandNext4F() (vec4(RandNext4()) / float(0xffffffffu))
#endif

float RandF (uint  seed) { return float(triple32(seed))                    / float(0xffffffffu); }
vec2  Rand2F(uvec2 seed) { return vec2(triple32(seed.x), triple32(seed.y)) / float(0xffffffffu); }

#define TAA_JITTER

vec2 TAAHash() {
	return (Rand2F(uvec2(frameCounter*2, frameCounter*2 + 1)) - 0.5) / viewSize;
}
#ifndef TAA_JITTER
	#define TAAHash() vec2(0.0)
#endif

#endif
