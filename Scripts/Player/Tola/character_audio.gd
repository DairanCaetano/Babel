extends Node2D
class_name CharacterAudio

## Sistema centralizado de áudio do personagem
## Gerencia todos os sons (passos, ataques, pulos, dano, etc)

# ===================================
# ÁUDIOS - Organizados por categoria
# ===================================

@export_category("Movement Sounds")
@export var run_audio: AudioStreamPlayer
@export var jump_audio: AudioStreamPlayer
@export var land_audio: AudioStreamPlayer
@export var dash_audio: AudioStreamPlayer
@export var wall_slide_audio: AudioStreamPlayer

@export_category("Combat Sounds")
@export var attack_light_audio: AudioStreamPlayer
@export var attack_heavy_audio: AudioStreamPlayer
@export var attack_air_audio: AudioStreamPlayer
@export var attack_hit_audio: AudioStreamPlayer
@export var attack_hit_object_audio: AudioStreamPlayer
@export var attack_voice_1_audio: AudioStreamPlayer  
@export var attack_voice_2_audio: AudioStreamPlayer
@export var attack_voice_3_audio: AudioStreamPlayer
@export var parry_audio: AudioStreamPlayer
@export var counter_voice_1_audio: AudioStreamPlayer 
@export var counter_voice_2_audio: AudioStreamPlayer  
@export var parry_success_audio: AudioStreamPlayer
@export var counter_audio: AudioStreamPlayer

@export_category("Damage Sounds")
@export var hit_audio_1: AudioStreamPlayer  # ✅ RENOMEADO
@export var hit_audio_2: AudioStreamPlayer  # ✅ NOVO
@export var hit_audio_3: AudioStreamPlayer  # ✅ NOVO
@export var death_audio: AudioStreamPlayer

@export_category("Sub-Weapon Sounds")
@export var throw_axe_audio: AudioStreamPlayer
@export var throw_spear_audio: AudioStreamPlayer
@export var throw_chakram_audio: AudioStreamPlayer
@export var fire_activate_audio: AudioStreamPlayer
@export var fire_loop_audio: AudioStreamPlayer
@export var fire_attack_extra_audio: AudioStreamPlayer

@export_category("Action Sounds")
@export var heal_audio: AudioStreamPlayer
@export var crouch_audio: AudioStreamPlayer
@export var grab_ledge_audio: AudioStreamPlayer
@export var climb_ladder_audio: AudioStreamPlayer
@export var roll_audio: AudioStreamPlayer

# ===================================
# REFERÊNCIAS
# ===================================

var character: BaseCharacter

# ===================================
# INICIALIZAÇÃO
# ===================================

func _ready() -> void:
	character = get_parent() as BaseCharacter
	if not character:
		push_error("CharacterAudio deve ser filho de BaseCharacter!")

# ===================================
# FUNÇÃO AUXILIAR - Variação de Pitch
# ===================================

func _play_with_random_pitch(audio_player: AudioStreamPlayer, min_pitch: float = 0.9, max_pitch: float = 1.1) -> void:
	"""Toca o áudio com pitch aleatório entre min_pitch e max_pitch"""
	if not audio_player:
		return
	
	# Gerar pitch aleatório entre 90% e 110%
	var random_pitch = randf_range(min_pitch, max_pitch)
	audio_player.pitch_scale = random_pitch
	audio_player.play()
	
	print("🎵 Pitch aleatório: ", "%.2f" % random_pitch)

# ===================================
# FUNÇÕES DE REPRODUÇÃO - Movement
# ===================================

func play_run() -> void:
	if run_audio and not run_audio.playing:
		run_audio.play()

func stop_run() -> void:
	if run_audio and run_audio.playing:
		run_audio.stop()

func play_jump() -> void:
	if jump_audio:
		jump_audio.play()

func play_land() -> void:
	if land_audio:
		land_audio.play()

func play_dash() -> void:
	if dash_audio:
		dash_audio.play()

func play_wall_slide() -> void:
	if wall_slide_audio and not wall_slide_audio.playing:
		wall_slide_audio.play()

func stop_wall_slide() -> void:
	if wall_slide_audio and wall_slide_audio.playing:
		wall_slide_audio.stop()

# ===================================
# FUNÇÕES DE REPRODUÇÃO - Combat (COM PITCH ALEATÓRIO)
# ===================================

func play_attack_light() -> void:
	"""Som de ataque leve com pitch aleatório (90% a 110%)"""
	_play_with_random_pitch(attack_light_audio, 0.9, 1.1)

func play_attack_heavy() -> void:
	"""Som de ataque pesado com pitch aleatório (90% a 110%)"""
	_play_with_random_pitch(attack_heavy_audio, 0.9, 1.1)

func play_attack_air() -> void:
	"""Som de ataque aéreo com pitch aleatório (90% a 110%)"""
	_play_with_random_pitch(attack_air_audio, 0.9, 1.1)

func play_attack_hit() -> void:
	"""Som de impacto em inimigos"""
	if attack_hit_audio:
		attack_hit_audio.play()

func play_attack_hit_object() -> void:
	"""Som de impacto em objetos destrutíveis"""
	if attack_hit_object_audio:
		attack_hit_object_audio.play()

