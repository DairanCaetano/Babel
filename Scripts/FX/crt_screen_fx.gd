extends CanvasLayer

func _ready() -> void:
	# Carregar estado salvo
	await get_tree().process_frame  # Aguardar serialization carregar
	
	if serialization.game_data.has("crt_filter_enabled"):
		visible = serialization.game_data["crt_filter_enabled"]
		print("🎨 CRT Filter carregado: ", "Ligado" if visible else "Desligado")
	else:
		visible = true
		serialization.game_data["crt_filter_enabled"] = true
		print("🎨 CRT Filter padrão: Ligado")
