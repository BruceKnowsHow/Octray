//#define DEBUG
#define DEBUG_VIEW 0 // [-10 -1 0 20 30 50]

#if ShaderStage < 0 && defined vsh
	out vec3 vDebug;
	#define Debug vDebug
#elif ShaderStage < 0 && defined fsh
	in vec3 vDebug;
	vec3 Debug = vDebug;
#else
	vec3 Debug = vec3(0.0);
#endif

void show( bool x) { Debug = vec3(float(x)); }
void show(float x) { Debug = vec3(x); }
void show( vec2 x) { Debug = vec3(x, 0.0); }
void show( vec3 x) { Debug = x; }
void show( vec4 x) { Debug = x.rgb; }


#ifndef DEBUG
//	#define CRASH_DANGLING_SHOW
#endif

#ifdef CRASH_DANGLING_SHOW
	#define show(x) DANGLING_SHOW
#else
	#define show(x) show(x);
#endif
