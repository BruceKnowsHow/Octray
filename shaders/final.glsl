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
uniform sampler2D colortex1;
uniform sampler2D colortex5;

const bool colortex0MipmapEnabled = true;
const bool colortex1MipmapEnabled = true;

uniform float frameTimeCounter;
uniform vec2 viewSize;
uniform int hideGUI;

#include "/../shaders/lib/settings/shadows.glsl"
#include "/../shaders/lib/Tonemap.glsl"

noperspective in vec2 texcoord;

#include "/../shaders/lib/exit.glsl"

#define _f float
const _f
	CH_A    = _f(0x69f99), CH_B    = _f(0x79797), CH_C    = _f(0xe111e),
	CH_D    = _f(0x79997), CH_E    = _f(0xf171f), CH_F    = _f(0xf1711),
	CH_G    = _f(0xe1d96), CH_H    = _f(0x99f99), CH_I    = _f(0xf444f),
	CH_J    = _f(0x88996), CH_K    = _f(0x95159), CH_L    = _f(0x1111f),
	CH_M    = _f(0x9f999), CH_N    = _f(0x9bd99), CH_O    = _f(0x69996),
	CH_P    = _f(0x79971), CH_Q    = _f(0x69b5a), CH_R    = _f(0x79759),
	CH_S    = _f(0xe1687), CH_T    = _f(0xf4444), CH_U    = _f(0x99996),
	CH_V    = _f(0x999a4), CH_W    = _f(0x999f9), CH_X    = _f(0x99699),
	CH_Y    = _f(0x99e8e), CH_Z    = _f(0xf843f), CH_0    = _f(0x6bd96),
	CH_1    = _f(0x46444), CH_2    = _f(0x6942f), CH_3    = _f(0x69496),
	CH_4    = _f(0x99f88), CH_5    = _f(0xf1687), CH_6    = _f(0x61796),
	CH_7    = _f(0xf8421), CH_8    = _f(0x69696), CH_9    = _f(0x69e84),
	CH_APST = _f(0x66400), CH_PI   = _f(0x0faa9), CH_UNDS = _f(0x0000f),
	CH_HYPH = _f(0x00600), CH_TILD = _f(0x0a500), CH_PLUS = _f(0x02720),
	CH_EQUL = _f(0x0f0f0), CH_SLSH = _f(0x08421), CH_EXCL = _f(0x33303),
	CH_QUES = _f(0x69404), CH_COMM = _f(0x00032), CH_FSTP = _f(0x00002),
	CH_QUOT = _f(0x55000), CH_BLNK = _f(0x00000), CH_COLN = _f(0x00202),
	CH_LPAR = _f(0x42224), CH_RPAR = _f(0x24442);
const vec2 MAP_SIZE = vec2(4,5);

float getBit(float map, float index) {
	return mod( floor( map*exp2(-index) ), 2.0 );
}

float floatToChar(float x) {
	float res = CH_BLNK;
	res += (step(-.5,x)-step(0.5,x))*CH_0;
	res += (step(0.5,x)-step(1.5,x))*CH_1;
	res += (step(1.5,x)-step(2.5,x))*CH_2;
	res += (step(2.5,x)-step(3.5,x))*CH_3;
	res += (step(3.5,x)-step(4.5,x))*CH_4;
	res += (step(4.5,x)-step(5.5,x))*CH_5;
	res += (step(5.5,x)-step(6.5,x))*CH_6;
	res += (step(6.5,x)-step(7.5,x))*CH_7;
	res += (step(7.5,x)-step(8.5,x))*CH_8;
	res += (step(8.5,x)-step(9.5,x))*CH_9;
	return res;
}

float drawChar(float character, vec2 pos, vec2 size, vec2 uv) {
	// Subtract our position from the current uv so that we can
	// know if we're inside the bounding box or not.
	uv-=pos;

	// Divide the screen space by the size, so our bounding box is 1x1.
	uv /= size;

	// Create a place to store the result.
	float res;

	// Branchless bounding box check.
	res = step(0.0,min(uv.x,uv.y)) - step(1.0,max(uv.x,uv.y));

	// Go ahead and multiply the UV by the bitmap size so we can work in
	// bitmap space coordinates.
	uv *= MAP_SIZE;

	// Get the appropriate bit and return it.
	res*=getBit( character, 4.0*floor(uv.y) + floor(uv.x) );
	return clamp(res,0.0,1.0);
}

