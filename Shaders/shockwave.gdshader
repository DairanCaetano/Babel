shader_type canvas_item;

uniform vec2 center;
uniform float force;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform float size;
uniform float thickness;
// Parâmetro para a intensidade da aberração cromática
uniform float chromatic : hint_range(-1.0, 1.0, 0.01) = 0.1;

void fragment() {
    float ratio = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
    vec2 scaledUV = (SCREEN_UV - vec2(0.5, 0.0)) / vec2(ratio, 1.0) + vec2(0.5, 0.0); 
    
    float len = length(scaledUV - center);
    float mask = (1.0 - smoothstep(size-0.1, size, len)) *
                 smoothstep(size-thickness-0.1, size-thickness, len);
    
    vec2 disp = normalize(scaledUV - center) * force * mask;
    
    // Aplicando aberração cromática com deslocamentos diferentes para cada canal
    COLOR.r = texture(SCREEN_TEXTURE, SCREEN_UV - disp - (disp * chromatic)).r;
    COLOR.g = texture(SCREEN_TEXTURE, SCREEN_UV - disp).g;
    COLOR.b = texture(SCREEN_TEXTURE, SCREEN_UV - disp + (disp * chromatic)).b;
    COLOR.a = 2.0;
}