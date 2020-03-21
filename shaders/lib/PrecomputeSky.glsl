#if !defined _PRECOMPUTEDSKY_
#define _PRECOMPUTEDSKY_

const int TRANSMITTANCE_TEXTURE_WIDTH = 256;
const int TRANSMITTANCE_TEXTURE_HEIGHT = 64;
const int SCATTERING_TEXTURE_R_SIZE = 32;
const int SCATTERING_TEXTURE_MU_SIZE = 128;
const int SCATTERING_TEXTURE_MU_S_SIZE = 32;
const int SCATTERING_TEXTURE_NU_SIZE = 8;
const int IRRADIANCE_TEXTURE_WIDTH = 64;
const int IRRADIANCE_TEXTURE_HEIGHT = 16;
#define COMBINED_SCATTERING_TEXTURES

// An atmosphere layer of width 'width', and whose density is defined as
//   'exp_term' * exp('exp_scale' * h) + 'linear_term' * h + 'constant_term',
// clamped to [0,1], and where h is the altitude.
struct DensityProfileLayer {
	float width;
	float exp_term;
	float exp_scale;
	float linear_term;
	float constant_term;
};

// An atmosphere density profile made of several layers on top of each other
// (from bottom to top). The width of the last layer is ignored, i.e. it always
// extend to the top atmosphere boundary. The profile values vary between 0
// (null density) to 1 (maximum density).
struct DensityProfile {
	DensityProfileLayer layers[2];
};

struct AtmosphereParameters {
	// The solar irradiance at the top of the atmosphere.
	vec3 solar_irradiance;
	// The sun's angular radius. Warning: the implementation uses approximations
	// that are valid only if this angle is smaller than 0.1 radians.
	float sun_angular_radius;
	// The distance between the planet center and the bottom of the atmosphere.
	float bottom_radius;
	// The distance between the planet center and the top of the atmosphere.
	float top_radius;
	// The density profile of air molecules, i.e. a function from altitude to
	// dimensionless values between 0 (null density) and 1 (maximum density).
	DensityProfile rayleigh_density;
	// The scattering coefficient of air molecules at the altitude where their
	// density is maximum (usually the bottom of the atmosphere), as a function of
	// wavelength. The scattering coefficient at altitude h is equal to
	// 'rayleigh_scattering' times 'rayleigh_density' at this altitude.
	vec3 rayleigh_scattering;
	// The density profile of aerosols, i.e. a function from altitude to
	// dimensionless values between 0 (null density) and 1 (maximum density).
	DensityProfile mie_density;
	// The scattering coefficient of aerosols at the altitude where their density
	// is maximum (usually the bottom of the atmosphere), as a function of
	// wavelength. The scattering coefficient at altitude h is equal to
	// 'mie_scattering' times 'mie_density' at this altitude.
	vec3 mie_scattering;
	// The extinction coefficient of aerosols at the altitude where their density
	// is maximum (usually the bottom of the atmosphere), as a function of
	// wavelength. The extinction coefficient at altitude h is equal to
	// 'mie_extinction' times 'mie_density' at this altitude.
	vec3 mie_extinction;
	// The asymetry parameter for the Cornette-Shanks phase function for the
	// aerosols.
	float mie_phase_function_g;
	// The density profile of air molecules that absorb light (e.g. ozone), i.e.
	// a function from altitude to dimensionless values between 0 (null density)
	// and 1 (maximum density).
	DensityProfile absorption_density;
	// The extinction coefficient of molecules that absorb light (e.g. ozone) at
	// the altitude where their density is maximum, as a function of wavelength.
	// The extinction coefficient at altitude h is equal to
	// 'absorption_extinction' times 'absorption_density' at this altitude.
	vec3 absorption_extinction;
	// The average albedo of the ground.
	vec3 ground_albedo;
	// The cosine of the maximum Sun zenith angle for which atmospheric scattering
	// must be precomputed (for maximum precision, use the smallest Sun zenith
	// angle yielding negligible sky light radiance values. For instance, for the
	// Earth case, 102 degrees is a good choice - yielding mu_s_min = -0.2).
	float mu_s_min;
};

