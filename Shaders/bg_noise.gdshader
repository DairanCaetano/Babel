shader_type canvas_item;

// =====================================================================
//  BG NOISE — as mesmas formas de luz em movimento das paredes, para o BG.
//  Aplicado nas camadas do BG pelo nó AplicarMaterial (Scripts/FX).
//  O padrão acompanha cada camada do parallax.
// =====================================================================

#include "res://Shaders/includes/caustic_noise.gdshaderinc"

group_uniforms Textura_Animada;
// Como as manchas se misturam com a arte do BG.
// Overlay / Soft Light: cinza 50% = neutro (não muda nada); mais claro clareia, mais escuro escurece.
uniform int blend_mode : hint_enum("Multiplicar", "Sobrepor (Overlay)", "Luz Suave (Soft Light)", "Tela (Screen)", "Cobrir com a cor") = 0;
uniform float caustic_drift : hint_range(0.0, 5.0) = 1.0;
// Direção do movimento (x: -1 esquerda, 1 direita | y: -1 cima, 1 baixo).
uniform vec2 caustic_direction = vec2(-1.0, 1.0);
uniform float caustic_morph : hint_range(0.0, 3.0) = 0.5;
// Maior = formas menores.
uniform vec2 caustic_scale = vec2(0.03, 0.03);
// 0 = sem efeito, 1 = partes apagadas ficam pretas.
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec3 caustic_thresholds = vec3(0.3, 0.35, 0.38);
uniform vec3 caustic_levels = vec3(0.3, 0.4, 0.3);
// Cor que as partes apagadas recebem (preto = escurece normal).
uniform vec4 caustic_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Cor que as partes acesas recebem (branco = cor original da arte).
uniform vec4 caustic_light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
group_uniforms;

group_uniforms Escurecer;
// Escurece a arte do fundo/decoração (aplicado antes das manchas).
// 0 = arte original, 1 = totalmente na cor do escuro.
uniform float escurecimento : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cor_do_escuro : source_color = vec4(0.0, 0.0, 0.0, 1.0);
group_uniforms;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// No Godot 4, COLOR já vem com a textura aplicada (não multiplicar de novo).
	vec4 col = COLOR;
	col.rgb = mix(col.rgb, cor_do_escuro.rgb, escurecimento);
	vec2 p = floor(world_pos) + 0.5;
	float n = cn_layered_noise(p * caustic_scale, cn_drift(caustic_direction, caustic_drift), caustic_morph);
	float lit = cn_light_steps(n, caustic_thresholds, caustic_levels);
	col.rgb = cn_apply_mode(col.rgb, lit, caustic_strength, caustic_shadow_color.rgb, caustic_light_color.rgb, blend_mode);
	COLOR = col;
}
