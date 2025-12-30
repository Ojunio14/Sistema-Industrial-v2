extends Node3D
class_name QuadtreeNode

# --- DADOS ---
var planet_data : PlanetData
var parent_planet : Node3D 
var player_camera : Node3D 

# --- PROPRIEDADES ---
var depth : int = 0
var normal : Vector3
var chunk_origin : Vector2
var chunk_size : float

# --- ESTRUTURA ---
var children : Array[QuadtreeNode] = []
var mesh_instance : PlanetMeshFace = null
var is_split : bool = false

# --- ZONA ATIVA ---
var is_active_zone : bool = false
var active_data : ActiveZoneData
var active_mesh : ActiveZoneMesh

const MAX_DEPTH = 8
const SPLIT_MULTIPLIER = 3.0 # Volte para o valor que você gostava (2.0 ou 1.25)

func initialize(_planet_data, _normal, _origin, _size, _depth, _parent_planet, _camera):
	planet_data = _planet_data
	normal = _normal
	chunk_origin = _origin
	chunk_size = _size
	depth = _depth
	parent_planet = _parent_planet
	player_camera = _camera
	
	update_lod()

func _process(delta):
	# LIMPEZA DE MALHA (GHOSTBUSTER)
	# Se tenho filhos ou sou zona ativa, não devo ter malha estática
	if (is_split or is_active_zone) and mesh_instance != null:
		mesh_instance.visible = false 
		mesh_instance.queue_free()   
		mesh_instance = null
	
	# LOD (Só roda se não for zona ativa)
	if not is_active_zone:
		update_lod()

func update_lod():
	if not is_instance_valid(player_camera): return

	var center_point = _get_center_point_on_sphere()
	var dist = player_camera.global_position.distance_to(center_point)
	var split_distance = (chunk_size * planet_data.radius) * SPLIT_MULTIPLIER
	
	# --- LÓGICA PADRÃO DE DIVISÃO ---
	if dist < split_distance and depth < MAX_DEPTH:
		if not is_split:
			split()
	
	# --- LÓGICA PADRÃO DE JUNÇÃO ---
	else:
		if is_split:
			# A ÚNICA PROTEÇÃO NECESSÁRIA:
			# Se tiver uma mina lá embaixo, não fecha. De resto, aja normal.
			if _has_active_zone_child(): return
			
			merge()
			
		elif mesh_instance == null and not is_active_zone:
			create_mesh()

# Verifica hierarquia para proteger a mina
func _has_active_zone_child() -> bool:
	for child in children:
		if child.is_active_zone: return true
		if child._has_active_zone_child(): return true
	return false

# --- A FERRAMENTA DE BUSCA (DRILL DOWN) ---
func drill_down_to_size(target_pos: Vector3, target_size: float) -> QuadtreeNode:
	var real_size = chunk_size * planet_data.radius
	
	# 1. Se cheguei no tamanho alvo (ou menor), SOU EU!
	if real_size <= target_size or depth >= MAX_DEPTH:
		return self

	# 2. Se sou grande demais, preciso dividir agora para achar o filho
	if not is_split:
		split() 
	
	# 3. Procura o filho mais próximo do clique
	var closest = null
	var min_dist = INF
	
	for child in children:
		# Verifica distância do centro do filho até o clique
		var d = child._get_center_point_on_sphere().distance_to(target_pos)
		if d < min_dist:
			min_dist = d
			closest = child
			
	if closest:
		return closest.drill_down_to_size(target_pos, target_size)
		
	return self

# --- AÇÕES BÁSICAS ---

func split():
	if is_split: return
	is_split = true
	
	if mesh_instance:
		mesh_instance.visible = false
		mesh_instance.queue_free()
		mesh_instance = null
	
	var half = chunk_size / 2.0
	create_child(chunk_origin, half)
	create_child(chunk_origin + Vector2(half, 0), half)
	create_child(chunk_origin + Vector2(0, half), half)
	create_child(chunk_origin + Vector2(half, half), half)

func merge():
	is_split = false
	for child in children:
		child.queue_free()
	children.clear()
	create_mesh()

