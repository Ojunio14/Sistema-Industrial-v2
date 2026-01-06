extends Node
class_name PlanningTool

@export var player_camera : Camera3D
@export var gizmo : MiningGizmo
@export var planet_center : Node3D
@export var cursor_visual : AdaptiveCursor 
@export var ramp_ratio : float = 3.0

enum ToolMode { FLATTEN, RAMP }
var current_mode = ToolMode.FLATTEN

var is_dragging : bool = false

# --- MUDANÇA 1: Armazenar Posições GLOBAIS ---
# Em vez de guardar o grid (que falha na borda), guardamos o ponto 3D exato.
var start_pos_global : Vector3
var current_pos_global : Vector3

# Ainda precisamos do grid para o Gizmo desenhar, mas a lógica usa o Global
var start_grid_visual : Vector2i
var current_grid_visual : Vector2i

# A Referência Visual (para o Gizmo saber como desenhar as linhas)
var anchor_zone_ref : ActiveZoneMesh 

var start_height : float = 0.0
var end_height : float = 0.0 

const RAY_LENGTH = 10000.0 # Aumentei para garantir

func _ready() -> void:
	if planet_center == null:
		planet_center = get_tree().get_first_node_in_group("earth")

func _unhandled_input(event):
	if Input.is_action_just_pressed("T"):
		try_place_mine()
		
	if Input.is_physical_key_pressed(KEY_M):
		if current_mode == ToolMode.FLATTEN:
			current_mode = ToolMode.RAMP
			print(">>> MODO: RAMPA")
		else:
			current_mode = ToolMode.FLATTEN
			print(">>> MODO: PLANO")
		if cursor_visual: cursor_visual.set_mode(current_mode, ramp_ratio)
			
	if Input.is_physical_key_pressed(KEY_R):
		if cursor_visual: cursor_visual.rotate_cursor()
