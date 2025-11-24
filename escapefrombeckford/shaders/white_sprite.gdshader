shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0; // 0 = normal, 1 = full white flash

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Preserve transparency automatically
    float alpha = tex.a;

    // Mix toward white only in the RGB channels
    vec3 flash = mix(tex.rgb, vec3(1.0), flash_amount);

    COLOR = vec4(flash, alpha);
}
