#ifndef LIB_SETTINGS_SHADOW_GLSL
#define LIB_SETTINGS_SHADOW_GLSL

const float shadowDistance           =  128; // [8 32 128 256 512 1024]
const int   shadowMapResolution      = 4096; // [64 512 1024 2048 4096 8192 16384] // (shadowDistance * 2.0) ^ (3 / 2)
//const int   shadowMapResolution      = 4096;
const float shadowDistanceRenderMul  =    2.0;
const float shadowIntervalSize       =    0.000001;
const float sunPathRotation          =   40.0;
const bool  shadowHardwareFiltering0 = false;

#endif
