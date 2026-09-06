extends Node
class_name player 

var enemy_healt: int = 5

var base_attack: int = 2
var bonus_attack: int = 3

var can_attack: bool = true


func _ready():
		#print (update_enemy_healt())
		pass
		
		
func update_enemy_healt() -> String:
	if can_attack == true:
		if base_attack + bonus_attack >= enemy_healt:
			return("inimigo derrotado.")
		elif base_attack + bonus_attack >= 3:
			return("inimigo ferido.")
		else:
			return("inimigo de pé.")
	else:
		return("sem energia.")
