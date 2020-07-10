#include "../version.glsl"
#define ShaderStage 32
#include "worldID.glsl"
#define Atrous
#define ATROUS_INDEX 0
#define vsh

#include "../programs/composite/C2_C6_AtrousFilter.glsl"
