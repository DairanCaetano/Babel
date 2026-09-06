extends RigidBody2D
class_name CollectableItem

var is_collectable: bool = true
var item_data: Dictionary = {}
var item_texture: String

# ✅ NOVO: Controle de tempo de vida (apenas para fragmentos)
var _is_fading: bool = false
var _can_freeze: bool = false  # ✅ Só permite congelar após um tempo

@export_category("Objects")
@export var _item_sprite: Sprite2D
@export var _animation: AnimationPlayer
@export var _collectable_audio: AudioStreamPlayer

@export_category("Variables")
@export var _min_horizontal_force: int = 40
@export var _horizontal_force: int = 120
@export var _vertical_force: int = -40
@export var _minimum_vertical_force: int = -120

# ✅ NOVO: Configurações de vida útil (APENAS PARA FRAGMENTOS)
@export_category("Shard Lifetime")
@export var _shard_cleanup_delay: float = 4.0  # Tempo até começar fade (fragmentos)
@export var _shard_fade_duration: float = 1.0  # Duração do fade out

func _ready() -> void:
	if not is_collectable:
		_animation.play("Lost")
		# ✅ APENAS fragmentos têm auto-limpeza
		_start_shard_lifetime_timer()
		# ✅ Aguarda 1 segundo antes de permitir congelamento
		_enable_freeze_check()
	
	_item_sprite.texture = load(item_texture)
	
	apply_impulse(
		Vector2(
			[
				randi_range(_min_horizontal_force, _horizontal_force), 
				- randi_range(_min_horizontal_force, _horizontal_force)
			].pick_random(),
			
			randi_range(_minimum_vertical_force, _vertical_force)
		)
	)

# ✅ NOVA FUNÇÃO: Habilita verificação de congelamento após delay
func _enable_freeze_check() -> void:
	await get_tree().create_timer(1.0).timeout
	_can_freeze = true

# ✅ NOVA FUNÇÃO: Gerenciar tempo de vida DOS FRAGMENTOS
func _start_shard_lifetime_timer() -> void:
	await get_tree().create_timer(_shard_cleanup_delay).timeout
	
	if not is_instance_valid(self) or _is_fading:
		return
	
	_start_fade_out()

# ✅ NOVA FUNÇÃO: Fade out suave
func _start_fade_out() -> void:
	_is_fading = true
	
	# Desativa física para economizar processamento
	freeze = true
	
	# Fade out visual
	var tween = create_tween()
	tween.tween_property(_item_sprite, "modulate:a", 0.0, _shard_fade_duration)
	await tween.finished
	
	queue_free()

# ✅ OTIMIZAÇÃO: Congelar fragmentos quando param de se mover
func _process(_delta: float) -> void:
	# Só processa fragmentos que não estão em fade E já podem congelar
	if is_collectable or _is_fading or not _can_freeze:
		return
	
	# Se está quase parado, congela física
	if linear_velocity.length() < 5.0 and abs(angular_velocity) < 0.1:
		freeze = true
		sleeping = true
		# Para de processar depois que congelou
		set_process(false)

func _on_collectable_area_body_entered(_body: Node2D) -> void:
	if not is_collectable:
		return
	
	if _body is BaseCharacter:
		global.inventory.collect_item(item_data)
		
		# ✅ TOCAR SOM COM PITCH RANDOMIZADO
		if _collectable_audio:
			_collectable_audio.pitch_scale = randf_range(0.8, 1.1)  # 80% a 110%
			_collectable_audio.play()
		
		global.spawn_effect(
			"res://Scenes/FX/collect_item_effect.tscn", Vector2.ZERO, global_position, false
		)
		
		# ✅ ESCONDER SPRITE IMEDIATAMENTE
		_item_sprite.visible = false
		
		# ✅ DESATIVAR COLISÃO
		$CollectableArea.monitoring = false
		$CollectableArea.monitorable = false
		
		# ✅ AGUARDAR SOM TERMINAR
		await _collectable_audio.finished
		
		queue_free()