func _process(delta):
	var hit = _get_mouse_hit()
	
	# Só processamos se o mouse bateu em algo válido
	if hit and hit.collider.get_parent() is ActiveZoneMesh:
		var hit_mesh = hit.collider.get_parent()
		var p_radius = hit_mesh.planet_radius
		var p_pos = planet_center.global_position if planet_center else Vector3.ZERO
		
		# --- POSIÇÃO ATUAL REAL (Global) ---
		var raw_global_pos = hit.position
		
		# Define quem é a referência para lógica interna
		var current_ref_mesh = hit_mesh
		if is_dragging and anchor_zone_ref != null:
			current_ref_mesh = anchor_zone_ref
			
		var data = current_ref_mesh.zone_data
		
		# Converte para Grid APENAS para cálculos lógicos locais se necessário
		var raw_grid_pos = data.world_to_grid(hit.position, p_pos, p_radius)
		var grid_pos = raw_grid_pos
		
		# --- TRAVAMENTO DE EIXO (Rampa com 'R') ---
		if is_dragging and current_mode == ToolMode.RAMP and cursor_visual:
			var fixed_dir = cursor_visual.get_current_direction()
			var diff = raw_grid_pos - start_grid_visual
			
			if fixed_dir.x != 0: diff.y = 0 
			else: diff.x = 0
			
			grid_pos = start_grid_visual + diff
			# (Nota: O Gizmo Global usa start_pos_global, mas a lógica de altura usa o grid travado)
		
		# 1. CLIQUE INICIAL (Começar Arraste)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not is_dragging:
				is_dragging = true
				
				# Salva a referência visual
				anchor_zone_ref = hit_mesh 
				data = anchor_zone_ref.zone_data 
				
				# --- O SEGREDO: Salva o Ponto 3D exato do início ---
				start_pos_global = hit.position
				start_grid_visual = raw_grid_pos 
				
				start_height = data.get_height_safe(start_grid_visual.x, start_grid_visual.y)
			
			# Atualiza o fim (Global e Visual)
			current_pos_global = hit.position
			current_grid_visual = grid_pos
			
			# Lógica de Altura
			if current_mode == ToolMode.FLATTEN:
				end_height = start_height
			else:
				var diff = Vector2(current_grid_visual) - Vector2(start_grid_visual)
				var dist = max(abs(diff.x), abs(diff.y))
				var drop_amount = dist / ramp_ratio
				end_height = start_height - drop_amount

			# --- ATUALIZAÇÃO DO GIZMO (GLOBAL) ---
			# Resetamos a posição do Gizmo para o centro do planeta.
			# Assim, ele pode desenhar linhas em coordenadas locais de QUALQUER chunk.
			gizmo.global_transform.origin = p_pos
			gizmo.global_transform.basis = Basis() # Reseta rotação para alinhar com o mundo
			
			var is_ramp_mode = (current_mode == ToolMode.RAMP)
			
			gizmo.update_gizmo_global(
				start_pos_global, 
				current_pos_global, 
				p_pos, 
				start_height, 
				end_height, 
				ramp_ratio, 
				is_ramp_mode
			)
			
		# 2. SOLTAR O MOUSE (Aplicar a Escavação)
		elif is_dragging:
			is_dragging = false
			
			var total_dirt = 0.0
			var changes = false
			
			var all_zones = get_tree().get_nodes_in_group("active_zones")
			
			for zone in all_zones:
				var z_data = zone.zone_data
				var z_radius = zone.planet_radius
				
				# Perguntamos para CADA chunk: "Onde esses pontos globais caem no SEU mapa?"
				var local_start = z_data.world_to_grid(start_pos_global, p_pos, z_radius)
				var local_end = z_data.world_to_grid(current_pos_global, p_pos, z_radius)
				
				var report
				if current_mode == ToolMode.FLATTEN:
					report = z_data.apply_flattening_area(local_start, local_end, start_height)
				else:
					report = z_data.apply_ramp_area(local_start, local_end, start_height, end_height)
				
				if report["modified"] > 0:
					total_dirt += report["dirt"]
					changes = true
			
			if changes:
				print("Terraplanagem Concluída! Terra: ", total_dirt)
			
			# LIMPEZA DO GIZMO
			gizmo.update_gizmo_global(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 0, 0, 0, false)
			anchor_zone_ref = null

# --- CRIAÇÃO DE MINA (Com Correção de Espelhamento) ---
func try_place_mine():
	var space_state = get_viewport().find_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	
	var from = player_camera.project_ray_origin(mouse_pos)
	var dir = player_camera.project_ray_normal(mouse_pos)
	var to = from + dir * RAY_LENGTH
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		# --- CORREÇÃO DE ESPELHAMENTO ---
		# Se a normal da superfície aponta na mesma direção do raio (costas), ignora.
		if dir.dot(result["normal"]) > 0.0:
			return # Bateu na parede interna do outro lado do planeta
		
		var hit_node = _find_quadtree_node(result["collider"])
		if hit_node and not hit_node.is_split:
			print("Criando Zona: ", hit_node.name)
			hit_node.promote_to_active_zone()

# --- HELPER MOUSE (Com Correção de Espelhamento) ---
# No AdaptiveCursor.gd

func _get_mouse_hit():
	var space_state = get_viewport().find_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Cria o raio
	var from = player_camera.project_ray_origin(mouse_pos)
	var dir = player_camera.project_ray_normal(mouse_pos)
	var to = from + dir * 2000.0 # Distância máxima
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		# --- A CORREÇÃO DO FANTASMA ---
		# Se a normal da superfície aponta na mesma direção do raio da câmera,
		# significa que estamos vendo as costas da parede (lado de dentro do outro lado).
		# Ignoramos para o cursor não aparecer lá.
		if dir.dot(result["normal"]) > 0.0:
			return {} # Retorna vazio (não bateu em nada válido)
	
	return result

func _find_quadtree_node(obj: Node) -> QuadtreeNode:
	var current = obj
	while current != null:
		if current is QuadtreeNode: return current
		current = current.get_parent()
	return null
