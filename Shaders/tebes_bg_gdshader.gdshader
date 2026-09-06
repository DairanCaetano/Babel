shader_type canvas_item;

uniform float move_speed = 0.5;

void fragment() {
	// Desloca a coordenada UV horizontalmente com o tempo
	vec2 offset_uv = vec2(UV.x + TIME * move_speed, UV.y);

	// Obtém a cor da textura com o deslocamento aplicado
	COLOR = texture(TEXTURE, offset_uv);
}
