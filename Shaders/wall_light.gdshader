shader_type canvas_item;

// =====================================================================
//  WALL LIGHT — estética estilo Animal Well para camadas de parede.
//  Usado junto com o nó WallMask (Scripts/FX/wall_mask.gd), que gera a
//  máscara com TODAS as camadas de parede (inclusive as secretas).
//  Sem o WallMask rodando (ex.: no editor), a camada aparece normal.
// =====================================================================

// ----- Máscara (preenchida pelo WallMask em tempo de execução) -----
uniform sampler2D wall_mask : filter_nearest, repeat_disable;
uniform bool mask_ready = false;
uniform vec2 mask_size = vec2(512.0, 302.0);
uniform vec2 mask_offset = vec2(0.0);
uniform float mask_scale = 1.0;

group_uniforms Borda;
// Cor da luz que contorna as paredes.
uniform vec4 rim_color : source_color = vec4(1.0, 0.86, 0.6, 1.0);
// Intensidade do contorno por lado (luz vem de cima).
uniform float rim_top : hint_range(0.0, 2.0) = 0.55;
uniform float rim_sides : hint_range(0.0, 2.0) = 0.3;
uniform float rim_bottom : hint_range(0.0, 2.0) = 0.12;

group_uniforms Interior;
// Distância (px) da borda até o miolo escuro. Tebes (16px): ~6. Egito (32px): ~12.
uniform float inner_depth : hint_range(2.0, 24.0) = 6.0;
// Quanto o miolo escurece (0 = nada, 1 = vira a cor de inner_tint).
uniform float inner_darkness : hint_range(0.0, 1.0) = 0.55;
uniform vec4 inner_tint : source_color = vec4(0.08, 0.05, 0.08, 1.0);
// Irregularidade (px) da fronteira entre borda e miolo.
uniform float inner_jitter : hint_range(0.0, 4.0) = 1.5;

group_uniforms Textura_Animada;
// Luz em movimento nas paredes (portado do animal-well-recreation, MIT).
// Velocidade com que as formas se deslocam pela parede.
uniform float caustic_drift : hint_range(0.0, 5.0) = 1.2;
// Direção do movimento (x: -1 esquerda, 1 direita | y: -1 cima, 1 baixo).
uniform vec2 caustic_direction = vec2(-1.0, -1.0);
// Velocidade com que as formas se deformam (crescem, se dividem, se juntam).
uniform float caustic_morph : hint_range(0.0, 3.0) = 0.5;
// Tamanho das formas: maior = formas menores. 0.025 ≈ formas de 40-60px.
// Use o mesmo valor em x e y para as formas saírem arredondadas.
uniform vec2 caustic_scale = vec2(0.025, 0.025);
// 0 = sem efeito, 1 = igual ao exemplo (as partes apagadas ficam pretas).
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.85;
// Limiares do ruído para cada degrau de luz.
uniform vec3 caustic_thresholds = vec3(0.3, 0.35, 0.38);
// Quanto de luz cada degrau soma (o total deve dar 1.0).
uniform vec3 caustic_levels = vec3(0.3, 0.4, 0.3);
// Cor que as partes apagadas recebem (preto = escurece normal).
uniform vec4 caustic_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Cor que as partes acesas recebem (branco = cor original da arte).
uniform vec4 caustic_light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
group_uniforms;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float solid(vec2 wp) {
	vec2 uv = (wp * mask_scale + mask_offset) / mask_size;
	return texture(wall_mask, uv).a;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

#include "res://Shaders/includes/caustic_noise.gdshaderinc"

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	if (!mask_ready || base.a <= 0.0) {
		COLOR = base;
	} else {
		// Centro do pixel do jogo (em coordenadas de mundo).
		vec2 p = floor(world_pos) + 0.5;

		// ----- Contorno: vizinho vazio = borda iluminada -----
		float up = 1.0 - solid(p + vec2(0.0, -1.0));
		float down = 1.0 - solid(p + vec2(0.0, 1.0));
		float left = 1.0 - solid(p + vec2(-1.0, 0.0));
		float right = 1.0 - solid(p + vec2(1.0, 0.0));
		float rim = max(up * rim_top, max(max(left, right) * rim_sides, down * rim_bottom));

		// ----- Profundidade: longe de qualquer vazio = miolo escuro -----
		vec2 j = (vec2(hash(p), hash(p + 17.0)) - 0.5) * 2.0 * inner_jitter;
		vec2 q = p + j;
		float d1 = inner_depth * 0.5;
		float d2 = inner_depth;
		float ring1 = solid(q + vec2(d1, 0.0)) * solid(q + vec2(-d1, 0.0)) * solid(q + vec2(0.0, d1)) * solid(q + vec2(0.0, -d1));
		float ring2 = solid(q + vec2(d2, d2)) * solid(q + vec2(-d2, d2)) * solid(q + vec2(d2, -d2)) * solid(q + vec2(-d2, -d2));
		float depth = (ring1 + ring1 * ring2) * 0.5;
		depth = floor(depth * 2.0 + 0.5) * 0.5; // 3 degraus: 0, 0.5, 1

		vec3 col = mix(base.rgb, inner_tint.rgb, depth * inner_darkness);

		// ----- Textura animada (presa ao mundo, em degraus de luz) -----
		float n = cn_layered_noise(p * caustic_scale, cn_drift(caustic_direction, caustic_drift), caustic_morph);
		float lit = cn_light_steps(n, caustic_thresholds, caustic_levels);
		col = cn_apply(col, lit, caustic_strength, caustic_shadow_color.rgb, caustic_light_color.rgb);

		// ----- Soma a luz do contorno -----
		col += rim_color.rgb * rim;

		COLOR = vec4(col, base.a);
	}
}
