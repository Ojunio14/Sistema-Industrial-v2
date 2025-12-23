extends Resource
class_name PlanetBiomeMap

@export var panorama : Texture2D : set = set_panorama
var _image : Image

func set_panorama(val):
	panorama = val
	if panorama:
		_image = panorama.get_image()
	emit_signal("changed")

func prepare_data():
	if panorama: _image = panorama.get_image()

# DIFERENÇA PRINCIPAL: Retorna uma COLOR completa (r, g, b)
func get_color_at_uv_smooth(u: float, v: float) -> Color:
	if not _image: return Color.BLACK # Retorna preto se não tiver imagem
	
	var w = _image.get_width()
	var h = _image.get_height()
	
	var x = u * (w - 1)
	var y = v * (h - 1)
	
	var x_floor = int(x)
	var y_floor = int(y)
	var x_ceil = min(x_floor + 1, w - 1)
	var y_ceil = min(y_floor + 1, h - 1)
	
	var x_lerp = x - x_floor
	var y_lerp = y - y_floor
	
	# Pega as Cores dos 4 vizinhos
	var top_left = _image.get_pixel(x_floor, y_floor)
	var top_right = _image.get_pixel(x_ceil, y_floor)
	var bottom_left = _image.get_pixel(x_floor, y_ceil)
	var bottom_right = _image.get_pixel(x_ceil, y_ceil)
	
	# Godot faz interpolação de Cores automaticamente com .lerp()
	var top_mix = top_left.lerp(top_right, x_lerp)
	var bottom_mix = bottom_left.lerp(bottom_right, x_lerp)
	
	return top_mix.lerp(bottom_mix, y_lerp)
