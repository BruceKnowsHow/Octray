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
	
/*
Example Usage:
		Body j = Body(vec3(0.5, 66.65, 50.5), rotationMatrix(vec3(0,1,0), frameTimeCounter));
		
		for (int i = 0; i < 6; ++i) {
			vec3 center = player_head_faces[i].center;
			mat3 tbn = player_head_faces[i].tbn;
			
			center = j.rot * center;
			tbn = j.rot * tbn;
			
			center += j.pos - (cameraPosition + gbufferModelViewInverse[3].xyz);
			
			vec2 coord = RayRectIntersection(vec3(0), normalize(wDir), center, tbn, wPos);
			
			if (coord.x > 0.0) color = vec3(coord, 0);
		}

*/