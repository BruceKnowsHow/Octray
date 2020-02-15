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
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D shadowtex0;

const bool colortex0MipmapEnabled = true;
const bool colortex1MipmapEnabled = true;

uniform float frameTimeCounter;
uniform vec2 viewSize;
uniform int hideGUI;

#include "lib/Tonemap.glsl"

noperspective in vec2 texcoord;

#include "lib/exit.glsl"

#include "lib/Text.glsl"

#include "lib/Bloom.fsh"

//#define FRAME_ACCUMULATION_COUNTER

void main() {
	vec4 lookup = texture(colortex0, texcoord);
	beni = lookup.a;
	vec3 color = lookup.rgb / lookup.a;
	vec3 avgCol = texture(colortex0, texcoord, 16).rgb / texture(colortex0, texcoord, 16).a;
	float expo = 1.0 / dot(avgCol, vec3(0.2125, 0.7154, 0.0721));
	expo = 1.0;
#ifdef AUTO_EXPOSURE
	expo = pow(1.0 / dot(avgCol, vec3(3.0)), 0.7);
	
#endif
	
	color = GetBloom(color);
	color *= min(expo, 1000.0);
	
	color = Tonemap(color);
	
	gl_FragColor.rgb = color;
	
#ifdef FRAME_ACCUMULATION_COUNTER
	if (hideGUI == 0) {
		vec2 textcoord = texcoord;
		textcoord.x *= viewSize.x / viewSize.y;
		
		vec3 whiteText = vec3(text(textcoord));
		if (texcoord.x < 0.61 && texcoord.y > 0.94) gl_FragColor.rgb *= 0.5;
		gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(1.0), whiteText);
	}
#endif
	
	exit();
}

#endif
/***********************************************************************/
