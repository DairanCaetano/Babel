shader_type canvas_item;

// Sistema de Blink (invencibilidade/parry/heal)
uniform bool blink_active = false;
uniform vec4 blink_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float blink_intensity : hint_range(0.0, 1.0) = 1.0;

// Sistema de Fire
uniform bool fire_active = false;
uniform vec4 fire_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float fire_intensity : hint_range(0.0, 1.0) = 0.4;

// ✅ NOVO: Sistema de Rainbow (level up / stat boost)
uniform bool rainbow_active = false;
uniform float rainbow_speed : hint_range(0.1, 5.0) = 2.0;
uniform float rainbow_intensity : hint_range(0.0, 1.0) = 0.65;

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec4 color = tex_color;
	
	// ✅ EFEITO 1: BLINK (prioridade máxima)
	if (blink_active) {
		color.rgb = mix(tex_color.rgb, blink_color.rgb, blink_intensity);
	}
	
	// ✅ EFEITO 2: FIRE COM PULSAR ANIMADO
	if (fire_active) {
		float pulse = 0.6 + 0.4 * sin(TIME * 6.0);
		float animated_intensity = fire_intensity * pulse;
		color.rgb = mix(color.rgb, fire_color.rgb, animated_intensity);
		color.rgb *= (1.0 + 0.2 * pulse);
	}
	
	// ✅ NOVO — EFEITO 3: RAINBOW (level up)
	if (rainbow_active) {
		float hue = fract(TIME * rainbow_speed * 0.2);
		vec3 rainbow_color = hsv2rgb(vec3(hue, 0.8, 1.0));
		float pulse = 0.7 + 0.3 * sin(TIME * rainbow_speed * 2.0);
		color.rgb = mix(color.rgb, rainbow_color, rainbow_intensity * pulse);
	}
	
	color.a *= COLOR.a;
	COLOR = color;
}