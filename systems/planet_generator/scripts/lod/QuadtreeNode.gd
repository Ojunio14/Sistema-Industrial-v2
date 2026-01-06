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

# --- CONTROLE DE TRANSIÇÃO (Novo!) ---
var children_ready_count : int = 0 # Conta quantos filhos já geraram a malha

const MAX_DEPTH = 8
const SPLIT_MULTIPLIER = 4.0

# Flag para evitar pedidos duplicados
var is_generating_mesh : bool = false


# No topo do QuadtreeNode
var frame_counter : int = 0
var check_interval : int = 10 # Checa LOD a cada 10 frames

func initialize(_planet_data, _normal, _origin, _size, _depth, _parent_planet, _camera):
	planet_data = _planet_data
	normal = _normal
	chunk_origin = _origin
	chunk_size = _size
	depth = _depth
	parent_planet = _parent_planet
	player_camera = _camera
	
	update_lod()


# Adicione uma variável para 'atrasar' a checagem
# Adicione uma variável para aleatoriedade
var _update_timer : int = 0

func _ready():
	# Cada chunk começa num frame diferente (0 a 9)
	# Isso evita que todos calculem LOD no mesmo milissegundo
	_update_timer = randi() % 10


func _process(delta):
	# Otimização: Só roda lógica pesada 1 vez a cada X frames
	frame_counter += 1
	if frame_counter < check_interval:
		return
	frame_counter = 0

	# ... Resto da sua lógica _process original ...
	if not is_active_zone:
		# SÓ RODA O LOD A CADA 10 FRAMES!
		# Como o planeta é gigante, você não precisa precisão de milissegundos na distância.
		_update_timer += 1
		if _update_timer >= 10:
			_update_timer = 0
			update_lod()

func update_lod():
	if not is_instance_valid(player_camera): return
	if is_generating_mesh: return # Se está carregando, não mexe

	var center_point = _get_center_point_on_sphere()
	var dist = player_camera.global_position.distance_to(center_point)
	var split_distance = (chunk_size * planet_data.radius) * SPLIT_MULTIPLIER
	
	# DIVISÃO
	if dist < split_distance and depth < MAX_DEPTH:
		if not is_split:
			split()
	
	# JUNÇÃO
	else:
		if is_split:
			# Se a gente acabou de dar split e os filhos nem carregaram ainda,
			# não dê merge imediatamente para evitar "batedeira"
			if children_ready_count < 4 and not children.is_empty():
				return 
				
			if _has_active_zone_child(): return
			merge()
			
		elif mesh_instance == null and not is_active_zone:
			request_mesh_generation()


# Função chamada (geralmente por RayCast) para converter este chunk em área editável
func promote_to_active_zone():
	if is_active_zone: return
	
	# 1. Marca como Zona Ativa IMEDIATAMENTE.
	# Isso é crucial: impede que o update_lod tente dividir/juntar esse nó
	# e impede que a thread sobrescreva a malha se estiver gerando.
	is_active_zone = true
	
	# Desativa o processamento de LOD deste nó
	set_process(false)
	
	# 2. Captura a resolução atual para manter a consistência visual
	var inherited_resolution : int = 32 # Valor padrão seguro (igual ao seu MAX_DEPTH)
	
	if mesh_instance != null:
		inherited_resolution = mesh_instance.resolution
		
		# Esconde e deleta a malha estática antiga
		mesh_instance.visible = false
		mesh_instance.queue_free()
		mesh_instance = null
	else:
		# Se por acaso clicou num chunk que ainda não carregou (raro), calculamos o alvo
		if depth < 4: inherited_resolution = 12
		elif depth < 6: inherited_resolution = 16
		elif depth < MAX_DEPTH - 1: inherited_resolution = 24
		else: inherited_resolution = 32

	print("Promovendo Chunk para Zona Ativa (Resolução: %d)" % inherited_resolution)

	# 3. Inicializa os dados da Zona Ativa (Sua lógica de mineração)
	# Certifique-se que você tem a classe ActiveZoneData no projeto
	active_data = ActiveZoneData.new()
	active_data.init_empty(inherited_resolution, chunk_size, chunk_origin, normal)
	
	# Gera o terreno editável usando os dados do planeta
	# Nota: Isso vai usar o 'point_on_planet' do PlanetData. 
	# Como otimizamos o HeightMap para usar Arrays, isso será rápido!
	active_data.generate_from_planet(
		planet_data, 
		load("res://systems/terrain_modifier/materials/dirt.tres"), 
		load("res://systems/terrain_modifier/materials/rock.tres")
	)

	# 4. Cria a Malha Editável (ActiveZoneMesh)
	active_mesh = ActiveZoneMesh.new()
	add_child(active_mesh)
	
	# Configurações de Material e Shader (fio branco de debug ou material final)
	var wire_mat = ShaderMaterial.new()
	var wire_shader = Shader.new()
	wire_shader.code = """
	shader_type spatial;
	render_mode wireframe, cull_back, unshaded;
	uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
	void fragment() { ALBEDO = line_color.rgb; }
	"""
	wire_mat.shader = wire_shader
	
	var debug_mat = StandardMaterial3D.new()
	debug_mat.vertex_color_use_as_albedo = true 
	# debug_mat.next_pass = wire_mat # Descomente se quiser ver o wireframe por cima
	
	# Inicializa a malha final
	active_mesh.initialize(active_data, planet_data.radius, debug_mat)




