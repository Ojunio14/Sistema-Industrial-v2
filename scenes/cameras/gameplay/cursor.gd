extends MeshInstance3D
class_name AdaptiveCursor

@export var player_camera : Camera3D


# Cores
var color_flat = Color(0.0, 1.0, 0.0, 0.5) # Verde
var color_ramp = Color(1.0, 1.0, 0.0, 0.5) # Amarelo

# Estados
enum CursorMode { FLATTEN, RAMP }
var current_mode = CursorMode.FLATTEN
var ramp_ratio : float = 3.0 

# Controle de Posição
var last_grid_pos : Vector2i = Vector2i(-1, -1)
var current_zone_mesh : ActiveZoneMesh = null

# Direções: Norte, Leste, Sul, Oeste
var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
var current_dir_index : int = 0 

func _ready():
	# Cria o material com RAIO-X (No Depth Test)
	# Isso impede que o cursor suma quando entrar na terra
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Vê os dois lados
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Brilha
	mat.albedo_color = color_flat
	
	# O SEGREDO: Faz aparecer através do chão
	mat.no_depth_test = true 
	mat.render_priority = 101 # Desenha na frente de tudo (até do Gizmo)
	
	self.material_override = mat

# Chamado pela PlanningTool (Tecla M)
func set_mode(mode, ratio):
	current_mode = mode
	ramp_ratio = max(ratio, 1.0) # Proteção contra divisão por zero
	
	if mode == CursorMode.FLATTEN:
		material_override.albedo_color = color_flat
	else:
		material_override.albedo_color = color_ramp
	
	_force_redraw()

# Chamado pela PlanningTool (Tecla R)
func rotate_cursor():
	current_dir_index = (current_dir_index + 1) % 4
	_force_redraw()

func _force_redraw():
	last_grid_pos = Vector2i(-1, -1)

func _process(delta):
	var result = _get_mouse_hit()
	
	if result and result.collider.get_parent() is ActiveZoneMesh:
		var target_mesh = result.collider.get_parent()
		var data = target_mesh.zone_data
		var p_radius = target_mesh.planet_radius
		
		# Posição global do planeta (necessário para world_to_grid)
		var p_pos = target_mesh.get_parent().global_position
		
		var grid_pos = data.world_to_grid(result.position, p_pos, p_radius)
		
		# Atualiza geometry se algo mudou
		if grid_pos != last_grid_pos or target_mesh != current_zone_mesh:
			last_grid_pos = grid_pos
			current_zone_mesh = target_mesh
			
			var facing = directions[current_dir_index]
			_update_cursor_geometry(grid_pos, data, p_radius, facing)
		
		visible = true
		
		# Cola o cursor na posição/rotação do planeta
		self.global_transform = target_mesh.get_parent().global_transform
		
	else:
		visible = false
		last_grid_pos = Vector2i(-1, -1)

func _update_cursor_geometry(grid_pos: Vector2i, data: ActiveZoneData, radius: float, facing: Vector2i):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var x = grid_pos.x
	var y = grid_pos.y
	
	if x >= data.resolution or y >= data.resolution: return

	# Altura do terreno neste ponto (Nível Base)
	var h_base = data.get_height_safe(x, y)
	
	# Offset visual pequeno para não "flickar" com o chão original
	var offset = 0.1 
	
	# Coleta as posições dos 4 cantos na altura base
	var p00 = _get_vertex_pos(x, y, data, radius, h_base + offset)
	var p10 = _get_vertex_pos(x + 1, y, data, radius, h_base + offset)
	var p01 = _get_vertex_pos(x, y + 1, data, radius, h_base + offset)
	var p11 = _get_vertex_pos(x + 1, y + 1, data, radius, h_base + offset)
	
	if current_mode == CursorMode.FLATTEN:
		# Modo Plano: Desenha o quadrado seguindo o terreno
		_add_quad(st, p00, p10, p01, p11)
		
	elif current_mode == CursorMode.RAMP:
		# Modo Rampa: Deformar "como os quadrados do terreno"
		
		# Calcula quanto desce em 1 bloco de distância
		# Ex: Se ratio é 3.0, desce 0.33m por bloco
		var drop_per_block = 1.0 / ramp_ratio
		var h_low = h_base - drop_per_block + offset
		
		# Precisamos recalcular os vértices da "ponta baixa"
		# Dependendo da rotação, baixamos os pares de vértices corretos
		
		var r00 = p00; var r10 = p10; var r01 = p01; var r11 = p11
		
		if facing == Vector2i(1, 0): # Direita (Leste) desce
			r10 = _get_vertex_pos(x + 1, y, data, radius, h_low)
			r11 = _get_vertex_pos(x + 1, y + 1, data, radius, h_low)
			
		elif facing == Vector2i(-1, 0): # Esquerda (Oeste) desce
			r00 = _get_vertex_pos(x, y, data, radius, h_low)
			r01 = _get_vertex_pos(x, y + 1, data, radius, h_low)
			
		elif facing == Vector2i(0, 1): # Baixo (Sul) desce
			r01 = _get_vertex_pos(x, y + 1, data, radius, h_low)
			r11 = _get_vertex_pos(x + 1, y + 1, data, radius, h_low)
			
		elif facing == Vector2i(0, -1): # Cima (Norte) desce
			r00 = _get_vertex_pos(x, y, data, radius, h_low)
			r10 = _get_vertex_pos(x + 1, y, data, radius, h_low)
			
		_add_quad(st, r00, r10, r01, r11)

	st.generate_normals()
	self.mesh = st.commit()

# --- Funções Auxiliares ---

func _add_quad(st: SurfaceTool, p00, p10, p01, p11):
	# Triângulo 1
	st.set_uv(Vector2(0, 0)); st.add_vertex(p00)
	st.set_uv(Vector2(1, 0)); st.add_vertex(p10)
	st.set_uv(Vector2(0, 1)); st.add_vertex(p01)
	
	# Triângulo 2
	st.set_uv(Vector2(1, 0)); st.add_vertex(p10)
	st.set_uv(Vector2(1, 1)); st.add_vertex(p11)
	st.set_uv(Vector2(0, 1)); st.add_vertex(p01)

func _get_mouse_hit():
	var space_state = get_viewport().find_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var from = player_camera.project_ray_origin(mouse_pos)
	var to = from + player_camera.project_ray_normal(mouse_pos) * 2000.0
	return space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))

func _get_vertex_pos(x: int, y: int, data: ActiveZoneData, radius: float, h_abs: float) -> Vector3:
	var axisA := Vector3(data.normal.y, data.normal.z, data.normal.x)
	var axisB : Vector3 = data.normal.cross(axisA)
	var percent = Vector2(x, y) / float(data.resolution)
	var global_percent = data.origin_uv + (percent * data.chunk_size)
	var point_cube = data.normal + (global_percent.x - 0.5) * 2.0 * axisA + (global_percent.y - 0.5) * 2.0 * axisB
	return point_cube.normalized() * (radius + h_abs)


# Adicione isso no final do AdaptiveCursor.gd

# Função para a Tool saber qual direção está escolhida
func get_current_direction() -> Vector2i:
	return directions[current_dir_index]
