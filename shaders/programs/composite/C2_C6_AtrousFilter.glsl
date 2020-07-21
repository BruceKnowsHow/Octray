#define ATROUS_FILTER

#define ATROUS_FILTER_PASSES_1
#define ATROUS_FILTER_PASSES_2
#define ATROUS_FILTER_PASSES_3
#define ATROUS_FILTER_PASSES_4
#define ATROUS_FILTER_PASSES_5

#ifdef ATROUS_FILTER
#endif
#ifdef ATROUS_FILTER_PASSES_1
#endif
#ifdef ATROUS_FILTER_PASSES_2
#endif
#ifdef ATROUS_FILTER_PASSES_3
#endif
#ifdef ATROUS_FILTER_PASSES_4
#endif
#ifdef ATROUS_FILTER_PASSES_5
#endif

/***********************************************************************/
#if defined vsh

noperspective out vec2 texcoord;

void main() {
	texcoord    = gl_Vertex.xy;
	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

#define COLORSAMPLER colortex2
uniform sampler2D COLORSAMPLER;
uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform vec2 viewSize;

noperspective in vec2 texcoord;

#include "../../lib/debug.glsl"
#include "../../lib/utility.glsl"
#include "../../lib/encoding.glsl"

/* DRAWBUFFERS:2 */
#if (defined DEBUG) && (DEBUG_PROGRAM == ShaderStage)
	/* DRAWBUFFERS:27 */
	#define DEBUG_OUT gl_FragData[1]
#endif
#include "../../lib/exit.glsl"

void main() {
	if (texture(depthtex0, texcoord).x >= 1.0) {
		gl_FragData[0] = texture(COLORSAMPLER, texcoord);
		return;
	}
	
	vec4 col = vec4(0);
	
	int kernal = 1 << ATROUS_INDEX;
	float weights = 0.0;
	
	vec4 color0 = texture(COLORSAMPLER, texcoord);
	vec3 normal = texture(colortex0, texcoord).rgb;
	float vDepth = texture(colortex0, texcoord).a;
	
	float accum = texture(colortex5, texcoord).a;
	
	for (int i = -kernal; i <= kernal; i += 1 << ATROUS_INDEX) {
		for (int j = -kernal; j <= kernal; j += 1 << ATROUS_INDEX) {
			ivec2 icoord = ivec2(gl_FragCoord.xy) + ivec2(vec2(i,j) / sqrt(accum));
			
			vec3 samplenormal = texelFetch(colortex0, icoord, 0).rgb;
			float sampledepth = texelFetch(colortex0, icoord, 0).a;
			vec4 color = texelFetch(COLORSAMPLER, icoord, 0);
			
			float weight = 1.0;
			// weight *= pow(length(16 - vec2(i,j)) / 16.0, 2.0);
			weight *= max(dot(normal, samplenormal)*16-15, 0.0);
			weight *= max(1.0-distance(vDepth, sampledepth), 0.0);
			weight = weight + 0.000001;
			
			col += color * weight;
			weights += weight;
		}
	}
	
	col /= weights;
	
	
	#if ATROUS_INDEX < 4
		gl_FragData[0] = vec4(col);
	#else
		gl_FragData[0] = vec4(col);
	#endif
	
	exit();
}

#endif
/***********************************************************************/
