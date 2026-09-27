extends Node2D
class_name ItemGlow

@export_category("Objects")
@export var _canvas: Sprite2D

var mat: ShaderMaterial

func setup(icon_texture: Texture2D, icon_scale: float = 0.4) -> void:
	if not _canvas:
		push_error("⚠️ ItemGlow: campo '_canvas' não atribuído na cena!")
		return
	
	if not _canvas.material:
		push_error("⚠️ ItemGlow: Sprite2D '_canvas' não tem ShaderMaterial atribuído.")
		return
	
	# ✅ CRÍTICO: duplica o material pra essa instância não compartilhar
	# o mesmo Resource com outras instâncias de ItemGlow
	mat = _canvas.material.duplicate()
	_canvas.material = mat
	
	if icon_texture == null:
		push_error("⚠️ ItemGlow: icon_texture é null! Verifique o caminho em ability_icon_path.")
		return
	
	mat.set_shader_parameter("icon_texture", icon_texture)
	mat.set_shader_parameter("icon_scale", icon_scale)
