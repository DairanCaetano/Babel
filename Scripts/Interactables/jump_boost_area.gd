extends Area2D
class_name JumpBoostArea

# ==========================================================================
# ÁREA DE IMPULSO DE PULO
# --------------------------------------------------------------------------
# Para passar de uma camera zone de baixo para a de cima dentro da MESMA fase.
# - Player SUBINDO dentro da área  → recebe um impulso para cima (1x por pulo).
# - Player caindo, parado ou andando → nada acontece.
# Coloque a área logo acima do ponto de onde ele pula, cobrindo a passagem.
# A colisão é única por instância: redimensione à vontade em cada fase.
# ==========================================================================

## Velocidade vertical aplicada no impulso (px/s). O pulo normal é 350.
## Altura aproximada alcançada ≈ velocidade² ÷ 1960 (ex.: 550 → ~155 px).
@export var boost_velocity: float = 550.0
## Impulso horizontal opcional (px/s, positivo = direita). 0 = mantém o do player.
@export var horizontal_boost: float = 0.0
## Só impulsiona se o player já estiver subindo pelo menos nesta velocidade (px/s).
@export var min_rising_speed: float = 10.0
## Enquanto o impulso não terminar, soltar o botão de pulo não corta a subida.
@export var lock_jump_cut: bool = true
@export var boost_sound: AudioStream

var _player: BaseCharacter = null
var _boosted_this_jump: bool = false
var _audio: AudioStreamPlayer2D

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if boost_sound:
		_audio = AudioStreamPlayer2D.new()
		_audio.stream = boost_sound
		_audio.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(_audio)

func _on_body_entered(body: Node) -> void:
	if body is BaseCharacter:
		_player = body
		_boosted_this_jump = false

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		_boosted_this_jump = false

func _physics_process(_delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	
	# Pousou dentro da área → libera para o próximo pulo
	if _player.is_on_floor():
		_boosted_this_jump = false
		return
	
	if _boosted_this_jump or _player._is_in_cinematic or not _player._is_alive:
		return
	
	# Só impulsiona quem já está SUBINDO (y negativo = para cima)
	if _player.velocity.y > -min_rising_speed:
		return
	
	_boosted_this_jump = true
	_player.velocity.y = minf(_player.velocity.y, -boost_velocity)
	if horizontal_boost != 0.0:
		_player.velocity.x = horizontal_boost
	if lock_jump_cut and "_ignore_jump_cut" in _player:
		_player._ignore_jump_cut = true
	if _audio:
		_audio.play()
	print("⬆️ JumpBoostArea: impulso ", -boost_velocity, " em ", name)