# --- SISTEMA DE THREAD COM WEAKREF (Anti-Crash) ---
func request_mesh_generation():
	if is_generating_mesh or mesh_instance != null: return
	is_generating_mesh = true
	
	var target_resolution = 16 
	var needs_collision = false
	var noise_multiplier = 1.0 # Padrão: Montanha completa
	
	# --- CONFIGURAÇÃO LOD AGRESSIVA (Para Câmera RTS) ---
	
	# DEPTH 0, 1, 2, 3 (Horizonte Distante)
	# Resolução 4 (Quadrado com leve curva): Quase zero custo de GPU.
	# Noise 0.0: Desliga cálculo de montanha (planeta liso longe). Economiza CPU.
	if depth <= 3: 
		target_resolution = 4 
		noise_multiplier = 0.0 
		
	# DEPTH 4, 5 (Médio-Longe)
	# Resolução 8: Um pouco mais definido, mas ainda muito leve.
	# Noise 0.5: Montanhas mais baixas/suaves para esconder o "pop-in".
	elif depth <= 5: 
		target_resolution = 8 
		noise_multiplier = 0.5
		
	# DEPTH 6 (Começando a aparecer detalhes)
	elif depth <= 6: 
		target_resolution = 16 
		
	# DEPTH 7 (Vizinho do Player)
	elif depth < MAX_DEPTH:
		target_resolution = 24 
		
	# DEPTH 8 (Onde o Player pisa)
	else: 
		# Resolução 32: O equilíbrio perfeito para física rápida no Jolt.
		# Se você usar 48 ou 64 aqui, a física vai travar o _process.
		target_resolution = 32 
		needs_collision = true
	
	# --- PREPARAÇÃO DOS DADOS ---
	
	# Duplicação segura do Noise (para evitar bugs de thread)
	var noise_safe = null
	if planet_data.mountain_noise:
		noise_safe = planet_data.mountain_noise.duplicate()
	
	var job_data = {
		"origin": chunk_origin,
		"size": chunk_size,
		"res": target_resolution,
		"norm": normal,
		"col": needs_collision, # Flag de colisão
		
		# Dados do PlanetData
		"radius": planet_data.radius,
		"min_h": planet_data.min_height,
		"amp": planet_data.amplitude,
		"sea": planet_data.sea_level,
		"mask_thr": planet_data.mask_threshold,
		"m_str": planet_data.mountain_strength,
		"t_steps": planet_data.terrace_steps,
		"h_map": planet_data.height_map, 
		"m_noise": noise_safe,
		
		# O NOVO PARÂMETRO
		"noise_mult": noise_multiplier 
	}
	
	var self_ref = weakref(self)
	WorkerThreadPool.add_task(
		_static_thread_job.bind(self_ref, job_data),
		true,
		"ChunkGen"
	)
# Atualize a chamada estática para desempacotar o dicionário novo
static func _static_thread_job(self_ref: WeakRef, data: Dictionary):
	# AQUI CHAMAMOS A FUNÇÃO QUE ACABAMOS DE CORRIGIR
	# Precisamos passar o data["noise_mult"] no final
	var generated_arrays = ChunkJob.generate_mesh_data(
		data["origin"], data["size"], data["res"], data["norm"],
		# Dados do Planeta
		data["radius"], data["min_h"], data["amp"], data["sea"],
		data["mask_thr"], data["m_str"], data["t_steps"],
		data["h_map"], data["m_noise"],
		# O NOVO ARGUMENTO:
		data["noise_mult"]
	)
	
	var node = self_ref.get_ref()
	if node:
		node.call_deferred("_on_mesh_generation_complete", generated_arrays, data["res"], data["col"])

# Essa é a função que a Thread chama quando termina
func _on_mesh_generation_complete(arrays: Array, resolution: int, collision: bool):
	# Validações de segurança básicas
	if not is_inside_tree(): return
	if is_active_zone: return
	if mesh_instance != null: return # Se já tem malha, ignora
	
	# --- MUDANÇA AQUI: NÃO CRIA A MALHA AGORA! ---
	# Em vez de criar instântaneo (o que trava o jogo), entra na fila do Planeta.
	if parent_planet and parent_planet.has_method("schedule_mesh_update"):
		parent_planet.schedule_mesh_update(self, arrays, resolution, collision)
	else:
		# Fallback se não tiver planeta pai (para testes isolados)
		finalize_mesh_creation(arrays, resolution, collision)

