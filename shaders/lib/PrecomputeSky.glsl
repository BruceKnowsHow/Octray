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
	6420.000000,
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

float ClampRadius(AtmosphereParameters atmosphere, float r) {
	return clamp(r, atmosphere.bottom_radius, atmosphere.top_radius);
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

bool RayIntersectsGround(AtmosphereParameters atmosphere, float r, float mu) {
//	return false;
	return mu < 0.0 && r * r * (mu * mu - 1.0) + atmosphere.bottom_radius * atmosphere.bottom_radius >= 0.0;
}

float DistanceToTopAtmosphereBoundary(AtmosphereParameters atmosphere, float r, float mu) {
	float discriminant = r * r * (mu * mu - 1.0) + atmosphere.top_radius * atmosphere.top_radius;

	return ClampDistance(-r * mu + SafeSqrt(discriminant));
}

vec2 GetTransmittanceTextureUvFromRMu(AtmosphereParameters atmosphere, float r, float mu) {
	// Distance to top atmosphere boundary for a horizontal ray at ground level.
	float H = sqrt(atmosphere.top_radius * atmosphere.top_radius - atmosphere.bottom_radius * atmosphere.bottom_radius);

	// Distance to the horizon.
	float rho = SafeSqrt(r * r - atmosphere.bottom_radius * atmosphere.bottom_radius);

	// Distance to the top atmosphere boundary for the ray (r,mu), and its minimum
	// and maximum values over all mu - obtained for (r,1) and (r,mu_horizon).
	float d = DistanceToTopAtmosphereBoundary(atmosphere, r, mu);
	float d_min = atmosphere.top_radius - r;
	float d_max = rho + H;
	
	float x_mu = (d - d_min) / (d_max - d_min);
	float x_r = rho / H;
	return vec2(GetTextureCoordFromUnitRange(x_mu, TRANSMITTANCE_TEXTURE_WIDTH), GetTextureCoordFromUnitRange(x_r, TRANSMITTANCE_TEXTURE_HEIGHT));
}

vec3 GetTransmittanceToTopAtmosphereBoundary(AtmosphereParameters atmosphere, sampler2D transmittance_texture, float r, float mu) {
	vec2 uv = GetTransmittanceTextureUvFromRMu(atmosphere, r, mu);
	
#if ShaderStage >= 30
	return vec3(transmittanceLookup(colortex4, uv).rgb);
#else
	return vec3(transmittanceLookup(gaux1, uv).rgb);
#endif
	return vec3(texture(transmittance_texture, uv));
}

vec3 GetTransmittanceToSun(AtmosphereParameters atmosphere, sampler2D transmittance_texture, float r, float mu_s) {
	float sin_theta_h = atmosphere.bottom_radius / r;
	float cos_theta_h = -sqrt(max(1.0 - sin_theta_h * sin_theta_h, 0.0));

	return GetTransmittanceToTopAtmosphereBoundary(atmosphere, transmittance_texture, r, mu_s) *
		smoothstep(-sin_theta_h * atmosphere.sun_angular_radius, sin_theta_h * atmosphere.sun_angular_radius, mu_s - cos_theta_h);
}

vec3 GetTransmittance(AtmosphereParameters atmosphere, sampler2D transmittance_texture, float r, float mu, float d, bool ray_r_mu_intersects_ground) {
	float r_d = ClampRadius(atmosphere, sqrt(d * d + 2.0 * r * mu * d + r * r));
	float mu_d = ClampCosine((r * mu + d) / r_d);

	if (ray_r_mu_intersects_ground) {
		return min(GetTransmittanceToTopAtmosphereBoundary(atmosphere, transmittance_texture, r_d, -mu_d) / 
			GetTransmittanceToTopAtmosphereBoundary(atmosphere, transmittance_texture, r, -mu), vec3(1.0));
	} else {
		return min(GetTransmittanceToTopAtmosphereBoundary(atmosphere, transmittance_texture, r, mu) /
			GetTransmittanceToTopAtmosphereBoundary(atmosphere, transmittance_texture, r_d, mu_d), vec3(1.0));
	}

}

vec4 GetScatteringTextureUvwzFromRMuMuSNu(AtmosphereParameters atmosphere, float r, float mu, float mu_s, float nu, bool ray_r_mu_intersects_ground) {
	// Distance to top atmosphere boundary for a horizontal ray at ground level.
	float H = sqrt(atmosphere.top_radius * atmosphere.top_radius - atmosphere.bottom_radius * atmosphere.bottom_radius);

	// Distance to the horizon.
	float rho = SafeSqrt(r * r - atmosphere.bottom_radius * atmosphere.bottom_radius);
	float u_r = GetTextureCoordFromUnitRange(rho / H, SCATTERING_TEXTURE_R_SIZE);

	// Discriminant of the quadratic equation for the intersections of the ray
	// (r,mu) with the ground (see RayIntersectsGround).
	float r_mu = r * mu;
	float discriminant = r_mu * r_mu - r * r + atmosphere.bottom_radius * atmosphere.bottom_radius;

	float u_mu;
	if (ray_r_mu_intersects_ground) {
		// Distance to the ground for the ray (r,mu), and its minimum and maximum
		// values over all mu - obtained for (r,-1) and (r,mu_horizon).
		float d = -r_mu - SafeSqrt(discriminant);
		float d_min = r - atmosphere.bottom_radius;
		float d_max = rho;

		u_mu = 0.5 - 0.5 * GetTextureCoordFromUnitRange(d_max == d_min ? 0.0 : (d - d_min) / (d_max - d_min), SCATTERING_TEXTURE_MU_SIZE / 2);
		
		float d2 = -r_mu + SafeSqrt(discriminant + H * H);
		float d_min2 = atmosphere.top_radius - r;
		float d_max2 = rho + H;

		float u_mu2 = 0.5 + 0.5 * GetTextureCoordFromUnitRange((d2 - d_min2) / (d_max2 - d_min2), SCATTERING_TEXTURE_MU_SIZE / 2);
		
	//	u_mu = mix(u_mu, u_mu2, 0.0);
	//	u_mu = mix(u_mu, 1.0, 1.0);
		
	} else {
		// Distance to the top atmosphere boundary for the ray (r,mu), and its
		// minimum and maximum values over all mu - obtained for (r,1) and
		// (r,mu_horizon).
		float d = -r_mu + SafeSqrt(discriminant + H * H);
		float d_min = atmosphere.top_radius - r;
		float d_max = rho + H;

		u_mu = 0.5 + 0.5 * GetTextureCoordFromUnitRange((d - d_min) / (d_max - d_min), SCATTERING_TEXTURE_MU_SIZE / 2);
		u_mu = mix(u_mu, 1.0, pow(1-abs(sunDir.y), 4.0)*0);
	}

	float d = DistanceToTopAtmosphereBoundary(atmosphere, atmosphere.bottom_radius, mu_s);
	float d_min = atmosphere.top_radius - atmosphere.bottom_radius;
	float d_max = H;
	float a = (d - d_min) / (d_max - d_min);
	float A = -2.0 * atmosphere.mu_s_min * atmosphere.bottom_radius / (d_max - d_min);
	float u_mu_s = GetTextureCoordFromUnitRange(max(1.0 - a / A, 0.0) / (1.0 + a), SCATTERING_TEXTURE_MU_S_SIZE);

	float u_nu = (nu + 1.0) / 2.0;
	return vec4(u_nu, u_mu_s, u_mu, u_r);
}


#ifdef COMBINED_SCATTERING_TEXTURES
	vec3 GetExtrapolatedSingleMieScattering(AtmosphereParameters atmosphere, vec4 scattering) {
		if (scattering.r == 0.0) return vec3(0.0);
		
		return scattering.rgb * scattering.a / scattering.r 
			* (atmosphere.rayleigh_scattering.r / atmosphere.mie_scattering.r) 
			* (atmosphere.mie_scattering / atmosphere.rayleigh_scattering);
	}
#endif

vec3 GetCombinedScattering(AtmosphereParameters atmosphere, sampler3D scattering_texture, sampler3D single_mie_scattering_texture, float r, float mu, float mu_s, float nu, bool ray_r_mu_intersects_ground, out vec3 single_mie_scattering) {
	vec4 uvwz = GetScatteringTextureUvwzFromRMuMuSNu(atmosphere, r, mu, mu_s, nu, ray_r_mu_intersects_ground);

	float tex_coord_x = uvwz.x * float(SCATTERING_TEXTURE_NU_SIZE - 1);
	float tex_x = floor(tex_coord_x);
	float lerp = tex_coord_x - tex_x;

	vec3 uvw0 = vec3((tex_x + uvwz.y) / float(SCATTERING_TEXTURE_NU_SIZE), uvwz.z, uvwz.w);
	vec3 uvw1 = vec3((tex_x + 1.0 + uvwz.y) / float(SCATTERING_TEXTURE_NU_SIZE), uvwz.z, uvwz.w);
	
	uvw0.z *= float(SCATTERING_TEXTURE_NU_SIZE) / float(SCATTERING_TEXTURE_NU_SIZE + 1.0);
	uvw1.z *= float(SCATTERING_TEXTURE_NU_SIZE) / float(SCATTERING_TEXTURE_NU_SIZE + 1.0);
	
	#ifdef COMBINED_SCATTERING_TEXTURES
		vec4 combined_scattering = texture(scattering_texture, uvw0) * (1.0 - lerp) + texture(scattering_texture, uvw1) * lerp;

		vec3 scattering = vec3(combined_scattering);
		single_mie_scattering = GetExtrapolatedSingleMieScattering(atmosphere, combined_scattering);
	#else
	vec3 scattering = vec3(
		texture(scattering_texture, uvw0) * (1.0 - lerp) +
		texture(scattering_texture, uvw1) * lerp);

	single_mie_scattering = vec3(
		texture(single_mie_scattering_texture, uvw0) * (1.0 - lerp) +
		texture(single_mie_scattering_texture, uvw1) * lerp);
	#endif
	
	return scattering;
}

vec2 GetIrradianceTextureUvFromRMuS(AtmosphereParameters atmosphere, float r, float mu_s) {
	float x_r = (r - atmosphere.bottom_radius) / (atmosphere.top_radius - atmosphere.bottom_radius);
	float x_mu_s = mu_s * 0.5 + 0.5;

	return vec2(GetTextureCoordFromUnitRange(x_mu_s, IRRADIANCE_TEXTURE_WIDTH), GetTextureCoordFromUnitRange(x_r, IRRADIANCE_TEXTURE_HEIGHT));
}

vec3 GetIrradiance(AtmosphereParameters atmosphere, sampler2D irradiance_texture, float r, float mu_s) {
	vec2 uv = GetIrradianceTextureUvFromRMuS(atmosphere, r, mu_s);

	return texture(irradiance_texture, uv).rgb;
}

vec3 GetSkyRadiance(
AtmosphereParameters atmosphere,
sampler2D transmittance_texture,
sampler3D scattering_texture,
sampler3D single_mie_scattering_texture,
vec3 camera, vec3 view_ray, float shadow_length,
vec3 sun_direction, out vec3 transmittance) {
	// Compute the distance to the top atmosphere boundary along the view ray,
	// assuming the viewer is in space (or NaN if the view ray does not intersect
	// the atmosphere).
	float r = length(camera);
	float rmu = dot(camera, view_ray);
	float distance_to_top_atmosphere_boundary = -rmu - sqrt(rmu * rmu - r * r + atmosphere.top_radius * atmosphere.top_radius);
	
	// If the viewer is in space and the view ray intersects the atmosphere, move
	// the viewer to the top atmosphere boundary (along the view ray):
	if (distance_to_top_atmosphere_boundary > 0.0) {
		camera = camera + view_ray * distance_to_top_atmosphere_boundary;
		r = atmosphere.top_radius;
		rmu += distance_to_top_atmosphere_boundary;
	} else if (r > atmosphere.top_radius) {
		// If the view ray does not intersect the atmosphere, simply return 0.
		transmittance = vec3(1.0);
		return vec3(0.0);
	}

	// Compute the r, mu, mu_s and nu parameters needed for the texture lookups.
	float mu = rmu / r;
	float mu_s = dot(camera, sun_direction) / r;
	float nu = dot(view_ray, sun_direction);

	bool ray_r_mu_intersects_ground = RayIntersectsGround(atmosphere, r, mu);
	transmittance = ray_r_mu_intersects_ground ? vec3(0.0) : GetTransmittanceToTopAtmosphereBoundary(atmosphere, transmittance_texture, r, mu);
	transmittance *= transmittance;
	
	vec3 single_mie_scattering;
	vec3 scattering;

	if (shadow_length == 0.0) {
		scattering = GetCombinedScattering(
			atmosphere, scattering_texture, single_mie_scattering_texture,
			r, mu, mu_s, nu, ray_r_mu_intersects_ground,
			single_mie_scattering);
	} else {
		// Case of light shafts (shadow_length is the total length noted l in our
		// paper): we omit the scattering between the camera and the point at
		// distance l, by implementing Eq. (18) of the paper (shadow_transmittance
		// is the T(x,x_s) term, scattering is the S|x_s=x+lv term).
		float d = shadow_length;
		float r_p = ClampRadius(atmosphere, sqrt(d * d + 2.0 * r * mu * d + r * r));

		float mu_p = (r * mu + d) / r_p;
		float mu_s_p = (r * mu_s + d * nu) / r_p;

		scattering = GetCombinedScattering(atmosphere, scattering_texture, single_mie_scattering_texture, r_p, mu_p, mu_s_p, nu, ray_r_mu_intersects_ground, single_mie_scattering);

		vec3 shadow_transmittance =
			GetTransmittance(atmosphere, transmittance_texture, r, mu, shadow_length, ray_r_mu_intersects_ground);

		scattering = scattering * shadow_transmittance;
		single_mie_scattering = single_mie_scattering * shadow_transmittance;
	}
	
	return scattering * RayleighPhaseFunction(nu) / 20.0 + single_mie_scattering * MiePhaseFunction(atmosphere.mie_phase_function_g, nu);
}

vec3 GetSkyRadianceToPoint(AtmosphereParameters atmosphere,
sampler2D transmittance_texture,
sampler3D scattering_texture,
sampler3D single_mie_scattering_texture,
vec3 camera, vec3 point, float shadow_length,
vec3 sun_direction, out vec3 transmittance) {
	// Compute the distance to the top atmosphere boundary along the view ray,
	// assuming the viewer is in space (or NaN if the view ray does not intersect
	// the atmosphere).
	vec3 view_ray = normalize(point - camera);
//	vec3 view_ray = normalize(wDir);
	float r = length(camera);
	float rmu = dot(camera, view_ray);
	float distance_to_top_atmosphere_boundary = -rmu - sqrt(rmu * rmu - r * r + atmosphere.top_radius * atmosphere.top_radius);

	// If the viewer is in space and the view ray intersects the atmosphere, move
	// the viewer to the top atmosphere boundary (along the view ray):
	if (distance_to_top_atmosphere_boundary > 0.0) {
		camera = camera + view_ray * distance_to_top_atmosphere_boundary;
		r = atmosphere.top_radius;
		rmu += distance_to_top_atmosphere_boundary;
	}

	// Compute the r, mu, mu_s and nu parameters for the first texture lookup.
	float mu = rmu / r;
	float mu_s = dot(camera, sun_direction) / r;
	float nu = dot(view_ray, sun_direction);
	float d = length(point - camera);
//	float d = length(wPos);
	
	bool ray_r_mu_intersects_ground = RayIntersectsGround(atmosphere, r, mu);

	transmittance = GetTransmittance(atmosphere, transmittance_texture, r, mu, d, ray_r_mu_intersects_ground);

	vec3 single_mie_scattering;
	vec3 scattering = GetCombinedScattering(atmosphere, scattering_texture, single_mie_scattering_texture,
		r, mu, mu_s, nu, ray_r_mu_intersects_ground, single_mie_scattering);

	// Compute the r, mu, mu_s and nu parameters for the second texture lookup.
	// If shadow_length is not 0 (case of light shafts), we want to ignore the
	// scattering along the last shadow_length meters of the view ray, which we
	// do by subtracting shadow_length from d (this way scattering_p is equal to
	// the S|x_s=x_0-lv term in Eq. (17) of our paper).
	d = max(d - shadow_length, 0.0);
	float r_p = ClampRadius(atmosphere, sqrt(d * d + 2.0 * r * mu * d + r * r));
	float mu_p = (r * mu + d) / r_p;
	float mu_s_p = (r * mu_s + d * nu) / r_p;

	vec3 single_mie_scattering_p;
	vec3 scattering_p = GetCombinedScattering(
		atmosphere, scattering_texture, single_mie_scattering_texture,
		r_p, mu_p, mu_s_p, nu, ray_r_mu_intersects_ground,
		single_mie_scattering_p);

	// Combine the lookup results to get the scattering between camera and point.
	vec3 shadow_transmittance = transmittance;
	if (shadow_length > 0.0) {
		// This is the T(x,x_s) term in Eq. (17) of our paper, for light shafts.
		shadow_transmittance = GetTransmittance(atmosphere, transmittance_texture, r, mu, d, ray_r_mu_intersects_ground);
	}
	
	scattering = scattering - shadow_transmittance * scattering_p;
	single_mie_scattering = single_mie_scattering - shadow_transmittance * single_mie_scattering_p;

	#ifdef COMBINED_SCATTERING_TEXTURES
		single_mie_scattering = GetExtrapolatedSingleMieScattering(atmosphere, vec4(scattering, single_mie_scattering.r));
	#endif

	// Hack to avoid rendering artifacts when the sun is below the horizon.
	single_mie_scattering = single_mie_scattering * smoothstep(float(0.0), float(0.01), mu_s);
	single_mie_scattering = max(vec3(0.0), single_mie_scattering);
	
	return scattering * RayleighPhaseFunction(nu) / 20.0 + single_mie_scattering * MiePhaseFunction(atmosphere.mie_phase_function_g, nu);
}

vec3 GetSolarRadiance() {
  return ATMOSPHERE.solar_irradiance / (PI * ATMOSPHERE.sun_angular_radius * ATMOSPHERE.sun_angular_radius) * SUN_SPECTRAL_RADIANCE_TO_LUMINANCE;
}

vec3 GetSunAndSkyIrradiance(AtmosphereParameters atmosphere, sampler2D transmittance_texture, sampler2D irradiance_texture, vec3 point, vec3 normal, vec3 sun_direction, out vec3 sky_irradiance) {
	float r = length(point);
	float mu_s = dot(point, sun_direction) / r;

	// Indirect irradiance (approximated if the surface is not horizontal).
	sky_irradiance = GetIrradiance(atmosphere, irradiance_texture, r, mu_s) * (1.0 + dot(normal, point) / r) * 0.5;

	// Direct irradiance.
	return atmosphere.solar_irradiance * GetTransmittanceToSun(atmosphere, transmittance_texture, r, mu_s);
}

#endif
