shader_type canvas_item;
render_mode blend_mix;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

group_uniforms smoke;
uniform vec4 smoke_color : source_color = vec4(0.82, 0.82, 0.82, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.55, 0.55, 0.55, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.96, 0.96, 0.96, 1.0);

group_uniforms shape;
// These are ratios of the largest guaranteed-safe radius inside the rect.
uniform float base_radius_ratio : hint_range(0.0, 1.0, 0.001) = 0.10;
uniform float end_radius_ratio : hint_range(0.0, 1.0, 0.001) = 0.78;
uniform float softness_ratio : hint_range(0.001, 0.5, 0.001) = 0.10;

// Chunkier cloud silhouette
uniform float lobe_strength : hint_range(0.0, 0.5, 0.001) = 0.16;
uniform float noise_strength : hint_range(0.0, 0.5, 0.001) = 0.04;
uniform float hollow_amount : hint_range(0.0, 1.0, 0.001) = 0.45;

group_uniforms motion;
uniform float swirl_strength : hint_range(0.0, 2.0, 0.001) = 0.28;
uniform float wobble_speed : hint_range(0.0, 10.0, 0.01) = 2.5;

group_uniforms alpha_settings;
uniform float opacity : hint_range(0.0, 2.0, 0.001) = 1.0;

// Optional: multiply by source texture alpha if using a textured Sprite/TextureRect.
uniform bool use_texture_alpha = false;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise21(p) * a;
		p = p * 2.0 + vec2(19.1, 7.3);
		a *= 0.5;
	}
	return v;
}

float ease_out_quad(float t) {
	return 1.0 - (1.0 - t) * (1.0 - t);
}

void fragment() {
	float t = clamp(progress, 0.0, 1.0);
	float grow_t = ease_out_quad(t);

	// Infer current on-screen rect size in pixels from UV derivatives.
	vec2 pixel_scale = fwidth(UV);
	vec2 rect_size = 1.0 / max(pixel_scale, vec2(0.00001));
	vec2 half_size = rect_size * 0.5;

	// Work in pixel space so the poof stays circular and bounded.
	vec2 p = (UV - vec2(0.5)) * rect_size;

	float radius_px = length(p);
	float angle = atan(p.y, p.x);

	// Largest radius that fits fully inside the rect, with a tiny safety margin.
	float safe_radius = min(half_size.x, half_size.y) - 2.0;
	safe_radius = max(safe_radius, 1.0);

	float current_radius = mix(base_radius_ratio, end_radius_ratio, grow_t) * safe_radius;
	float softness = softness_ratio * safe_radius;

	// Chunkier outward-only lobes.
	// Using lower frequencies and positive-only bumps makes the silhouette read as
	// bigger smoke puffs rather than ruffled fuzz.
	float lobe_a = pow(max(0.0, sin(angle * 4.0 + t * 7.0)), 1.5);
	float lobe_b = pow(max(0.0, sin(angle * 3.0 - t * 5.5 + 1.2)), 1.7);
	float lobe_c = pow(max(0.0, sin(angle * 5.0 + t * 4.0 + 2.1)), 1.3);

	float lobes = (lobe_a * 0.55 + lobe_b * 0.35 + lobe_c * 0.20);
	lobes *= lobe_strength * safe_radius;

	// Gentle noisy breakup.
	vec2 dir = vec2(cos(angle + t * wobble_speed), sin(angle - t * wobble_speed));
	vec2 noise_uv = p / max(safe_radius, 0.0001) * 4.5 + dir * swirl_strength + vec2(t * 2.7, -t * 2.1);
	float n = fbm(noise_uv);
	float boundary_noise = (n - 0.5) * 2.0 * noise_strength * safe_radius;

	float outer_boundary = current_radius + lobes + boundary_noise;

	// Critical: keep the entire soft edge inside the object.
	outer_boundary = min(outer_boundary, safe_radius - softness);
	outer_boundary = max(outer_boundary, 0.0);

	// Main cloud body
	float body = 1.0 - smoothstep(outer_boundary, outer_boundary + softness, radius_px);

	// Hollow interior as it dissipates
	float hollow_t = smoothstep(0.2, 0.85, t) * hollow_amount;
	float inner_radius = current_radius * mix(0.0, 0.52, hollow_t);
	float inner = 1.0 - smoothstep(inner_radius, inner_radius + softness * 1.5, radius_px);

	float smoke = max(body - inner * hollow_t, 0.0);

	// Slight interior breakup
	float interior_noise = fbm(p / max(safe_radius, 0.0001) * 6.0 + vec2(t * 4.0, -t * 3.0));
	smoke *= mix(0.82, 1.12, interior_noise);

	// Fast appear, slower fade
	float appear = smoothstep(0.0, 0.06, t);
	float fade = 1.0 - smoothstep(0.65, 1.0, t);

	// Soft shading
	vec2 light_dir = normalize(vec2(-0.7, -0.9));
	vec2 normalish = normalize(p + vec2(0.0001));
	float light_side = clamp(0.5 + 0.5 * dot(light_dir, normalish), 0.0, 1.0);

	vec3 col = mix(shadow_color.rgb, smoke_color.rgb, light_side);
	col = mix(col, highlight_color.rgb, smoothstep(0.45, 1.0, body) * 0.35);

	// Tiny central burst
	float burst = 1.0 - smoothstep(0.0, current_radius * 0.35, radius_px);
	col += burst * (1.0 - t) * 0.15;

	float tex_alpha = 1.0;
	if (use_texture_alpha) {
		tex_alpha = texture(TEXTURE, UV).a;
	}

	float alpha = smoke * appear * fade * opacity * tex_alpha;
	alpha = clamp(alpha, 0.0, 1.0);

	COLOR = vec4(col, alpha);
}