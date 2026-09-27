shader_type canvas_item;

uniform sampler2D icon_texture;
uniform float icon_scale : hint_range(0.1, 1.0) = 0.4;

uniform float wave_amount : hint_range(0.0, 0.3) = 0.06;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.5;
uniform float rainbow_speed : hint_range(0.0, 5.0) = 0.5;
uniform float saturation : hint_range(0.0, 1.0) = 0.85;
uniform float brightness : hint_range(0.5, 2.0) = 1.3;
uniform float glow_alpha : hint_range(0.0, 1.0) = 0.6;

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

float sample_icon_alpha(vec2 canvas_uv) {
	vec2 icon_uv = (canvas_uv - 0.5) / icon_scale + 0.5;
	if (icon_uv.x < 0.0 || icon_uv.x > 1.0 || icon_uv.y < 0.0 || icon_uv.y > 1.0) {
		return 0.0;
	}
	return texture(icon_texture, icon_uv).a;
}

void fragment() {
	vec2 offset1 = vec2(sin(UV.y * 8.0 + TIME * wave_speed), 0.0) * wave_amount;
	vec2 offset2 = vec2(sin(UV.y * 8.0 + TIME * wave_speed + 2.094), 0.0) * wave_amount;
	vec2 offset3 = vec2(sin(UV.y * 8.0 + TIME * wave_speed + 4.189), 0.0) * wave_amount;
	
	float a1 = sample_icon_alpha(UV + offset1);
	float a2 = sample_icon_alpha(UV + offset2);
	float a3 = sample_icon_alpha(UV + offset3);
	
	vec2 centered = UV - vec2(0.5);
	float base_angle = atan(centered.y, centered.x);
	float hue_base = fract(base_angle / TAU + TIME * rainbow_speed * 0.1);
	
	vec3 color1 = hsv2rgb(vec3(hue_base, saturation, brightness));
	vec3 color2 = hsv2rgb(vec3(fract(hue_base + 0.33), saturation, brightness));
	vec3 color3 = hsv2rgb(vec3(fract(hue_base + 0.66), saturation, brightness));
	
	vec3 final_rgb = color1 * a1 + color2 * a2 + color3 * a3;
	float final_alpha = max(a1, max(a2, a3));
	final_rgb /= max(final_alpha, 0.001);
	
	COLOR = vec4(final_rgb, final_alpha * glow_alpha * COLOR.a);
}