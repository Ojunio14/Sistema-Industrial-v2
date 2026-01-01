extends Resource
class_name ActiveZoneData
signal data_changed
# --- CABEÇALHO (METADADOS) ---
@export var resolution : int = 64        # Número de Células (ex: 64)
var vertex_resolution : int = 65         # Número de Vértices (ex: 65)
var chunk_size : float
var origin_uv : Vector2                  # No Mesh você chamou de origin_uv
var normal : Vector3


var original_height_map : PackedFloat32Array # Nova variável
# --- CAMADA 1: GEOMETRIA (PackedFloat32Array é super otimizado) ---
# Guarda apenas a altura (deslocamento do raio).
# Tamanho: vertex_resolution * vertex_resolution
@export var height_map : PackedFloat32Array

# --- CAMADA 2: CONTEÚDO (PackedByteArray) ---
# Guarda o ID do material que está no topo.
# 0 = Ar, 1 = Terra, 2 = Pedra, etc.
# Tamanho: resolution * resolution
@export var material_map : PackedByteArray

# --- DICIONÁRIO DE MATERIAIS (Cache) ---
# Mapeia ID -> Resource de Material (Para o Mesh saber a cor)
var material_palette = {
	1: load("res://systems/terrain_modifier/materials/dirt.tres"),
	2: load("res://systems/terrain_modifier/materials/rock.tres")
}

# --- INICIALIZAÇÃO ---
func init_empty(_res: int, _size: float, _origin: Vector2, _normal: Vector3):
	resolution = _res
	vertex_resolution = resolution + 1
	chunk_size = _size
	origin_uv = _origin
	normal = _normal
	
	# Aloca memória preenchida com zeros
	height_map.resize(vertex_resolution * vertex_resolution)
	height_map.fill(0.0)
	
	material_map.resize(resolution * resolution)
	material_map.fill(1) # Preenche tudo com Terra (ID 1) por padrão
	
	# Inicializa o mapa original também
	original_height_map.resize(vertex_resolution * vertex_resolution)
	original_height_map.fill(0.0)

# --- GERAÇÃO INICIAL (Copia do Planeta) ---
func generate_from_planet(planet_data: PlanetData, mat_dirt, mat_rock):
	# Atualiza a paleta com o que veio do gerador
	material_palette[1] = mat_dirt
	material_palette[2] = mat_rock
	
	var axisA := Vector3(normal.y, normal.z, normal.x)
	var axisB : Vector3 = normal.cross(axisA)
	
	# Loop pelos vértices para capturar a altura real
	for y in range(vertex_resolution):
		for x in range(vertex_resolution):
			var percent = Vector2(x, y) / float(resolution)
			var global_percent = origin_uv + (percent * chunk_size)
			
			var point_cube = normal + (global_percent.x - 0.5) * 2.0 * axisA + (global_percent.y - 0.5) * 2.0 * axisB
			var point_sphere = point_cube.normalized()
			
			# Pega a altura real do planeta neste ponto
			var planet_pos = planet_data.point_on_planet(point_sphere)
			var real_height = planet_pos.length() - planet_data.radius
			
			# Salva no Array
			_set_height_internal(x, y, real_height)
			
			# SALVA A REFERÊNCIA ORIGINAL AQUI
			original_height_map[y * vertex_resolution + x] = real_height
# --- ACESSO AOS DADOS (API) ---

# Função segura chamada pelo seu Mesh
func get_height_safe(x: int, y: int) -> float:
	# Clamp impede crash se o mesh pedir um vértice fora do array
	x = clamp(x, 0, vertex_resolution - 1)
	y = clamp(y, 0, vertex_resolution - 1)
	return height_map[y * vertex_resolution + x]

# Função interna rápida (sem check de segurança)
func _set_height_internal(x: int, y: int, val: float):
	height_map[y * vertex_resolution + x] = val

# --- SISTEMA DE MATERIAIS (Simulando a Stack) ---

# O seu Mesh pede "get_stack". Para não quebrar seu código agora,
# vamos retornar um objeto simples que finge ser uma Stack.
class FakeStack:
	var mat_res : Resource#StandardMaterial3D
	func _init(m): mat_res = m
	func get_top_material(): return mat_res

func get_stack(x: int, y: int) -> FakeStack:
	# Garante que não saia do limite (clamp)
	x = clamp(x, 0, resolution - 1)
	y = clamp(y, 0, resolution - 1)
	
	var mat_id = material_map[y * resolution + x]
	var mat_resource = material_palette.get(mat_id, null)
	
	return FakeStack.new(mat_resource)