const AtmosphereParameters ATMOSPHERE = AtmosphereParameters(
	// The solar irradiance at the top of the atmosphere.
	vec3(1.474000,1.850400,1.911980),
	// The sun's angular radius. Warning: the implementation uses approximations
	// that are valid only if this angle is smaller than 0.1 radians.
	0.004675,
	// The distance between the planet center and the bottom of the atmosphere.
	6360.000000,
	// The distance between the planet center and the top of the atmosphere.
	6480.000000,
//	6480.000000,
	// The density profile of air molecules, i.e. a function from altitude to
	// dimensionless values between 0 (null density) and 1 (maximum density).
	DensityProfile(DensityProfileLayer[2](DensityProfileLayer(0.000000,0.000000,0.000000,0.000000,0.000000),DensityProfileLayer(0.000000,1.000000,-0.125000,0.000000,0.000000))),
	// The scattering coefficient of air molecules at the altitude where their
	// density is maximum (usually the bottom of the atmosphere), as a function of
	// wavelength. The scattering coefficient at altitude h is equal to
	// 'rayleigh_scattering' times 'rayleigh_density' at this altitude.
	vec3(0.005802,0.013558,0.033100),
	// The density profile of aerosols, i.e. a function from altitude to
	// dimensionless values between 0 (null density) and 1 (maximum density).
	DensityProfile(DensityProfileLayer[2](DensityProfileLayer(0.000000,0.000000,0.000000,0.000000,0.000000),DensityProfileLayer(0.000000,1.000000,-0.833333,0.000000,0.000000))),
	// The scattering coefficient of aerosols at the altitude where their density
	// is maximum (usually the bottom of the atmosphere), as a function of
	// wavelength. The scattering coefficient at altitude h is equal to
	// 'mie_scattering' times 'mie_density' at this altitude.
	vec3(0.003996,0.003996,0.003996),
	// The extinction coefficient of aerosols at the altitude where their density
	// is maximum (usually the bottom of the atmosphere), as a function of
	// wavelength. The extinction coefficient at altitude h is equal to
	// 'mie_extinction' times 'mie_density' at this altitude.
	vec3(0.004440,0.004440,0.004440),
	// The asymetry parameter for the Cornette-Shanks phase function for the
	// aerosols.
	0.800000,
	// The density profile of air molecules that absorb light (e.g. ozone), i.e.
	// a function from altitude to dimensionless values between 0 (null density)
	// and 1 (maximum density).
	DensityProfile(DensityProfileLayer[2](DensityProfileLayer(25.000000,0.000000,0.000000,0.066667,-0.666667),DensityProfileLayer(0.000000,0.000000,0.000000,-0.066667,2.666667))),
	// The extinction coefficient of molecules that absorb light (e.g. ozone) at
	// the altitude where their density is maximum, as a function of wavelength.
	// The extinction coefficient at altitude h is equal to
	// 'absorption_extinction' times 'absorption_density' at this altitude.
	vec3(0.000650,0.001881,0.000085),
	// The average albedo of the ground.
	vec3(0.100000,0.100000,0.100000),
	// The cosine of the maximum Sun zenith angle for which atmospheric scattering
	// must be precomputed (for maximum precision, use the smallest Sun zenith
	// angle yielding negligible sky light radiance values. For instance, for the
	// Earth case, 102 degrees is a good choice - yielding mu_s_min = -0.2).
	-0.207912);

const vec3 SKY_SPECTRAL_RADIANCE_TO_LUMINANCE = vec3(683.000000,683.000000,683.000000) * PI;
const vec3 SUN_SPECTRAL_RADIANCE_TO_LUMINANCE = vec3(98242.786222,69954.398112,66475.012354) * PI;

