/***********************************************************************/
#if defined vsh

#include "lib/debug.glsl"

out vec3 vColor;

void main() {
	vColor = gl_Color.rgb;
	
	gl_Position = ftransform();
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

#include "lib/debug.glsl"

in vec3 vColor;

/* DRAWBUFFERS:123 */
#include "lib/exit.glsl"

void main() {
	gl_FragData[0] = vec4(vColor, 1.0);
	
	exit();
}

#endif
/***********************************************************************/