# No final de ActiveZoneData.gd

# Converte uma posição do MUNDO 3D para coordenadas do GRID (X, Y)
func world_to_grid(world_pos: Vector3, planet_center: Vector3, planet_radius: float) -> Vector2i:
	var axisA := Vector3(normal.y, normal.z, normal.x)
	var axisB : Vector3 = normal.cross(axisA)
	
	# 1. Vetor do centro do planeta até o clique
	var direction = (world_pos - planet_center).normalized()
	
	# 2. Projetar essa direção no plano da face do cubo
	# (Matemática inversa do Cubesphere)
	# Nota: Isso é uma aproximação local, mas funciona bem para chunks pequenos.
	
	# Precisamos saber onde este chunk começa no cubo unitário (-1 a 1)
	# origin_uv vai de 0.0 a 1.0. Vamos converter para -1.0 a 1.0 se necessário,
	# mas como sua logica usa 0..1, vamos manter.
	
	# Vamos usar uma abordagem de projeção local (mais simples e robusta para edição)
	# Calculamos o centro do chunk no mundo
	var center_perc = origin_uv + Vector2(chunk_size, chunk_size) * 0.5
	var center_cube = normal + (center_perc.x - 0.5) * 2.0 * axisA + (center_perc.y - 0.5) * 2.0 * axisB
	var center_world_dir = center_cube.normalized()
	
	# Diferença entre onde clicamos e o centro do chunk
	var diff = direction - center_world_dir
	
	# Projetamos essa diferença nos eixos do chunk
	# Multiplicamos por (radius * chunk_size) aproximado para converter ângulo em metros/unidades
	# Mas o jeito mais fácil é trabalhar no espaço UV direto:
	
	# Hack Matemático: Projetar direto nos eixos A e B
	# A coordenada UV é proporcional ao produto escalar com os eixos tangentes
	var local_x = direction.dot(axisA)
	var local_y = direction.dot(axisB)
	
	# Precisamos normalizar isso relativo ao origin_uv do chunk
	# Isso é complexo de fazer perfeito, então vamos usar BUSCA LOCAL se a projeção falhar.
	# Mas vamos tentar a projeção linear simples primeiro, que é muito rápida:
	
	# Offset relativo ao inicio do chunk
	var start_cube = normal + (origin_uv.x - 0.5) * 2.0 * axisA + (origin_uv.y - 0.5) * 2.0 * axisB
	var start_dir = start_cube.normalized()
	
	var rel_dir = direction - start_dir
	
	# Projeção escalar
	var u = rel_dir.dot(axisA) * 0.5 # O fator 0.5 ajusta a escala do cubo unitário
	var v = rel_dir.dot(axisB) * 0.5
	
	# Ajuste fino: Como é uma esfera, a escala não é linear. 
	# Mas para chunks pequenos (HCS), é quase linear.
	# Vamos converter U/V (0.0 a chunk_size) para Pixels (0 a resolution)
	
	var pixel_x = int((u / chunk_size) * resolution)
	var pixel_y = int((v / chunk_size) * resolution)
	
	return Vector2i(pixel_x, pixel_y)

# Aplica deformação em uma área circular
# No ActiveZoneData.gd

func apply_brush(center_x: int, center_y: int, radius: float, strength: float):
	var brush_steps = int(radius)
	var dirty_visuals = false # Para só emitir sinal se algo mudou
	
	for y in range(center_y - brush_steps, center_y + brush_steps + 1):
		for x in range(center_x - brush_steps, center_x + brush_steps + 1):
			
			var dist = Vector2(x, y).distance_to(Vector2(center_x, center_y))
			
			if dist <= brush_steps:
				if x >= 0 and x < vertex_resolution and y >= 0 and y < vertex_resolution:
					
					var current_h = get_height_safe(x, y)
					# Aplica a força (Escavação)
					var new_h = current_h + strength * (1.0 - (dist / brush_steps))
					
					set_height(x, y, new_h)
					dirty_visuals = true
					
					# --- NOVA LÓGICA DE MATERIAIS ---
					# Verifica a célula correspondente a este vértice
					# (Como vértices são quinas, verificamos a célula à direita/baixo dele)
					if x < resolution and y < resolution:
						_update_material_based_on_depth(x, y, new_h)

	if dirty_visuals:
		emit_signal("data_changed")