const vec3 sunbright = SUN_SPECTRAL_RADIANCE_TO_LUMINANCE / SUN_SPECTRAL_RADIANCE_TO_LUMINANCE.b;
const vec3 skybright = 0.2 * SKY_SPECTRAL_RADIANCE_TO_LUMINANCE / SKY_SPECTRAL_RADIANCE_TO_LUMINANCE;
// const vec3 skybright = 1.0 * (SKY_SPECTRAL_RADIANCE_TO_LUMINANCE / SUN_SPECTRAL_RADIANCE_TO_LUMINANCE) /  (SKY_SPECTRAL_RADIANCE_TO_LUMINANCE / SUN_SPECTRAL_RADIANCE_TO_LUMINANCE).b;

const float atmosphereScale = 5.0;
vec3 kCamera = vec3(0.0, 30.0 + cameraPosition.y/1000.0 + ATMOSPHERE.bottom_radius, 0.0);

#define timeDay 1.0
#define cubesmooth(x) ((x) * (x) * (3.0 - 2.0 * (x)))

vec3 kPoint(vec3 wPos) {
	return kCamera + wPos / 1000.0 * atmosphereScale;
}

#define atmosphereSampler SKY_SAMPLER

/*
* Use these textures as if you were just doing a texture lookup
* from another custom texture attatchment.
*/
vec4 transmittanceLookup(sampler3D Combined3WayTexture, vec2 coord) {
	// Clamp the edges of the texture to avoid bleeding from other textures
	coord = clamp(coord, vec2(0.5 / 256.0, 0.5 / 64.0), vec2(255.5 / 256.0, 63.5 / 64.0));
	
	return texture(Combined3WayTexture, vec3(coord * vec2(1.0, 0.5), 32.5 / 33.0));
}

vec4 irradianceLookup(sampler3D Combined3WayTexture, vec2 coord) {
	// Clamp the edges of the texture to avoid bleeding from other textures
	coord = clamp(coord, vec2(0.5 / 64.0, 0.5 / 16.0), vec2(63.5 / 64.0, 15.5 / 16.0));
	
	return texture(Combined3WayTexture, vec3(coord * vec2(0.25, 0.125) + vec2(0.0, 0.5), 32.5 / 33.0));
}


float ClampCosine(float mu) {
	return clamp(mu, float(-1.0), float(1.0));
}

float ClampDistance(float d) {
	return max(d, 0.0);
}

float ClampRadius(float r) {
	return clamp(r, ATMOSPHERE.bottom_radius, ATMOSPHERE.top_radius);
}

float SafeSqrt(float a) {
	return sqrt(max(a, 0.0));
}

float RayleighPhaseFunction(float nu) {
	float k = 3.0 / (16.0 * PI);

	return k * (1.0 + nu * nu);
}

float MiePhaseFunction(float g, float nu) {
	float k = 3.0 / (8.0 * PI) * (1.0 - g * g) / (2.0 + g * g);

	return k * (1.0 + nu * nu) / pow(1.0 + g * g - 2.0 * g * nu, 1.5);
}

float GetTextureCoordFromUnitRange(float x, int texture_size) {
	return 0.5 / float(texture_size) + x * (1.0 - 1.0 / float(texture_size));
}

bool RayIntersectsGround(float r, float mu) {
//	return false;
	return mu < 0.0 && r * r * (mu * mu - 1.0) + ATMOSPHERE.bottom_radius * ATMOSPHERE.bottom_radius >= 0.0;
}

float DistanceToTopAtmosphereBoundary(float r, float mu) {
	float discriminant = r * r * (mu * mu - 1.0) + ATMOSPHERE.top_radius * ATMOSPHERE.top_radius;

	return ClampDistance(-r * mu + SafeSqrt(discriminant));
}

