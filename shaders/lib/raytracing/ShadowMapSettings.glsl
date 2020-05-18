#if !defined LIB_SETTINGS_SHADOW_GLSL
#define LIB_SETTINGS_SHADOW_GLSL

#include "UserSettings.glsl"

#if (VOXELIZATION_DISTANCE == 0)
const float shadowDistance           =  112;
const int   shadowMapResolution      = 4096;
const float shadowDistanceRenderMul  =    2.0;
#elif (VOXELIZATION_DISTANCE == 1)
const float shadowDistance           =   232;
const int   shadowMapResolution      = 8192;
const float shadowDistanceRenderMul  =     2.0;
#elif (VOXELIZATION_DISTANCE == 2)
const float shadowDistance           =   478;
const int   shadowMapResolution      = 16384;
const float shadowDistanceRenderMul  =     1.0;
#endif

const float shadowIntervalSize       =    0.000001;
const bool  shadowHardwareFiltering0 = false;

#endif
