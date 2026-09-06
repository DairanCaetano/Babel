shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 16.0) = 2.0;

void fragment() {
	// quantiza as coordenadas de tela para uma grade de pixels
	vec2 uv = FRAGCOORD.xy;
	uv = floor(uv / pixel_size) * pixel_size;

	// descarta pixels que estão fora da grade
	vec2 grid_uv = mod(FRAGCOORD.xy, pixel_size);
	if (grid_uv.x > 1.0 || grid_uv.y > 1.0) {
		discard;
	}

	COLOR = vec4(1.0, 1.0, 1.0, 1.0);
}