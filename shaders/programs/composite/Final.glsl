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
#include "../../lib/exit.glsl"
#include "../../lib/Tonemap.glsl"
#include "../../lib/utility.glsl"


/***********************************************************************/
/* Text Rendering */
const int
	_A    = 0x64bd29, _B    = 0x749d27, _C    = 0xe0842e, _D    = 0x74a527,
	_E    = 0xf09c2f, _F    = 0xf09c21, _G    = 0xe0b526, _H    = 0x94bd29,
	_I    = 0xf2108f, _J    = 0x842526, _K    = 0x9284a9, _L    = 0x10842f,
	_M    = 0x97a529, _N    = 0x95b529, _O    = 0x64a526, _P    = 0x74a4e1,
	_Q    = 0x64acaa, _R    = 0x749ca9, _S    = 0xe09907, _T    = 0xf21084,
	_U    = 0x94a526, _V    = 0x94a544, _W    = 0x94a5e9, _X    = 0x949929,
	_Y    = 0x94b90e, _Z    = 0xf4106f, _0    = 0x65b526, _1    = 0x431084,
	_2    = 0x64904f, _3    = 0x649126, _4    = 0x94bd08, _5    = 0xf09907,
	_6    = 0x609d26, _7    = 0xf41041, _8    = 0x649926, _9    = 0x64b904,
	_APST = 0x631000, _PI   = 0x07a949, _UNDS = 0x00000f, _HYPH = 0x001800,
	_TILD = 0x051400, _PLUS = 0x011c40, _EQUL = 0x0781e0, _SLSH = 0x041041,
	_EXCL = 0x318c03, _QUES = 0x649004, _COMM = 0x000062, _FSTP = 0x000002,
	_QUOT = 0x528000, _BLNK = 0x000000, _COLN = 0x000802, _LPAR = 0x410844,
	_RPAR = 0x221082;

const ivec2 MAP_SIZE = ivec2(5, 5);

int GetBit(int bitMap, int index) {
	return (bitMap >> index) & 1;
}

float DrawChar(int charBitMap, inout vec2 anchor, vec2 charSize, vec2 uv) {
	uv = (uv - anchor) / charSize;
	
	anchor.x += charSize.x;
	
	if (!all(lessThan(abs(uv - vec2(0.5)), vec2(0.5))))
		return 0.0;
	
	uv *= MAP_SIZE;
	
	int index = int(uv.x) % MAP_SIZE.x + int(uv.y)*MAP_SIZE.x;
	
	return GetBit(charBitMap, index);
}

const int STRING_LENGTH = 8;
int[STRING_LENGTH] drawString;

float DrawString(inout vec2 anchor, vec2 charSize, int stringLength, vec2 uv) {
	uv = (uv - anchor) / charSize;
	
	anchor.x += charSize.x * stringLength;
	
	if (!all(lessThan(abs(uv / vec2(stringLength, 1.0) - vec2(0.5)), vec2(0.5))))
		return 0.0;
	
	int charBitMap = drawString[int(uv.x)];
	
	uv *= MAP_SIZE;
	
	int index = int(uv.x) % MAP_SIZE.x + int(uv.y)*MAP_SIZE.x;
	
	return GetBit(charBitMap, index);
}

#define log10(x) (log2(x) / log2(10.0))

float DrawInt(int val, inout vec2 anchor, vec2 charSize, vec2 uv) {
	if (val == 0) return DrawChar(_0, anchor, charSize, uv);
	
	const int _DIGITS[10] = int[10](_0,_1,_2,_3,_4,_5,_6,_7,_8,_9);
	
	bool isNegative = val < 0.0;
	
	if (isNegative) drawString[0] = _HYPH;
	
	val = abs(val);
	
	int posPlaces = int(ceil(log10(abs(val) + 0.001)));
	int strIndex = posPlaces - int(!isNegative);
	
	while (val > 0) {
		drawString[strIndex--] = _DIGITS[val % 10];
		val /= 10;
	}
	
	return DrawString(anchor, charSize, posPlaces + int(isNegative), texcoord);
}

