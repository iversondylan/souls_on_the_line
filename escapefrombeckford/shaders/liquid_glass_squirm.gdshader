shader_type canvas_item;
// shader by Pcniado, modified with internal squirming distortion spheres

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float u_roundness : hint_range(0.0, 1.0) = 1.0;

uniform float u_distortion_intensity = 1.0;
uniform float u_blur_intensity = 1.2;

// Internal distortion spheres
uniform float u_blob_intensity : hint_range(0.0, 20.0) = 6.0;
uniform float u_blob_radius : hint_range(0.02, 0.5) = 0.16;
uniform float u_blob_speed : hint_range(0.0, 5.0) = 1.0;
uniform float u_blob_blur_boost : hint_range(0.0, 5.0) = 0.6;
uniform float u_blob_wobble : hint_range(0.0, 0.2) = 0.03;
uniform float u_overlay_alpha : hint_range(0.0, 1.0) = 0.38;
uniform vec4 u_glass_tint : source_color = vec4(0.58, 0.88, 1.0, 1.0);
uniform vec4 u_shine_colour : source_color = vec4(0.92, 1.0, 1.0, 1.0);
uniform float u_tint_strength : hint_range(0.0, 1.0) = 0.12;
uniform float u_shine_strength : hint_range(0.0, 1.0) = 0.38;
uniform float u_shine_alpha_boost : hint_range(0.0, 1.0) = 0.18;
uniform float u_distortion_colour_strength : hint_range(0.0, 1.0) = 0.16;

vec3 screen_blend(vec3 base, vec3 blend) {
	return 1.0 - (1.0 - base) * (1.0 - blend);
}

float sdf_box(vec2 p, vec2 b, float r) {
	vec2 d = abs(p) - b + vec2(r);
	return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

vec3 get_blurred_color(sampler2D tex, vec2 screen_uv, vec2 pixel_size, float blur_radius) {
	vec3 color = vec3(0.0);
	float total_weight = 0.0;

	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * blur_radius * pixel_size;
			float weight = exp(-0.5 * float(x * x + y * y) / 2.0);

			color += texture(tex, screen_uv + offset).rgb * weight;
			total_weight += weight;
		}
	}

	return color / total_weight;
}

vec2 blob_center(float id, float t) {
	return vec2(
		0.5
			+ 0.20 * sin(t * (0.83 + id * 0.11) + id * 2.71)
			+ u_blob_wobble * sin(t * (2.10 + id * 0.37) + id * 5.13),
		0.5
			+ 0.20 * cos(t * (0.71 + id * 0.09) + id * 4.12)
			+ u_blob_wobble * cos(t * (1.84 + id * 0.29) + id * 3.47)
	);
}

void fragment() {
	vec2 pixel_scale = fwidth(UV);
	vec2 rect_size = 1.0 / pixel_scale;

	vec2 local_pos = (UV - 0.5) * rect_size;
	vec2 half_size = rect_size * 0.5;

	float max_radius = min(rect_size.x, rect_size.y) * 0.5;
	float current_radius = max_radius * u_roundness;

	float dist = sdf_box(local_pos, half_size, current_radius);

	if (dist > 0.0) {
		discard;
	}

	float min_side = min(rect_size.x, rect_size.y);
	float inversed_sdf = -dist / min_side;

	vec2 normalized_glass_coord = local_pos / max(length(local_pos), 0.0001);
	float dist_from_center = 1.0 - clamp(inversed_sdf / 0.3, 0.0, 1.0);

	float distortion = 1.0 - sqrt(1.0 - pow(dist_from_center, 2.0));

	vec2 offset_pixels = distortion * normalized_glass_coord * half_size * u_distortion_intensity;
	vec2 screen_uv_offset = offset_pixels * SCREEN_PIXEL_SIZE;
	vec2 target_uv = SCREEN_UV - screen_uv_offset;

	float current_blur_radius = u_blur_intensity * (1.0 - dist_from_center * 0.5);

	// Internal squirming distortion spheres
	float t = TIME * u_blob_speed;
	vec2 blob_offset = vec2(0.0);
	float blob_field = 0.0;

	for (int i = 0; i < 3; i++) {
		float id = float(i);
		vec2 center = blob_center(id, t);

		float radius = u_blob_radius * (1.0 + 0.12 * sin(t * (1.6 + id * 0.21) + id * 1.9));

		vec2 delta = UV - center;
		float d = length(delta);
		vec2 dir = delta / max(d, 0.0001);

		float mask = 1.0 - smoothstep(radius, radius * 1.35, d);

		// Radial bulge
		blob_offset += dir * mask * u_blob_intensity * SCREEN_PIXEL_SIZE;

		// Slight tangential "squirm"
		float swirl = sin(d * 30.0 - t * (3.2 + id * 0.6) + id * 2.4);
		blob_offset += vec2(-dir.y, dir.x) * mask * swirl * u_blob_intensity * 0.35 * SCREEN_PIXEL_SIZE;

		blob_field += mask;
	}

	blob_field = clamp(blob_field, 0.0, 1.0);
	target_uv += blob_offset;
	current_blur_radius += blob_field * u_blob_blur_boost;

	float edge_factor = smoothstep(0.0, 0.02, inversed_sdf);
	vec2 chromatic_shift = normalized_glass_coord * edge_factor * 3.0 * SCREEN_PIXEL_SIZE;

	float r = get_blurred_color(screen_texture, target_uv - chromatic_shift, SCREEN_PIXEL_SIZE, current_blur_radius).r;
	float g = get_blurred_color(screen_texture, target_uv, SCREEN_PIXEL_SIZE, current_blur_radius).g;
	float b = get_blurred_color(screen_texture, target_uv + chromatic_shift, SCREEN_PIXEL_SIZE, current_blur_radius).b;

	vec3 base_screen = texture(screen_texture, SCREEN_UV).rgb;
	vec3 refracted_screen = max(vec3(r, g, b), base_screen);

	float rim = 1.0 - smoothstep(0.0, 0.085, inversed_sdf);
	float diagonal = 1.0 - smoothstep(0.0, 0.055, abs((UV.x - UV.y * 0.55) - 0.22));
	float top_glint = 1.0 - smoothstep(0.0, 0.16, length((UV - vec2(0.32, 0.24)) * vec2(1.0, 1.8)));
	float shine = clamp(rim * 0.75 + diagonal * 0.35 + top_glint * 0.55 + blob_field * 0.18, 0.0, 1.0);

	vec3 refracted_lift = max(refracted_screen - base_screen, vec3(0.0)) * u_distortion_colour_strength;
	vec3 surface_lift = u_glass_tint.rgb * u_tint_strength;
	surface_lift += u_shine_colour.rgb * shine * u_shine_strength;
	surface_lift += refracted_lift;

	vec3 glass_color = screen_blend(base_screen, clamp(surface_lift, vec3(0.0), vec3(1.0)));

	float edge_fade = smoothstep(0.0, 0.025, inversed_sdf);
	float alpha = u_overlay_alpha + shine * u_shine_alpha_boost;
	COLOR = vec4(glass_color, edge_fade * clamp(alpha, 0.0, 1.0));
}
