shader_type canvas_item;
render_mode blend_add;

group_uniforms Color;
uniform vec3 primary_color : source_color = vec3(1.0);
uniform vec3 secondary_color : source_color = vec3(1.0, 0.8, 0.4);
uniform float emission = 2.0;
uniform float emission_mult = 1.0;

group_uniforms Shape;
uniform float streaks1_count = 5.0;
uniform float streaks2_count = 11.0;
uniform float streaks_fade : hint_range(-2.0, 2.0, 0.01) = 0.4;
uniform float streaks_thickness : hint_range(0.0, 4.0, 0.01) = 0.5;
uniform float center_radius : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float fade_radius : hint_range(0.0, 1.0, 0.01) = 0.4;

float overlay(float base, float blend){
	float limit = step(0.5, base);
	return mix(
		2.0 * base * blend,
		1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
		limit
	);
}

void fragment() {
	vec2 centered_uv = UV - 0.5;
	float angle = atan(centered_uv.x, centered_uv.y);
	float radius = length(centered_uv) * 2.0;

	float streaks1 = sin(angle * streaks1_count + TIME);
	float streaks2 = sin(angle * streaks2_count - TIME);

	float value = overlay(streaks1, streaks2);

	value -= (1.0 - radius) * streaks_fade;
	value *= 1.0 - (radius - value * streaks_thickness);

	float mask = max(1.0 - radius, 0.0);
	value *= mask;
	value = min(value, mask);

	value = smoothstep(0.1, 1.0, value);

	float fade_denominator = max(fade_radius - center_radius, 0.001);
	value *= pow(clamp((radius - center_radius) / fade_denominator, 0.0, 1.0), 4.0);

	vec3 final_color = mix(secondary_color, primary_color, value);
	float alpha = value;

	COLOR = vec4(final_color * emission * emission_mult, alpha) * COLOR;
}