func _update_material_based_on_depth(x: int, y: int, current_height: float):
	# Recupera a altura original deste ponto
	var original = original_height_map[y * vertex_resolution + x]
	
	# Regra: Se a profundidade for maior que 2 metros, vira PEDRA (ID 2).
	# Se for menor, continua TERRA (ID 1).
	var depth_diff = original - current_height
	
	var current_mat = get_material_id(x, y)
	var new_mat = 1 # Terra
	
	if depth_diff > 2.0:
		new_mat = 2 # Pedra
	
	# Só altera se mudou (economiza processamento)
	if current_mat != new_mat:
		set_material_id(x, y, new_mat)



# Adicione isso no ActiveZoneData.gd

# Lê o ID do material na célula X, Y
func get_material_id(x: int, y: int) -> int:
	# Proteção para não quebrar se pedir fora do limite
	if x < 0 or x >= resolution or y < 0 or y >= resolution:
		return 0 # Retorna 0 (Ar/Vazio) se estiver fora
		
	return material_map[y * resolution + x]

# Define o ID do material na célula X, Y
func set_material_id(x: int, y: int, id: int):
	if x < 0 or x >= resolution or y < 0 or y >= resolution:
		return
		
	material_map[y * resolution + x] = id


# Adicione isso no topo do script para o Mesh poder ouvir
func set_height(x: int, y: int, new_height: float):
	# Proteção para não sair do array
	if x < 0 or x >= vertex_resolution or y < 0 or y >= vertex_resolution:
		return
	
	# Altera o valor na memória
	height_map[y * vertex_resolution + x] = new_height

# No final de ActiveZoneData.gd

# Função chamada quando o jogador solta o mouse para confirmar a mineração
func apply_flattening_area(start: Vector2i, end: Vector2i, target_height: float) -> Dictionary:
	var min_x = min(start.x, end.x)
	var max_x = max(start.x, end.x)
	var min_y = min(start.y, end.y)
	var max_y = max(start.y, end.y)
	
	var total_dirt_removed : float = 0.0
	var total_rock_removed : float = 0.0
	var cells_modified : int = 0
	
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if x >= vertex_resolution or y >= vertex_resolution: continue
			
			var current_h = get_height_safe(x, y)
			
			# Calcula diferença (Volume desta célula)
			# Nota: Estamos tratando vértice como célula para simplificar volume
			var diff = current_h - target_height
			
			# Se diff > 0, estamos cavando (removendo terra)
			# Se diff < 0, estamos aterrando (precisa de terra) - Vamos focar em cavar agora
			
			if abs(diff) > 0.01: # Só altera se tiver mudança real
				
				# Verifica que material estamos tirando (baseado na profundidade original)
				# Se já estamos fundo, é pedra. Se estamos na superfície, é terra.
				var mat_id = get_material_id(min(x, resolution-1), min(y, resolution-1))
				
				if diff > 0: # Cavando
					if mat_id == 2: # Pedra
						total_rock_removed += diff
					else: # Terra
						total_dirt_removed += diff
				
				# APLICA A NOVA ALTURA
				set_height(x, y, target_height)
				
				# Atualiza o tipo de material (se cavou fundo demais, vira pedra)
				_update_material_based_on_depth(x, y, target_height)
				
				cells_modified += 1
	
	# Avisa o Mesh para reconstruir TUDO de uma vez
	if cells_modified > 0:
		emit_signal("data_changed")
	
	# Retorna o relatório para o jogo (Inventário)
	return {
		"dirt": total_dirt_removed,
		"rock": total_rock_removed,
		"modified": cells_modified
	}

# No ActiveZoneData.gd