float drawIntCarriage(int val, in vec2 pos, vec2 size, vec2 uv, int places) {
	// Create a place to store the current values.
	float res = 0.0,digit = 0.0;
	// Surely it won't be more than 10 chars long, will it?
	// (MAX_INT is 10 characters)
	for (int i = 0; i < 10; ++i) {
		// If we've run out of film, cut!
		if(val == 0 && i >= places) break;
		// The current lsd is the difference between the current
		// value and the value rounded down one place.
		digit = float( val-(val/10)*10 );
		// Draw the character. Since there are no overlaps, we don't
		// need max().
		res += drawChar(floatToChar(digit),pos,size,uv);
		// Move the carriage.
		pos.x -= size.x*1.2;
		// Truncate away this most recent digit.
		val /= 10;
	}
	
	return res;
}

float drawInt( in int val, in vec2 pos, in vec2 size, in vec2 uv )
{
    vec2 p = vec2(pos);
    float s = sign(float(val));
    val *= int(s);
    
    float c = drawIntCarriage(val,p,size,uv,1);
    return c + drawChar(CH_HYPH,p,size,uv)*max(0.0, -s);
}

/*
	Prints a fixed point fractional value. Be even more careful about overflowing.
*/
float drawFixed( in float val, in int places, in vec2 pos, in vec2 size, in vec2 uv )
{
    // modf() sure would be nice right about now.
    vec2 p = vec2(pos);
    float res = 0.0;
    
    // Draw the floating point part.
    res = drawIntCarriage( int( fract(val)*pow(10.0,float(places)) ), p, size, uv, places );
    // The decimal is tiny, so we back things up a bit before drawing it.
    p.x -= size.x*2.4;
    res = max(res, drawChar(CH_FSTP,p,size,uv)); p.x-=size.x*1.2;
    // And after as well.
//    p.x += size.x *.1;
    // Draw the integer part.
    res = max(res, drawIntCarriage(int(floor(val)),p,size,uv,1));
	return res;
}

float drawFixed2( in float val, in int places, in vec2 pos, in vec2 size, in vec2 uv )
{
    // modf() sure would be nice right about now.
    vec2 p = vec2(pos);
    float res = 0.0;
    
    // Draw the floating point part.
//    res = drawIntCarriage( int( fract(val)*pow(10.0,float(places)) ), p, size, uv, places );
    // The decimal is tiny, so we back things up a bit before drawing it.
    p.x -= size.x*2.4;
//    res = max(res, drawChar(CH_FSTP,p,size,uv)); p.x-=size.x*1.2;
    // And after as well.
//    p.x += size.x *.1;
    // Draw the integer part.
    res = max(res, drawIntCarriage(int(floor(val)),p,size,uv,1));
	return res;
}

float beni;

float text( in vec2 uv )
{
    // Set a general character size...
    vec2 charSize = vec2(.03, .0375) * 0.8;
    // and a starting position.
    vec2 charPos = vec2(0.02, 0.955);
    // Draw some text!
    float chr = 0.0;
	chr += drawChar( CH_F, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_R, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_A, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_M, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_E, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_S, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_BLNK, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_A, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_C, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_C, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_U, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_M, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_U, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_L, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_A, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_T, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_E, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_D, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_BLNK, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_LPAR, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_S, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_P, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_P, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_RPAR, charPos, charSize, uv); charPos.x += .035;
	chr += drawChar( CH_COLN, charPos, charSize, uv); charPos.x += .035;
	charPos.x += .2;
	chr += drawFixed2( beni, 2, charPos, charSize, uv);
	/*
    // Bitmap text rendering!
    chr += drawChar( CH_B, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_I, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_T, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_M, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_A, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_P, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_BLNK, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_T, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_E, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_X, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_T, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_BLNK, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_R, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_E, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_N, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_D, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_E, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_R, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_I, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_N, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_G, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_EXCL, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_EXCL, charPos, charSize, uv); charPos.x += .04;
    
    // Today's Date: {date}
    charPos = vec2(0.05, .75);
    chr += drawChar( CH_T, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_O, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_D, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_A, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_Y, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_APST, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_S, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_BLNK, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_D, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_A, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_T, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_E, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_BLNK, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_LPAR, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_M, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_M, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_HYPH, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_D, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_D, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_HYPH, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_Y, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_Y, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_Y, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_Y, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_RPAR, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_COLN, charPos, charSize, uv); charPos.x += .1;
    // The date itself.
    charPos.x += .3;
    // chr += drawIntCarriage( int(iDate.x), charPos, charSize, uv, 4);
    // chr += drawChar( CH_HYPH, charPos, charSize, uv); charPos.x-=.04;
    // chr += drawIntCarriage( int(iDate.z)+1, charPos, charSize, uv, 2);
    // chr += drawChar( CH_HYPH, charPos, charSize, uv); charPos.x-=.04;
    // chr += drawIntCarriage( int(iDate.y)+1, charPos, charSize, uv, 2);
    
    // Shader uptime:
    charPos = vec2(0.05, .6);
    chr += drawChar( CH_I, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_G, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_L, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_O, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_B, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_A, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_L, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_T, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_I, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_M, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_E, charPos, charSize, uv); charPos.x += .04;
    chr += drawChar( CH_COLN, charPos, charSize, uv); charPos.x += .04;
    // The uptime itself.
    charPos.x += .3;
    chr += drawFixed( beni, 2, charPos, charSize, uv);
	*/
    return chr;
}

