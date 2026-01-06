#@tool
extends Node3D

# Arraste o Resource PlanetData aqui
@export var planet_data : PlanetData 
# Arraste o Player ou Camera3D aqui
@export var viewer : Camera3D 


# ... (suas variáveis exportadas viewer, planet_data, etc) ...

# --- FILA DE COLISÃO ---
var _collision_queue : Array[PlanetMeshFace] = []

#func _physics_process(delta: float) -> void:
	## Se tiver alguém na fila, atende O PRIMEIRO e remove da fila
	#if not _collision_queue.is_empty():
		## Pega o primeiro da fila
		#var chunk_to_process = _collision_queue.pop_front()
		#
		## Verifica se o chunk ainda existe (o player pode ter se afastado e deletado ele)
		#if is_instance_valid(chunk_to_process):
			#chunk_to_process.create_collision_now()
#
## Função para os filhos pedirem uma senha na fila
#func request_collision(mesh_face : PlanetMeshFace):
	#_collision_queue.append(mesh_face)
# FILA DE VISUALIZAÇÃO (Para não travar o FPS ao carregar chunks)
var _mesh_queue : Array = [] # Vai guardar dicionários com os dados
const MAX_MESHES_PER_FRAME = 2 # Ajuste esse número! (1 é super estável, 5 carrega rápido mas pode travar)

func _process(delta):
	# Processa a fila VISUAL
	var processed_count = 0
	while not _mesh_queue.is_empty() and processed_count < MAX_MESHES_PER_FRAME:
		var job = _mesh_queue.pop_front()
		
		# Verifica se o QuadtreeNode ainda existe e precisa da malha
		if is_instance_valid(job.node) and job.node.is_generating_mesh:
			job.node.finalize_mesh_creation(job.arrays, job.resolution, job.collision)
			processed_count += 1

# Função chamada pelos QuadtreeNodes para entrar na fila
func schedule_mesh_update(node, arrays, resolution, collision):
	_mesh_queue.append({
		"node": node,
		"arrays": arrays,
		"resolution": resolution,
		"collision": collision
	})

func _ready():
	# --- CORREÇÃO OBRIGATÓRIA ---
	# Prepara os dados do mapa de altura ANTES de criar qualquer Quadtree.
	# Isso roda na Main Thread, é seguro e garante que não teremos buracos.
	if planet_data and planet_data.height_map:
		planet_data.height_map.prepare_data()
	# ----------------------------

	var rig_cam = get_tree().get_first_node_in_group("Camera_Rts").get_node("GimbalElevation/Camera")
	viewer = rig_cam
	generate_planet()

func generate_planet():
	# Limpa filhos antigos para não duplicar
	for child in get_children():
		child.queue_free()
	
	if not planet_data or not viewer:
		return

	# As 6 direções da Cube Sphere
	var directions = [
		Vector3.UP, Vector3.DOWN, 
		Vector3.LEFT, Vector3.RIGHT, 
		Vector3.FORWARD, Vector3.BACK
	]
	
	for dir in directions:
		var root_face = QuadtreeNode.new()
		add_child(root_face)
		
		# INICIALIZAÇÃO DA RAIZ:
		# Origin: (0, 0) -> Começa no canto
		# Size: 1.0 -> Cobre a face inteira (100%)
		# Depth: 0 -> Nível inicial
		root_face.initialize(planet_data, dir, Vector2(0,0), 1.0, 0, self, viewer)
