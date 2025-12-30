extends Node
class_name MiningTool

@export var player_camera : Camera3D
@export var ray_length : float = 10000.0

# O TAMANHO QUE VOCÊ QUER (Ex: 1000 = 1km, 50 = 50m)
@export var target_zone_size : float = 50.0 

@export var planet_center : Node3D # Arraste o nó do Planeta aqui
@export var brush_radius : float = 3.0 # Tamanho do buraco (em vértices)
@export var dig_speed : float = -0.5   # Velocidade (Negativo = Cavar)



func _unhandled_input(event):
	if Input.is_action_just_pressed("T"):
		try_place_mine()


func _process(delta):
	# Botão Esquerdo: Cavar
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_perform_raycast(dig_speed * delta * 10.0) # Multiplicador de velocidade
		
	# Botão Direito: Subir Terra (Opcional)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_perform_raycast(-dig_speed * delta * 10.0)

func _perform_raycast(strength: float):
	var space_state = get_viewport().find_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var from = player_camera.project_ray_origin(mouse_pos)
	var to = from + player_camera.project_ray_normal(mouse_pos) * 1000.0
	
	var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	
	if result:
		var collider = result["collider"]
		
		# Verifica se clicamos numa Zona Ativa (que deve ser filha do ActiveZoneMesh ou ser o próprio)
		# Nota: Como o ActiveZoneMesh cria o colisor via create_trimesh_collision, o collider é um StaticBody filho.
		var mesh_instance = collider.get_parent()
		
		if mesh_instance is ActiveZoneMesh:
			var hit_pos = result["position"]
			var data = mesh_instance.zone_data
			
			# 1. Converter Hit Pos -> Grid X,Y
			# Precisamos passar o centro e raio do planeta
			# Se o planet_center for null, assumimos (0,0,0)
			var p_center = planet_center.global_position if planet_center else Vector3.ZERO
			var p_radius = mesh_instance.planet_radius
			
			# Precisamos converter o hit_pos GLOBAL para LOCAL do planeta se o planeta moveu
			# Mas por enquanto assumimos planeta estático na origem ou hit_pos correto.
			# Importante: A função world_to_grid espera posição relativa ao centro se usarmos a lógica de direção.
			# Vamos passar hit_pos - p_center para ser a posição local
			var local_hit = hit_pos - p_center
			
			# Chama a função de conversão que criamos no Passo 1
			# Nota: Precisamos ajustar aquela função para aceitar local_pos direto ou calcular direção.
			# Vamos assumir que passamos o hit_pos global e ele calcula a direção.
			var grid_coords = data.world_to_grid(hit_pos, p_center, p_radius)
			
			# 2. Aplicar o Pincel
			# Se grid_coords for válido (dentro do array)
			if grid_coords.x >= 0 and grid_coords.x < data.vertex_resolution:
				data.apply_brush(grid_coords.x, grid_coords.y, brush_radius, strength)


func try_place_mine():
	var space_state = get_viewport().find_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var from = player_camera.project_ray_origin(mouse_pos)
	var to = from + player_camera.project_ray_normal(mouse_pos) * ray_length
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result["collider"]
		
		# 1. Encontra qual nó da Quadtree foi clicado
		var hit_node = _find_quadtree_node(collider)
		
		if hit_node:
			# --- A LÓGICA SIMPLIFICADA ---
			
			# Verificação de Segurança:
			# Só podemos promover nós que são "Folhas" (não têm filhos).
			# Se is_split for true, significa que clicamos num pai invisível (erro de colisão),
			# mas com a sua lógica atual, isso não deve acontecer.
			
			if not hit_node.is_split:
				print("Criando Zona de Mineração no Chunk: ", hit_node.name)
				
				# Simplesmente promovemos o nó que clicamos.
				# A resolução alta (64x64) será criada DENTRO dele pelo promote_to_active_zone.
				hit_node.promote_to_active_zone()
			else:
				print("Aviso: Tentativa de clicar em um nó que já está dividido.")

func _find_quadtree_node(obj: Node) -> QuadtreeNode:
	var current = obj
	while current != null:
		if current is QuadtreeNode:
			return current
		current = current.get_parent()
	return null

func _find_face_root(node: QuadtreeNode) -> QuadtreeNode:
	var current = node
	while current.get_parent() is QuadtreeNode:
		current = current.get_parent()
	return current
