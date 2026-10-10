extends StaticBody2D
class_name TrainingDummy

# ========== BONECO DE TREINO (inimigo de teste) ==========
# Recebe golpes de todas as armas do Tola e mostra o dano na tela.
# - Não ataca, não se move, não morre: ao zerar a vida, ela volta ao máximo.
# - Corpo na camada "Enemy Body" (chakram) + Hurtbox no grupo "enemy_hitbox" (demais armas).

@export var max_health: int = 2000
@export var auto_reset_delay: float = 3.0 # segundos sem apanhar para a vida voltar ao máximo (0 = nunca)

@export_category("Objects")
@export var _sprite: Sprite2D
@export var _info_label: Label

var _health: int = 0
var _hits: int = 0
var _total_damage: int = 0
var _last_damage: int = 0
var _idle_time: float = 0.0
var _flash_tween: Tween

func _ready() -> void:
	_health = max_health
	_update_label()

func _process(delta: float) -> void:
	if auto_reset_delay <= 0.0 or _hits == 0:
		return
	_idle_time += delta
	if _idle_time >= auto_reset_delay:
		_reset()

# ✅ Mesma assinatura dos inimigos: todas as armas chamam isso
func update_health(_damage: int, _entity) -> void:
	_idle_time = 0.0
	_hits += 1
	_last_damage = _damage
	_total_damage += _damage
	_health -= _damage
	
	print("🎯 Boneco: -", _damage, " | golpes: ", _hits, " | total: ", _total_damage, " | vida: ", max(_health, 0), "/", max_health)
	
	if _health <= 0:
		print("🎯 Boneco zerado! Vida restaurada.")
		_health = max_health
	
	_flash()
	_update_label()

func _reset() -> void:
	_health = max_health
	_hits = 0
	_total_damage = 0
	_last_damage = 0
	_idle_time = 0.0
	_update_label()

func _flash() -> void:
	if not _sprite:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = Color(3, 3, 3)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)

func _update_label() -> void:
	if not _info_label:
		return
	# ✅ Mostra só o dano do golpe mais recente (vazio até o primeiro golpe)
	_info_label.text = str(_last_damage) if _last_damage > 0 else ""
