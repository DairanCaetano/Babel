shader_type canvas_item;

uniform float strength: hint_range(0.0, 0.1) = 0.02;	// intensidade da distorção
uniform float speed: hint_range(0.0, 10.0) = 2.0;	// velocidade da animação
uniform float frequency: hint_range(0.0, 50.0) = 20.0; // frequência das ondas

void fragment() {
	// Coordenadas UV originais
	vec2 uv = UV;

	// Criando ondas verticais (efeito calor)
	float wave_x = sin(uv.y * frequency + TIME * speed) * strength;
	float wave_y = cos(uv.x * frequency * 0.5 + TIME * speed * 1.2) * strength * 0.5;

	// Aplica distorção
	uv.x += wave_x;
	uv.y += wave_y;

	// Renderiza com distorção
	COLOR = texture(TEXTURE, uv) * COLOR;
}
