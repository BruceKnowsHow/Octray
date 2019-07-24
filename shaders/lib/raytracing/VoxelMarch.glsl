#ifndef VOXELMARCH_GLSL
#define VOXELMARCH_GLSL

#include "/../shaders/lib/settings/shadows.glsl"

#include "/../shaders/lib/raytracing/WorldToVoxelCoord.glsl"

float Lookup(vec3 position, int LOD) {
	return texelFetch(shadowtex0, WorldToVoxelCoord(position, LOD), 0).x;
}

float fMin(vec3 a, out vec3 val) {
	float ret = min(a.x, min(a.y, a.z));
	vec2 c = 1.0 - clamp((a.xy - ret) * 1e35, 0.0, 1.0);
	val = vec3(c.xy, 1.0 - c.x - c.y);
	return ret;
}


struct Face {
// A "Face" is a single planar quad.
// A Face stores texture and geometric information.
// Geometry is stored as vec3 representing the quad's centroid,
// as well as a mat3 representing the quad's TBN matrix.
// The quad's size/dimensions are stored implicitely within the tangent and binormal.
// The quad's centroid is defined in the frame of reference of the Body it is a part of.
	
//	vec2 midTexCoord;
//	vec2 spriteSize;
	vec3 basic_color;
	
	vec3 center;
	mat3 tbn;
};

struct Body {
// A body is a set of Faces that all move and rotate together,
// you could think of a body as sharing a single "joint".
// The parameters of a body are dynamic, so they are stored in the voxel map.
// Bodies are composed of an array of faces, these faces are predefined/baked/constant in the shader.
	
	vec3 pos;
	mat3 rot;
};

mat3 rotationMatrix(vec3 axis, float angle)
{
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return mat3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c);
}

vec2 RayRectIntersection(vec3 rayPos, vec3 rayDir, vec3 qCenter, mat3 qTBN, vec3 wPos) {
	float f = dot(rayDir, qTBN[2]);
	float t = dot(qCenter - rayPos, qTBN[2]) / f;
	
	vec3 intersection = rayPos + rayDir * t;
	vec3 dist = intersection - qCenter;
	
	vec2 coord = (-dist * mat2x3(qTBN)) + 0.5;
	
	if (f < 0.0 && t > 0.0 && all(lessThan(abs(coord - 0.5), vec2(0.5)))) {
		if (dot(intersection,intersection) > dot(wPos,wPos))
			return vec2(-1e35);
		
		return coord;
	} else {
		return vec2(-1e35);
	}
}

// Facing x+ axis
const Face[6] player_head_faces = Face[6](
	    Face(vec3(1.0), vec3( 0.0,  0.25,  0.0), mat3(16./8,0,0,   0,0,16./8,   0, 1, 0)), // Top
	    Face(vec3(1.0), vec3( 0.0, -0.25,  0.0), mat3(16./8,0,0,   0,0,16./8,   0,-1, 0)), // Bottom
	    Face(vec3(1.0), vec3( 0.0,  0.0, -0.25), mat3(16./8,0,0,   0,16./8,0,   0, 0,-1)), // Left
	    Face(vec3(1.0), vec3( 0.0,  0.0,  0.25), mat3(16./8,0,0,   0,16./8,0,   0, 0, 1)), // Right
	    Face(vec3(1.0), vec3( 0.25,  0.0,  0.0), mat3(0,0,16./8,   0,16./8,0,   1, 0, 0)), // Front
	    Face(vec3(1.0), vec3(-0.25,  0.0,  0.0), mat3(0,0,16./8,   0,16./8,0,  -1, 0, 0))  // Back
	);
	
const Face[1][6] body_faces_array = Face[1][6](
		player_head_faces
	);
	

float VoxelMarch(inout vec3 pos, vec3 rayDir, out vec3 plane, float LOD) {
	pos += (abs(pos) + 1.0) * sign(rayDir) / 4096.0;
	pos = Part1Transform(pos);
	
	while (LOD > 0 && Lookup(pos, int(LOD)) < 1.0) --LOD;
	if (LOD == 0 && Lookup(pos, 0) < 1.0) return Lookup(pos, 0);
	
	vec3 stepDir = sign(rayDir);
	vec3 dirPositive = (stepDir * 0.5 + 0.5);
	vec3 tDelta  = 1.0 / rayDir;
	
	vec3 bound = exp2(LOD) * floor(pos * exp2(-LOD) + dirPositive);
	
	vec3 pos0 = pos;
	vec3 P0 = intBitsToFloat(floatBitsToInt(pos) + ivec3(mix(vec3(-2), vec3(2), dirPositive)));
	
	int t = 0;
	
	while (t++ < 256) {
		vec3 tMax = (bound - pos0)*tDelta;
		float L = fMin(tMax, plane);
		float oldPos = dot(pos, plane);
		pos = P0 + rayDir * L;
		
		if (any(greaterThan(abs(pos - vec2(128, shadowRadius).yxy), vec2(128, shadowRadius).yxy))) { break; }
		
		LOD += (abs(int(dot(pos,plane)*exp2(-LOD-1)) - int(oldPos*exp2(-LOD-1))));
		LOD = min(LOD, 7);
		
		float lookup = Lookup(floor(pos), int(LOD));
		float hit = clamp(1e35 - lookup*1e35, 0.0, 1.0);
		
		LOD -= (hit);
		if (LOD < 0) return lookup;
		
		vec3 a = exp2(LOD) * floor(pos*exp2(-LOD)+dirPositive);
		vec3 b = bound + stepDir * ((1.0 - hit) * exp2(LOD));
		bound = mix(a, b, plane);
	}
	
	return -1e35;
}



float VoxelMarch(inout vec3 pos, vec3 rayDir, inout vec3 plane, float LOD, bool underwater) {
	return VoxelMarch(pos, rayDir, plane, LOD);
}

#endif
