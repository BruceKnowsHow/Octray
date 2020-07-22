/***********************************************************************/
#if defined fsh

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform mat4  gbufferPreviousProjection;
uniform mat4  gbufferProjectionInverse;
uniform mat4  gbufferModelViewInverse;
uniform mat4  gbufferPreviousModelView;
uniform vec3  cameraPosition;
uniform vec3  previousCameraPosition;
uniform vec2  viewSize;
uniform float frameTimeCounter;
uniform int   frameCounter;
uniform int   hideGUI;

vec2 texcoord = gl_FragCoord.xy / viewSize * MC_RENDER_QUALITY;

const bool colortex2MipmapEnabled = true;
const bool colortex3MipmapEnabled = true;
const bool colortex4MipmapEnabled = true;
const bool colortex5MipmapEnabled = true;

#include "../../lib/debug.glsl"
#include "../../lib/Tonemap.glsl"
#include "../../lib/exit.glsl"
#include "../../lib/Text.glsl"


vec4 cubic(float x) {
	float x2 = x * x;
	float x3 = x2 * x;
	vec4 w;
	
	w.x =   -x3 + 3*x2 - 3*x + 1;
	w.y =  3*x3 - 6*x2       + 4;
	w.z = -3*x3 + 3*x2 + 3*x + 1;
	w.w =  x3;
	
	return w / 6.0;
}

