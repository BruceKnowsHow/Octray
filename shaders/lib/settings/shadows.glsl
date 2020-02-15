#if !defined LIB_SETTINGS_SHADOW_GLSL
#define LIB_SETTINGS_SHADOW_GLSL

#define VOXELIZATION_DISTANCE 256 // [128 256]

#if (VOXELIZATION_DISTANCE == 128)
const float shadowDistance           =  128;
const int   shadowMapResolution      = 8192;
const float shadowDistanceRenderMul  =    2.0;
#elif (VOXELIZATION_DISTANCE == 256)
const float shadowDistance           =   256;
const int   shadowMapResolution      = 16384;
const float shadowDistanceRenderMul  =     1.0;
#endif

const float shadowIntervalSize       =    0.000001;
const float sunPathRotation          =   40.0; // [-40.0 -30.0 -20.0 -10.0 0.0 10.0 20.0 30.0 40.0]
const bool  shadowHardwareFiltering0 = false;

const int shadowRadius   = int(min(shadowDistance, far));
const int shadowDiameter = 2 * shadowRadius;
const ivec3 shadowDimensions = ivec3(shadowDiameter, 256, shadowDiameter);

#endif
