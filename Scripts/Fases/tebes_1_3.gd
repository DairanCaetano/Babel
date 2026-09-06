extends BaseLevel

func _ready() -> void:
	level_name = "tebes_1_3"
	level_music_track = "tebe_1"
	super._ready()

func setup_dialogs() -> void:
	# ✅ DIÁLOGO 1 - Primeira conversa
	save_point_dialogs.append({
		"dialog_name": "first_meeting",
		"lines": [
			{
				"character": "azazel",
				"text": "É um complexo grandioso de cavernas."
			},
			{
				"character": "tola",
				"text": "Daqui vinham as pedras que sustentavam seus templos e de onde esculpiam seus ídolos."
			},
			{
				"character": "azazel",
				"text": "E o que você pensa dos deuses estrangeiros?"
			},
			{
				"character": "tola",
				"text": "Acho que todo deus é um estrangeiro."
			}
		]
	})
	
	# ✅ DIÁLOGO 2 - Segunda conversa
	save_point_dialogs.append({
		"dialog_name": "second_meeting",
		"lines": [
			{
				"character": "tola",
				"text": "Você já confrontou os senhores adorados nessas terras?"
			},
			{
				"character": "azazel",
				"text": "Sim, eu os vi. Eles são estranhos, brutos, mas lindos à sua maneira."
			},
			{
				"character": "tola",
				"text": "Lindos? Sempre pensei nos estrangeiros como monstros."
			},
			{
				"character": "azazel",
				"text": "O medo do desconhecido é o mais comum dos medos."
			}
		]
	})
	
	# ✅ DIÁLOGO 3 - Terceira conversa
	save_point_dialogs.append({
		"dialog_name": "third_meeting",
		"lines": [
			{
				"character": "tola",
				"text": "Você não teme?"
			},
			{
				"character": "azazel",
				"text": "Medo é uma emoção que não me pertence. Sou um ser do cosmos. Eu não tenho a mesma agência que vocês mortais."
			}
		]
	})
	
	# ✅ DIÁLOGO 4 - Último (VAI REPETIR a partir da 5ª conversa)
	save_point_dialogs.append({
		"dialog_name": "final_loop",
		"lines": [
			{
				"character": "tola",
				"text": "Nessa terra eles adoravam ao senhor das alianças, Baal Berite."
			},
			{
				"character": "azazel",
				"text": "Um senhor muito antigo e muito honorável pelos povos que o cercam."
			},
			{
				"character": "tola",
				"text": "Ele habitava também em nossas cidades e era adorado até pelos nossos."
			},
			{
				"character": "azazel",
				"text": "Os mortais mudam de mestre com a facilidade com que mudam de roupas."
			},
			{
				"character": "tola",
				"text": "..."
			}
		]
	})
	
	print("✅ [Tebes 1-3] ", save_point_dialogs.size(), " diálogos configurados")
