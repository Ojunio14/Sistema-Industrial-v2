
extends Resource
class_name PlanetData

# --- 1. GERAIS ---
@export var radius : float = 50.0 : set = set_radius
@export var min_height : float = 0.0 : set = set_min_height
@export var amplitude : float = 20.0 : set = set_amplitude # Altura MÁXIMA global

# Tudo abaixo disso na imagem vira mar. Tudo acima vira terra.
@export_range(0.0, 1.0) var sea_level : float = 0.15 

# --- 2. INPUTS ---
@export var height_map : PlanetHeightMap : set = set_height_map

# ESSE É O SEGREDO: O Noise que desenha a pedra
@export var mountain_noise : FastNoiseLite 

# --- 3. CONFIGURAÇÃO DA MONTANHA (COI STYLE) ---
@export_group("Montanha Industrial")
@export var mountain_strength : float = 1.0 # Força extra do noise
@export var terrace_steps : float = 15.0    # Degraus
@export var mask_threshold : float = 0.4    # A partir de que cor cinza a montanha começa?

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

# --- LÓGICA DE GERAÇÃO ---
func point_on_planet(point_on_sphere : Vector3) -> Vector3:
	var p = point_on_sphere.normalized()
	
	# 1. UV
	var u = (atan2(p.x, p.z) / (2.0 * PI)) + 0.5; u = 1.0 - u
	var v = (asin(p.y) / PI) + 0.5; v = 1.0 - v
	
	# 2. LÊ A "MÁSCARA" (Sua pintura)
	var mask_val = 0.0
	if height_map: mask_val = height_map.get_height_at_uv_smooth(u, v)
	
	var final_height = 0.0
	
	# Se for Terra (maior que nível do mar)
	if mask_val > sea_level:
		
		# A. Base do Continente (Planícies)
		# Normaliza para começar do 0 logo após o mar
		var land_base = (mask_val - sea_level) / (1.0 - sea_level)
		
		# B. Cálculo da Montanha (Noise)
		var mountain_detail = 0.0
		
		# Só calculamos noise se a pintura for clara o suficiente (acima do threshold)
		# Ex: Cinza Escuro = Chão Liso. Cinza Claro/Branco = Montanha.
		if mask_val > mask_threshold and mountain_noise:
			
			# 1. O Ruído Puro
			var n = mountain_noise.get_noise_3dv(p * radius)
			
			# 2. Ridged (Picos pontudos)
			n = 1.0 - abs(n)
			n = pow(n, 2.0)
			
			# 3. Terracing (Degraus industriais)
			var n_stepped = floor(n * terrace_steps) / terrace_steps
			n = lerp(n, n_stepped, 0.6)
			
			# 4. A MÁGICA: WEIGHTED MASK (Máscara Ponderada)
			# Calculamos o quanto estamos "dentro" da área de montanha na pintura.
			# Isso faz a montanha nascer pequena nas bordas do branco e alta no centro.
			var mountain_weight = (mask_val - mask_threshold) / (1.0 - mask_threshold)
			mountain_weight = clamp(mountain_weight, 0.0, 1.0)
			mountain_weight = pow(mountain_weight, 0.5) # Suaviza a transição
			
			mountain_detail = n * mountain_strength * mountain_weight
		
		# Soma: Base do Chão (Pintura) + Detalhe da Montanha (Noise)
		final_height = land_base + mountain_detail
		
	return p * (radius + min_height + (final_height * amplitude))

# --- Shader Helper ---
func get_biome_id_for_shader(point_on_sphere: Vector3) -> Color:
	return Color.RED
	
#func point_on_planet(point_on_sphere : Vector3) -> Vector3:
	#var p = point_on_sphere.normalized()
	#
	## 1. Cálculo UV
	#var u = (atan2(p.x, p.z) / (2.0 * PI)) + 0.5; u = 1.0 - u
	#var v = (asin(p.y) / PI) + 0.5; v = 1.0 - v
	#
	## 2. Base do Continente (Mantém igual para todos)
	#var h_raw = 0.0
	#if height_map: h_raw = height_map.get_height_at_uv_smooth(u, v)
	#
	#var h_processed = h_raw / plateau_threshold
	#h_processed = clamp(h_processed, 0.0, 1.0)
	#h_processed = smoothstep(0.0, 1.0, h_processed)
	#var continent_height = h_processed * amplitude
	#
	## 3. Detalhe do Bioma (AGORA COM LÓGICA SEPARADA)
	#var biome_detail = 0.0
	#
	#var pixel_color = Color.BLACK
	#if biome_map: pixel_color = biome_map.get_color_at_uv_smooth(u, v)
	#var biome_id = get_biome_index(pixel_color)
	#
	## Verifica se o ID é válido e se tem noise configurado
	#if biome_id != -1 and biome_id < biome_noises.size() and biome_noises[biome_id]:
		#var noise_res = biome_noises[biome_id]
		#var raw_noise = noise_res.get_noise_3dv(p * radius)
		#
		## Pega a força configurada no inspector
		#var strength = 1.0
		#if biome_id < biome_noise_amplitude.size():
			#strength = biome_noise_amplitude[biome_id]
			#
		## --- AQUI É ONDE A MÁGICA ACONTECE ---
		#match biome_id:
			#
			## CASO 0: MONTANHAS INDUSTRIAIS (Captain of Industry)
			## Características: Pontudas, Altas, com Degraus
			#0:
				#var n = 1.0 - abs(raw_noise) # Cria picos (Ridged manual)
				#n = pow(n, 2.0)              # Deixa mais íngreme
				#
				## Degraus (Terracing)
				#var steps = 10.0
				#var n_stepped = floor(n * steps) / steps
				#n = lerp(n, n_stepped, 0.5)  # Mistura liso com degrau
				#
				#biome_detail = n * strength * h_processed
#
			## CASO 1: DESERTO / DUNAS
			## Características: Ondas suaves, sem degraus, altura média
			#1:
				## Usa o noise puro (ondas senoidais)
				## abs() aqui cria dunas afiadas no topo mas curvas na base
				#var n = abs(raw_noise) 
				#n = pow(n, 1.5) # Levemente curvado
				#
				#biome_detail = n * strength * h_processed
#
			## CASO 2: FLORESTA / COLINAS
			## Características: Suave, arredondado, baixo
			#2:
				## Apenas noise padrão simples
				#var n = (raw_noise + 1.0) / 2.0 # Normaliza para 0 a 1
				#
				#biome_detail = n * strength * h_processed
#
			## CASO PADRÃO (Para qualquer outro bioma não listado acima)
			#_:
				#biome_detail = raw_noise * strength * h_processed
#
	## 4. Soma Final
	#return p * (radius + min_height + continent_height + biome_detail)
