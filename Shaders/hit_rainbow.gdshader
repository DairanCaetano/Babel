// Dano iridescente — "rainbow palette cycling" (estilo Castlevania SOTN, PS1)
// Cada pixel ganha um "índice falso" a partir da própria cor (como o índice da
// paleta CLUT no PS1). O índice escolhe um tom no círculo de cores, e o círculo
// gira a cada passo do ciclo: as cores "escorrem" pelo sprite como óleo na água.
// hit_strength e cycle_time são controlados por script (0 = sprite normal).
shader_type canvas_item;

// Controlados pelo script
uniform float hit_strength : hint_range(0.0, 1.0) = 0.0;
uniform float cycle_time = 0.0;

// Visual
// Quantas voltas no arco-íris o sprite inteiro dá: baixo = faixas largas (óleo), alto = picotado (SOTN)
uniform float spread : hint_range(0.0, 16.0) = 3.0;
// 0 = índice pelo brilho (faixas suaves) | 1 = índice pela cor (chuvisco tipo PS1)
uniform float color_index : hint_range(0.0, 1.0) = 0.6;
// Quantos tons a "paleta" tem (poucos = cara de paleta de 8/16 cores)
uniform int palette_steps : hint_range(2, 64) = 12;
uniform float saturation : hint_range(0.0, 1.0) = 0.9;
// Quanto do volume (claro/escuro) do sprite original é mantido
uniform float keep_shading : hint_range(0.0, 1.0) = 0.7;
// Brilho geral do efeito
uniform float brightness : hint_range(0.5, 2.0) = 1.15;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float color_hash(vec3 col) {
	// cores iguais → mesmo índice (como uma entrada de paleta)
	vec3 q = floor(col * 31.0 + 0.5);
	return fract(sin(dot(q, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float luma = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
	float idx = mix(luma, color_hash(base.rgb), color_index);
	float hue = fract(idx * spread + cycle_time);
	float steps = float(palette_steps);
	hue = floor(hue * steps) / steps;
	vec3 rainbow = hsv2rgb(vec3(hue, saturation, 1.0));
	float shade = mix(1.0, clamp(luma * 1.6 + 0.25, 0.0, 1.0), keep_shading);
	rainbow *= shade * brightness;
	COLOR = vec4(mix(base.rgb, rainbow, hit_strength), base.a);
}
