shader_type canvas_item;

uniform float pixel_size = 4.0;       // Tamanho do "pixel" ajustável
uniform vec2 viewport_size;           // Tamanho do viewport, definido pelo GDScript
uniform vec4 trail_color = vec4(0.827, 0.047, 0.314, 1.0); // Cor hexadecimal #d30c50

void fragment() {
    // Converte as coordenadas de fragmento para a resolução pixelada
    vec2 pixelated_uv = floor(FRAGCOORD.xy / pixel_size) * pixel_size / viewport_size;

    // Define a cor final usando o valor de cor especificado
    COLOR = trail_color;
}
