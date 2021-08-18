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
#if defined fsh

#define COLORSAMPLER colortex2
uniform sampler2D COLORSAMPLER;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec2 viewSize;
uniform int frameCounter;

vec2 texcoord = gl_FragCoord.xy / viewSize;

#include "../../lib/debug.glsl"
#include "../../lib/utility.glsl"
#include "../../lib/encoding.glsl"
#include "../../lib/Random.glsl"


vec2 Reproject() {
	float depth = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x;
	
	vec4 pene;
	pene = vec4(vec3(gl_FragCoord.xy / viewSize, depth) * 2.0 - 1.0, 1.0);
	
	vec4 position = pene;
	
	pene = gbufferModelViewInverse * gbufferProjectionInverse * pene;
	pene = pene / pene.w;
	
	pene.xyz += cameraPosition - previousCameraPosition;
	pene = gbufferPreviousProjection * gbufferPreviousModelView * pene;
	pene = pene / pene.w;
	pene.xy = pene.xy * 0.5 + 0.5;
	
	return pene.xy;
}

/* DRAWBUFFERS:265 */
#if (defined DEBUG) && (DEBUG_PROGRAM == ShaderStage)
	/* DRAWBUFFERS:2657 */
	#define DEBUG_OUT gl_FragData[3]
#endif
#include "../../lib/exit.glsl"

float linearizeDepth(float depth, mat4 projectionMatInverse) {
	return -1.0 / ((depth * 2.0 - 1.0) * projectionMatInverse[2].w + projectionMatInverse[3].w);
}

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
	
	vec4 accum = texture(colortex5, texcoord);
	
	ivec2 icoord0 = ivec2(gl_FragCoord.xy);
	
	for (int i = -kernal; i <= kernal; i += 1 << ATROUS_INDEX) {
		for (int j = -kernal; j <= kernal; j += 1 << ATROUS_INDEX) {
			ivec2 icoord = icoord0 + ivec2(vec2(i,j) / sqrt(accum.a));
			
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
	
	
	ivec2 old = ivec2(Reproject()*viewSize);
	
	float depthOld = texture2D(depthtex0, Reproject()).x;
	vec4 oldPos = vec4(Reproject(), depthOld, 1.0) * 2.0 - 1.0;
	oldPos = inverse(gbufferPreviousModelView) * inverse(gbufferPreviousProjection) * oldPos;
	oldPos = oldPos / oldPos.w;
	oldPos.xyz -= cameraPosition - previousCameraPosition;
	
	vec4 pos = vec4(gl_FragCoord.xy/viewSize, texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x, 1.0) * 2.0 - 1.0;
	pos = gbufferModelViewInverse * gbufferProjectionInverse * pos;
	pos = pos / pos.w;
	
	// show(abs(pos.xyz-oldPos.xyz))
	
	// vec4 prevLight = vec4(0.0);
	
	// ivec2 pix0 = ivec2(Reproject() * viewSize);
	
	// for (int i = -1; i <= 1; ++i) {
	// 	for (int j = -1; j <= 1; ++j) {
	// 		ivec2 point = pix0 + ivec2(i,j);
	// 		prevLight += texelFetch(colortex5, point, 0) / 9.0 * max(0.0, 1.0 - distance(texcoord, Reproject()) / sqrt(2000));
	// 	}
	// }
	
	// if (any(greaterThan(abs(Reproject() - vec2(0.5)), vec2(0.5)))) prevLight = vec4(0.0);
	
	
	gl_FragData[0] = vec4(col);
	gl_FragData[1] = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).xxxx;
	// show(abs(texture2D(colortex6, Reproject()).rgb - texture2D(colortex0, texcoord).rgb))
	// show(abs(texture2D(colortex6, Reproject()).a - texture2D(colortex0, texcoord).a))
	// show(abs(linearizeDepth(texture2D(colortex6, Reproject()).r, gbufferProjectionInverse) - linearizeDepth(texture2D(depthtex0, Reproject()).x, gbufferProjectionInverse)) * 1.0)
	// show(accum.rgb / accum.a)
	// gl_FragData[2] = prevLight;
	exit();
}

#endif
/***********************************************************************/