vec2 GetTransmittanceTextureUvFromRMu(float r, float mu) {
	// Distance to top atmosphere boundary for a horizontal ray at ground level.
	float H = sqrt(ATMOSPHERE.top_radius * ATMOSPHERE.top_radius - ATMOSPHERE.bottom_radius * ATMOSPHERE.bottom_radius);

	// Distance to the horizon.
	float rho = SafeSqrt(r * r - ATMOSPHERE.bottom_radius * ATMOSPHERE.bottom_radius);

	// Distance to the top atmosphere boundary for the ray (r,mu), and its minimum
	// and maximum values over all mu - obtained for (r,1) and (r,mu_horizon).
	float d = DistanceToTopAtmosphereBoundary(r, mu);
	float d_min = ATMOSPHERE.top_radius - r;
	float d_max = rho + H;
	
	float x_mu = (d - d_min) / (d_max - d_min);
	float x_r = rho / H;
	return vec2(GetTextureCoordFromUnitRange(x_mu, TRANSMITTANCE_TEXTURE_WIDTH), GetTextureCoordFromUnitRange(x_r, TRANSMITTANCE_TEXTURE_HEIGHT));
}

vec3 GetTransmittanceToTopAtmosphereBoundary(float r, float mu) {
	vec2 uv = GetTransmittanceTextureUvFromRMu(r, mu);
	
	return transmittanceLookup(atmosphereSampler, uv).rgb;
}

vec3 GetTransmittanceToSun(float r, float mu_s) {
	float sin_theta_h = ATMOSPHERE.bottom_radius / r;
	float cos_theta_h = -sqrt(max(1.0 - sin_theta_h * sin_theta_h, 0.0));

	return GetTransmittanceToTopAtmosphereBoundary(r, mu_s) *
		smoothstep(-sin_theta_h * ATMOSPHERE.sun_angular_radius, sin_theta_h * ATMOSPHERE.sun_angular_radius, mu_s - cos_theta_h);
}

vec3 GetTransmittance(float r, float mu, float d, bool ray_r_mu_intersects_ground) {
	float r_d = ClampRadius(sqrt(d * d + 2.0 * r * mu * d + r * r));
	float mu_d = ClampCosine((r * mu + d) / r_d);

	if (ray_r_mu_intersects_ground) {
		return min(GetTransmittanceToTopAtmosphereBoundary(r_d, -mu_d) /
			GetTransmittanceToTopAtmosphereBoundary(r, -mu), vec3(1.0));
	} else {
		return min(GetTransmittanceToTopAtmosphereBoundary(r, mu) /
			GetTransmittanceToTopAtmosphereBoundary(r_d, mu_d), vec3(1.0));
	}

}

