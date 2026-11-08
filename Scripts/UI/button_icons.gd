extends RefCounted
class_name ButtonIcons

# ==========================================================================
# ÍCONES DE BOTÃO POR DISPOSITIVO
# --------------------------------------------------------------------------
# Descobre qual dispositivo o jogador está usando (teclado/mouse, Xbox,
# PlayStation ou Switch) e devolve o ícone certo de cada ação.
# Ícones do pacote "Controllers and Keyboard" (Vryell): sempre o 1º ícone
# da linha (versão preta, botão normal), em grade de 16x16.
#
# Quem mostra ícones chama ButtonIcons.detect_from_event(event) no _input
# e compara ButtonIcons.get_device() para saber quando trocar.
# ==========================================================================

enum Device { KEYBOARD, XBOX, PLAYSTATION, SWITCH }

const _DIR: String = "res://sprites/UI/BUTTONS/Controllers and Keyboard/"
const _CELL: int = 16

# folha, coluna, linha (em células de 16px)
const _ICONS: Dictionary = {
	Device.PLAYSTATION: {
		"confirm": ["controller_ps.png", 0, 4],     # ✕
		"back": ["controller_ps.png", 0, 6],        # ○
	},
	Device.XBOX: {
		"confirm": ["controller_xbox.png", 0, 4],   # A
		"back": ["controller_xbox.png", 0, 6],      # B
	},
	Device.SWITCH: {
		# Switch: botão de BAIXO se chama B, o da DIREITA se chama A
		"confirm": ["controller_switch.png", 0, 4], # B
		"back": ["controller_switch.png", 0, 6],    # A
	},
	Device.KEYBOARD: {
		"confirm": ["kb_dark_alphanumeric.png", 0, 23],  # tecla X
		"back": ["mouse.png", 2, 3],                     # clique direito
	},
}

# Texto dos botões de trocar página (topo do menu de pausa)
const _SHOULDERS: Dictionary = {
	Device.PLAYSTATION: ["L1", "R1"],
	Device.XBOX: ["LB", "RB"],
	Device.SWITCH: ["L", "R"],
	Device.KEYBOARD: ["Q", "E"],
}

static var _device: int = -1
static var _cache: Dictionary = {}
static var _input_map_ready: bool = false


static func get_device() -> int:
	if _device == -1:
		var _pads: Array[int] = Input.get_connected_joypads()
		_device = device_from_name(Input.get_joy_name(_pads[0])) if _pads.size() > 0 else Device.KEYBOARD
	return _device


static func detect_from_event(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			_device = Device.KEYBOARD
	elif event is InputEventJoypadButton:
		if event.is_pressed():
			_device = device_from_name(Input.get_joy_name(event.device))
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.5:
			_device = device_from_name(Input.get_joy_name(event.device))


static func device_from_name(joy_name: String) -> int:
	var _n: String = joy_name.to_lower()
	for _k in ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5", "sony"]:
		if _n.contains(_k):
			return Device.PLAYSTATION
	for _k in ["nintendo", "switch", "pro controller", "joy-con", "joycon"]:
		if _n.contains(_k):
			return Device.SWITCH
	return Device.XBOX   # Xbox e controles genéricos


static func get_icon(kind: String) -> Texture2D:
	var _dev: int = get_device()
	var _key: String = "%d_%s" % [_dev, kind]
	if _cache.has(_key):
		return _cache[_key]
	var _def: Array = _ICONS.get(_dev, {}).get(kind, [])
	if _def.is_empty() or not ResourceLoader.exists(_DIR + _def[0]):
		return null
	var _atlas := AtlasTexture.new()
	_atlas.atlas = load(_DIR + _def[0])
	_atlas.region = Rect2(_def[1] * _CELL, _def[2] * _CELL, _CELL, _CELL)
	_cache[_key] = _atlas
	return _atlas


static func get_shoulder_labels() -> Array:
	return _SHOULDERS.get(get_device(), ["LB", "RB"])


static func ensure_input_map() -> void:
	"""Teclado/mouse: o clique direito também é 'sair' (close_menu)."""
	if _input_map_ready or not InputMap.has_action("close_menu"):
		return
	_input_map_ready = true
	for _e in InputMap.action_get_events("close_menu"):
		if _e is InputEventMouseButton and _e.button_index == MOUSE_BUTTON_RIGHT:
			return
	var _click := InputEventMouseButton.new()
	_click.button_index = MOUSE_BUTTON_RIGHT
	_click.pressed = true
	InputMap.action_add_event("close_menu", _click)
