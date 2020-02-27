#if !defined EXIT_GLSL
#define EXIT_GLSL

#if (defined DEBUG) && (ShaderStage <= -10)

#elif (defined DEBUG) && (ShaderStage < 50)

	#if (DEBUG_PROGRAM == ShaderStage)
		/* DRAWBUFFERS:6 */
	#elif (DEBUG_PROGRAM < ShaderStage)
		/* DRAWBUFFERS:0123 */
	#endif

#elif (defined DEBUG) && (ShaderStage == 50)
	//uniform sampler2D colortex1;
	#if (DEBUG_PROGRAM < 50)
		uniform sampler2D colortex6;
	#endif

#endif

#ifdef DEBUG
	#if (ShaderStage < 50)
		#if (DEBUG_PROGRAM < ShaderStage)
			void exit() { discard; }
		#elif (DEBUG_PROGRAM == ShaderStage)
			void exit() { gl_FragData[0] = vec4(Debug, 1.0); }
		#else
			#define exit()
		#endif
	#else
		#if (DEBUG_PROGRAM <= -10)
			void exit() { gl_FragColor = vec4(texture(shadowcolor0, texcoord).rgb, 1.0); }
		#elif (DEBUG_PROGRAM < 50)
			void exit() { gl_FragColor = vec4(texture(colortex6, texcoord).rgb, 1.0); }
		#elif (DEBUG_PROGRAM == 50)
			void exit() { gl_FragColor = vec4(Debug * DEBUG_BRIGHTNESS, 1.0); }
		#endif
	#endif
#else
	#define exit()
#endif

#endif
