/***********************************************************************/
#if defined vsh

out vec3 vColor;

#include "../../lib/debug.glsl"

void main() {
	vColor = gl_Color.rgb;
	
	gl_Position = ftransform();
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

in vec3 vColor;

#include "../../lib/debug.glsl"

void main() {
	discard;
	// gl_FragData[0] = vec4(vColor, 1.0);
}

#endif
/***********************************************************************/
