extends RigidBody2D
class_name BullHeadPhysics

@export_category("Settings")
@export var trigger_group: String = "bull_head_trigger"  # Grupo que destrói a parede
@export var mass_value: float = 50.0  # Peso da cabeça
@export var lifetime_after_release: float = 3.0  # ✅ NOVO: Tempo em segundos antes de sumir

var is_held: bool = true

func _ready() -> void:
	if is_held:
		freeze = true
		gravity_scale = 0
	
	mass = mass_value
	
	# ✅ ADICIONAR AO GRUPO CORRETO
	add_to_group(trigger_group)
	
	print("✅ BullHeadPhysics configurado - Grupo: ", trigger_group)

func release() -> void:
	print("💥 Cabeça de Touro liberada - começando queda!")
	is_held = false
	freeze = false
	gravity_scale = 1.0
	
	# ✅ INICIAR TIMER PARA DESTRUIR APÓS X SEGUNDOS
	_start_destruction_timer()

func _start_destruction_timer() -> void:
	await get_tree().create_timer(lifetime_after_release).timeout
	
	if is_instance_valid(self):
		print("🗑️ Cabeça de Touro destruída após ", lifetime_after_release, " segundos")
		queue_free()