func create_child(offset : Vector2, size : float):
	var child = QuadtreeNode.new()
	add_child(child)
	children.append(child)
	child.initialize(planet_data, normal, offset, size, depth + 1, parent_planet, player_camera)

func create_mesh():
	if is_active_zone or is_split: return
	if mesh_instance != null: return
	
	mesh_instance = PlanetMeshFace.new()
	add_child(mesh_instance)
	
	# --- LÓGICA DE OTIMIZAÇÃO (LOD DE RESOLUÇÃO) ---
	# Quanto maior o Depth, mais perto estamos e menor é o chunk.
	# Chunk Perto (Depth Alto) -> Precisa de muitos vértices (64) para detalhe de 1m.
	# Chunk Longe (Depth Baixo) -> Pode ter poucos vértices (16 ou 24) pois está longe.
	
# --- LOD DE RESOLUÇÃO (OTIMIZADO PARA TOP-DOWN) ---
	
	# Depth 0 a 3 (Chunks gigantes/longe):
	# Resolução 16 é o mínimo seguro para manter a curvatura sem abrir buracos.
	if depth < 4:
		mesh_instance.resolution = 16 
		
	# Depth 4 e 5 (Chunks médios):
	# Subimos um pouco para 24 ou 32. Isso ajuda na transição visual.
	elif depth < 6:
		mesh_instance.resolution = 24
		
	# Depth 6 e 7 (Chunks chegando perto):
	# Resolução 48. Quase perfeito, mas ainda leve.
	elif depth < MAX_DEPTH - 1: # Se MAX_DEPTH for 8, isso pega o depth 6
		mesh_instance.resolution = 48
		
	# Depth Máximo (O chão onde o player joga):
	# Aqui mantemos o 64 para garantir o detalhe de 1m e o encaixe com a Zona Ativa.
	else:
		mesh_instance.resolution = 64 
	
	# -----------------------------------------------
	
	# -----------------------------------------------
	
	mesh_instance.normal = normal
	mesh_instance.chunk_origin = chunk_origin
	mesh_instance.chunk_size = chunk_size
	
	mesh_instance.regenerate_mesh(planet_data)

#func promote_to_active_zone():
	#if is_active_zone: return
	#is_active_zone = true
#
	## 1. Limpa a malha estática
	#if mesh_instance:
		#mesh_instance.visible = false 
		#mesh_instance.queue_free()   
		#mesh_instance = null
	#
	#set_process(false) 
	#
	## ======================================================================
	## CÁLCULO DE RESOLUÇÃO DINÂMICA
	## ======================================================================
	#
	## CONFIGURAÇÃO: Qual a distância você quer entre um vértice e outro?
	## 1.0 = Muito detalhado (1 metro)
	## 1.5 = Equilibrado (1.5 metros)
	#var target_spacing : float = 1.0 
	#
	## 1. Calcula o tamanho real deste pedaço de terreno em metros (comprimento do arco)
	## (Considerando que uma face inteira é PI * Raio / 2)
	#var face_arc_length = (PI * planet_data.radius) / 2.0
	#var my_real_size_meters = chunk_size * face_arc_length
	#
	## 2. Define quantos vértices precisamos para atingir o espaçamento alvo
	## Ex: Se o chunk tem 30m e queremos 1m, precisamos de 30 vértices.
	#var dynamic_resolution = int(my_real_size_meters / target_spacing)
	#
	## 3. Travas de Segurança (Mínimo 16, Máximo 128 para não travar o PC)
	#dynamic_resolution = clamp(dynamic_resolution, 16, 128)
	#var my_size = face_arc_length / pow(2, depth)
	#
	#print("--- INFORMAÇÃO DO CHUNK ---")
	#print("Depth Atual: ", depth)
	#print("Tamanho Real: ", my_size, " metros")
	#print("Criando Zona de %.1fm com Resolução %d (Detalhe: %.2fm)" % 
		#[my_real_size_meters, dynamic_resolution, my_real_size_meters/dynamic_resolution])
	#
	## ======================================================================
	#
	## Inicializa com a resolução calculada
	#active_data = ActiveZoneData.new()
	#active_data.init_empty(dynamic_resolution, chunk_size, chunk_origin, normal)
	#
	#active_data.generate_from_planet(
		#planet_data, 
		#load("res://systems/terrain_modifier/materials/dirt.tres"), 
		#load("res://systems/terrain_modifier/materials/rock.tres")
	#)
	#
	#active_mesh = ActiveZoneMesh.new()
	#add_child(active_mesh)
	#var wire_mat = ShaderMaterial.new()
	#var wire_shader = Shader.new()
	#wire_shader.code = """
	#shader_type spatial;
	#render_mode wireframe, cull_back, unshaded;
	#uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
	#void fragment() { ALBEDO = line_color.rgb; }
	#"""
	#wire_mat.shader = wire_shader
	## Para ver a malha final (sem ser vermelha, use o material normal ou null se o shader cuidar)
	#var debug_mat = StandardMaterial3D.new()
	#debug_mat.vertex_color_use_as_albedo = true # Para ver as cores do terreno
	#
	#debug_mat.next_pass = wire_mat
	#
	#active_mesh.initialize(active_data, planet_data.radius, debug_mat)

