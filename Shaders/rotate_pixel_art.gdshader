shader_type canvas_item;

// Rotate Pixel Art — por Elephando (godotshaders.com)
// Mantém os pixels alinhados à grade quando um Sprite2D/AnimatedSprite2D gira.
// Adaptado: _Frames permite usar com sprite sheets (AnimatedSprite2D com AtlasTexture).
//   Ex.: sheet com 2 quadros lado a lado -> _Frames = (2, 1). Textura única -> (1, 1).

varying mat2 _Rot;

uniform float _Biais : hint_range(0, 0.1, 0.0001) = 0.01;
// Colunas e linhas do sprite sheet (todos os quadros do mesmo tamanho)
uniform vec2 _Frames = vec2(1.0, 1.0);

vec2 rotate_uv(vec2 uv, mat2 rot){
	return rot * (uv - 0.5) + 0.5;
}

vec2 scale_uv(vec2 uv, vec2 s){
	return (uv - 0.5) * s + 0.5;
}

void vertex(){
	_Rot = mat2(MODEL_MATRIX);
}

void fragment(){
	// Qual quadro do sheet está sendo desenhado e o UV local dentro dele
	vec2 cell = min(floor(UV * _Frames), _Frames - 1.0);
	vec2 local_uv = UV * _Frames - cell;

	vec2 def = 1. / TEXTURE_PIXEL_SIZE / _Frames;
	vec2 scale = vec2(def.x / def.y, 1.);

	vec2 new_uv = local_uv;
	new_uv = scale_uv(new_uv, scale);
	new_uv = rotate_uv(new_uv, _Rot);
	def /= scale;
	new_uv = floor(new_uv * def) / (def - 1.);
	new_uv = rotate_uv(new_uv, transpose(_Rot));
	new_uv = scale_uv(new_uv, 1. / scale);

	bvec2 lim0 = greaterThanEqual(new_uv, vec2(0. - _Biais));
	bvec2 lim1 = lessThanEqual(new_uv, vec2(1. + _Biais));

	float mask = float(all(lim0) && all(lim1));
	// clamp evita puxar pixels do quadro vizinho no sheet
	COLOR = texture(TEXTURE, (cell + clamp(new_uv, 0.0, 1.0)) / _Frames) * mask;
}
