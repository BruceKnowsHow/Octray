#define WHITEWORLD Off // [On Off]

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

#include "lib/debug.glsl"
#include "lib/utility.glsl"
#include "lib/encoding.glsl"

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex5;

uniform bool accum;

noperspective in vec2 texcoord;

/* DRAWBUFFERS:5 */
#include "lib/exit.glsl"

void main() {
	vec3 albedo = texture(colortex1, texcoord).rgb;
	
	vec4 prevCol = max(texture(colortex5, texcoord), 0) * float(accum);
	vec4 currCol = texture(colortex2, texcoord);
	
	if (!WHITEWORLD) {
		currCol.rgb *= albedo;
	}
	
	gl_FragData[0] = prevCol + currCol;
	
	exit();
}

#endif
/***********************************************************************/
