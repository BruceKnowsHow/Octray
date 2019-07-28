#if !defined LIB_SETTINGS_SHADOW_GLSL
#define LIB_SETTINGS_SHADOW_GLSL

const float shadowDistance           =  128; // [128 256]
const int   shadowMapResolution      = 5800; // [5800 11600]
const float shadowDistanceRenderMul  =    2.0;
const float shadowIntervalSize       =    0.000001;
const float sunPathRotation          =   40.0;
const bool  shadowHardwareFiltering0 = false;

#endif
