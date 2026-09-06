extends TileMapLayer

func _ready():
	_debug_print_all_tiles()

func _debug_print_all_tiles():
	print("🔍 === DEBUGANDO TODOS OS TILES ===")
	var used_cells = get_used_cells()
	
	for cell_pos in used_cells:
		var tile_data = get_cell_tile_data(cell_pos)
		if tile_data:
			var wall_data = tile_data.get_custom_data("Wall") if tile_data else null
			if wall_data != null and wall_data != "":
				print("📍 Tile em ", cell_pos, " tem Wall: '", wall_data, "'")
				