func play_attack_voice() -> void:
	"""Som do grito do personagem ao atacar (40% de chance, 3 variações)"""
	# 40% de chance de tocar
	if randf() <= 0.6:
		# Escolher aleatoriamente entre as 3 vozes (33.3% cada)
		var voice_choice = randi() % 3  # 0, 1 ou 2
		
		match voice_choice:
			0:
				if attack_voice_1_audio:
					attack_voice_1_audio.play()
					print("🗣️ Grito de ataque tocado! (Voz 1)")
			1:
				if attack_voice_2_audio:
					attack_voice_2_audio.play()
					print("🗣️ Grito de ataque tocado! (Voz 2)")
			2:
				if attack_voice_3_audio:
					attack_voice_3_audio.play()
					print("🗣️ Grito de ataque tocado! (Voz 3)")

func play_parry() -> void:
	"""Som mecânico de preparar defesa (imediato)"""
	if parry_audio:
		parry_audio.play()
		print("🛡️ Som mecânico de parry tocado")

func play_counter_voice() -> void:
	"""Voz do counter (60% de chance, 2 variações)"""
	# 60% de chance de tocar
	if randf() <= 0.6:
		# Escolher aleatoriamente entre as 2 vozes (50% cada)
		var voice_choice = randi() % 2  # 0 ou 1
		
		match voice_choice:
			0:
				if counter_voice_1_audio:
					counter_voice_1_audio.play()
					print("⚔️ Voz de counter tocada! (Variação 1)")
			1:
				if counter_voice_2_audio:
					counter_voice_2_audio.play()
					print("⚔️ Voz de counter tocada! (Variação 2)")

func play_parry_success() -> void:
	"""Som quando o parry bloqueia um ataque (hit stop + brilho)"""
	if parry_success_audio:
		parry_success_audio.play()

func play_counter() -> void:
	"""Som de contra-ataque com pitch aleatório (90% a 110%)"""
	_play_with_random_pitch(counter_audio, 0.9, 1.1)

# ===================================
# FUNÇÕES DE REPRODUÇÃO - Damage
# ===================================

# ✅ ATUALIZADA: Agora com 3 variações aleatórias
func play_hit() -> void:
	"""Som ao receber dano (3 variações aleatórias)"""
	# Escolher aleatoriamente entre os 3 sons (33.3% cada)
	var hit_choice = randi() % 3  # 0, 1 ou 2
	
	match hit_choice:
		0:
			if hit_audio_1:
				hit_audio_1.play()
				print("💥 Som de hit tocado! (Variação 1)")
		1:
			if hit_audio_2:
				hit_audio_2.play()
				print("💥 Som de hit tocado! (Variação 2)")
		2:
			if hit_audio_3:
				hit_audio_3.play()
				print("💥 Som de hit tocado! (Variação 3)")

func play_death() -> void:
	if death_audio:
		death_audio.play()


func play_throw_axe() -> void:
	if throw_axe_audio:
		throw_axe_audio.play()

func play_throw_spear() -> void:
	if throw_spear_audio:
		throw_spear_audio.play()

func play_throw_chakram() -> void:
	if throw_chakram_audio:
		throw_chakram_audio.play()

func play_fire_activate() -> void:
	"""Som de ativação do Fire Power"""
	if fire_activate_audio:
		fire_activate_audio.play()
		print("🔥 Som de ativação do Fire tocado!")

func play_fire_loop() -> void:
	"""Inicia loop de som enquanto Fire está ativo"""
	if fire_loop_audio and not fire_loop_audio.playing:
		fire_loop_audio.play()
		print("🔥 Loop de Fire iniciado!")

func stop_fire_loop() -> void:
	"""Para o loop de som do Fire"""
	if fire_loop_audio and fire_loop_audio.playing:
		fire_loop_audio.stop()
		print("🔥 Loop de Fire parado!")

func play_fire_attack_extra() -> void:
	"""Som extra de fogo durante ataques com Fire ativo"""
	if fire_attack_extra_audio:
		fire_attack_extra_audio.play()
		print("🔥 Som extra de fogo no ataque!")

# ===================================
# FUNÇÕES DE REPRODUÇÃO - Actions
# ===================================

func play_heal() -> void:
	if heal_audio:
		heal_audio.play()

func play_crouch() -> void:
	if crouch_audio:
		crouch_audio.play()

func play_grab_ledge() -> void:
	if grab_ledge_audio:
		grab_ledge_audio.play()

func play_climb_ladder() -> void:
	if climb_ladder_audio and not climb_ladder_audio.playing:
		climb_ladder_audio.play()

func stop_climb_ladder() -> void:
	if climb_ladder_audio and climb_ladder_audio.playing:
		climb_ladder_audio.stop()

func play_roll() -> void:
	if roll_audio:
		roll_audio.play()

# ===================================
# SISTEMA DE PASSOS (Loop automático)
# ===================================

func update_run_audio() -> void:
	if not character:
		return
	
	# ✅ Verificar se está correndo
	var is_moving = abs(character.velocity.x) > 10.0
	var should_play = character.is_on_floor() and is_moving and not character._is_crouching
	
	# ✅ Estados que bloqueiam o áudio
	var is_blocked = (
		character._character_texture._is_on_action or 
		not character._is_alive or 
		character._on_ladder or
		character.on_ledge or
		character._skills.is_rolling() or
		character._skills.is_wall_sliding()
	)
	
	if should_play and not is_blocked:
		play_run()
	else:
		stop_run()

# ===================================
# SISTEMA DE WALL SLIDE (Loop automático)
# ===================================

func update_wall_slide_audio() -> void:
	if not character:
		return
	
	if character._skills.is_wall_sliding():
		play_wall_slide()
	else:
		stop_wall_slide()
