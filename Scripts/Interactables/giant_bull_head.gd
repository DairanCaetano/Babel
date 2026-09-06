extends Node2D
class_name GiantBullHead

@export_category("References")
@export var wooden_support: StaticBody2D
@export var bull_head: RigidBody2D
@export var old_wooden_support: Node2D
@export var hidden_area: HiddenArea

@export_category("Persistence")
@export var bull_head_id: String = ""

func _ready() -> void:
	add_to_group("breakable_wall")
	
	if not wooden_support or not bull_head or not old_wooden_support:
		push_error("❌ GiantBullHead: Configure as referências no Inspector!")
		return
	
	if bull_head_id.is_empty():
		bull_head_id = "bull_head_" + name
	
	if _was_already_destroyed():
		print("🚫 GiantBullHead já foi destruído antes: ", bull_head_id)
		_remove_all()
		return
	
	print("✅ GiantBullHead configurado - ID: ", bull_head_id)

func _was_already_destroyed() -> bool:
	return serialization.game_data.get("destroyed_walls", []).has(bull_head_id)

func save_destroyed_state() -> void:
	if not serialization.game_data.has("destroyed_walls"):
		serialization.game_data["destroyed_walls"] = []
	
	if not serialization.game_data["destroyed_walls"].has(bull_head_id):
		serialization.game_data["destroyed_walls"].append(bull_head_id)
		print("💾 GiantBullHead salvo como destruído: ", bull_head_id)
	
	if hidden_area and is_instance_valid(hidden_area):
		hidden_area.save_destroyed_state()

func _remove_all() -> void:
	if is_instance_valid(wooden_support):
		wooden_support.queue_free()
	if is_instance_valid(bull_head):
		bull_head.queue_free()
	if is_instance_valid(old_wooden_support):
		old_wooden_support.queue_free()
	if is_instance_valid(hidden_area):
		hidden_area.queue_free()
	queue_free()