func apply_ramp_area(start: Vector2i, end: Vector2i, start_height: float, end_height: float) -> Dictionary:
	var min_x = min(start.x, end.x)
	var max_x = max(start.x, end.x)
	var min_y = min(start.y, end.y)
	var max_y = max(start.y, end.y)
	
	# --- CORREÇÃO 1: Renomeei para 'grid_diff' (Diferença de Grade) ---
	var grid_diff = end - start 
	
	# Vetores para calcular a inclinação (Slope)
	var ramp_vector = Vector2.ZERO
	
	# Verifica qual eixo é o dominante (X ou Y)
	# Usamos grid_diff aqui
	if abs(grid_diff.x) > abs(grid_diff.y):
		ramp_vector = Vector2(grid_diff.x, 0) # Trava no Eixo X (Horizontal)
	else:
		ramp_vector = Vector2(0, grid_diff.y) # Trava no Eixo Y (Vertical)
	
	var ramp_length_sq = ramp_vector.length_squared()
	
	var total_dirt = 0.0
	var total_rock = 0.0
	var cells_modified = 0
	
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if x >= vertex_resolution or y >= vertex_resolution: continue
			
			# --- A MATEMÁTICA DA RAMPA ---
			var current_vector = Vector2(x - start.x, y - start.y)
			
			var t = 0.0
			if ramp_length_sq > 0:
				t = current_vector.dot(ramp_vector) / ramp_length_sq
			
			t = clamp(t, 0.0, 1.0)
			
			var target_h = lerp(start_height, end_height, t)
			# -----------------------------
			
			var current_h = get_height_safe(x, y)
			
			# --- CORREÇÃO 2: Descomentei e renomeei para 'height_diff' ---
			var height_diff = current_h - target_h
			
			# Agora comparamos float com float. Tudo certo.
			if abs(height_diff) > 0.01:
				var mat_id = get_material_id(min(x, resolution-1), min(y, resolution-1))
				
				if height_diff > 0: # Cavando
					if mat_id == 2: 
						total_rock += height_diff
					else: 
						total_dirt += height_diff
				
				# Aplica a altura calculada
				set_height(x, y, target_h)
				_update_material_based_on_depth(x, y, target_h)
				cells_modified += 1
				
	if cells_modified > 0:
		emit_signal("data_changed")
		
	return {"dirt": total_dirt, "rock": total_rock, "modified": cells_modified}

#func apply_ramp_area(start: Vector2i, end: Vector2i, start_height: float, end_height: float) -> Dictionary:
	#var min_x = min(start.x, end.x)
	#var max_x = max(start.x, end.x)
	#var min_y = min(start.y, end.y)
	#var max_y = max(start.y, end.y)
	#
## --- CORREÇÃO: ALINHAMENTO DE EIXO (SNAP) ---
	#var raw_vec = start - end # ou end - start, depende da sua ordem
	## Vamos manter coerência com o código anterior:
	#var diff = end - start
	#
	## Vetores para calcular a inclinação (Slope)
	## Vetor "Direção da Rampa" (Do início ao fim do arraste)
	#var ramp_vector = Vector2.ZERO
	#
	## Verifica qual eixo é o dominante (X ou Y)
	#if abs(diff.x) > abs(diff.y):
		#ramp_vector = Vector2(diff.x, 0) # Trava no Eixo X (Horizontal)
	#else:
		#ramp_vector = Vector2(0, diff.y) # Trava no Eixo Y (Vertical)
	#
	#
	#
	#var ramp_length_sq = ramp_vector.length_squared()
	#
	#var total_dirt = 0.0
	#var total_rock = 0.0
	#var cells_modified = 0
	#
	#for y in range(min_y, max_y + 1):
		#for x in range(min_x, max_x + 1):
			#if x >= vertex_resolution or y >= vertex_resolution: continue
			#
			## --- A MATEMÁTICA DA RAMPA ---
			## 1. Vetor do ponto atual relativo ao início
			#var current_vector = Vector2(x - start.x, y - start.y)
			#
			## 2. Projeção escalar: Onde este ponto cai na linha da rampa (0.0 a 1.0)
			## Se t = 0 (Início), Se t = 1 (Fim), Se t = 0.5 (Meio)
			#var t = 0.0
			#if ramp_length_sq > 0:
				#t = current_vector.dot(ramp_vector) / ramp_length_sq
			#
			## Clamp garante que não suba/desça além dos pontos se selecionar atrás
			#t = clamp(t, 0.0, 1.0)
			#
			## 3. Calcula a altura alvo interpolada (Lerp)
			#var target_h = lerp(start_height, end_height, t)
			## -----------------------------
			#
			#var current_h = get_height_safe(x, y)
			##var diff = current_h - target_h
			#
			#if abs(diff) > 0.01:
				#var mat_id = get_material_id(min(x, resolution-1), min(y, resolution-1))
				#
				#if diff > 0: # Cavando
					#if mat_id == 2: total_rock += diff
					#else: total_dirt += diff
				#
				## Aplica a altura calculada
				#set_height(x, y, target_h)
				#_update_material_based_on_depth(x, y, target_h)
				#cells_modified += 1
				#
	#if cells_modified > 0:
		#emit_signal("data_changed")
		#
	#return {"dirt": total_dirt, "rock": total_rock, "modified": cells_modified}
