extends Resource
class_name PlanetHeightMap

@export var panorama : Texture2D : set = set_panorama
var _image : Image

func set_panorama(val):
	panorama = val
	if panorama:
		_image = panorama.get_image()
	emit_signal("changed")

func prepare_data():
	if panorama: _image = panorama.get_image()

# NOVA FUNÇÃO: Lê o valor suave entre os pixels
func get_height_at_uv_smooth(u: float, v: float) -> float:
	if not _image: return 0.0
	
	var w = _image.get_width()
	var h = _image.get_height()
	
	# Coordenadas flutuantes exatas
	var x = u * (w - 1)
	var y = v * (h - 1)
	
	# Pega os 4 pixels vizinhos
	var x_floor = int(x)
	var y_floor = int(y)
	var x_ceil = min(x_floor + 1, w - 1)
	var y_ceil = min(y_floor + 1, h - 1)
	
	# Fração para misturar (quanto estou perto do próximo pixel?)
	var x_lerp = x - x_floor
	var y_lerp = y - y_floor
	
	# Lê os 4 cantos
	var top_left = _image.get_pixel(x_floor, y_floor).r
	var top_right = _image.get_pixel(x_ceil, y_floor).r
	var bottom_left = _image.get_pixel(x_floor, y_ceil).r
	var bottom_right = _image.get_pixel(x_ceil, y_ceil).r
	
	# Interpolação Bilinear (Suavização)
	var top_mix = lerp(top_left, top_right, x_lerp)
	var bottom_mix = lerp(bottom_left, bottom_right, x_lerp)
	
	return lerp(top_mix, bottom_mix, y_lerp)