vec4 GetScatteringTextureUvwzFromRMuMuSNu(float r, float mu, float mu_s, float nu, bool ray_r_mu_intersects_ground) {
	// Distance to top atmosphere boundary for a horizontal ray at ground level.
	float H = sqrt(ATMOSPHERE.top_radius * ATMOSPHERE.top_radius - ATMOSPHERE.bottom_radius * ATMOSPHERE.bottom_radius);
	
	if (distance(r, ATMOSPHERE.bottom_radius) < 0.1) { r = ATMOSPHERE.bottom_radius; }
	
	// Distance to the horizon.
	float rho = SafeSqrt(r * r - ATMOSPHERE.bottom_radius * ATMOSPHERE.bottom_radius);
	float u_r = GetTextureCoordFromUnitRange(rho / H, SCATTERING_TEXTURE_R_SIZE);
	
	// Discriminant of the quadratic equation for the intersections of the ray
	// (r,mu) with the ground (see RayIntersectsGround).
	float r_mu = r * mu;
	float discriminant = r_mu * r_mu - r * r + ATMOSPHERE.bottom_radius * ATMOSPHERE.bottom_radius;

	float u_mu;
	if (false && ray_r_mu_intersects_ground) {
	// if (ray_r_mu_intersects_ground) {
		// Distance to the ground for the ray (r,mu), and its minimum and maximum
		// values over all mu - obtained for (r,-1) and (r,mu_horizon).
		float d = -r_mu - SafeSqrt(discriminant);
		float d_min = r - ATMOSPHERE.bottom_radius;
		float d_max = rho;

		u_mu = 0.5 - 0.5 * GetTextureCoordFromUnitRange(d_max == d_min ? 0.0 : (d - d_min) / (d_max - d_min), SCATTERING_TEXTURE_MU_SIZE / 2);
		
		float d2 = -r_mu + SafeSqrt(discriminant + H * H);
		float d_min2 = ATMOSPHERE.top_radius - r;
		float d_max2 = rho + H;

		float u_mu2 = 0.5 + 0.5 * GetTextureCoordFromUnitRange((d2 - d_min2) / (d_max2 - d_min2), SCATTERING_TEXTURE_MU_SIZE / 2);
		
	//	u_mu = mix(u_mu, u_mu2, 0.0);
	//	u_mu = mix(u_mu, 1.0, 0.5);
		
	} else {
		// Distance to the top atmosphere boundary for the ray (r,mu), and its
		// minimum and maximum values over all mu - obtained for (r,1) and
		// (r,mu_horizon).
		float d = -r_mu + SafeSqrt(discriminant + H * H);
		float d_min = ATMOSPHERE.top_radius - r;
		float d_max = rho + H;
		
		u_mu = 0.5 + 0.5 * GetTextureCoordFromUnitRange((d - d_min) / (d_max - d_min), SCATTERING_TEXTURE_MU_SIZE / 2);
		
		float d2 = -r_mu + SafeSqrt(discriminant + H * H);
		float d_min2 = ATMOSPHERE.top_radius - r;
		float d_max2 = rho + H;

		float u_mu2 = 0.5 + 0.5 * GetTextureCoordFromUnitRange((d2 - d_min2) / (d_max2 - d_min2), SCATTERING_TEXTURE_MU_SIZE / 2);
		
		
		// u_mu = mix(u_mu, u_mu2, 0.5);
	//	u_mu = mix(u_mu, 1.0, pow(1-abs(sunDirection.y), 4.0));
	}

	float d = DistanceToTopAtmosphereBoundary(ATMOSPHERE.bottom_radius, mu_s);
	float d_min = ATMOSPHERE.top_radius - ATMOSPHERE.bottom_radius;
	float d_max = H;
	float a = (d - d_min) / (d_max - d_min);
	float ASDSA = -2.0 * ATMOSPHERE.mu_s_min * ATMOSPHERE.bottom_radius / (d_max - d_min);
	float u_mu_s = GetTextureCoordFromUnitRange(max(1.0 - a / ASDSA, 0.0) / (1.0 + a), SCATTERING_TEXTURE_MU_S_SIZE);
	
	float u_nu = (nu + 1.0) / 2.0;
	
	//u_mu -= 0.1;
	return vec4(u_nu, u_mu_s, u_mu, u_r);
}


vec3 GetExtrapolatedSingleMieScattering(vec4 scattering) {
	if (scattering.r == 0.0) return vec3(0.0);
	
	return scattering.rgb * scattering.a / scattering.r
		* (ATMOSPHERE.rayleigh_scattering.r / ATMOSPHERE.mie_scattering.r)
		* (ATMOSPHERE.mie_scattering / ATMOSPHERE.rayleigh_scattering);
}

vec3 GetCombinedScattering(float r, float mu, float mu_s, float nu, bool ray_r_mu_intersects_ground, out vec3 single_mie_scattering) {
	vec4 uvwz = GetScatteringTextureUvwzFromRMuMuSNu(r, mu, mu_s, nu, ray_r_mu_intersects_ground);
	
	float tex_coord_x = uvwz.x * float(SCATTERING_TEXTURE_NU_SIZE - 1);
	float tex_x = floor(tex_coord_x);
	float lerp = tex_coord_x - tex_x;

	vec3 uvw0 = vec3((tex_x + uvwz.y) / float(SCATTERING_TEXTURE_NU_SIZE), uvwz.z, uvwz.w);
	vec3 uvw1 = vec3((tex_x + 1.0 + uvwz.y) / float(SCATTERING_TEXTURE_NU_SIZE), uvwz.z, uvwz.w);
	
	uvw0.z *= float(SCATTERING_TEXTURE_NU_SIZE) / float(SCATTERING_TEXTURE_NU_SIZE + 1.0);
	uvw1.z *= float(SCATTERING_TEXTURE_NU_SIZE) / float(SCATTERING_TEXTURE_NU_SIZE + 1.0);
	
	vec4 combined_scattering = texture(atmosphereSampler, uvw0) * (1.0 - lerp) + texture(atmosphereSampler, uvw1) * lerp;
	
	vec3 scattering = vec3(combined_scattering);
	single_mie_scattering = GetExtrapolatedSingleMieScattering(combined_scattering);
	
	
	return scattering;
}

