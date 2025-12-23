
extends Resource
class_name PlanetData

# --- 1. CONFIGURAÇÕES GERAIS ---
@export var radius : float = 50.0 : set = set_radius
@export var resolution : int = 0 

@export var min_height : float = 0.0 : set = set_min_height
@export var amplitude : float = 20.0 : set = set_amplitude
# Ajuste da "Praia" para o continente
@export_range(0.01, 1.0) var plateau_threshold : float = 0.2 

# --- 2. IMAGENS ---
@export var height_map : PlanetHeightMap : set = set_height_map
@export var biome_map : PlanetBiomeMap : set = set_biome_map

# --- 3. A LISTA DE CORES VIP ---
@export_group("Biomas")
# Coloque aqui suas 7 cores (Vermelho, Verde, Azul, Amarelo...)
# A ORDEM IMPORTA: A cor 0 vai ser o ID 0 no shader.
@export var biome_colors : Array[Color]

# Tolerância: Se a cor não for EXATAMENTE igual, até onde aceitamos?
@export_range(0.01, 1.0) var color_tolerance : float = 0.1

# Noises para relevo (opcional, só se quiser montanhas 3D)
@export var biome_noises : Array[FastNoiseLite]
@export var biome_noise_amplitude : Array[float]

# --- SETTERS ---
func set_radius(val): radius = val; emit_signal("changed")
func set_min_height(val): min_height = val; emit_signal("changed")
func set_amplitude(val): amplitude = val; emit_signal("changed")
func set_height_map(val):
	height_map = val
	if height_map and not height_map.is_connected("changed", Callable(self, "on_data_changed")):
		height_map.changed.connect(Callable(self, "on_data_changed"))
	emit_signal("changed")
func set_biome_map(val):
	biome_map = val
	if biome_map and not biome_map.is_connected("changed", Callable(self, "on_data_changed")):
		biome_map.changed.connect(Callable(self, "on_data_changed"))
	emit_signal("changed")
func on_data_changed():
	if height_map: height_map.prepare_data()
	if biome_map: biome_map.prepare_data()
	emit_signal("changed")

# --- MATEMÁTICA ---
func get_color_squared_dist(c1: Color, c2: Color) -> float:
	var dr = c1.r - c2.r; var dg = c1.g - c2.g; var db = c1.b - c2.b
	return (dr * dr) + (dg * dg) + (db * db)

# A BUSCA PELO ID (0 a 6 ou 255)
func get_biome_index(pixel_color: Color) -> int:
	var closest_index = -1
	var min_dist = 999.0
	
	# Procura na lista VIP
	for i in range(biome_colors.size()):
		var target_col = biome_colors[i]
		var dist = get_color_squared_dist(pixel_color, target_col)
		
		if dist < min_dist:
			min_dist = dist
			closest_index = i
	
	# SE A COR ESTIVER LONGE DEMAIS, É BASE (255)
	if min_dist > color_tolerance:
		return -1 
		
	return closest_index

# --- FUNÇÃO CHAMADA PELO MESH PARA PINTAR O ID ---
func get_biome_id_for_shader(point_on_sphere: Vector3) -> Color:
	var p = point_on_sphere.normalized()
	var u = (atan2(p.x, p.z) / (2.0 * PI)) + 0.5; u = 1.0 - u
	var v = (asin(p.y) / PI) + 0.5; v = 1.0 - v
	
	var raw_color = Color.BLACK
	if biome_map: raw_color = biome_map.get_color_at_uv_smooth(u, v)
	
	# Pega o ID (0, 1, 2... ou -1)
	var index = get_biome_index(raw_color)
	
	# REGRA DO CHÃO BASE:
	# Se deu -1 (cor desconhecida), enviamos 1.0 (que o shader lê como 255)
	if index == -1:
		return Color(1.0, 0.0, 0.0, 1.0)
	
	# Se achou cor conhecida, normaliza (ID / 255.0)
	return Color(float(index) / 255.0, 0.0, 0.0, 1.0)

# --- FUNÇÃO DE FORMA (Altura) ---
func point_on_planet(point_on_sphere : Vector3) -> Vector3:
	var p = point_on_sphere.normalized()
	var u = (atan2(p.x, p.z) / (2.0 * PI)) + 0.5; u = 1.0 - u 
	var v = (asin(p.y) / PI) + 0.5; v = 1.0 - v
	
	var h_raw = 0.0
	if height_map: h_raw = height_map.get_height_at_uv_smooth(u, v)
	
	var h_processed = h_raw / plateau_threshold
	h_processed = clamp(h_processed, 0.0, 1.0)
	h_processed = smoothstep(0.0, 1.0, h_processed)
	var continent_height = h_processed * amplitude
	
	# Detalhe do bioma (opcional, igual conversamos antes)
	var biome_detail = 0.0
	var pixel_color = Color.BLACK
	if biome_map: pixel_color = biome_map.get_color_at_uv_smooth(u, v)
	var biome_id = get_biome_index(pixel_color)
	
	if biome_id != -1 and biome_id < biome_noises.size() and biome_noises[biome_id]:
		var n_val = biome_noises[biome_id].get_noise_3dv(p * radius)
		var strength = 1.0
		if biome_id < biome_noise_amplitude.size(): strength = biome_noise_amplitude[biome_id]
		biome_detail = n_val * strength * h_processed
	
	return p * (radius + min_height + continent_height + biome_detail)
