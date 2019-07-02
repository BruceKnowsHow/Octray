const int noiseTextureResolution = 64; // [16 32 64 128 256 512 1024]
const float noiseRes = float(noiseTextureResolution);
const float noiseResInverse = 1.0 / noiseRes;
const float noiseScale = 64.0 / noiseRes;

#define cubesmooth(x) ((x) * (x)) * (3.0 - 2.0 * (x));

float GetWaveCoord(float coord) {
	const float madd = 0.5 * noiseResInverse;
	float whole = floor(coord);
	coord = whole + cubesmooth(coord - whole);
	
	return coord * noiseResInverse + madd;
}

vec2 GetWaveCoord(vec2 coord) {
	const vec2 madd = vec2(0.5 * noiseResInverse);
	vec2 whole = floor(coord);
	coord = whole + cubesmooth(coord - whole);
	
	return coord * noiseResInverse + madd;
}

float SharpenWave(float wave) {
	wave = 1.0 - abs(wave * 2.0 - 1.0);
	
	return wave < 0.78 ? wave : (wave * -2.5 + 5.0) * wave - 1.6;
}

#define WAVE_MULT  1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define WAVE_SPEED 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

const vec4 heights = vec4(29.0, 15.0, 17.0, 4.0);
const vec4 height  = heights * WAVE_MULT / (heights.x + heights.y + heights.z + heights.w);

const vec2[4] scale = vec2[4](
	vec2(0.0065, 0.0052  ) * noiseRes * noiseScale,
	vec2(0.013 , 0.00975 ) * noiseRes * noiseScale,
	vec2(0.0195, 0.014625) * noiseRes * noiseScale,
	vec2(0.0585, 0.04095 ) * noiseRes * noiseScale);

const vec4 stretch = vec4(
	scale[0].x * -1.7 ,
	scale[1].x * -1.7 ,
	scale[2].x *  1.1 ,
	scale[3].x * -1.05);

mat4x2 waveTime = mat4x2(0.0);

void SetupWaveFBM() {
	const vec2 disp1 = vec2(0.04155, -0.0165   ) * noiseRes * noiseScale;
	const vec2 disp2 = vec2(0.017  , -0.0469   ) * noiseRes * noiseScale;
	const vec2 disp3 = vec2(0.0555 ,  0.03405  ) * noiseRes * noiseScale;
	const vec2 disp4 = vec2(0.00825, -0.0491625) * noiseRes * noiseScale;
	
	float w = frameTimeCounter * WAVE_SPEED * 0.6;
	
	waveTime[0] = w * disp1;
	waveTime[1] = w * disp2;
	waveTime[2] = w * disp3;
	waveTime[3] = w * disp4;
}

float GetWaves(vec2 coord) {
	float waves = 0.0;
	vec2 c;
	
	for (int i = 0; i <= 3; i++) {
		c = coord * scale[i] + waveTime[i];
		c.y = coord.x * stretch[i] + c.y;
		c = GetWaveCoord(c);
		
		float wave = texture2D(noisetex, c).x;
		if (i == 0) wave = SharpenWave(wave);
		
		waves += wave * height[i];
	}
	
	return waves;
}

float GetWaves(vec2 coord, inout mat4x2 c) {
	float waves = 0.0;
	vec2 ebin;
	
	for (int i = 0; i <= 3; i++) {
		c[i] = coord * scale[i] + waveTime[i];
		c[i].y = coord.x * stretch[i] + c[i].y;
		ebin = GetWaveCoord(c[i]);
		c[i].x = ebin.x;
		
		float wave = texture2D(noisetex, ebin).x;
		if (i == 0) wave = SharpenWave(wave);
		
		waves += wave * height[i];
	}
	
	return waves;
}

float GetWaves(mat4x2 c, float offset) {
	float waves = 0.0;
	
	for (int i = 0; i <= 3; i++) {
		c[i].y = GetWaveCoord(offset * scale[i].y + c[i].y);
		
		float wave = texture2D(noisetex, c[i].xy).x;
		if (i == 0) wave = SharpenWave(wave);
		
		waves += wave * height[i];
	}
	
	return waves;
}

vec2 GetWaveDifferentials(vec2 coord, const float scale) { // Get finite wave differentials for the world-space X and Z coordinates
	mat4x2 c;
	
	float a  = GetWaves(coord, c);
	float aX = GetWaves(coord + vec2(scale,   0.0));
	float aY = GetWaves(c, scale);
	
	return a - vec2(aX, aY);
}

vec3 GetWaveNormals(vec3 worldSpacePosition, vec3 flatWorldNormal) {
	if (WAVE_MULT == 0.0) return vec3(0.0, 0.0, 1.0);
	
	SetupWaveFBM();
	
	float angleCoeff  = dot(normalize(-wPosition.xyz), normalize(flatWorldNormal));
	      angleCoeff /= clamp(length(wPosition) * 0.05, 1.0, 10.0);
	      angleCoeff  = clamp(angleCoeff * 2.5, 0.0, 1.0);
	      angleCoeff  = sqrt(angleCoeff);
	
//	vec3 worldPos    = wPosition + cameraPosition - worldDisplacement;
	vec3 worldPos    = wPosition + cameraPosition;
	     worldPos.xz = worldPos.xz + worldPos.y;
	
	
//	vec2 diff = GetWaveDifferentials(worldPos.xz, 0.1) * angleCoeff;
	vec2 diff = GetWaveDifferentials(worldPos.xz, 0.1);
	
	return vec3(diff, sqrt(1.0 - dot(diff, diff)));
}