vec2 GetIrradianceTextureUvFromRMuS(float r, float mu_s) {
	float x_r = (r - ATMOSPHERE.bottom_radius) / (ATMOSPHERE.top_radius - ATMOSPHERE.bottom_radius);
	float x_mu_s = mu_s * 0.5 + 0.5;

	return vec2(GetTextureCoordFromUnitRange(x_mu_s, IRRADIANCE_TEXTURE_WIDTH), GetTextureCoordFromUnitRange(x_r, IRRADIANCE_TEXTURE_HEIGHT));
}

vec3 GetIrradiance(float r, float mu_s) {
	vec2 uv = GetIrradianceTextureUvFromRMuS(r, mu_s);

	return irradianceLookup(atmosphereSampler, uv).rgb;
}

vec3 PrecomputedSky(
	vec3 camera, vec3 view_ray, float shadow_length,
	vec3 sun_direction, inout vec3 transmittance
) {
	// Compute the distance to the top atmosphere boundary along the view ray,
	// assuming the viewer is in space (or NaN if the view ray does not intersect
	// the atmosphere).
	float r = length(camera);
	float rmu = dot(camera, view_ray);
	float distance_to_top_atmosphere_boundary = -rmu - sqrt(rmu * rmu - r * r + ATMOSPHERE.top_radius * ATMOSPHERE.top_radius);
	
	vec3 inTransmittance = transmittance;
	
	// If the viewer is in space and the view ray intersects the move
	// the viewer to the top atmosphere boundary (along the view ray):
	if (distance_to_top_atmosphere_boundary > 0.0) {
		camera = camera + view_ray * distance_to_top_atmosphere_boundary;
		r = ATMOSPHERE.top_radius;
		rmu += distance_to_top_atmosphere_boundary;
	} else if (r > ATMOSPHERE.top_radius) {
		// If the view ray does not intersect the simply return 0.
		return vec3(0.0);
	}

	// Compute the r, mu, mu_s and nu parameters needed for the texture lookups.
	float mu = rmu / r;
	float mu_s = dot(camera, sun_direction) / r;
	float nu = dot(view_ray, sun_direction);

	bool ray_r_mu_intersects_ground = RayIntersectsGround(r, mu);
	
	transmittance = ray_r_mu_intersects_ground ? vec3(0.0) : GetTransmittanceToTopAtmosphereBoundary(r, mu);
	transmittance *= transmittance * inTransmittance;
	
	vec3 single_mie_scattering;
	vec3 scattering;

	if (shadow_length == 0.0) {
		scattering = GetCombinedScattering(
			r, mu, mu_s, nu, ray_r_mu_intersects_ground,
			single_mie_scattering);
	} else {
		// Case of light shafts (shadow_length is the total length noted l in our
		// paper): we omit the scattering between the camera and the point at
		// distance l, by implementing Eq. (18) of the paper (shadow_transmittance
		// is the T(x,x_s) term, scattering is the S|x_s=x+lv term).
		float d = shadow_length;
		float r_p = ClampRadius(sqrt(d * d + 2.0 * r * mu * d + r * r));

		float mu_p = (r * mu + d) / r_p;
		float mu_s_p = (r * mu_s + d * nu) / r_p;

		scattering = GetCombinedScattering(r_p, mu_p, mu_s_p, nu, ray_r_mu_intersects_ground, single_mie_scattering);

		vec3 shadow_transmittance =
			GetTransmittance(r, mu, shadow_length, ray_r_mu_intersects_ground);

		scattering = scattering * shadow_transmittance;
		single_mie_scattering = single_mie_scattering * shadow_transmittance;
	}
	
	vec3 inScatter = (scattering * RayleighPhaseFunction(nu) + single_mie_scattering * MiePhaseFunction(ATMOSPHERE.mie_phase_function_g, nu)) * inTransmittance / 3.14;
	
//	inScatter = SetSaturationLevel(inScatter, 1.5);
	
	return inScatter;
}

