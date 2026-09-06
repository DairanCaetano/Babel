extends Control
class_name ItensInfo

@export_category("Objects")
@export var item_icon: TextureRect
@export var item_name_label: Label
@export var animation_player: AnimationPlayer

var display_duration: float = 2.0
var fade_duration: float = 0.3
var slide_distance: float = 50.0

func _ready() -> void:
	# Inicializa como oculto
	visible = false
	modulate = Color(1, 1, 1, 0)
	
	# Conecta ao sinal global para quando itens são coletados
	if global.has_signal("item_collected"):
		global.item_collected.connect(_on_item_collected)
	
	# Se não existir o sinal, cria um método alternativo
	global.ui_item_notification = self

func _on_item_collected(item_data: Dictionary) -> void:
	show_item_notification(item_data)

func show_item_notification(item_data: Dictionary) -> void:
	# Cancela qualquer animação em andamento
	if animation_player and animation_player.is_playing():
		animation_player.stop()
	
	# Atualiza as informações do item
	update_item_display(item_data)
	
	# Torna visível e inicia a animação
	visible = true
	animate_in()

func update_item_display(item_data: Dictionary) -> void:
	# Atualiza o nome do item
	if item_name_label:
		item_name_label.text = item_data.get("name", "Item")
	
	# Atualiza o ícone do item
	if item_icon and item_data.has("path"):
		var texture = load(item_data["path"]) as Texture2D
		if texture:
			item_icon.texture = texture
		else:
			# Fallback para uma textura padrão se não conseguir carregar
			item_icon.texture = null

func animate_in() -> void:
	# Posição inicial (ligeiramente deslocada para baixo)
	var start_position = position
	position.y += slide_distance
	
	# Criar tween para animação de entrada
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Animar opacidade
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	
	# Animar posição
	tween.tween_property(self, "position:y", start_position.y, fade_duration)
	
	# Aguardar e depois animar saída
	tween.tween_callback(animate_out).set_delay(display_duration)

func animate_out() -> void:
	# Criar tween para animação de saída
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Animar opacidade
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	
	# Animar posição para cima
	tween.tween_property(self, "position:y", position.y - slide_distance, fade_duration)
	
	# Ocultar quando terminar
	tween.tween_callback(hide_notification)

func hide_notification() -> void:
	visible = false
	# Resetar posição para próxima notificação
	position.y += slide_distance

# Método público para ser chamado diretamente se necessário
func display_item(item_data: Dictionary) -> void:
	show_item_notification(item_data)

# Método para configurar durações personalizadas
func set_display_duration(duration: float) -> void:
	display_duration = duration

func set_fade_duration(duration: float) -> void:
	fade_duration = duration

func set_slide_distance(distance: float) -> void:
	slide_distance = distance
