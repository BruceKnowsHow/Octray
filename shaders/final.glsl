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

#include "/../shaders/lib/debug.glsl"
uniform sampler2D colortex0;

#include "/../shaders/lib/settings/shadows.glsl"

noperspective in vec2 texcoord;

#include "/../shaders/lib/exit.glsl"

void main() {
	vec3 color = texture(colortex0, texcoord).rgb;
	
	gl_FragColor.rgb = color;
	
	exit();
}

#endif
/***********************************************************************/
