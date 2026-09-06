shader_type canvas_item;

// Sistema de Blink (invencibilidade/parry/heal)
uniform bool blink_active = false;
uniform vec4 blink_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float blink_intensity : hint_range(0.0, 1.0) = 1.0;

// Sistema de Fire
uniform bool fire_active = false;
uniform vec4 fire_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float fire_intensity : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec4 color = tex_color;

	// ✅ EFEITO 1: BLINK (prioridade máxima)
	if (blink_active) {
		color.rgb = mix(tex_color.rgb, blink_color.rgb, blink_intensity);
	}

	// ✅ EFEITO 2: FIRE COM PULSAR ANIMADO
	if (fire_active) {
		// Pulsar baseado no tempo (3 pulsações por segundo)
		float pulse = 0.6 + 0.4 * sin(TIME * 6.0);

		// Intensidade varia entre fire_intensity e fire_intensity * pulse
		float animated_intensity = fire_intensity * pulse;

		color.rgb = mix(color.rgb, fire_color.rgb, animated_intensity);
		color.rgb *= (1.0 + 0.2 * pulse); // Aumenta brilho com o pulsar
	}

	// ✅ CRÍTICO: APLICAR APENAS O ALPHA DO MODULATE (transparência)
	// NÃO multiplica RGB (evita escurecer), apenas aplica transparência
	color.a *= COLOR.a;

	COLOR = color;
}