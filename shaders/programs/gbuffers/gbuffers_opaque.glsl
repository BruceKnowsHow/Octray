/***********************************************************************/
#if defined vsh

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float far;
uniform int frameCounter;
uniform ivec2 atlasSize;
uniform vec2 viewSize;
uniform bool accum;

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

out      mat3  tbnMatrix;
out      vec4  vColor;
out      vec3  wPosition;
out      vec3  wPos;
out      vec2  texcoord;
out      float discardflag;
flat out int   blockID;

#include "../../lib/utility.glsl"
#include "../../lib/Random.glsl"
#include "../../lib/Deformation.glsl"
#include "../../lib/raytracing/Voxelization.glsl"

mat3 CalculateTBN() {
	vec3 tangent  = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * at_tangent.xyz);
	vec3 normal   = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal) ;
	vec3 binormal = cross(tangent, normal); // Orthogonalize binormal
	
	return mat3(tangent, binormal, normal);
}

void main() {
	blockID = BackPortID(int(mc_Entity.x));
	
	texcoord = gl_MultiTexCoord0.st;
	
	tbnMatrix = CalculateTBN();
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	if (isTallGrass(blockID)) tbnMatrix[2] = normalize(tbnMatrix[2] + normalize(vec3(-1.5,0.5,1.25153))*0.01);
	if (isTallGrass(blockID)) tbnMatrix[0] = normalize(tbnMatrix[0] + normalize(vec3(-1.5,0.5,1.25153))*0.01);
	
	if (isBackFaceType(blockID)) position.xyz -= tbnMatrix[2] * exp2(-12);
	
	wPosition = position.xyz;
	wPos = position.xyz - gbufferModelViewInverse[3].xyz;
	
	position.xyz = Deform(position.xyz);
	
	discardflag = 0.0;
#if UNHANDLED_BLOCKS >= 2
	discardflag += float(!isVoxelized(blockID));
#endif
	discardflag += float(blockID == 0);
	discardflag += float(OutOfVoxelBounds(mix(WorldToVoxelSpace(wPosition - tbnMatrix[2]), vec3(1), vec3(0,1,0))));

	if (discardflag > 0.0) { gl_Position = vec4(-1.0); return; }
	
	
	vColor = gl_Color;
	
	gl_Position = gbufferProjection * gbufferModelView * position;
	gl_Position.xy += TAAHash() * float(accum) * gl_Position.w * 2.0;
}

#endif
/***********************************************************************/

/***********************************************************************/
#if defined fsh

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;
uniform mat4  gbufferModelViewInverse;
uniform vec2  viewSize;
uniform ivec2 atlasSize;
uniform int   frameCounter;

in      mat3  tbnMatrix;
in      vec4  vColor;
in      vec3  wPosition;
in      vec3  wPos;
in      vec2  texcoord;
flat in vec2  cornerTexCoord;
in      float discardflag;
flat in int   blockID;

#include "../../lib/debug.glsl"
#include "../../lib/encoding.glsl"
#include "../../block.properties"

/* DRAWBUFFERS:01 */
#if (defined DEBUG) && (DEBUG_PROGRAM == ShaderStage)
	/* DRAWBUFFERS:017 */
	#define DEBUG_OUT gl_FragData[2]
#endif
#include "../../lib/exit.glsl"

void main() {
	if (discardflag > 0.0) discard;
	
	vec4 diffuse = texture(tex, texcoord) * vec4(vColor.rgb, 1.0);
	vec4 normal = texture(normals, texcoord);
	vec4 spec = texture(specular, texcoord);
	
#if !defined gbuffers_water
	if (diffuse.a <= 0.1 && !isGlassType(blockID)) discard;
#else
	if (diffuse.a <= 0 && !isGlassType(blockID)) discard;
#endif
	
	mat3 tbn = tbnMatrix;
	
	if (!gl_FrontFacing) {
		tbn[0] *= -1;
		tbn[1] *= -1;
		tbn[2] *= -1;
	}
	
	gl_FragData[0] = vec4(PackGBuffers(diffuse, normal, spec).xyz, EncodeTBNU(tbn));
	gl_FragData[1] = vec4(blockID / 255.0, wPos);
	
	exit();
}

#endif
/***********************************************************************/
