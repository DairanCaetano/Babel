shader_type canvas_item;

// Sistema de Blink (invencibilidade/parry/heal)
uniform bool blink_active = false;
uniform vec4 blink_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float blink_intensity : hint_range(0.0, 1.0) = 1.0;
// Estilo do blink de dano: Branco (cor sólida acima) ou Arco-íris (iridescente,
// "rainbow palette cycling" estilo Castlevania SOTN). Inimigos usam Arco-íris;
// a Tola continua no Branco (invencibilidade/parry/cura).
uniform int blink_style : hint_enum("Branco:0", "Arco-íris:1") = 0;

group_uniforms Dano_Arco_Iris;
// Opacidade máxima do arco-íris sobre o sprite
uniform float hit_opacity : hint_range(0.0, 1.0) = 0.6;
// Parte da contagem do blink usada pelo efeito (0.5 = metade: 0,4 s vira 0,2 s)
uniform float hit_active_fraction : hint_range(0.05, 1.0) = 0.5;
// Em que ponto do efeito o fade começa (0.5 = na metade; 1 = sem fade)
uniform float hit_fade_start : hint_range(0.0, 1.0) = 0.5;
// Voltas no arco-íris: baixo = faixas largas (óleo), alto = picotado (SOTN)
uniform float hit_spread : hint_range(0.0, 16.0) = 3.0;
// 0 = índice pelo brilho (faixas suaves) | 1 = pela cor do pixel (chuvisco PS1)
uniform float hit_color_index : hint_range(0.0, 1.0) = 0.6;
// Quantos tons a "paleta" tem
uniform int hit_palette_steps : hint_range(2, 64) = 12;
uniform float hit_saturation : hint_range(0.0, 1.0) = 0.9;
// Quanto do claro/escuro do sprite original é mantido
uniform float hit_keep_shading : hint_range(0.0, 1.0) = 0.7;
uniform float hit_brightness : hint_range(0.5, 2.0) = 1.15;
// Passos de cor por segundo (30 = ritmo de PS1) e quanto gira a cada passo
uniform float hit_cycle_fps : hint_range(1.0, 60.0) = 30.0;
uniform float hit_cycle_step : hint_range(0.0, 0.5) = 0.08;
group_uniforms;

// Sistema de Fire
uniform bool fire_active = false;
uniform vec4 fire_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float fire_intensity : hint_range(0.0, 1.0) = 0.4;

// ✅ NOVO: Sistema de Rainbow (level up / stat boost)
uniform bool rainbow_active = false;
uniform float rainbow_speed : hint_range(0.1, 5.0) = 2.0;
uniform float rainbow_intensity : hint_range(0.0, 1.0) = 0.65;

// ✅ NOVO: Contorno (Lâmina do Contra-Ataque: verde = cura, vermelho = bônus)
uniform bool outline_active = false;
uniform vec4 outline_color : source_color = vec4(0.35, 1.0, 0.45, 1.0);
uniform float outline_width = 1.0;

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

float color_hash(vec3 col) {
	vec3 q = floor(col * 31.0 + 0.5);
	return fract(sin(dot(q, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

vec3 hit_rainbow_color(vec3 base) {
	float luma = dot(base, vec3(0.2126, 0.7152, 0.0722));
	float idx = mix(luma, color_hash(base), hit_color_index);
	float cycle = floor(TIME * hit_cycle_fps) * hit_cycle_step;
	float hue = fract(idx * hit_spread + cycle);
	float steps = float(hit_palette_steps);
	hue = floor(hue * steps) / steps;
	vec3 rgb = hsv2rgb(vec3(hue, hit_saturation, 1.0));
	float shade = mix(1.0, clamp(luma * 1.6 + 0.25, 0.0, 1.0), hit_keep_shading);
	return rgb * shade * hit_brightness;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec4 color = tex_color;
	
	// ✅ EFEITO 1: BLINK (prioridade máxima)
	if (blink_active) {
		if (blink_style == 1) {
			// Os scripts descem blink_intensity de 1 a 0: usamos a primeira parte
			float elapsed = (1.0 - blink_intensity) / hit_active_fraction;
			float strength = 0.0;
			if (elapsed < 1.0) {
				float fade = 1.0;
				if (hit_fade_start < 1.0) {
					fade = 1.0 - smoothstep(hit_fade_start, 1.0, elapsed);
				}
				strength = hit_opacity * fade;
			}
			color.rgb = mix(tex_color.rgb, hit_rainbow_color(tex_color.rgb), strength);
		} else {
			color.rgb = mix(tex_color.rgb, blink_color.rgb, blink_intensity);
		}
	}
	
	// ✅ EFEITO 2: FIRE COM PULSAR ANIMADO
	if (fire_active) {
		float pulse = 0.6 + 0.4 * sin(TIME * 6.0);
		float animated_intensity = fire_intensity * pulse;
		color.rgb = mix(color.rgb, fire_color.rgb, animated_intensity);
		color.rgb *= (1.0 + 0.2 * pulse);
	}
	
	// ✅ NOVO — EFEITO 3: RAINBOW (level up)
	if (rainbow_active) {
		float hue = fract(TIME * rainbow_speed * 0.2);
		vec3 rainbow_color = hsv2rgb(vec3(hue, 0.8, 1.0));
		float pulse = 0.7 + 0.3 * sin(TIME * rainbow_speed * 2.0);
		color.rgb = mix(color.rgb, rainbow_color, rainbow_intensity * pulse);
	}
	
	// ✅ EFEITO 4: CONTORNO (pixels transparentes vizinhos do sprite)
	if (outline_active && tex_color.a < 0.1) {
		vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
		float neighbor = texture(TEXTURE, UV + vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a
			+ texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (neighbor > 0.0) {
			color = outline_color;
		}
	}
	
	color.a *= COLOR.a;
	COLOR = color;
}