float DrawFloat(float val, inout vec2 anchor, vec2 charSize, int negPlaces, vec2 uv) {
	int whole = int(val);
	int part  = int(fract(abs(val)) * pow(10, negPlaces));
	
	int posPlaces = max(int(ceil(log10(abs(val)))), 1);
	
	anchor.x -= charSize.x * (posPlaces + int(val < 0) + 0.25);
	float ret = 0.0;
	ret += DrawInt(whole, anchor, charSize, uv);
	ret += DrawChar(_FSTP, anchor, charSize, texcoord);
	anchor.x -= charSize.x * 0.3;
	ret += DrawInt(part, anchor, charSize, uv);
	
	return ret;
}

void DrawDebugText() {
	#if (defined DEBUG) && (defined DRAW_DEBUG_VALUE) && (DEBUG_PROGRAM != 50)
		vec2 charSize = vec2(0.03) * viewSize.yy / viewSize;
		vec2 texPos = vec2(charSize.x / 5.0, 1.0 - charSize.y * 1.2);
		
		if (hideGUI != 0
		 || texcoord.x > charSize.x * 12.0
		 || texcoord.y < 1 - charSize.y * 4.5)
		{ return; }
		
		vec3 color = vec3(0.0);
		float text = 0.0;
		
		vec3 val = texelFetch(colortex7, ivec2(viewSize/2.0), 0).rgb;
		
		drawString = int[STRING_LENGTH](_R,_COLN, 0,0,0,0,0,0);
		text += DrawString(texPos, charSize, 2, texcoord);
		texPos.x += charSize.x * 5.0;
		text += DrawFloat(val.r, texPos, charSize, 4, texcoord);
		color += text * vec3(1.0, 0.0, 0.0) * sqrt(clamp(abs(val.r), 0.2, 1.0));
		
		texPos.x = charSize.x / 5.0, 1.0;
		texPos.y -= charSize.y * 1.4;
		
		text = 0.0;
		drawString = int[STRING_LENGTH](_G,_COLN, 0,0,0,0,0,0);
		text += DrawString(texPos, charSize, 2, texcoord);
		texPos.x += charSize.x * 5.0;
		text += DrawFloat(val.g, texPos, charSize, 4, texcoord);
		color += text * vec3(0.0, 1.0, 0.0) * sqrt(clamp(abs(val.g), 0.2, 1.0));
		
		texPos.x = charSize.x / 5.0, 1.0;
		texPos.y -= charSize.y * 1.4;
		
		text = 0.0;
		drawString = int[STRING_LENGTH](_B,_COLN, 0,0,0,0,0,0);
		text += DrawString(texPos, charSize, 2, texcoord);
		texPos.x += charSize.x * 5.0;
		text += DrawFloat(val.b, texPos, charSize, 4, texcoord);
		color += text * vec3(0.0, 0.8, 1.0)* sqrt(clamp(abs(val.b), 0.2, 1.0));
		
		gl_FragColor.rgb = color;
	#endif
}
/***********************************************************************/


/***********************************************************************/
/* Bloom */
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
	#ifndef BLOOM
		return color;
	#endif
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
	
	return mix(color, min(pow(bloom[0], vec3(BLOOM_CURVE)), bloom[0]), BLOOM_AMOUNT);
}
/***********************************************************************/


/***********************************************************************/
/* Motion Blur */
#define MOTION_BLUR
#define MOTION_BLUR_INTENSITY 1.0
#define MAX_MOTION_BLUR_AMOUNT 1.0
#define VARIABLE_MOTION_BLUR_SAMPLES 1
#define VARIABLE_MOTION_BLUR_SAMPLE_COEFFICIENT 1.0
#define MAX_MOTION_BLUR_SAMPLE_COUNT 50
#define CONSTANT_MOTION_BLUR_SAMPLE_COUNT 2

vec3 MotionBlur(vec3 color) {
	#ifndef MOTION_BLUR
		return color;
	#endif
	
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
/***********************************************************************/


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
	
	DrawDebugText();
}

#endif
/***********************************************************************/
