extends BaseLevel
class_name TesteEstetica

## Fase de TESTE da estética estilo Animal Well (não faz parte do jogo).
## Contém: Chão (Rocha desértica), uma parede falsa (área secreta) e uma parede quebrável.

## Restaura a parede quebrável e a área secreta toda vez que a fase carrega,
## para dar para testar de novo sem precisar apagar o save.
@export var resetar_paredes_ao_entrar: bool = true

const PREFIXO_IDS: String = "teste_estetica_"

func _enter_tree() -> void:
	# _enter_tree roda ANTES do _ready das paredes (filhas), então elas
	# já nascem sem saber que foram destruídas em um teste anterior.
	if not resetar_paredes_ao_entrar:
		return
	if not serialization.game_data.has("destroyed_walls"):
		return
	var destruidas: Array = serialization.game_data["destroyed_walls"]
	for id in destruidas.duplicate():
		if str(id).begins_with(PREFIXO_IDS):
			destruidas.erase(id)
			print("🔄 TesteEstetica: parede restaurada para teste: ", id)
