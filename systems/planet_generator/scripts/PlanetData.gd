extends Resource
class_name PlanetData

# --- PROTEÇÃO MULTITHREAD ---
# Este objeto garante que apenas uma thread leia os dados por vez.
#var _mutex := Mutex.new()

# --- 1. GERAIS ---
@export var radius : float = 50.0 : set = set_radius
@export var min_height : float = 0.0 : set = set_min_height
@export var amplitude : float = 20.0 : set = set_amplitude 

@export_range(0.0, 1.0) var sea_level : float = 0.15 

# --- 2. INPUTS ---
@export var height_map : PlanetHeightMap : set = set_height_map
@export var mountain_noise : FastNoiseLite 

# --- 3. CONFIGURAÇÃO DA MONTANHA ---
@export_group("Montanha Industrial")
@export var mountain_strength : float = 1.0 
@export var terrace_steps : float = 15.0    
@export var mask_threshold : float = 0.4    

# --- SETTERS ---
func set_radius(val): radius = val; emit_signal("changed")
func set_min_height(val): min_height = val; emit_signal("changed")
func set_amplitude(val): amplitude = val; emit_signal("changed")
func set_height_map(val):
	height_map = val
	if height_map and not height_map.is_connected("changed", Callable(self, "on_data_changed")):
		height_map.changed.connect(Callable(self, "on_data_changed"))
	emit_signal("changed")
func on_data_changed():
	if height_map: height_map.prepare_data()
	emit_signal("changed")






# --- LÓGICA DE GERAÇÃO (PROTEGIDA) ---
func point_on_planet(point_on_sphere : Vector3) -> Vector3:
	# -------------------------------------------------------------
	# 1. BLOQUEIO (LOCK): Nenhuma outra thread passa daqui enquanto eu não terminar
	# -------------------------------------------------------------
	#_mutex.lock()
	
	# Usamos defer para garantir que o unlock ocorra mesmo se der erro no meio
	# (Mas em GDScript puro, o ideal é chamar unlock manual antes de todo return)
	
	var p = point_on_sphere.normalized()
	
	# 1. UV
	var u = (atan2(p.x, p.z) / (2.0 * PI)) + 0.5; u = 1.0 - u
	var v = (asin(p.y) / PI) + 0.5; v = 1.0 - v
	
	# 2. LÊ A "MÁSCARA" 
	var mask_val = 0.0
	# Essa é a chamada perigosa que estava retornando 0 aleatoriamente
	if height_map: mask_val = height_map.get_height_at_uv_smooth(u, v)
	
	var final_height = 0.0
	
	# Se for Terra
	if mask_val > sea_level:
		var land_base = (mask_val - sea_level) / (1.0 - sea_level)
		var mountain_detail = 0.0
		
		if mask_val > mask_threshold and mountain_noise:
			var n = mountain_noise.get_noise_3dv(p * radius)
			
			n = 1.0 - abs(n)
			n = pow(n, 2.0)
			
			var n_stepped = floor(n * terrace_steps) / terrace_steps
			n = lerp(n, n_stepped, 0.6)
			
			var mountain_weight = (mask_val - mask_threshold) / (1.0 - mask_threshold)
			mountain_weight = clamp(mountain_weight, 0.0, 1.0)
			mountain_weight = pow(mountain_weight, 0.5) 
			
			mountain_detail = n * mountain_strength * mountain_weight
		
		final_height = land_base + mountain_detail
		
	var result = p * (radius + min_height + (final_height * amplitude))
	
	# -------------------------------------------------------------
	# 2. DESBLOQUEIO (UNLOCK): Libera para a próxima thread
	# -------------------------------------------------------------
	#_mutex.unlock()
	
	return result

func get_biome_id_for_shader(point_on_sphere: Vector3) -> Color:
	return Color.RED