vec3 PrecomputedSkyToPoint(
	vec3 camera, vec3 point, float shadow_length,
	vec3 sun_direction, inout vec3 transmittance
) {
	// Compute the distance to the top atmosphere boundary along the view ray,
	// assuming the viewer is in space (or NaN if the view ray does not intersect
	// the atmosphere).
	vec3 view_ray = normalize(point - camera);
	view_ray = normalize(view_ray + vec3(0,0.01,0) * float(abs(view_ray.y) < 0.01)*sign(view_ray.y) );
//	vec3 view_ray = normalize(wDir);
	float r = length(camera);
	float rmu = dot(camera, view_ray);
	float distance_to_top_atmosphere_boundary = -rmu - sqrt(rmu * rmu - r * r + ATMOSPHERE.top_radius * ATMOSPHERE.top_radius);

	// If the viewer is in space and the view ray intersects the move
	// the viewer to the top atmosphere boundary (along the view ray):
	if (distance_to_top_atmosphere_boundary > 0.0) {
		camera = camera + view_ray * distance_to_top_atmosphere_boundary;
		r = ATMOSPHERE.top_radius;
		rmu += distance_to_top_atmosphere_boundary;
	}

	// Compute the r, mu, mu_s and nu parameters for the first texture lookup.
	float mu = rmu / r;
	float mu_s = dot(camera, sun_direction) / r;
	float nu = dot(view_ray, sun_direction);
	float d = length(point - camera);
	
	bool ray_r_mu_intersects_ground = RayIntersectsGround(r, mu);
	
	vec3 inTransmittance = transmittance;
	transmittance = GetTransmittance(r, mu, d, ray_r_mu_intersects_ground);
	transmittance *= inTransmittance;

	vec3 single_mie_scattering;
	vec3 scattering = GetCombinedScattering(r, mu, mu_s, nu, ray_r_mu_intersects_ground, single_mie_scattering);

	// Compute the r, mu, mu_s and nu parameters for the second texture lookup.
	// If shadow_length is not 0 (case of light shafts), we want to ignore the
	// scattering along the last shadow_length meters of the view ray, which we
	// do by subtracting shadow_length from d (this way scattering_p is equal to
	// the S|x_s=x_0-lv term in Eq. (17) of our paper).
	d = max(d - shadow_length, 0.0);
	float r_p = ClampRadius(sqrt(d * d + 2.0 * r * mu * d + r * r));
	float mu_p = (r * mu + d) / r_p;
	float mu_s_p = (r * mu_s + d * nu) / r_p;

	vec3 single_mie_scattering_p;
	vec3 scattering_p = GetCombinedScattering(
		r_p, mu_p, mu_s_p, nu, ray_r_mu_intersects_ground,
		single_mie_scattering_p);
	
	// Combine the lookup results to get the scattering between camera and point.
	vec3 shadow_transmittance = transmittance;
	if (shadow_length > 0.0) {
		// This is the T(x,x_s) term in Eq. (17) of our paper, for light shafts.
		shadow_transmittance = GetTransmittance(r, mu, d, ray_r_mu_intersects_ground);
	}
	
	scattering = scattering - shadow_transmittance * scattering_p;
	single_mie_scattering = single_mie_scattering - shadow_transmittance * single_mie_scattering_p;
	
	single_mie_scattering = GetExtrapolatedSingleMieScattering(vec4(scattering, single_mie_scattering.r));

	// Hack to avoid rendering artifacts when the sun is below the horizon.
	single_mie_scattering = single_mie_scattering * smoothstep(float(0.0), float(0.01), mu_s);
	single_mie_scattering = max(vec3(0.0), single_mie_scattering);
	
	vec3 inScatter = (scattering * RayleighPhaseFunction(nu) + single_mie_scattering * MiePhaseFunction(ATMOSPHERE.mie_phase_function_g, nu)) * inTransmittance;
	
//	inScatter = SetSaturationLevel(inScatter, 1.5);
	
	return inScatter;
}

