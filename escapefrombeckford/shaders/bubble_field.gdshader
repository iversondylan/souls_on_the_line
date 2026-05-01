shader_type canvas_item;
render_mode blend_mix;

group_uniforms noise_textures;
uniform sampler2D panning_noise_texture : source_color;
uniform sampler2D haze_noise_texture : source_color;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

group_uniforms colours;
uniform vec4 base_colour : source_color = vec4(0.14, 0.21, 0.57, 1.0);
uniform vec4 secondary_colour : source_color = vec4(0.53, 0.68, 1.0, 1.0);
uniform vec4 edge_colour : source_color = vec4(0.85, 0.95, 1.0, 1.0);

group_uniforms barrier_shape;
uniform float radius : hint_range(0.0, 1.0, 0.01) = 0.46;
uniform float edge_width : hint_range(0.001, 0.5, 0.001) = 0.08;
uniform float alpha_strength : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform bool use_texture_alpha = false;

group_uniforms breathing;
uniform float breathe_rate : hint_range(0.0, 10.0, 0.01) = 1.2;
uniform float breathe_amplitude : hint_range(0.0, 0.5, 0.001) = 0.08;

group_uniforms distortion;
uniform float edge_distortion_amount : hint_range(0.0, 0.1, 0.001) = 0.012;
uniform float interior_distortion_amount : hint_range(0.0, 0.05, 0.001) = 0.003;
uniform float distortion_speed : hint_range(0.0, 5.0, 0.01) = 0.8;

group_uniforms colour_motion;
uniform float colour_pan_speed : hint_range(0.0, 5.0, 0.01) = 0.25;

vec3 screen_blend(vec3 base, vec3 blend) {
	return 1.0 - (1.0 - base) * (1.0 - blend);
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);

	// Smooth squash/stretch.
	// Positive breathe: visually taller and narrower.
	// Negative breathe: visually shorter and wider.
	float breathe = sin(TIME * breathe_rate * TAU) * breathe_amplitude;

	float scale_x = 1.0 + breathe;
	float scale_y = 1.0 - breathe;

	vec2 shaped = centered;
	shaped.x *= scale_x;
	shaped.y *= scale_y;

	float dist = length(shaped);

	// Smooth oval/circle mask. No ruffled boundary.
	float bubble_mask = 1.0 - smoothstep(radius - edge_width, radius, dist);

	// Smooth edge ring.
	float edge_outer = 1.0 - smoothstep(radius, radius + edge_width, dist);
	float edge_inner = 1.0 - smoothstep(radius - edge_width, radius, dist);
	float edge_mask = clamp(edge_outer - edge_inner, 0.0, 1.0);

	// Wider invisible band for screen distortion around the edge.
	float edge_distance = abs(dist - radius);
	float distortion_ring = 1.0 - smoothstep(0.0, edge_width * 2.0, edge_distance);

	// Interior colour movement.
	vec2 pan_uv = uv + vec2(-colour_pan_speed, colour_pan_speed * 0.37) * TIME;
	float mix_value = texture(panning_noise_texture, pan_uv).r;
	vec3 field_colour = mix(base_colour.rgb, secondary_colour.rgb, mix_value);

	// Haze distortion.
	vec2 haze_uv = uv + vec2(TIME * distortion_speed, TIME * distortion_speed * 0.73);
	float haze_x = texture(haze_noise_texture, haze_uv).r * 2.0 - 1.0;
	float haze_y = texture(haze_noise_texture, haze_uv + vec2(0.31, 0.47)).r * 2.0 - 1.0;

	vec2 noise_dir = vec2(haze_x, haze_y);

	// Distortion is always present, but strongest at the smooth edge.
	vec2 screen_offset = noise_dir * edge_distortion_amount * distortion_ring;
	screen_offset += noise_dir * interior_distortion_amount * bubble_mask;

	vec3 base_screen = texture(screen_texture, SCREEN_UV).rgb;
	vec3 distorted_screen = texture(screen_texture, SCREEN_UV + screen_offset).rgb;
	distorted_screen = max(distorted_screen, base_screen);

	float tex_alpha = 1.0;
	if (use_texture_alpha) {
		tex_alpha = texture(TEXTURE, UV).a;
	}

	vec3 lift = field_colour * bubble_mask * 0.35;
	lift += edge_colour.rgb * edge_mask;
	vec3 rgb = screen_blend(distorted_screen, clamp(lift, vec3(0.0), vec3(1.0)));
	rgb = max(rgb, base_screen);

	float alpha = alpha_strength * bubble_mask;
	alpha += edge_mask * 0.45;
	alpha *= tex_alpha;
	alpha = clamp(alpha, 0.0, 1.0);

	COLOR = vec4(rgb, alpha);
}