func promote_to_active_zone():
	if is_active_zone: return
	
	# 1. CAPTURA A RESOLUÇÃO ATUAL ANTES DE DELETAR
	# Isso garante que a nova malha tenha exatamente a mesma contagem de vértices da antiga.
	var inherited_resolution : int = 64 # Valor padrão de segurança
	
	if mesh_instance != null:
		inherited_resolution = mesh_instance.resolution
		
		# Limpa a malha estática
		mesh_instance.visible = false 
		mesh_instance.queue_free()   
		mesh_instance = null
	else:
		# Se por acaso não tinha malha (raro), calculamos baseado no Depth
		# usando a mesma lógica do create_mesh
		if depth < 4: inherited_resolution = 16
		elif depth < 6: inherited_resolution = 24
		elif depth < MAX_DEPTH - 1: inherited_resolution = 48
		else: inherited_resolution = 64
	
	is_active_zone = true
	set_process(false) 
	
	print("Promovendo para Zona Ativa com Resolução Herdada: ", inherited_resolution)

	# 2. INICIA COM O VALOR HERDADO
	active_data = ActiveZoneData.new()
	active_data.init_empty(inherited_resolution, chunk_size, chunk_origin, normal)
	
	active_data.generate_from_planet(
		planet_data, 
		load("res://systems/terrain_modifier/materials/dirt.tres"), 
		load("res://systems/terrain_modifier/materials/rock.tres")
	)

	active_mesh = ActiveZoneMesh.new()
	add_child(active_mesh)
	var wire_mat = ShaderMaterial.new()
	var wire_shader = Shader.new()
	wire_shader.code = """
	shader_type spatial;
	render_mode wireframe, cull_back, unshaded;
	uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
	void fragment() { ALBEDO = line_color.rgb; }
	"""
	wire_mat.shader = wire_shader
	# Para ver a malha final (sem ser vermelha, use o material normal ou null se o shader cuidar)
	var debug_mat = StandardMaterial3D.new()
	debug_mat.vertex_color_use_as_albedo = true # Para ver as cores do terreno
	
	debug_mat.next_pass = wire_mat
	
	active_mesh.initialize(active_data, planet_data.radius, debug_mat)

	
	# ... (resto do código de material igual) ...
	#var mat = StandardMaterial3D.new()
	#mat.vertex_color_use_as_albedo = true 
	#active_mesh.initialize(active_data, planet_data.radius, mat)


func _get_center_point_on_sphere() -> Vector3:
	var axisA := Vector3(normal.y, normal.z, normal.x)
	var axisB : Vector3 = normal.cross(axisA)
	var center_perc = chunk_origin + Vector2(chunk_size, chunk_size) * 0.5
	var pointOnCube = normal + (center_perc.x - 0.5) * 2.0 * axisA + (center_perc.y - 0.5) * 2.0 * axisB
	return parent_planet.to_global(pointOnCube.normalized() * planet_data.radius)
