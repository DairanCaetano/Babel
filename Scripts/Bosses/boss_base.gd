extends CharacterBody2D
class_name Boss

# Signal padrão para TODOS os bosses
signal boss_defeated(boss_id: String)

@export var boss_id: String = ""  # ID único do boss

@export_category("Efeito de Morte")
## Câmera superlenta + fundo preto + Tola e chefe em silhueta vermelha
@export var kill_effect_enabled: bool = true
## Vazio = Scenes/FX/boss_kill_effect.tscn (ajuste duração/som nessa cena)
@export var kill_effect_scene: PackedScene
const _KILL_EFFECT_DEFAULT: String = "res://Scenes/FX/boss_kill_effect.tscn"

@export_category("Cartão de Apresentação")
enum TitleCardStyle { OFF, TEXT, BLACK, RED, WHITE }
## Nome do chefe no primeiro rugido (só no primeiro encontro).
## TEXT = só o nome sobre a luta; BLACK/RED/WHITE = fundo em tela cheia.
@export var title_card_style: TitleCardStyle = TitleCardStyle.TEXT
## Chave do nome no texts.csv (vazio = o próprio chefe define no _ready)
@export var boss_name_key: String = ""
## Chave do subtítulo (linha menor embaixo do nome). Vazio = só o nome.
@export var boss_subtitle_key: String = ""
## Tamanho do nome deste chefe (múltiplo da fonte 14). 0 = padrão do cartão (2)
@export var title_name_scale: int = 0
## Tamanho do subtítulo deste chefe. 0 = padrão do cartão (1)
@export var title_subtitle_scale: int = 0
## Som próprio do cartão (vazio = sem som; música e rugido seguem normais)
@export var title_card_sound: AudioStream
const _TITLE_CARD_SCENE: String = "res://Scenes/UI/boss_title_card.tscn"

var _is_alive: bool = true

func _ready():
	if boss_id == "":
		push_error("Boss sem ID definido! Configure o boss_id no inspector.")
	if not boss_defeated.is_connected(_play_kill_effect):
		boss_defeated.connect(_play_kill_effect)

# ========== CARTÃO DE APRESENTAÇÃO ==========
func show_title_card(duration: float) -> void:
	"""Chamado pelo chefe no início do PRIMEIRO rugido.
	Aparece só no primeiro encontro (registrado no save na hora)."""
	if title_card_style == TitleCardStyle.OFF or boss_name_key == "" or boss_id == "":
		return
	
	var _seen = serialization.game_data.get("seen_boss_titles", [])
	if not _seen is Array:
		_seen = []
	var _always: bool = false
	var _game = get_tree().get_first_node_in_group("game_main")
	if OS.has_feature("editor") and _game and "debug_always_show_boss_title" in _game:
		_always = _game.debug_always_show_boss_title
	if _seen.has(boss_id) and not _always:
		return
	if not _seen.has(boss_id):
		_seen.append(boss_id)
		serialization.game_data["seen_boss_titles"] = _seen
		serialization.save_data()
	
	if not ResourceLoader.exists(_TITLE_CARD_SCENE):
		return
	var _card = load(_TITLE_CARD_SCENE).instantiate()
	get_tree().root.add_child(_card)
	if _card.has_method("setup"):
		var _subtitle: String = tr(boss_subtitle_key) if boss_subtitle_key != "" else ""
		_card.setup(int(title_card_style), tr(boss_name_key), title_card_sound, duration, _subtitle, title_name_scale, title_subtitle_scale)

# ========== EFEITO DE MORTE ==========
func _play_kill_effect(_id: String = "") -> void:
	if not kill_effect_enabled:
		return
	var _scene: PackedScene = kill_effect_scene
	if not _scene and ResourceLoader.exists(_KILL_EFFECT_DEFAULT):
		_scene = load(_KILL_EFFECT_DEFAULT)
	if not _scene:
		return
	var _sprites: Array = []
	var _boss_sprite: CanvasItem = get_kill_effect_sprite()
	if _boss_sprite:
		_sprites.append(_boss_sprite)
	var _player = get_tree().get_first_node_in_group("player")
	if _player and "_character_texture" in _player and _player._character_texture:
		_sprites.append(_player._character_texture)
	var _effect = _scene.instantiate()
	var _host: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	_host.add_child(_effect)
	_effect.global_position = global_position
	if _effect.has_method("start"):
		_effect.start(_sprites)

func get_kill_effect_sprite() -> CanvasItem:
	"""Sprite principal do chefe (Rá usa _texture, Baal usa texture).
	Chefes novos podem sobrescrever esta função."""
	for _prop in ["_texture", "texture"]:
		if _prop in self:
			var _value = get(_prop)
			if _value is CanvasItem:
				return _value
	for _child in get_children():
		if _child is AnimatedSprite2D or _child is Sprite2D:
			return _child
	return null

func _save_boss_death() -> void:
	"""Salva a morte do boss (global + save) e avisa portas/spawners"""
	# Tudo centralizado no BossEventManager. Antes o nome ia só pro game_data e o
	# save_data() sobrescrevia a lista com global.defeated_bosses → num jogo novo
	# a morte do chefe se perdia.
	BossEventManager.register_boss_defeat(boss_id)
	print("✅ Boss derrotado salvo: ", boss_id)

func is_already_defeated() -> bool:
	"""Verifica se o boss já foi derrotado anteriormente"""
	return BossEventManager.is_boss_defeated(boss_id)
