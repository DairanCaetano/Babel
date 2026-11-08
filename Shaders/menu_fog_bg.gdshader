// Fundo dos menus de itens — névoa escura animada e pixelada — Babel
// Adaptado de "Pixelated Warped Fractal Noise" (shadecore_dev / godotshaders.com),
// baseado em https://godotshaders.com/shader/warped-fractal-noise/
//
// Copyright Gerardo Montaño 2025
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// ALTERAÇÕES PARA O BABEL:
// - Pixelização em pixels do JOGO (480x270), igual à transição de nuvens.
// - Cores em preto/cinza com transparência, sobre uma base escura (base_color).
// - Névoa na tela toda (sem sumir nas bordas).
// - blend_mode: 0 = normal (névoa cinza por cima da base, como nos menus);
//   1 = multiply (a névoa escurece a cor da base sem desbotar — fundos coloridos).
// - O TIME dos shaders continua correndo com o jogo pausado: anima nos menus.

shader_type canvas_item;

// Base escura por baixo da névoa
uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);
uniform int blend_mode : hint_enum("Normal", "Multiply") = 0;

uniform float speed = 0.05;
uniform vec2 game_resolution = vec2(480.0, 270.0);
uniform float pixel_size = 2.0;
uniform float zoom = 2.0;

uniform float gradient_pixelation : hint_range(0.001, 1.0) = 0.25;
uniform float background_threshold : hint_range(0.0, 1.0) = 0.15;
uniform float color_low_threshold : hint_range(0.0, 1.0) = 0.30;
uniform float color_mid_threshold : hint_range(0.0, 1.0) = 0.55;

// Tons da névoa (o alpha de cada um é a transparência)
uniform vec4 color_low : source_color = vec4(0.08, 0.08, 0.09, 0.25);
uniform vec4 color_mid : source_color = vec4(0.16, 0.16, 0.18, 0.35);
uniform vec4 color_high : source_color = vec4(0.30, 0.30, 0.32, 0.45);

#define iTime (TIME * speed)

const mat2 mtx = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));

float rand(vec2 n) {
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 ip = floor(p);
	vec2 u = fract(p);
	u = u * u * (3.0 - 2.0 * u);
	float res = mix(
		mix(rand(ip), rand(ip + vec2(1.0, 0.0)), u.x),
		mix(rand(ip + vec2(0.0, 1.0)), rand(ip + vec2(1.0, 1.0)), u.x), u.y);
	return res * res;
}

float fbm(vec2 p) {
	float f = 0.0;
	f += 0.500000 * noise(p + iTime); p = mtx * p * 2.02;
	f += 0.031250 * noise(p); p = mtx * p * 2.01;
	f += 0.250000 * noise(p); p = mtx * p * 2.03;
	f += 0.125000 * noise(p); p = mtx * p * 2.01;
	f += 0.062500 * noise(p); p = mtx * p * 2.04;
	f += 0.015625 * noise(p + sin(iTime));
	return f / 0.96875;
}

float pattern(in vec2 p) {
	return fbm(p + fbm(p + fbm(p)));
}

vec4 colormap(float x) {
	if (x < background_threshold) {
		return vec4(0.0);
	} else if (x < color_low_threshold) {
		return mix(vec4(0.0), color_low,
			round((x - background_threshold) / (color_low_threshold - background_threshold) / gradient_pixelation) * gradient_pixelation);
	} else if (x < color_mid_threshold) {
		return mix(color_low, color_mid,
			round((x - color_low_threshold) / (color_mid_threshold - color_low_threshold) / gradient_pixelation) * gradient_pixelation);
	}
	return mix(color_mid, color_high,
		round((x - color_mid_threshold) / (1.0 - color_mid_threshold) / gradient_pixelation) * gradient_pixelation);
}

void fragment() {
	// Pixelizar no grid do jogo
	vec2 grid = game_resolution / max(pixel_size, 1.0);
	vec2 uv = floor(UV * grid) / grid;
	// Corrige a proporção 16:9 (a névoa não fica esticada)
	vec2 p = uv * zoom * vec2(game_resolution.x / game_resolution.y, 1.0);
	vec4 fog = colormap(pattern(p));

	if (blend_mode == 1) {
		// Multiply: a névoa escurece a base (mantém a cor)
		vec3 mult = mix(vec3(1.0), fog.rgb, fog.a);
		COLOR = vec4(base_color.rgb * mult, base_color.a);
	} else {
		// Normal: névoa por cima da base escura
		float out_a = fog.a + base_color.a * (1.0 - fog.a);
		vec3 out_rgb = (fog.rgb * fog.a + base_color.rgb * base_color.a * (1.0 - fog.a)) / max(out_a, 0.0001);
		COLOR = vec4(out_rgb, out_a);
	}
}
