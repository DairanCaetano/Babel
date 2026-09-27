shader_type canvas_item;

uniform float speed : hint_range(0.1, 5.0) = 2.5;
uniform float saturation : hint_range(0.0, 1.0) = 0.85;
uniform float brightness : hint_range(0.5, 2.0) = 1.3;

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	float hue = fract(TIME * speed * 0.2);
	vec3 rainbow = hsv2rgb(vec3(hue, saturation, brightness));
	
	COLOR = vec4(rainbow, tex_color.a * COLOR.a);
}