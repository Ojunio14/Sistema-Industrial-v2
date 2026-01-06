extends MeshInstance3D
class_name AdaptiveCursor

@export var player_camera : Camera3D

# --- Cores e Materiais ---
var color_flat = Color(0.0, 1.0, 0.0, 0.5) # Verde semitransparente
var color_ramp = Color(1.0, 1.0, 0.0, 0.5) # Amarelo semitransparente

# --- Estados e Modos ---
enum CursorMode { FLATTEN, RAMP }
var current_mode = CursorMode.FLATTEN
var ramp_ratio : float = 3.0 

# --- Controle de Posição ---
var last_grid_pos : Vector2i = Vector2i(-1, -1)
var current_zone_mesh : ActiveZoneMesh = null

# --- Direções para Rotação (Tecla R) ---
# Ordem: Norte, Leste, Sul, Oeste (no espaço UV local)
var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
var current_dir_index : int = 0 

func _ready():
	# Configura o material visual
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Vê os dois lados do quadrado
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Brilha no escuro
	mat.albedo_color = color_flat
	
	# IMPORTANTE: Faz o cursor aparecer através do terreno (Raio-X)
	mat.no_depth_test = true 
	mat.render_priority = 101 # Desenha na frente de tudo
	
	self.material_override = mat

# --- Funções chamadas pelo PlanningTool ---

func set_mode(mode, ratio):
	current_mode = mode
	ramp_ratio = max(ratio, 1.0) # Evita divisão por zero
	
	if mode == CursorMode.FLATTEN:
		material_override.albedo_color = color_flat
	else:
		material_override.albedo_color = color_ramp
	
	_force_redraw()

func rotate_cursor():
	current_dir_index = (current_dir_index + 1) % 4
	_force_redraw()

func get_current_direction() -> Vector2i:
	return directions[current_dir_index]

func _force_redraw():
	last_grid_pos = Vector2i(-1, -1) # Força atualização no próximo frame

# --- Loop Principal ---

func _process(delta):
	# 1. Faz o Raycast com proteção contra espelhamento
	var result = _get_mouse_hit()
	
	# 2. Verifica se bateu em um Chunk Ativo Válido
	if result and result.has("collider") and result.collider.get_parent() is ActiveZoneMesh:
		var target_mesh = result.collider.get_parent()
		var data = target_mesh.zone_data
		var p_radius = target_mesh.planet_radius
		
		# Pega a posição do centro do planeta (importante para converter coords)
		var p_pos = target_mesh.get_parent().global_position
		
		# Converte posição do mouse (Mundo) para Grid (x, y)
		var grid_pos = data.world_to_grid(result.position, p_pos, p_radius)
		
		# Só recalcula a geometria se mudou de quadrado ou de chunk
		if grid_pos != last_grid_pos or target_mesh != current_zone_mesh:
			last_grid_pos = grid_pos
			current_zone_mesh = target_mesh
			
			var facing = directions[current_dir_index]
			_update_cursor_geometry(grid_pos, data, p_radius, facing)
		
		# MOSTRA O CURSOR e posiciona
		visible = true
		self.global_transform = target_mesh.get_parent().global_transform
		
	else:
		# Se olhou pro céu ou pro infinito -> ESCONDE
		visible = false
		last_grid_pos = Vector2i(-1, -1)
		current_zone_mesh = null

# --- Construção da Malha (Quadrado ou Cunha) ---

