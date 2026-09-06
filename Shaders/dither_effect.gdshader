shader_type canvas_item;

// Controle do efeito
uniform float dither_size : hint_range(1.0, 32.0, 1.0) = 8.0;
uniform bool use_bayer_8x8 = true; // true = 8x8, false = 4x4
uniform float dither_threshold : hint_range(0.0, 1.0) = 0.5;

// Matriz Bayer 4x4
const float bayer4[16] = {
	0.0/16.0,   8.0/16.0,   2.0/16.0,  10.0/16.0,
	12.0/16.0,  4.0/16.0,  14.0/16.0,  6.0/16.0,
	3.0/16.0,  11.0/16.0,   1.0/16.0,   9.0/16.0,
	15.0/16.0,  7.0/16.0,  13.0/16.0,  5.0/16.0
};

// Matriz Bayer 8x8
const float bayer8[64] = {
	 0.0/64.0, 32.0/64.0,  8.0/64.0, 40.0/64.0,  2.0/64.0, 34.0/64.0, 10.0/64.0, 42.0/64.0,
	48.0/64.0, 16.0/64.0, 56.0/64.0, 24.0/64.0, 50.0/64.0, 18.0/64.0, 58.0/64.0, 26.0/64.0,
	12.0/64.0, 44.0/64.0,  4.0/64.0, 36.0/64.0, 14.0/64.0, 46.0/64.0,  6.0/64.0, 38.0/64.0,
	60.0/64.0, 28.0/64.0, 52.0/64.0, 20.0/64.0, 62.0/64.0, 30.0/64.0, 54.0/64.0, 22.0/64.0,
	 3.0/64.0, 35.0/64.0, 11.0/64.0, 43.0/64.0,  1.0/64.0, 33.0/64.0,  9.0/64.0, 41.0/64.0,
	51.0/64.0, 19.0/64.0, 59.0/64.0, 27.0/64.0, 49.0/64.0, 17.0/64.0, 57.0/64.0, 25.0/64.0,
	15.0/64.0, 47.0/64.0,  7.0/64.0, 39.0/64.0, 13.0/64.0, 45.0/64.0,  5.0/64.0, 37.0/64.0,
	63.0/64.0, 31.0/64.0, 55.0/64.0, 23.0/64.0, 61.0/64.0, 29.0/64.0, 53.0/64.0, 21.0/64.0
};

void fragment() {
	// Pega a cor original da textura
	vec4 tex_color = texture(TEXTURE, UV);

	// Multiplica pelo modulate (COLOR contém o modulate do TextureRect)
	vec4 final_color = tex_color * COLOR;

	// Calcula o alpha efetivo (combinação de textura e modulate)
	float effective_alpha = final_color.a;

	// Se o alpha estiver acima do threshold, não aplica dithering
	if (effective_alpha >= dither_threshold) {
		COLOR = final_color;
	} else {
		// Calcula coordenadas do pixel para o dithering
		vec2 pixel_coord = floor(UV * vec2(textureSize(TEXTURE, 0)) / dither_size);

		float threshold;

		if (use_bayer_8x8) {
			// Usa matriz 8x8
			int x = int(mod(pixel_coord.x, 8.0));
			int y = int(mod(pixel_coord.y, 8.0));
			int index = y * 8 + x;
			threshold = bayer8[index];
		} else {
			// Usa matriz 4x4
			int x = int(mod(pixel_coord.x, 4.0));
			int y = int(mod(pixel_coord.y, 4.0));
			int index = y * 4 + x;
			threshold = bayer4[index];
		}

		// Normaliza o alpha para o range do dithering (0.0 a dither_threshold)
		float normalized_alpha = effective_alpha / dither_threshold;

		// Aplica o dithering: se o alpha normalizado for menor que o threshold, descarta o pixel
		if (normalized_alpha < threshold) {
			COLOR.a = 0.0; // Pixel completamente transparente (efeito pixelizado)
		} else {
			COLOR = final_color;
			COLOR.a = 1.0; // Pixel completamente opaco
		}
	}
}