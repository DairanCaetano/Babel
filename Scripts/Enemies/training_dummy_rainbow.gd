extends TrainingDummy
class_name TrainingDummyRainbow
# Boneco de treino com o dano iridescente ("rainbow palette cycling").
# Ao apanhar, o sprite cicla pelas cores do arco-íris por alguns quadros.
# Todos os parâmetros visuais ficam no material do Sprite (shader hit_rainbow).

@export_category("Efeito Iridescente")
## Duração do efeito a cada golpe (s)
@export var effect_duration: float = 0.2
## Opacidade do efeito sobre o sprite (1 = arco-íris total, 0 = sem efeito)
@export_range(0.0, 1.0, 0.05) var effect_opacity: float = 0.6
## Em que ponto da duração o fade começa (0.5 = na metade; 1 = sem fade)
@export_range(0.0, 1.0, 0.05) var fade_start: float = 0.5
## Passos de cor por segundo (30 = ritmo de PS1)
@export var cycle_fps: float = 30.0
## Quanto o arco-íris gira a cada passo (0.08 ≈ 12 passos por volta)
@export var cycle_step: float = 0.08
## Começa cada golpe num ponto diferente do arco-íris
@export var random_start: bool = true
## Mostra o efeito em loop no jogo, para ajustar o visual com calma
@export var preview_loop: bool = false:
	set(v):
		preview_loop = v
		if not v:
			_set_shader(0.0, _cycle)

var _effect_time: float = 0.0
var _cycle: float = 0.0
var _step_timer: float = 0.0

func _process(delta: float) -> void:
	super._process(delta)
	var _active: bool = preview_loop or _effect_time > 0.0
	if not _active:
		return
	_effect_time = maxf(_effect_time - delta, 0.0)
	_step_timer += delta
	var _interval: float = 1.0 / maxf(cycle_fps, 1.0)
	while _step_timer >= _interval:
		_step_timer -= _interval
		_cycle = fmod(_cycle + cycle_step, 1.0)
	var _strength: float = 0.0
	if preview_loop:
		_strength = effect_opacity
	elif _effect_time > 0.0:
		_strength = effect_opacity * _fade_factor()
	_set_shader(_strength, _cycle)

# 1 até fade_start da duração; depois desce suave até 0 no fim
func _fade_factor() -> float:
	if effect_duration <= 0.0:
		return 0.0
	var _elapsed: float = 1.0 - (_effect_time / effect_duration)
	if _elapsed <= fade_start or fade_start >= 1.0:
		return 1.0
	var _t: float = (_elapsed - fade_start) / (1.0 - fade_start)
	return 1.0 - smoothstep(0.0, 1.0, _t)

# Substitui o piscar branco do boneco base
func _flash() -> void:
	if random_start:
		_cycle = randf()
	_effect_time = effect_duration
	_step_timer = 0.0
	_set_shader(effect_opacity, _cycle)

func _set_shader(strength: float, cycle: float) -> void:
	if not _sprite or not (_sprite.material is ShaderMaterial):
		return
	var _mat: ShaderMaterial = _sprite.material as ShaderMaterial
	_mat.set_shader_parameter("hit_strength", strength)
	_mat.set_shader_parameter("cycle_time", cycle)
