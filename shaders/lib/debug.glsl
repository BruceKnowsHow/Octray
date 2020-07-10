#if !defined DEBUG_GLSL
#define DEBUG_GLSL


//#define DEBUG
#define DEBUG_PROGRAM 30 // [-10 -1 30 31 32 50]
#define DEBUG_BRIGHTNESS 1.0 // [1/65536.0 1/32768.0 1/16384.0 1/8192.0 1/4096.0 1/2048.0 1/1024.0 1/512.0 1/256.0 1/128.0 1/64.0 1/32.0 1/16.0 1/8.0 1/4.0 1/2.0 1.0 2.0 4.0 8.0 16.0 32.0 64.0 128.0 256.0 512.0 1024.0 2048.0 4096.0 8192.0 16384.0 32768.0 65536.0]
#define DRAW_DEBUG_VALUE

// #if false && (ShaderStage < 0) && (defined vsh)
	// out vec3 vDebug;
	// #define Debug vDebug
// #elif false && (ShaderStage < 0) && (defined fsh)
	// in vec3 vDebug;
	// vec3 Debug = vDebug;
// #else
	vec3 Debug = vec3(0.0);
// #endif

// Write the direct variable onto the screen
void show( bool x) { Debug = vec3(float(x)); }
void show(float x) { Debug = vec3(x); }
void show( vec2 x) { Debug = vec3(x, 0.0); }
void show( vec3 x) { Debug = x; }
void show( vec4 x) { Debug = x.rgb; }


void inc( bool x) { Debug += vec3(float(x)); }
void inc(float x) { Debug += vec3(x); }
void inc( vec2 x) { Debug += vec3(x, 0.0); }
void inc( vec3 x) { Debug += x; }
void inc( vec4 x) { Debug += x.rgb; }

#ifdef DRAW_DEBUG_VALUE
	// Display the value of the variable on the debug value viewer
	#define showval(x) if (distance(texcoord, vec2(0.5)) < 0.001) show(x);
	#define incval(x)  if (distance(texcoord, vec2(0.5)) < 0.001) inc(x);
#else
	#define showval(x)
	#define incval(x)
#endif


#ifndef DEBUG
#define CRASH_DANGLING_SHOW
#endif

#ifdef CRASH_DANGLING_SHOW
	#define show(x) DANGLING_SHOW
	#define inc(x) DANGLING_SHOW
#else
	#define show(x) show(x);
	#define inc(x) inc(x);
#endif

//#define FREEZE_NOISE

#ifdef FREEZE_NOISE
	#define frameCounter 0
#endif

#endif
