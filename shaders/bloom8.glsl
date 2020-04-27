/***********************************************************************/
#if defined vsh

uniform vec2 viewSize;

noperspective out vec2 texcoord;

void main() {
	texcoord    = gl_Vertex.xy;
	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
	
	vec2 vertexScale = vec2(0.25 + 1/viewSize.x * 2.0, 0.375 + 1/viewSize.y * 4.0);
	
	gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * vertexScale) * 2.0 - 1.0; // Crop the vertex to only cover the areas that are being used
	
	texcoord *= vertexScale; // Compensate for the vertex adjustment to make this a true "crop" rather than a "downscale"
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

#include "lib/debug.glsl"
#include "lib/utility.glsl"
#include "lib/encoding.glsl"

#define COMPOSITE0_COLOR_OUT colortex5
uniform sampler2D COMPOSITE0_COLOR_OUT;
const bool colortex5MipmapEnabled = true;


uniform vec2 viewSize;


noperspective in vec2 texcoord;

#define cubesmooth(x) ((x) * (x) * (3.0 - 2.0 * (x)))

vec3 ComputeBloomTile(const float scale, vec2 offset) { // Computes a single bloom tile, the tile's blur level is inversely proportional to its size
	// Each bloom tile uses (1.0 / scale + pixelSize * 2.0) texcoord-units of the screen
	
	vec2 coord  = texcoord;
	     coord -= offset + 1 / viewSize; // A pixel is added to the offset to give the bloom tile a padding
	     coord *= scale;
	
	vec2 padding = scale / viewSize;
	
	if (any(greaterThanEqual(abs(coord - 0.5), padding + 0.5)))
		return vec3(0.0);
	
	
	float Lod = log2(scale);
	
	const float range     = 2.0 * scale; // Sample radius has to be adjusted based on the scale of the bloom tile
	const float interval  = 1.0 * scale;
	float  maxLength = length(vec2(range));
	
	vec3  bloom       = vec3(0.0);
	float totalWeight = 0.0;
	
	for (float i = -range; i <= range; i += interval) {
		for (float j = -range; j <= range; j += interval) {
			float weight  = 1.0 - length(vec2(i, j)) / maxLength;
			      weight *= weight;
			      weight  = cubesmooth(weight); // Apply a faux-gaussian falloff
			
			vec2 offset = vec2(i, j) / viewSize;
			
			vec4 lookup = textureLod(COMPOSITE0_COLOR_OUT, coord + offset, Lod);
			
			bloom       += lookup.rgb * weight / lookup.a;
			totalWeight += weight;
		}
	}
	
	return bloom / totalWeight;
}

vec3 ComputeBloom() {
	vec3 bloom  = ComputeBloomTile(  4, vec2(0.0                         ,                          0.0));
	     bloom += ComputeBloomTile(  8, vec2(0.0                         , 0.25      + 1/viewSize.y * 2.0));
	     bloom += ComputeBloomTile( 16, vec2(0.125    + 1/viewSize.x * 2.0, 0.25     + 1/viewSize.y * 2.0));
	     bloom += ComputeBloomTile( 32, vec2(0.1875   + 1/viewSize.x * 4.0, 0.25     + 1/viewSize.y * 2.0));
	     bloom += ComputeBloomTile( 64, vec2(0.125    + 1/viewSize.x * 2.0, 0.3125   + 1/viewSize.y * 4.0));
	     bloom += ComputeBloomTile(128, vec2(0.140625 + 1/viewSize.x * 4.0, 0.3125   + 1/viewSize.y * 4.0));
	     bloom += ComputeBloomTile(256, vec2(0.125    + 1/viewSize.x * 2.0, 0.328125 + 1/viewSize.y * 6.0));
	
	return max(bloom, vec3(0.0));
}

/* DRAWBUFFERS:3 */
#include "lib/exit.glsl"

void main() {
	gl_FragData[0] = vec4(ComputeBloom(), 1.0);
	#define OBF_FIX
	exit();
}

#endif
/***********************************************************************/
