extends Resource
class_name PlanetHeightMap

@export var panorama : Texture2D : set = set_panorama

# Dados crus na memória (Acesso Thread-Safe natural)
var _data : PackedFloat32Array
var _width : int = 0
var _height : int = 0
var _is_ready : bool = false

func set_panorama(val):
	panorama = val
	_is_ready = false # Se mudou a textura, os dados antigos são inválidos
	emit_signal("changed")

# Esta função DEVE ser chamada pela Main Thread antes de qualquer coisa
func prepare_data():
	if not panorama: 
		_is_ready = false
		return
		
	# get_image() é pesado e perigoso em threads. Fazemos aqui.
	var img = panorama.get_image()
	if not img: 
		_is_ready = false
		return
		
	_width = img.get_width()
	_height = img.get_height()
	
	# Redimensiona e copia
	_data.resize(_width * _height)
	
	for y in range(_height):
		for x in range(_width):
			# Assumindo altura no canal R. Ajuste se precisar.
			_data[y * _width + x] = img.get_pixel(x, y).r
			
	_is_ready = true
	print("PlanetHeightMap: Dados gerados com sucesso (%dx%d)" % [_width, _height])

# Leitura Segura (Sem locks, sem checks complexos)
func get_height_at_uv_smooth(u: float, v: float) -> float:
	if not _is_ready: return 0.0 # Se não preparou, infelizmente é plano.
	
	# Proteção matemática para evitar erros de array
	u = fposmod(u, 1.0)
	v = clamp(v, 0.0, 1.0)
	
	var x = u * (_width - 1)
	var y = v * (_height - 1)
	
	var x_floor = int(x)
	var y_floor = int(y)
	var x_ceil = (x_floor + 1) % _width
	var y_ceil = min(y_floor + 1, _height - 1)
	
	# Acesso direto ao Array (Super Rápido)
	var tl = _data[y_floor * _width + x_floor]
	var tr = _data[y_floor * _width + x_ceil]
	var bl = _data[y_ceil * _width + x_floor]
	var br = _data[y_ceil * _width + x_ceil]
	
	var x_lerp = x - x_floor
	var y_lerp = y - y_floor
	
	return lerp(lerp(tl, tr, x_lerp), lerp(bl, br, x_lerp), y_lerp)