vec3 BicubicTexture(sampler2D tex, vec2 coord) {
	coord *= viewSize;
	
	vec2 f = fract(coord);
	
	coord -= f;
	
	vec4 xcubic = cubic(f.x);
	vec4 ycubic = cubic(f.y);
	
	vec4 c = coord.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
	
	vec4 offset  = c + vec4(xcubic.yw, ycubic.yw) / s;
	     offset /= viewSize.xxyy;
	
	vec3 sample0 = texture2D(tex, offset.xz).rgb;
	vec3 sample1 = texture2D(tex, offset.yz).rgb;
	vec3 sample2 = texture2D(tex, offset.xw).rgb;
	vec3 sample3 = texture2D(tex, offset.yw).rgb;
	
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	
	return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

vec3 GetBloomTile(sampler2D tex, const int scale, vec2 offset) {
	vec2 coord  = texcoord;
	     coord /= scale;
	     coord += offset + 0.75/viewSize;
	
	return BicubicTexture(tex, coord);
}

#define BLOOM
#define BLOOM_AMOUNT 0.15
#define BLOOM_CURVE 1.0

vec3 GetBloom(sampler2D tex, vec3 color) {
	vec3 bloom[8];
	
	// These arguments should be identical to those in composite2.fsh
	bloom[1] = GetBloomTile(tex,   4, vec2(0.0                         ,                          0.0));
	bloom[2] = GetBloomTile(tex,   8, vec2(0.0                         , 0.25     + 1/viewSize.y * 2.0));
	bloom[3] = GetBloomTile(tex,  16, vec2(0.125    + 1/viewSize.x * 2.0, 0.25     + 1/viewSize.y * 2.0));
	bloom[4] = GetBloomTile(tex,  32, vec2(0.1875   + 1/viewSize.x * 4.0, 0.25     + 1/viewSize.y * 2.0));
	bloom[5] = GetBloomTile(tex,  64, vec2(0.125    + 1/viewSize.x * 2.0, 0.3125   + 1/viewSize.y * 4.0));
	bloom[6] = GetBloomTile(tex, 128, vec2(0.140625 + 1/viewSize.x * 4.0, 0.3125   + 1/viewSize.y * 4.0));
	bloom[7] = GetBloomTile(tex, 256, vec2(0.125    + 1/viewSize.x * 2.0, 0.328125 + 1/viewSize.y * 6.0));
	
	bloom[0] = vec3(0.0);
	
	for (uint index = 1; index <= 7; index++)
		bloom[0] += bloom[index];
	
	bloom[0] /= 7.0;
	
	// return color + bloom[0];
	
	return mix(color, min(pow(bloom[0], vec3(BLOOM_CURVE)), bloom[0]), BLOOM_AMOUNT);
}
#ifndef BLOOM
	#define GetBloom(tex, color) (color)
#endif


#define MOTION_BLUR
#define MOTION_BLUR_INTENSITY 1.0
#define MAX_MOTION_BLUR_AMOUNT 1.0
#define VARIABLE_MOTION_BLUR_SAMPLES 1
#define VARIABLE_MOTION_BLUR_SAMPLE_COEFFICIENT 1.0
#define MAX_MOTION_BLUR_SAMPLE_COUNT 50
#define CONSTANT_MOTION_BLUR_SAMPLE_COUNT 2

vec3 MotionBlur(vec3 color) {
	float depth = texture(depthtex0, texcoord).x;
	
	vec4 pene;
	pene = vec4(vec3(texcoord, depth) * 2.0 - 1.0, 1.0);
	
	vec4 position = pene;
	
	pene = gbufferProjectionInverse * pene;
	pene = pene / pene.w;
	pene = gbufferModelViewInverse * pene;
	
	pene.xyz = pene.xyz + (cameraPosition - previousCameraPosition) * clamp(length(pene.xyz - gbufferModelViewInverse[3].xyz) / 2.0 - 1.0, 0.0, 1.0);
	pene = gbufferPreviousModelView * pene;
	pene = gbufferPreviousProjection * pene;
	pene = pene / pene.w;
	
	float intensity = MOTION_BLUR_INTENSITY * 0.5;
	float maxVelocity = MAX_MOTION_BLUR_AMOUNT * 0.1;
	
	vec2 velocity = (position.st - pene.st) * intensity; // Screen-space motion vector
	     velocity = clamp(velocity, vec2(-maxVelocity), vec2(maxVelocity));
	
	float sampleCount = length(velocity * viewSize) * VARIABLE_MOTION_BLUR_SAMPLE_COEFFICIENT; // There should be exactly 1 sample for every pixel when the sample coefficient is 1.0
	      sampleCount = floor(clamp(sampleCount, 1, MAX_MOTION_BLUR_SAMPLE_COUNT));
	
	vec2 sampleStep = velocity / sampleCount;
	vec2 offset = sampleStep;
	
	for(float i = 1.0; i <= sampleCount; i++) {
		vec2 coord = texcoord + sampleStep * i - offset;
		
		color += texture2D(colortex5, coord).rgb;
	}
	
	return color / max(sampleCount + 1.0, 1.0);
}
#ifndef MOTION_BLUR
	#define MotionBlur(color) (color)
#endif


#define AUTO_EXPOSURE On // [On Off]
#define DRAW_DEBUG_VALUE

void main() {
	vec4 lookup = texture(colortex5, texcoord);
	// vec3 color = texture(colortex5, texcoord).rgb;
	vec3 color = lookup.rgb;
	vec3 avgCol = textureLod(colortex5, vec2(0.5), 16).rgb / textureLod(colortex5, vec2(0.5), 16).a;
	float expo = 1.0 / dot(avgCol, vec3(0.2125, 0.7154, 0.0721));
	expo = 1.0;
	if (AUTO_EXPOSURE) {
		expo = pow(1.0 / dot(avgCol, vec3(3.0)), 0.7);
	}
	
	color = MotionBlur(color);
	color *= min(expo, 1000.0);
	color = color / lookup.a;
	color = GetBloom(colortex3, color);
	
	color = Tonemap(color);
	
	gl_FragColor.rgb = color;
	
	exit();
	
	#if (defined DEBUG) && (defined DRAW_DEBUG_VALUE) && (DEBUG_PROGRAM != 50)
		if (hideGUI == 0) {
			vec2 textcoord = texcoord ;
			textcoord.x *= viewSize.x / viewSize.y;
			textcoord = textcoord ;
			vec2 fix = viewSize.yy / viewSize;
			
			vec3 whiteText = vec3(DrawDebugValue(textcoord));
			
			float centerDist = sqrt(dot((texcoord - vec2(0.5))/fix, (texcoord - vec2(0.5))/fix));
			if (texcoord.x < 0.21 && texcoord.y > 0.85) gl_FragColor.rgb *= 0.0;
			gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(1.0), whiteText);
		}
	#endif
}

#endif
/***********************************************************************/
