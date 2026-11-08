// Silhueta de cor chapada — Babel
// Pinta o sprite inteiro de uma cor só, mantendo o contorno (alpha) do desenho.
// Usado no efeito de morte do chefe (Tola e chefe em vermelho sobre fundo preto).
// amount: 1 = silhueta total, 0 = sprite normal (para o fade de saída).

shader_type canvas_item;

uniform vec4 silhouette_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	vec4 flat_color = vec4(silhouette_color.rgb, tex.a * silhouette_color.a);
	COLOR = mix(tex, flat_color, amount);
}
