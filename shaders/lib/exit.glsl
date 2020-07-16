#if !defined EXIT_GLSL
#define EXIT_GLSL

#if (defined DEBUG) && (ShaderStage == 50)
	
	#if (DEBUG_PROGRAM <= -10)
		uniform sampler2D shadowcolor0;
	#elif (DEBUG_PROGRAM < 50)
		uniform sampler2D colortex7;
	#endif

#endif

#ifdef DEBUG
	#if (DEBUG_PROGRAM == ShaderStage) && (ShaderStage < 50)
		void exit() { DEBUG_OUT = vec4(Debug, 1.0); }
	#elif (ShaderStage == 50)
		#if (DEBUG_PROGRAM <= -10)
			void exit() { gl_FragColor = vec4(texture(shadowcolor0, texcoord).rgb * DEBUG_BRIGHTNESS, 1.0); }
		#elif (DEBUG_PROGRAM < 50)
			void exit() { gl_FragColor = vec4(texture(colortex7, texcoord).rgb * DEBUG_BRIGHTNESS, 1.0); }
		#elif (DEBUG_PROGRAM == 50)
			void exit() { gl_FragColor = vec4(Debug * DEBUG_BRIGHTNESS, 1.0); }
		#endif
	#else
		#define exit()
	#endif
#else
	#define exit()
#endif

#endif
