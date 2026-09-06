extends Node2D
class_name RopeVisual

@export_category("Rope Settings")
@export var rope_width: float = 3.0
@export var rope_color: Color = Color(0.4, 0.3, 0.2)
@export var rope_health: int = 1

@export_category("References")
@export var anchor: Node2D
@export var box: Node2D
@export var line: Line2D
@export var hit_box: Area2D
@export var collision: CollisionShape2D

@export_category("Audio")
@export var _rope_broken_audio: AudioStreamPlayer

var is_active: bool = true

func _ready() -> void:
	if not line:
		line = get_node_or_null("Line2D")
	
	if not hit_box:
		hit_box = get_node_or_null("RopeHitBox")
	
	if not collision and hit_box:
		collision = hit_box.get_node_or_null("CollisionShape2D")
	
	if not anchor or not box:
		push_error("❌ RopeVisual: Anchor/Box não configurado!")
	
	if not line:
		push_error("❌ RopeVisual: Line2D não encontrado!")
	
	if line:
		line.width = rope_width
		line.default_color = rope_color
		line.z_index = -1
	
	if collision and not collision.shape:
		collision.shape = RectangleShape2D.new()
	
	if hit_box and not hit_box.area_entered.is_connected(_on_rope_hit):
		hit_box.area_entered.connect(_on_rope_hit)
	
	if hit_box:
		hit_box.add_to_group("destructible_objects")
	
	print("✅ RopeVisual configurado")

func _process(_delta: float) -> void:
	if not is_active or not anchor or not box or not line:
		return
	
	var anchor_pos = anchor.global_position
	var box_pos = box.global_position
	
	var local_anchor = to_local(anchor_pos)
	var local_box = to_local(box_pos)
	
	line.points = [local_anchor, local_box]
	
	if collision and collision.shape is RectangleShape2D:
		var direction = box_pos - anchor_pos
		var distance = direction.length()
		
		collision.shape.size = Vector2(rope_width * 2, distance)
		collision.global_position = (anchor_pos + box_pos) / 2.0
		collision.rotation = direction.angle() + PI/2

func _on_rope_hit(area: Area2D) -> void:
	if not is_active:
		return
	
	if area.is_in_group("player_attack"):
		_take_damage(1)

func _take_damage(damage: int) -> void:
	rope_health -= damage
	
	if line:
		var tween = create_tween()
		tween.tween_property(line, "modulate", Color.WHITE, 0.1)
		tween.tween_property(line, "modulate", rope_color, 0.1)
	
	if rope_health <= 0:
		_break_rope()

func _break_rope() -> void:
	if not is_active:
		return
	
	is_active = false
	
	# ✅ TOCAR SOM DE CORDA QUEBRANDO
	if _rope_broken_audio and _rope_broken_audio.stream:
		_rope_broken_audio.play()
		print("🔊 Som de corda quebrada tocado!")
	else:
		print("⚠️ AudioStreamPlayer não configurado ou sem stream!")
	
	if hit_box:
		if hit_box.area_entered.is_connected(_on_rope_hit):
			hit_box.area_entered.disconnect(_on_rope_hit)
		hit_box.monitoring = false
		hit_box.remove_from_group("destructible_objects")
	
	if collision:
		collision.disabled = true
	
	if line:
		line.visible = false
	
	if box and box.has_method("break_rope"):
		box.break_rope()
	
	print("🔗 Corda quebrada!")
