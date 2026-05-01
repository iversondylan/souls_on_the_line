// Attach to a ColorRect in front of texture/background

shader_type canvas_item;

// Handles the concentric ripples
uniform float frequency: hint_range(0, 15, 0.01) = 4.0;
uniform float amplitude: hint_range(0, 3, 0.1) = 2.0;
uniform float ripple_rate : hint_range(0, 20.0, 1) = 5;

// Handles the waves themselves
uniform float wave_amplitude: hint_range(0.001, 0.1, 0.001) = 0.05;
uniform float wave_frequency: hint_range(0, 15, 0.01) = 4.0;
uniform vec4 ripple_colour : source_color = vec4(0.72, 0.9, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.5;

uniform sampler2D noise;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;

vec2 wave(vec2 uv, float time) {
    return vec2(
        uv.x + sin(uv.y * wave_frequency + time) * wave_amplitude,
        uv.y + sin(uv.x * wave_frequency + time) * wave_amplitude
    );
}

void fragment() {
	vec2 center_position = -1.0 + 2.0 * UV / (1.0 / TEXTURE_PIXEL_SIZE);
	float center_distance = length(center_position);
	
	float ripple = sin(center_distance * -frequency * PI + ripple_rate * TIME) * amplitude / (center_distance + 1.0);
	
	vec2 center_dir = center_position / max(center_distance, 0.0001);
	vec2 uv = FRAGCOORD.xy / (1.0 / SCREEN_PIXEL_SIZE).xy + center_dir * ripple * wave_amplitude;
    vec2 background_wave = wave(uv, TIME);
	vec4 background_texture = texture(SCREEN_TEXTURE, background_wave);

	float alpha_scalar = (1.0 - min(center_distance, 1.0)) * background_texture.x * 2.5; 
	
	float ripple_alpha = alpha_scalar * (ripple + background_texture.x * background_texture.y);
	ripple_alpha = max(ripple_alpha - (background_texture.y * 0.45), 0.0);
	ripple_alpha = clamp(ripple_alpha * opacity, 0.0, 1.0);

	COLOR = vec4(ripple_colour.rgb, ripple_alpha * ripple_colour.a);

}
