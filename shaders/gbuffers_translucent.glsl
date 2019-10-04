/***********************************************************************/
#if defined vsh

#include "/../shaders/gbuffers_opaque.glsl"

#endif
/***********************************************************************/

/***********************************************************************/
#if defined fsh

#include "/../shaders/lib/debug.glsl"
#include "/../shaders/lib/encoding.glsl"
#include "/../shaders/lib/utility.glsl"

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D shadowtex0;
uniform sampler2D noisetex;
uniform sampler3D gaux1;

uniform mat4 gbufferModelViewInverse;
uniform vec2 viewSize;

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;

vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);

uniform ivec2 atlasSize;

uniform float frameTimeCounter;

uniform int isEyeInWater;

in float discardflag;

in vec2 texcoord;
in vec2 lmcoord;

in vec4 vColor;
in vec3 wPosition;

in mat3 tbnMatrix;

flat in vec2 midTexCoord;
flat in float blockID;

#include "/../shaders/lib/settings/shadows.glsl"
#include "/../shaders/lib/raytracing/VoxelMarch.glsl"
#include "/../shaders/lib/WaterWaves.fsh"
#include "/../shaders/lib/raytracing/ComputeRaytracedReflections.glsl"

#include "/../shaders/block.properties"

/* DRAWBUFFERS:23 */
#include "/../shaders/lib/exit.glsl"

#if defined DEBUG && DEBUG_VIEW == ShaderStage
/* DRAWBUFFERS:0 */
#endif

float GetRefractiveIndex(float ID) {
	if (isWater(ID)) return 1.3333;
	if (isGlass(ID)) return 1.52;
	return 1.0;
}

void main() {
	if (discardflag > 0.0) discard;
	
	vec4 diffuse = textureLod(tex, texcoord, 0);
	
	if (diffuse.a <= 0.0) discard;
	
	diffuse.rgb = pow(diffuse.rgb, vec3(2.2)) * vColor.rgb;
	vec3 wPos = wPosition;
	vec3 normal = tbnMatrix * ( (isWater(blockID)) ? GetWaveNormals(wPos, tbnMatrix[2]) : normalize(textureLod(normals, texcoord, 0).rgb * 2.0 - 1.0) );
	vec2 spec   = (isWater(blockID)) ? vec2(0.0, 1.0) : textureLod(specular, texcoord, 0).rg*0;
	vec3 color = diffuse.rgb;
	
	if (isWater(blockID)) diffuse *= 0.0;
	
	if (isEyeInWater == 0) {
		vec3 backColor = vec3(0.0);
		
		vec3 currPos = wPos - gbufferModelViewInverse[3].xyz;
		
		float refl = (1.0 - abs(dot(normalize(currPos), normal))) * spec.g;
		float refr = (1-refl);
		
		vec3 rayDir = reflect(normalize(currPos), normal);
		RaytraceColorFromDirection(backColor, currPos, rayDir, refl, true, false, tex, normals, specular);
		
		float ior = 1.0 / GetRefractiveIndex(blockID);
		
		rayDir = refract(normalize(currPos), normal, ior);
		RaytraceColorFromDirection(backColor, currPos, rayDir, refr, !isWater(blockID), isWater(blockID), tex, normals, specular);
		
		if (isGlass(blockID)) backColor *= diffuse.rgb;
		
		color = mix(backColor, color, diffuse.a);
	} else if (isEyeInWater == 1) {
		vec3 backColor = vec3(0.0);
		
		vec3 currPos = wPosition - gbufferModelViewInverse[3].xyz;
		
		float refr = 1.0;
		float refl = 1.0 - refr;
		
		vec3 rayDir = reflect(normalize(currPos), normal);
	//	RaytraceColorFromDirection(backColor, currPos, rayDir, refl, true, false, tex, normals, specular);
		
		float ior = isWater(blockID) ? 0.95 : 1.0 / GetRefractiveIndex(blockID);
		
		rayDir = refract(normalize(currPos), normal, ior);
		RaytraceColorFromDirection(backColor, currPos, rayDir, refr, isWater(blockID), false, tex, normals, specular);
		
		color = mix(backColor, color, diffuse.a);
	}
	
	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = vec4(EncodeNormalU(normal), pack2x8(spec), 0.0, 1.0);
	
	exit();
}

#endif
/***********************************************************************/