func _update_cursor_geometry(grid_pos: Vector2i, data: ActiveZoneData, radius: float, facing: Vector2i):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var x = grid_pos.x
	var y = grid_pos.y
	
	# Proteção para não desenhar fora do array
	if x >= data.resolution or y >= data.resolution: return

	# Altura atual do terreno
	var h_base = data.get_height_safe(x, y)
	var offset = 0.1 # Leve flutuação para não "piscar" com o chão
	
	# Calcula os 4 cantos na altura normal
	var p00 = _get_vertex_pos(x, y, data, radius, h_base + offset)
	var p10 = _get_vertex_pos(x + 1, y, data, radius, h_base + offset)
	var p01 = _get_vertex_pos(x, y + 1, data, radius, h_base + offset)
	var p11 = _get_vertex_pos(x + 1, y + 1, data, radius, h_base + offset)
	
	if current_mode == CursorMode.FLATTEN:
		# Desenha quadrado plano
		_add_quad(st, p00, p10, p01, p11)
		
	elif current_mode == CursorMode.RAMP:
		# Desenha rampa inclinada
		# Calcula quanto desce em 1 bloco
		var drop_per_block = 1.0 / ramp_ratio
		var h_low = h_base - drop_per_block + offset
		
		# Prepara variáveis para deformar
		var r00 = p00; var r10 = p10; var r01 = p01; var r11 = p11
		
		# Abaixa os vértices corretos dependendo da direção da rotação
		if facing == Vector2i(1, 0): # Direita desce
			r10 = _get_vertex_pos(x + 1, y, data, radius, h_low)
			r11 = _get_vertex_pos(x + 1, y + 1, data, radius, h_low)
		elif facing == Vector2i(-1, 0): # Esquerda desce
			r00 = _get_vertex_pos(x, y, data, radius, h_low)
			r01 = _get_vertex_pos(x, y + 1, data, radius, h_low)
		elif facing == Vector2i(0, 1): # Baixo desce
			r01 = _get_vertex_pos(x, y + 1, data, radius, h_low)
			r11 = _get_vertex_pos(x + 1, y + 1, data, radius, h_low)
		elif facing == Vector2i(0, -1): # Cima desce
			r00 = _get_vertex_pos(x, y, data, radius, h_low)
			r10 = _get_vertex_pos(x + 1, y, data, radius, h_low)
			
		_add_quad(st, r00, r10, r01, r11)

	st.generate_normals()
	self.mesh = st.commit()

# --- Raycast Protegido ---

func _get_mouse_hit():
	if player_camera == null: return {}
	
	var space_state = get_viewport().find_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	
	var from = player_camera.project_ray_origin(mouse_pos)
	var dir = player_camera.project_ray_normal(mouse_pos)
	var to = from + dir * 2000.0 # Raio longo
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		# --- CORREÇÃO DE FANTASMA ---
		# Se a normal da superfície aponta na mesma direção do raio (costas),
		# significa que estamos vendo o lado de dentro do planeta. Ignora.
		if dir.dot(result["normal"]) > 0.0:
			return {} # Retorna "nada"
			
	return result

# --- Helpers Matemáticos ---

func _add_quad(st: SurfaceTool, p00, p10, p01, p11):
	# Triângulo 1
	st.set_uv(Vector2(0, 0)); st.add_vertex(p00)
	st.set_uv(Vector2(1, 0)); st.add_vertex(p10)
	st.set_uv(Vector2(0, 1)); st.add_vertex(p01)
	
	# Triângulo 2
	st.set_uv(Vector2(1, 0)); st.add_vertex(p10)
	st.set_uv(Vector2(1, 1)); st.add_vertex(p11)
	st.set_uv(Vector2(0, 1)); st.add_vertex(p01)

func _get_vertex_pos(x: int, y: int, data: ActiveZoneData, radius: float, h_abs: float) -> Vector3:
	# Mesma matemática do ActiveZoneData para garantir alinhamento perfeito
	var axisA := Vector3(data.normal.y, data.normal.z, data.normal.x)
	var axisB : Vector3 = data.normal.cross(axisA)
	
	var percent = Vector2(x, y) / float(data.resolution)
	var global_percent = data.origin_uv + (percent * data.chunk_size)
	
	var point_cube = data.normal + (global_percent.x - 0.5) * 2.0 * axisA + (global_percent.y - 0.5) * 2.0 * axisB
	
	return point_cube.normalized() * (radius + h_abs)