vec3 GetBloomTile(const int scale, vec2 offset) {
	vec2 coord  = texcoord;
	     coord /= scale;
	     coord += offset + 1/viewSize;
	
	return texture2D(colortex1, coord).rgb;
}

#define BLOOM_AMOUNT 0.3
#define BLOOM_CURVE 1.5

vec3 GetBloom(vec3 color) {
	vec3[8] bloom;
	
	// These arguments should be identical to those in composite2.fsh
	bloom[1] = GetBloomTile(  4, vec2(0.0                         ,                          0.0));
	bloom[2] = GetBloomTile(  8, vec2(0.0                         , 0.25     + 1/viewSize.y * 2.0));
	bloom[3] = GetBloomTile( 16, vec2(0.125    + 1/viewSize.x * 2.0, 0.25     + 1/viewSize.y * 2.0));
	bloom[4] = GetBloomTile( 32, vec2(0.1875   + 1/viewSize.x * 4.0, 0.25     + 1/viewSize.y * 2.0));
	bloom[5] = GetBloomTile( 64, vec2(0.125    + 1/viewSize.x * 2.0, 0.3125   + 1/viewSize.y * 4.0));
	bloom[6] = GetBloomTile(128, vec2(0.140625 + 1/viewSize.x * 4.0, 0.3125   + 1/viewSize.y * 4.0));
	bloom[7] = GetBloomTile(256, vec2(0.125    + 1/viewSize.x * 2.0, 0.328125 + 1/viewSize.y * 6.0));
	
	bloom[0] = vec3(0.0);
	
	for (uint index = 1; index <= 7; index++)
		bloom[0] += bloom[index];
	
	bloom[0] /= 7.0;
	
	return mix(color, min(pow(bloom[0], vec3(BLOOM_CURVE)), bloom[0]), BLOOM_AMOUNT);
}

void main() {
	vec4 lookup = texture(colortex0, texcoord);
	beni = lookup.a;
	vec3 color = lookup.rgb / lookup.a;
	color = GetBloom(color);
	vec3 avgCol = texture(colortex0, texcoord, 10).rgb / texture(colortex0, texcoord, 10).a;
	float expo = 1.0 / dot(avgCol, vec3(0.2125, 0.7154, 0.0721));
	expo = 0.5 / dot(avgCol, vec3(1.0/3.0));
	
	
	
	color = Tonemap(color * expo   );
	// if (texcoord.x > 0.5)
	// color = (texture(colortex0, texcoord + vec2(-0.5, 0.0), 9).rgb / beni);
	
	
	gl_FragColor.rgb = color;
	
	if (hideGUI == 0) {
		if (distance(texcoord.x, 0.33) * viewSize.x / viewSize.y < 0.005) gl_FragColor.rgb *= 0.5;
		if (distance(texcoord.x, 0.66) * viewSize.x / viewSize.y < 0.005) gl_FragColor.rgb *= 0.5;
		if (distance(texcoord.y, 0.33) < 0.005) gl_FragColor.rgb *= 0.5;
		if (distance(texcoord.y, 0.66) < 0.005) gl_FragColor.rgb *= 0.5;
	}
	
	vec2 textcoord = texcoord;
	textcoord.x *= viewSize.x / viewSize.y;
	
	vec3 whiteText = vec3(text(textcoord));
	// vec3 blackText0 = vec3(text(textcoord + vec2(4.0*viewSize.x / viewSize.y, 4.0) / viewSize));
	// vec3 blackText1 = vec3(text(textcoord + vec2(4.0*viewSize.x / viewSize.y, -4.0) / viewSize));
	// vec3 blackText2 = vec3(text(textcoord + vec2(-4.0*viewSize.x / viewSize.y, 4.0) / viewSize));
	// vec3 blackText3 = vec3(text(textcoord + vec2(-4.0*viewSize.x / viewSize.y, -4.0) / viewSize));
	
	if (hideGUI == 0) {
		// gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(0.0), blackText0);
		// gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(0.0), blackText1);
		// gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(0.0), blackText2);
		// gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(0.0), blackText3);
		if (texcoord.x < 0.61 && texcoord.y > 0.94) gl_FragColor.rgb *= 0.5;
		gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(1.0), whiteText);
	}
//	gl_FragColor = mix(gl_FragColor, texture(colortex5, texcoord), 0.5);
	exit();
}

#endif
/***********************************************************************/
