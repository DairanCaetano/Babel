// Vinheta de ruído escuro nas bordas da tela — Babel
// Adaptado de "Dark Noise Vignette" (Silver637 / godotshaders.com)
//
// ALTERAÇÕES PARA O BABEL:
// - intensity: liga/desliga suave (controlado pelo ScreenVignette).
// - reach: suavidade da borda interna da vinheta. Substitui o uso
//   do alpha da cor no original (lá, alpha = 1 gerava smoothstep(1, 1, x),
//   que é indefinido em GLSL).
// - Pixelização em pixels do JOGO (480x270), igual à transição de nuvens.
// - speed protegido contra divisão por zero.

shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
// Tamanho da vinheta: MENOR = escuro só nas beiradas; MAIOR = avança para o centro.
uniform float radius = 1.0;
uniform float speed : hint_range(0.01, 10.0) = 1.0;
uniform vec4 effect_color : source_color = vec4(0.251, 0.0, 0.0, 1.0);
// Suavidade da borda interna: MENOR = borda mais suave e vinheta um pouco menor;
// MAIOR = borda mais dura e vinheta um pouco maior. (O tamanho principal é o radius.)
uniform float reach : hint_range(0.0, 0.99) = 0.6;

uniform vec2 game_resolution = vec2(480.0, 270.0);
uniform float pixel_size = 1.0;

float snoise(vec3 uv, float res) {
	const vec3 s = vec3(1e0, 1e2, 1e3);
	uv *= res;

	vec3 uv0 = floor(mod(uv, res)) * s;
	vec3 uv1 = floor(mod(uv + vec3(1.0), res)) * s;

	vec3 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);

	vec4 v = vec4(uv0.x + uv0.y + uv0.z, uv1.x + uv0.y + uv0.z,
				uv0.x + uv1.y + uv0.z, uv1.x + uv1.y + uv0.z);

	vec4 r = fract(sin(v * 1e-1) * 1e3);
	float r0 = mix(mix(r.x, r.y, f.x), mix(r.z, r.w, f.x), f.y);

	r = fract(sin((v + uv1.z - uv0.z) * 1e-1) * 1e3);
	float r1 = mix(mix(r.x, r.y, f.x), mix(r.z, r.w, f.x), f.y);

	return mix(r0, r1, f.z) * 2.0 - 1.0;
}

void fragment() {
	// Pixelizar no grid do jogo
	vec2 grid = game_resolution / max(pixel_size, 1.0);
	vec2 uv = (floor(UV * grid) + 0.5) / grid;

	vec2 p = (uv - 0.5) * radius;

	float color = 3.0 - (3.0 * length(2.0 * p));

	vec3 coord = vec3(atan(p.x, p.y) / 6.2832 + 0.5, length(p) * 0.4, 0.5);

	float time = -TIME / max(speed, 0.01);
	for (int i = 1; i <= 7; i++) {
		float power = pow(2.0, float(i));
		color += (1.5 / power) * snoise(coord + vec3(0.0, -time * 0.05, time * 0.01), power * 16.0);
	}

	// Centro transparente, bordas opacas
	float alpha = 1.0 - smoothstep(reach, 1.0, color);

	COLOR = vec4(
		color - (1.0 - effect_color.r),
		color - (1.0 - effect_color.g),
		color - (1.0 - effect_color.b),
		clamp(alpha, 0.0, 1.0) * intensity
	);
}
