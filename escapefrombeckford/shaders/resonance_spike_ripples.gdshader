shader_type canvas_item;
render_mode blend_add;

uniform vec4 ring_colour : source_color = vec4(0.60, 0.86, 1.0, 1.0);
uniform vec4 core_colour : source_color = vec4(0.22, 0.52, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float frequency : hint_range(1.0, 30.0, 0.1) = 8.0;
uniform float speed : hint_range(-5.0, 5.0, 0.01) = 0.72;
uniform float ring_width : hint_range(0.001, 0.25, 0.001) = 0.075;
uniform float oval_y_scale : hint_range(0.25, 4.0, 0.01) = 1.8;
uniform float edge_softness : hint_range(0.001, 0.4, 0.001) = 0.22;
uniform float shimmer_strength : hint_range(0.0, 1.0, 0.01) = 0.18;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	vec2 oval = centered * vec2(1.0, oval_y_scale);
	float dist = length(oval);

	float shape = 1.0 - smoothstep(0.5 - edge_softness, 0.5, dist);
	float center_fade = smoothstep(0.03, 0.22, dist);
	float outer_fade = 1.0 - smoothstep(0.34, 0.5, dist);

	float phase = dist * frequency - TIME * speed;
	float ring_phase = abs(fract(phase) - 0.5);
	float ring = 1.0 - smoothstep(0.0, ring_width, ring_phase);

	float secondary_phase = abs(fract(phase * 0.63 + 0.27 + TIME * speed * 0.15) - 0.5);
	float secondary_ring = 1.0 - smoothstep(0.0, ring_width * 0.75, secondary_phase);

	float shimmer = sin((UV.x * 9.0 + UV.y * 5.0) + TIME * 4.0) * 0.5 + 0.5;
	float alpha = ring * 0.85 + secondary_ring * 0.35;
	alpha *= shape * center_fade * outer_fade;
	alpha *= opacity * (1.0 + shimmer * shimmer_strength);
	alpha = clamp(alpha, 0.0, 1.0);

	vec3 colour = mix(core_colour.rgb, ring_colour.rgb, clamp(dist * 1.8, 0.0, 1.0));
	colour += ring_colour.rgb * secondary_ring * 0.18;

	COLOR = vec4(colour, alpha);
}
