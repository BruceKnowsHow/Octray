#include "version.glsl"
#define ShaderStage -1
#include "worldID.glsl"
#define gbuffers_textured_lit
#define vsh

#if defined world0
#include "../gbuffers_opaque.glsl"
#endif
