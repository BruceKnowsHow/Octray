/***********************************************************************/
#if defined vsh

uniform vec2 viewSize;

noperspective out vec2 texcoord;

void main() {
	texcoord    = gl_Vertex.xy;
	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

#include "/../shaders/lib/debug.glsl"
#include "/../shaders/lib/utility.glsl"

uniform sampler2D shadowtex0;

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

uniform vec2 viewSize;

noperspective in vec2 texcoord;

#include "/../shaders/lib/raytracing/WorldToVoxelCoord.glsl"

/* DRAWBUFFERS:5 */
#include "/../shaders/lib/exit.glsl"

void main() {
	const float h0 = 256.0 * shadowDiameter * shadowDiameter / shadowMapResolution;

	const ivec2 lodOffset[8] = ivec2[8](
		ivec2(0, 0), ivec2(0, h0), ivec2(0, h0*1.5), ivec2(0, h0*1.75),
		ivec2(0, h0*1.875), ivec2(0, h0*1.9375), ivec2(0, h0*1.96875), ivec2(0, h0*1.9921875));

	const int width = shadowMapResolution;
	const int widthl2 = int(log2(width));

	ivec2 b = ivec2(gl_FragCoord.st);
	b.y = b.y * 1280;

	int linenum = b.x + b.y;

	ivec2 coord =  ivec2(linenum % width, linenum >> widthl2) + lodOffset[3];
	
	show(texelFetch(shadowtex0, coord, 0))
	
	gl_FragData[0] = (texelFetch(shadowtex0, coord, 0));
	gl_FragData[0] = (1.0-texture(shadowtex0, texcoord, 0));
	exit();
}

#endif
/***********************************************************************/
