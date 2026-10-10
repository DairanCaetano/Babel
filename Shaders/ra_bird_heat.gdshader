shader_type canvas_item;

// Shader da forma de Pássaro de Fogo do Rá.
// Distorção de calor (igual à ideia do heat.gdshader) medida em PIXELS, pra
// não depender do tamanho da sprite sheet, + o blink de dano (mesmos nomes
// do blink.gdshader, então o piscar ao levar dano continua funcionando).

// Blink (dano)
uniform bool blink_active = false;
uniform vec4 blink_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float blink_intensity : hint_range(0.0, 1.0) = 1.0;

// Calor
uniform float heat_strength : hint_range(0.0, 6.0) = 1.5;	// deslocamento máximo em pixels
uniform float heat_speed : hint_range(0.0, 10.0) = 3.0;		// velocidade da animação
uniform float heat_frequency : hint_range(0.0, 1.0) = 0.15;	// ondas por pixel

void fragment() {
	vec2 px = UV / TEXTURE_PIXEL_SIZE;

	float wave_x = sin(px.y * heat_frequency + TIME * heat_speed) * heat_strength;
	float wave_y = cos(px.x * heat_frequency * 0.5 + TIME * heat_speed * 1.2) * heat_strength * 0.5;

	vec2 uv = UV + vec2(wave_x, wave_y) * TEXTURE_PIXEL_SIZE;
	vec4 color = texture(TEXTURE, uv);

	if (blink_active) {
		color.rgb = mix(color.rgb, blink_color.rgb, blink_intensity);
	}

	color.a *= COLOR.a;
	COLOR = color;
}
