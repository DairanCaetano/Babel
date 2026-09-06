# equipment_manager.gd (Autoload)
extends Node

signal item_equipped(item_data: Dictionary)
signal item_unequipped(slot_type: String)

# ✅ Apenas espelha os dados, não controla
var equipments_inventory: Dictionary = {
	"armor": {}, "weapon": {}, 
	"offhand": {}, "consumable": {}
}
