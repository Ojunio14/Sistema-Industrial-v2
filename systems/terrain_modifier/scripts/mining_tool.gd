extends Node
class_name PlanningTool

@export var player_camera : Camera3D
@export var gizmo : MiningGizmo # Arraste o nó do Gizmo aqui
@export var planet_center : Node3D


@export var ray_length : float = 10000.0

# O TAMANHO QUE VOCÊ QUER (Ex: 1000 = 1km, 50 = 50m)
@export var target_zone_size : float = 50.0 

enum ToolMode { FLATTEN, RAMP }
var current_mode = ToolMode.FLATTEN

# Variáveis para a Rampa
var start_height : float = 0.0
var end_height : float = 0.0 # Será a altura onde o mouse está agora
# FATOR DE INCLINAÇÃO (RAMP RATIO)
# 3.0 significa: "Ande 3 metros para descer 1 metro"
# Quanto maior esse número, mais SUAVE é a rampa.
@export var ramp_ratio : float = 3.0
@export var cursor_visual : AdaptiveCursor

# Variáveis de Controle
var is_dragging : bool = false
var start_grid : Vector2i
var current_grid : Vector2i
var active_zone_ref : ActiveZoneMesh



func _ready() -> void:
	# Busca o planeta automaticamente se não estiver assignado
	if planet_center == null:
		planet_center = get_tree().get_first_node_in_group("earth")

func _unhandled_input(event):
	if Input.is_action_just_pressed("T"):
		try_place_mine()
	
	# Troca de modo com tecla M
	if Input.is_physical_key_pressed(KEY_M):
		if current_mode == ToolMode.FLATTEN:
			current_mode = ToolMode.RAMP
			print("Modo: RAMPA (Descida Automática)")
		else:
			current_mode = ToolMode.FLATTEN
			print("Modo: PLANAR (Nivelar)")
# DIAGNÓSTICO
		if cursor_visual != null:
			print(">>> Enviando comando para o Cursor Visual...")
			cursor_visual.set_mode(current_mode, ramp_ratio)
		else:
			printerr("ERRO: A variável 'Cursor Visual' está vazia no Inspector do PlanningTool!")

# AVISA O CURSOR SOBRE A MUDANÇA
# --- NOVO: ROTAÇÃO COM R ---
	if Input.is_physical_key_pressed(KEY_R):
		if cursor_visual:
			cursor_visual.rotate_cursor()
func _process(delta):
	var hit = _get_mouse_hit()
	
	if hit and hit.collider.get_parent() is ActiveZoneMesh:
		var mesh_inst = hit.collider.get_parent()
		var data = mesh_inst.zone_data
		var p_radius = mesh_inst.planet_radius
		var p_pos = planet_center.global_position if planet_center else Vector3.ZERO
		
		# Converte mouse para Grid
		var grid_pos = data.world_to_grid(hit.position, p_pos, p_radius)
		
		# 1. CLIQUE INICIAL
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not is_dragging:
				is_dragging = true
				start_grid = grid_pos
				active_zone_ref = mesh_inst
				
				# Define altura inicial onde clicamos
				start_height = data.get_height_safe(start_grid.x, start_grid.y)
			
			current_grid = grid_pos
			
			
			# --- LÓGICA CORRIGIDA E SUAVIZADA ---
			if current_mode == ToolMode.FLATTEN:
				end_height = start_height
			else:
				# Modo Rampa
			# --- CORREÇÃO: DISTÂNCIA MANHATTAN (Eixo Dominante) ---
				# Em vez de distance_to (que pega diagonal), pegamos só o maior eixo.
				var diff = Vector2(current_grid) - Vector2(start_grid)
				var dist = max(abs(diff.x), abs(diff.y))
				
				# Nova Fórmula: Altura = Distância / Fator
				# Exemplo com Ratio 3.0:
				# Se andou 3m -> Desce 1m
				# Se andou 9m -> Desce 3m
				var drop_amount = dist / ramp_ratio
				end_height = start_height - drop_amount
			# ------------------------------------
			# ---------------------------------------

			# Visualização
			gizmo.global_transform = mesh_inst.get_parent().global_transform
			gizmo.update_gizmo(start_grid, current_grid, data, p_radius, start_height, end_height)
			
		# 2. SOLTAR O MOUSE
		elif is_dragging:
			is_dragging = false
			
			var report
			if current_mode == ToolMode.FLATTEN:
				report = data.apply_flattening_area(start_grid, current_grid, start_height)
			else:
				# Agora passamos o end_height calculado (que já inclui a descida)
				report = data.apply_ramp_area(start_grid, current_grid, start_height, end_height)
			
			if report["modified"] > 0:
				print("Operação Concluída! Terra removida: ", report["dirt"])
			
			gizmo.update_gizmo(Vector2i(-1,-1), Vector2i(-1,-1), data, 0, 0, 0)


func _get_mouse_hit():
	# (Mesma função de Raycast dos scripts anteriores)
	var space_state = get_viewport().find_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var from = player_camera.project_ray_origin(mouse_pos)
	var to = from + player_camera.project_ray_normal(mouse_pos) * 2000.0
	return space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))


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
