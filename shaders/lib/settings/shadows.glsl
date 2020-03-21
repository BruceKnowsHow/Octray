#if !defined LIB_SETTINGS_SHADOW_GLSL
#define LIB_SETTINGS_SHADOW_GLSL

#define VOXELIZATION_DISTANCE 256 // [128 256 384 478]

#if (VOXELIZATION_DISTANCE == 128)
const float shadowDistance           =  128;
const int   shadowMapResolution      = 8192;
const float shadowDistanceRenderMul  =    2.0;
#elif (VOXELIZATION_DISTANCE == 256)
const float shadowDistance           =   256;
const int   shadowMapResolution      = 16384;
const float shadowDistanceRenderMul  =     1.0;
#elif (VOXELIZATION_DISTANCE == 384)
const float shadowDistance           =   384;
const int   shadowMapResolution      = 16384;
const float shadowDistanceRenderMul  =     1.0;
#elif (VOXELIZATION_DISTANCE == 478)
const float shadowDistance           =   478;
const int   shadowMapResolution      = 16384;
const float shadowDistanceRenderMul  =     1.0;
#endif

const float shadowIntervalSize       =    0.000001;
const float sunPathRotation          =  -40.0; // [-80.0 -70.0 -60.0 -50.0 -40.0 -30.0 -20.0 -10.0 0.0 10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0]
const bool  shadowHardwareFiltering0 = false;

#endif
