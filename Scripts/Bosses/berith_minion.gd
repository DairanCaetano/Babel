extends Estatuas
class_name BerithMinion

var _start_animation_played: bool = false

func _ready():
	super._ready()
	
	# Reproduz a animação "Start" assim que o minion surgir
	if texture.sprite_frames and texture.sprite_frames.has_animation("Start"):
		texture.play("Start")
		_start_animation_played = false
		current_state = "spawning"
	else:
		# Se não tiver a animação "Start", continua normalmente
		_start_animation_played = true

func _on_animation_finished():
	super._on_animation_finished()
	
	# Quando a animação "Start" terminar, volta ao comportamento normal
	if texture.animation == "Start" and not _start_animation_played:
		_start_animation_played = true
		
		# Se o jogador estiver na área de detecção, inicia o chase
		if _player_in_range and is_instance_valid(_player_in_range):
			_transition_to_chase()
		else:
			_transition_to_idle()
