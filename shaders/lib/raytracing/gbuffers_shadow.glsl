#define GSH_MODE_ACTIVE 0
#define GSH_MODE_PASSTHROUGH 1
#define GSH_MODE_DISABLED 2

#define GSH_MODE GSH_MODE_ACTIVE // [GSH_MODE_ACTIVE GSH_MODE_PASSTHROUGH GSH_MODE_DISABLED]

/***********************************************************************/
#if defined vsh

uniform sampler2D tex;
uniform mat4  gbufferModelViewInverse;
uniform mat4  shadowModelViewInverse;
uniform vec3  cameraPosition;
uniform vec3  previousCameraPosition;
uniform float far;
uniform int   instanceId;

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

     out vec4  vColor;
flat out vec4  data0;
flat out vec4  data1;
     out vec3  wPosition;
flat out vec3  vNormal;
     out vec2  texcoord;
flat out vec2  midTexCoord;
     out float discardflag;
flat out int   blockID;

#if GSH_MODE == GSH_MODE_ACTIVE
	const int countInstances = 1;
#else
	const int countInstances = 8;
#endif

#include "Voxelization.glsl"
#include "RT_Encoding.glsl"

mat3 CalculateTBN() {
	vec3 tangent  = normalize(mat3(shadowModelViewInverse) * gl_NormalMatrix * at_tangent.xyz);
	vec3 normal   = normalize(mat3(shadowModelViewInverse) * gl_NormalMatrix * gl_Normal) ;
	vec3 binormal = cross(tangent, normal); // Orthogonalize binormal
	
	return mat3(tangent, binormal, normal);
}

void main() {
	blockID = BackPortID(int(mc_Entity.x));
	
	discardflag = 0.0;
	#if UNHANDLED_BLOCKS >= 1
		discardflag += int(!isVoxelized(blockID));
	#endif
	if (discardflag > 0.0) { gl_Position = vec4(-1.0); return; }
	
	vColor  = gl_Color;
	
	vNormal = normalize(mat3(shadowModelViewInverse) * gl_NormalMatrix * gl_Normal);
	midTexCoord = mc_midTexCoord.st;
	texcoord = gl_MultiTexCoord0.st;
	
	wPosition = (shadowModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz;
	
	gl_Position = vec4(0.0);
	
	#if GSH_MODE != GSH_MODE_ACTIVE
		vec2 atlasSize = textureSize(tex, 0).xy;
		vec2 texDirection = sign(texcoord - mc_midTexCoord)*vec2(1,sign(at_tangent.w));
		vec2 spriteSize = abs(midTexCoord - texcoord) * 2.0 * atlasSize;
		
		mat3 tbnMatrix = CalculateTBN();
		
		vec3 triCentroid = wPosition.xyz - (tbnMatrix * vec3(texDirection * spriteSize / atlasSize * 16.0,0.5));
		// vec3 triCentroid = (wPosition[0] + wPosition[1] + wPosition[2]) / 3.0 - vNormal[0] / 4096.0;
		triCentroid += fract(cameraPosition);
		
		vec3 vPos = WorldToVoxelSpace_ShadowMap(triCentroid);
		
		const vec2 offset[4] = vec2[4](vec2(-1,-1),vec2(-1,1),vec2(1,1),vec2(1,-1));
		
		vec2 coord = VoxelToTextureSpace(uvec3(vPos), instanceId) + 0.5;
		coord += offset[(gl_VertexID) % 4] * 0.5;
		coord /= shadowMapResolution;
		
		vec2 cornerTexCoord = midTexCoord - abs(midTexCoord - texcoord);
		
		vec2 hs = RT_hsv(vColor.rgb).rg;
		
		data0 = vec4(log2(spriteSize.x) / 255.0, blockID / 255.0, hs);
		data1 = vec4(vColor.rgb, 0.0);
		
		float depth = packTexcoord(cornerTexCoord);
		gl_Position = vec4(coord * 2.0 - 1.0, depth, 1.0);
	#endif
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined gsh

layout(triangles) in;

#if (GSH_MODE == GSH_MODE_ACTIVE)
	layout(points, max_vertices = 8) out;
#else
	layout(triangle_strip, max_vertices = 3) out;
#endif

uniform sampler2D tex;
uniform mat4  shadowModelView;
uniform mat4  shadowProjection;
uniform mat4  gbufferModelViewInverse;
uniform vec3  cameraPosition;
uniform float far;

in      vec4  vColor[];
flat in vec4  data0[];
flat in vec4  data1[];
in      vec3  wPosition[];
flat in vec3  vNormal[];
in      vec2  texcoord[];
flat in vec2  midTexCoord[];
in      float discardflag[];
flat in int   blockID[];

flat out vec4 _data0;
flat out vec4 _data1;

#include "Voxelization.glsl"
#include "RT_Encoding.glsl"

void main() {
	#if (GSH_MODE != GSH_MODE_ACTIVE)
		for (int i = 0; i < 3; ++i) {
			gl_Position = gl_in[i].gl_Position;
			_data0 = data0[i];
			_data1 = data1[i];
			
			EmitVertex();
		}
		
		return;
	#endif
	
	if (discardflag[0] + discardflag[1] + discardflag[2] > 0.0) return;
	
	if (abs(dot(wPosition[0] - wPosition[1], wPosition[2] - wPosition[1])) < 0.001) return;
	
	vec3 triCentroid = (wPosition[0] + wPosition[1] + wPosition[2]) / 3.0 - vNormal[0] / 4096.0;
	triCentroid += fract(cameraPosition);
	
	vec3 vPos = WorldToVoxelSpace_ShadowMap(triCentroid);
	
	if (OutOfVoxelBounds(vPos)) return;
	
	vec2 atlasSize = textureSize(tex, 0).xy;
	vec2 spriteSize = abs(midTexCoord[0] - texcoord[0]) * 2.0 * atlasSize;
	vec2 cornerTexCoord = midTexCoord[0] - abs(midTexCoord[0] - texcoord[0]);
	
	vec2 hs = RT_hsv(vColor[0].rgb).rg;
	
	_data0 = vec4(log2(spriteSize.x) / 255.0, blockID[0] / 255.0, hs);
	_data1 = vec4(vColor[0].rgb, 0.0);
	
	// Can pass an unsigned integer range [0, 2^23 - 1]
	float depth = packTexcoord(cornerTexCoord);
	
	for (int LOD = 0; LOD <= 7; ++LOD) {
		vec2 coord = (VoxelToTextureSpace(uvec3(vPos), LOD) + 0.5) / shadowMapResolution;
		
		gl_Position = vec4(coord * 2.0 - 1.0, depth, 1.0);
		EmitVertex();
	}
};

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

// layout(early_fragment_tests) in;

#if (GSH_MODE != GSH_MODE_DISABLED)
	#define data0 _data0
	#define data1 _data1
#endif

flat in vec4 data0;
flat in vec4 data1;

void main() {
	gl_FragData[0] = data0;
	// gl_FragData[1] = data1;
}

#endif
/***********************************************************************/