vec3 GetSolarRadiance() {
  return ATMOSPHERE.solar_irradiance / (PI * ATMOSPHERE.sun_angular_radius * ATMOSPHERE.sun_angular_radius) * SUN_SPECTRAL_RADIANCE_TO_LUMINANCE;
}

vec3 GetSunAndSkyIrradiance(vec3 point, vec3 normal, vec3 sun_direction, out vec3 sky_irradiance) {
	float r = length(point);
	float mu_s = dot(point, sun_direction) / r;

	// Indirect irradiance (approximated if the surface is not horizontal).
	sky_irradiance = GetIrradiance(r, mu_s) * (1.0 + dot(normal, point) / r) * 0.5;
	
	// Direct irradiance.
	return ATMOSPHERE.solar_irradiance * GetTransmittanceToSun(r, mu_s);
}

vec3 GetSunIrradiance(vec3 point, vec3 sun_direction) {
	float r = length(point);
	float mu_s = dot(point, sun_direction) / r;

	// Direct irradiance.
	return ATMOSPHERE.solar_irradiance * GetTransmittanceToSun(r, mu_s);
}

vec3 CalculateNightSky(vec3 wDir, inout vec3 transmit) {
	const vec3 nightSkyColor = vec3(0.04, 0.04, 0.1)*0.4;
	
	float value = (dot(wDir, -sunDirection) * 0.5 + 0.5) + 0.5;
	value *= 1.0 - timeDay;
	float horizon = cubesmooth(pow(1.0 - abs(wDir.y), 4.0));
	
	return nightSkyColor * value * transmit;
}

#define FOG_ENABLED
#define FOG_POWER 1.5 // [1.0 1.5 2.0 3.0 4.0 6.0 8.0]
#define FOG_START 0.2 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8]

float CalculateFogfactor(vec3 position) {
	float fogfactor  = length(position) / far;
		  fogfactor  = clamp(fogfactor - FOG_START, 0.0, 1.0) / (1.0 - FOG_START);
		  fogfactor  = pow(fogfactor, FOG_POWER);
		  fogfactor  = clamp(fogfactor, 0.0, 1.0);
	
	return fogfactor;
}
#ifndef FOG_ENABLED
	#define CalculateFogfactor(position) 0.0
#endif

vec3 SkyAtmosphere(vec3 wDir, inout vec3 transmit) {
	vec3 inScatter = vec3(0.0);
//	inScatter += CalculateNightSky(wDir, transmit);
	inScatter += PrecomputedSky(kCamera, wDir, 0.0, sunDirection, transmit);
	
	return inScatter;
}

vec3 SkyAtmosphereToPoint(vec3 wPos0, vec3 wPos1, inout vec3 transmit) {
	vec3 wDir = normalize(wPos1 - wPos0);
	vec3 transmitIgnore = vec3(1.0);
	vec3 inScatter = vec3(0.0);
//	inScatter += CalculateNightSky(wDir, transmitIgnore);
	inScatter += PrecomputedSky(kCamera, wDir, 0.0, sunDirection, transmitIgnore);
	
	float fog0 = CalculateFogfactor(wPos0);
	float fog1 = CalculateFogfactor(wPos1);
	
	float fog = fog1 - fog0;
	
	inScatter *= transmit * fog;
	
	transmit *= 1.0 - fog;
	return inScatter;
}

#endif
