shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0) = 0.0;
uniform float thickness : hint_range(0.01, 1.0) = 0.2;
uniform float softness : hint_range(0.001, 0.5) = 0.08;
uniform float hue_speed : hint_range(-2.0, 2.0) = 0.15;
uniform float noise_scale : hint_range(1.0, 20.0) = 6.0;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.35;
uniform float global_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float saturation : hint_range(0.0, 1.0) = 0.55;
uniform float brightness : hint_range(0.5, 2.0) = 1.2;

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0;
	float angle = atan(centered.y, centered.x);

	float ring = 1.0 - smoothstep(thickness * 0.5 - softness, thickness * 0.5 + softness, abs(dist - radius));

	float hue = fract(angle / (2.0 * 3.14159265) + TIME * hue_speed + radius * 0.3);
	vec3 rainbow = hsv2rgb(vec3(hue, saturation, brightness));

	float n = noise(UV * noise_scale + TIME * 0.15);
	vec3 color = mix(rainbow, rainbow * n * 1.4, noise_strength);

	float alpha = ring * global_alpha;
	alpha *= mix(0.6, 1.0, n);

	COLOR = vec4(color, alpha);
}