# --- NOVA FUNÇÃO: O Planeta chama isso quando for sua vez ---
func finalize_mesh_creation(arrays: Array, resolution: int, collision: bool):
	is_generating_mesh = false # Libera a flag agora
	
	# Verifica de novo se não foi deletado enquanto estava na fila
	if not is_inside_tree() or is_split or mesh_instance != null:
		return

	# CRIAÇÃO REAL DA MALHA (Isso é o que gasta tempo)
	mesh_instance = PlanetMeshFace.new()
	add_child(mesh_instance)
	
	mesh_instance.normal = normal
	mesh_instance.chunk_origin = chunk_origin
	mesh_instance.chunk_size = chunk_size
	
	# Aplica os dados (Visual e Física)
	mesh_instance.apply_mesh_data(arrays, resolution, collision)
	
	# Avisa o pai que nasceu (para esconder o buraco/LOD antigo)
	if depth > 0:
		var p = get_parent()
		if p and p.has_method("on_child_mesh_ready"):
			p.on_child_mesh_ready()

# --- SPLIT INTELIGENTE (Sem Buracos) ---
# No topo, adicione:
var _safety_timer : Timer

func split():
	if is_split: return
	is_split = true
	
	# NÃO DELETA O PAI AGORA. Vamos esperar os filhos.
	# MAS... criamos um "Relógio Bomba".
	# Se os filhos demorarem mais de 0.5 segundos, o pai se explode.
	if mesh_instance:
		_safety_timer = Timer.new()
		add_child(_safety_timer)
		_safety_timer.wait_time = 0.5 # Tempo máximo de tolerância
		_safety_timer.one_shot = true
		_safety_timer.timeout.connect(func(): 
			if mesh_instance: 
				mesh_instance.queue_free()
				mesh_instance = null
		)
		_safety_timer.start()
	
	children_ready_count = 0
	
	var half = chunk_size / 2.0
	create_child(chunk_origin, half)
	create_child(chunk_origin + Vector2(half, 0), half)
	create_child(chunk_origin + Vector2(0, half), half)
	create_child(chunk_origin + Vector2(half, half), half)

func on_child_mesh_ready():
	children_ready_count += 1
	
	# Se os 4 filhos chegaram, matamos o pai E o timer
	if children_ready_count >= 4:
		if is_instance_valid(_safety_timer):
			_safety_timer.stop()
			_safety_timer.queue_free()
			
		if mesh_instance:
			mesh_instance.visible = false
			mesh_instance.queue_free()
			mesh_instance = null

# --- MERGE ---

func merge():
	is_split = false
	children_ready_count = 0
	
	# No Merge, deletamos os filhos e pedimos nossa malha de volta.
	# (Visualmente pode dar um pequeno pop aqui, mas é menos pior que o buraco. 
	#  Para corrigir isso precisaria carregar o pai em background antes de deletar filhos, 
	#  o que é mais complexo. Vamos focar no Split primeiro).
	for child in children:
		child.queue_free()
	children.clear()
	
	request_mesh_generation()

# --- RESTO DAS FUNÇÕES AUXILIARES ---
func create_child(offset : Vector2, size : float):
	var child = QuadtreeNode.new()
	add_child(child)
	children.append(child)
	child.initialize(planet_data, normal, offset, size, depth + 1, parent_planet, player_camera)

func _has_active_zone_child() -> bool:
	for child in children:
		if child.is_active_zone: return true
		if child._has_active_zone_child(): return true
	return false

func _get_center_point_on_sphere() -> Vector3:
	var axisA := Vector3(normal.y, normal.z, normal.x)
	var axisB : Vector3 = normal.cross(axisA)
	var center_perc = chunk_origin + Vector2(chunk_size, chunk_size) * 0.5
	var pointOnCube = normal + (center_perc.x - 0.5) * 2.0 * axisA + (center_perc.y - 0.5) * 2.0 * axisB
	return parent_planet.to_global(pointOnCube.normalized() * planet_data.radius)

# Adicione suas funções drill_down e promote_to_active aqui...
# (Certifique-se que o drill_down chame split() novo se necessário)
func drill_down_to_size(target_pos: Vector3, target_size: float) -> QuadtreeNode:
	var real_size = chunk_size * planet_data.radius
	if real_size <= target_size or depth >= MAX_DEPTH:
		return self
	if not is_split:
		split() 
	var closest = null
	var min_dist = INF
	for child in children:
		var d = child._get_center_point_on_sphere().distance_to(target_pos)
		if d < min_dist:
			min_dist = d
			closest = child
	if closest:
		return closest.drill_down_to_size(target_pos, target_size)
	return self
