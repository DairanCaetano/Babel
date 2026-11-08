// =====================================================================
//  CAUSTIC NOISE — formas de luz em movimento (paredes e BG).
//  Portado do animal-well-recreation (GeordieTomo, licença MIT).
//  Use com: #include "res://Shaders/includes/caustic_noise.gdshaderinc"
// =====================================================================

vec2 cn_grad_random(vec2 uv) {
	uv = vec2(dot(uv, vec2(127.1, 311.7)), dot(uv, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float cn_gnoise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	vec2 blur = smoothstep(0.0, 1.0, f);
	return mix(
		mix(dot(cn_grad_random(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
			dot(cn_grad_random(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), blur.x),
		mix(dot(cn_grad_random(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
			dot(cn_grad_random(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), blur.x),
		blur.y) + 0.5;
}

// drift = deslocamento das formas (vetor: o padrão anda no sentido CONTRÁRIO a ele;
//         use cn_drift() para informar a direção do movimento) | morph = deformação
float cn_layered_noise(vec2 uv, vec2 drift, float morph) {
	float val = 0.0;
	float amp = 0.4;
	for (int i = 0; i < 5; i++) {
		float k = 0.1 + 0.05 * float(i);
		val += cn_gnoise(uv + TIME * drift * k) * amp;
		amp *= 0.5;
		uv *= 1.2;
		uv += vec2(cos(uv.y * 2.0 + TIME / amp * 0.1 * morph), sin(uv.x * 2.0 + TIME / amp * 0.1 * morph));
		uv = vec2(cn_gnoise(uv), cn_gnoise(uv));
	}
	return val;
}

// Direção em que as formas devem se mover (ex.: (-1, 1) = para a esquerda e para baixo)
// + velocidade -> vetor de deslocamento para cn_layered_noise.
vec2 cn_drift(vec2 direction, float speed) {
	if (length(direction) < 0.0001) {
		return vec2(0.0);
	}
	return -normalize(direction) * speed * 1.41421356;
}

// Aplica as manchas na cor: partes apagadas tingidas com shadow_color,
// partes acesas com light_color. strength 0 = sem efeito.
vec3 cn_apply(vec3 col, float lit, float strength, vec3 shadow_color, vec3 light_color) {
	vec3 factor = mix(shadow_color, light_color, lit);
	return col * mix(vec3(1.0), factor, strength);
}

// ----- Modos de mistura (a = arte, b = cor da mancha) -----
float cn_soft_light_d(float a) {
	return a <= 0.25 ? ((16.0 * a - 12.0) * a + 4.0) * a : sqrt(a);
}

vec3 cn_blend(vec3 a, vec3 b, int mode) {
	vec3 r = a * b; // 0 = Multiplicar
	if (mode == 1) { // Sobrepor (Overlay)
		r = vec3(
			a.r < 0.5 ? 2.0 * a.r * b.r : 1.0 - 2.0 * (1.0 - a.r) * (1.0 - b.r),
			a.g < 0.5 ? 2.0 * a.g * b.g : 1.0 - 2.0 * (1.0 - a.g) * (1.0 - b.g),
			a.b < 0.5 ? 2.0 * a.b * b.b : 1.0 - 2.0 * (1.0 - a.b) * (1.0 - b.b));
	} else if (mode == 2) { // Luz Suave (Soft Light)
		r = vec3(
			b.r <= 0.5 ? a.r - (1.0 - 2.0 * b.r) * a.r * (1.0 - a.r) : a.r + (2.0 * b.r - 1.0) * (cn_soft_light_d(a.r) - a.r),
			b.g <= 0.5 ? a.g - (1.0 - 2.0 * b.g) * a.g * (1.0 - a.g) : a.g + (2.0 * b.g - 1.0) * (cn_soft_light_d(a.g) - a.g),
			b.b <= 0.5 ? a.b - (1.0 - 2.0 * b.b) * a.b * (1.0 - a.b) : a.b + (2.0 * b.b - 1.0) * (cn_soft_light_d(a.b) - a.b));
	} else if (mode == 3) { // Tela (Screen)
		r = 1.0 - (1.0 - a) * (1.0 - b);
	} else if (mode == 4) { // Cobrir com a cor
		r = b;
	}
	return r;
}

// Igual a cn_apply, mas com modo de mistura escolhível.
vec3 cn_apply_mode(vec3 col, float lit, float strength, vec3 shadow_color, vec3 light_color, int mode) {
	vec3 layer = mix(shadow_color, light_color, lit);
	return mix(col, cn_blend(col, layer, mode), strength);
}

// Converte o ruído em degraus de luz (0 = apagado, 1 = aceso).
float cn_light_steps(float n, vec3 thresholds, vec3 levels) {
	return levels.x * step(thresholds.x, n)
		+ levels.y * step(thresholds.y, n)
		+ levels.z * step(thresholds.z, n);
}
