extends MeshInstance3D
class_name MiningGizmo

@export var line_color : Color = Color(1.0, 0.6, 0.0, 1.0)
const MAX_DRAW_CELLS = 800 
const MAX_LABELS = 100 # Limite de labels para não travar

# Template do Label (Crie um nó Label3D filho deste Gizmo na cena)
@onready var label_template : Label3D = $Label3D 
var label_pool : Array[Label3D] = []

func _ready():
	if mesh == null: mesh = ImmediateMesh.new()
	
	if material_override == null:
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = line_color
		mat.vertex_color_use_as_albedo = true 
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true 
		mat.render_priority = 100 
		material_override = mat
	
	# Prepara o pool de labels
	if label_template:
		label_template.visible = false
		label_pool.append(label_template)

# Função Global com Labels
func update_gizmo_global(start_pos: Vector3, end_pos: Vector3, planet_center: Vector3, start_height: float, end_height: float, ramp_ratio: float, mode_is_ramp: bool):
	if mesh == null: mesh = ImmediateMesh.new()
	mesh.clear_surfaces()
	_hide_all_labels() # Esconde labels antigos
	
	if start_pos == Vector3.ZERO: return

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material_override)
	mesh.surface_set_color(line_color)
	
	var vertices_added = false
	var label_count = 0 # Contador para limitar labels
	
	var all_zones = get_tree().get_nodes_in_group("active_zones")
	
	for zone in all_zones:
		var data = zone.zone_data
		var radius = zone.planet_radius
		
		# 1. Global -> Local
		var local_start = data.world_to_grid(start_pos, planet_center, radius)
		var local_end = data.world_to_grid(end_pos, planet_center, radius)
		
		# 2. Clamp
		var min_x = max(0, min(local_start.x, local_end.x))
		var max_x = min(data.vertex_resolution - 1, max(local_start.x, local_end.x))
		var min_y = max(0, min(local_start.y, local_end.y))
		var max_y = min(data.vertex_resolution - 1, max(local_start.y, local_end.y))
		
		if min_x > max_x or min_y > max_y: continue
			
		# 3. Desenho
		var axes = _get_axis(data)
		var axisA = axes[0]
		var axisB = axes[1]
		
		var area = (max_x - min_x) * (max_y - min_y)
		var step = 1
		if area > 800: step = 2
		
		for y in range(min_y, max_y + 1, step):
			for x in range(min_x, max_x + 1, step):
				
				var current_h = data.get_height_safe(x, y)
				var pos_top = _calc_pos(x, y, data, radius, current_h, axisA, axisB)
				
				# --- Lógica de Altura Alvo ---
				var target_h_here = start_height
				if mode_is_ramp:
					var point_global = (pos_top.normalized() * radius) + planet_center
					var dist_from_start = start_pos.distance_to(point_global)
					target_h_here = start_height - (dist_from_start / ramp_ratio)
				else:
					target_h_here = end_height 
				
				var pos_bottom = _calc_pos(x, y, data, radius, target_h_here, axisA, axisB)
				
				# Linhas
				if abs(target_h_here - current_h) > 0.1:
					mesh.surface_add_vertex(pos_bottom); mesh.surface_add_vertex(pos_top)
					vertices_added = true
				
				if x < max_x:
					var next_pos_bot = _calc_pos(x + step, y, data, radius, _get_next_target(x+step, y, start_pos, radius, planet_center, ramp_ratio, start_height, mode_is_ramp, end_height, data, axisA, axisB), axisA, axisB)
					mesh.surface_add_vertex(pos_bottom); mesh.surface_add_vertex(next_pos_bot)
					var next_h = data.get_height_safe(x + step, y)
					var next_pos_top = _calc_pos(x + step, y, data, radius, next_h, axisA, axisB)
					mesh.surface_add_vertex(pos_top); mesh.surface_add_vertex(next_pos_top)
					vertices_added = true
					
				if y < max_y:
					var next_pos_bot_y = _calc_pos(x, y + step, data, radius, _get_next_target(x, y+step, start_pos, radius, planet_center, ramp_ratio, start_height, mode_is_ramp, end_height, data, axisA, axisB), axisA, axisB)
					mesh.surface_add_vertex(pos_bottom); mesh.surface_add_vertex(next_pos_bot_y)
					var next_h = data.get_height_safe(x, y + step)
					var next_pos_top = _calc_pos(x, y + step, data, radius, next_h, axisA, axisB)
					mesh.surface_add_vertex(pos_top); mesh.surface_add_vertex(next_pos_top)
					vertices_added = true
				
				# --- LOGICA DOS LABELS ---
				# Só mostra se estiver dentro do limite de contagem
				if label_count < MAX_LABELS and x < max_x and y < max_y:
					var lbl = _get_label_from_pool(label_count)
					lbl.visible = true
					
					# Calcula o centro da célula para o label
					var center_pos = _calc_pos_center(x, y, data, radius, target_h_here, axisA, axisB)
					
					# Como o Gizmo está na posição do Planeta, e center_pos é relativo ao planeta,
					# podemos usar direto.
					lbl.position = center_pos
					lbl.text = "%d" % int(target_h_here)
					
					label_count += 1

	if vertices_added:
		mesh.surface_end()
	else:
		mesh.clear_surfaces()

# --- POOLING DE LABELS ---
func _get_label_from_pool(index: int) -> Label3D:
	if index < label_pool.size():
		return label_pool[index]
	
	var new_label = label_template.duplicate()
	add_child(new_label)
	label_pool.append(new_label)
	return new_label

func _hide_all_labels():
	for lbl in label_pool:
		lbl.visible = false

# --- HELPERS ---
func _get_next_target(x, y, start_pos, radius, center, ratio, start_h, is_ramp, end_h, data, axisA, axisB):
	if not is_ramp: return end_h
	var pos = _calc_pos(x, y, data, radius, 0, axisA, axisB)
	var p_global = (pos.normalized() * radius) + center
	var dist = start_pos.distance_to(p_global)
	return start_h - (dist / ratio)

func _get_axis(data):
	var a = Vector3(data.normal.y, data.normal.z, data.normal.x)
	var b = data.normal.cross(a)
	return [a, b]

func _calc_pos(x, y, data, radius, height, axisA, axisB):
	var percent = Vector2(x, y) / float(data.resolution)
	var global_percent = data.origin_uv + (percent * data.chunk_size)
	var point_cube = data.normal + (global_percent.x - 0.5) * 2.0 * axisA + (global_percent.y - 0.5) * 2.0 * axisB
	return point_cube.normalized() * (radius + height)

# Helper para pegar o centro da célula (X+0.5, Y+0.5)
func _calc_pos_center(x, y, data, radius, height, axisA, axisB):
	var percent = (Vector2(x, y) + Vector2(0.5, 0.5)) / float(data.resolution)
	var global_percent = data.origin_uv + (percent * data.chunk_size)
	var point_cube = data.normal + (global_percent.x - 0.5) * 2.0 * axisA + (global_percent.y - 0.5) * 2.0 * axisB
	return point_cube.normalized() * (radius + height)
