extends MeshInstance3D
class_name MiningGizmo

@export var line_color : Color = Color(1.0, 0.6, 0.0, 1.0)

# Otimização: Limite máximo de números na tela para não travar o PC
const MAX_LABELS = 600 

# Template: O Label3D original que você criou na cena
@onready var label_template : Label3D = $Label3D 

# Piscina de Labels (Cache)
var label_pool : Array[Label3D] = []

func _ready():
	if mesh == null: mesh = ImmediateMesh.new()
	
	# Configura Material das Linhas
	if material_override == null:
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = line_color
		mat.vertex_color_use_as_albedo = true 
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true 
		mat.render_priority = 100 
		material_override = mat
	
	# Configura o Template e esconde ele (ele é só um molde)
	if label_template:
		label_template.visible = false
		# Adiciona ele na pool como o primeiro item
		label_pool.append(label_template)

func update_gizmo(start: Vector2i, end: Vector2i, data: ActiveZoneData, radius: float, target_height: float):
	if mesh == null: mesh = ImmediateMesh.new()
	mesh.clear_surfaces()
	
	# Esconde todos os labels da rodada anterior
	_hide_all_labels()
	
	if start == Vector2i(-1, -1): return

	var min_x = min(start.x, end.x)
	var max_x = max(start.x, end.x)
	var min_y = min(start.y, end.y)
	var max_y = max(start.y, end.y)
	
	# Proteção: Se a área for muito grande, aumentamos o "step" para não desenhar linhas demais
	var area = (max_x - min_x) * (max_y - min_y)
	var step = 1
	if area > 800: step = 2
	
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material_override)
	mesh.surface_set_color(line_color)
	
	var axes = _get_axis(data)
	var axisA = axes[0]
	var axisB = axes[1]
	
	var vertices_added = false
	var label_count = 0 # Contador de labels usados
	
	for y in range(min_y, max_y + 1, step):
		for x in range(min_x, max_x + 1, step):
			if x >= data.vertex_resolution or y >= data.vertex_resolution: continue
			
			var current_h = data.get_height_safe(x, y)
			
			var pos_top = _calc_pos(x, y, data, radius, current_h, axisA, axisB)
			var pos_bottom = _calc_pos(x, y, data, radius, target_height, axisA, axisB)
			
			# --- DESENHO DAS LINHAS (Gaiola) ---
			var is_corner = (x == min_x or x == max_x) and (y == min_y or y == max_y)
			if is_corner or abs(target_height - current_h) > 0.1:
				mesh.surface_add_vertex(pos_bottom)
				mesh.surface_add_vertex(pos_top)
				vertices_added = true
			
			if x < max_x: # Linhas horizontais e teto
				var next_h = data.get_height_safe(x + step, y)
				var next_p_top = _calc_pos(x + step, y, data, radius, next_h, axisA, axisB)
				var next_p_bottom = _calc_pos(x + step, y, data, radius, target_height, axisA, axisB)
				mesh.surface_add_vertex(pos_top); mesh.surface_add_vertex(next_p_top)
				mesh.surface_add_vertex(pos_bottom); mesh.surface_add_vertex(next_p_bottom)
				vertices_added = true
				
			if y < max_y: # Linhas verticais e teto
				var next_h = data.get_height_safe(x, y + step)
				var next_p_top = _calc_pos(x, y + step, data, radius, next_h, axisA, axisB)
				var next_p_bottom = _calc_pos(x, y + step, data, radius, target_height, axisA, axisB)
				mesh.surface_add_vertex(pos_top); mesh.surface_add_vertex(next_p_top)
				mesh.surface_add_vertex(pos_bottom); mesh.surface_add_vertex(next_p_bottom)
				vertices_added = true

			# --- LÓGICA DO LABEL POR QUADRADO ---
			# Só colocamos label se estivermos dentro do limite (x < max_x e y < max_y)
			# E se não tivermos estourado o limite de performance (MAX_LABELS)
			if x < max_x and y < max_y and label_count < MAX_LABELS:
				# Calcula o centro da célula
				var center_pos = _calc_pos_center(x, y, data, radius, target_height, axisA, axisB)
				
				# Pega um label da piscina
				var lbl = _get_label_from_pool(label_count)
				lbl.visible = true
				lbl.position = to_local(center_pos) # Converte para local se o Gizmo não estiver na origem
				lbl.text = "%d" % int(target_height) # Mostra só o número inteiro
				
				label_count += 1

	if vertices_added:
		mesh.surface_end()
	else:
		mesh.clear_surfaces()

# --- SISTEMA DE POOLING ---
func _get_label_from_pool(index: int) -> Label3D:
	# Se já temos labels suficientes na lista, retorna o existente
	if index < label_pool.size():
		return label_pool[index]
	
	# Se não, cria um novo duplicando o template
	var new_label = label_template.duplicate()
	add_child(new_label)
	label_pool.append(new_label)
	return new_label

func _hide_all_labels():
	for lbl in label_pool:
		lbl.visible = false

# Helpers matemáticos
func _get_axis(data):
	var a = Vector3(data.normal.y, data.normal.z, data.normal.x)
	var b = data.normal.cross(a)
	return [a, b]

func _calc_pos(x, y, data, radius, height, axisA, axisB):
	var percent = Vector2(x, y) / float(data.resolution)
	var global_percent = data.origin_uv + (percent * data.chunk_size)
	var point_cube = data.normal + (global_percent.x - 0.5) * 2.0 * axisA + (global_percent.y - 0.5) * 2.0 * axisB
	return point_cube.normalized() * (radius + height)

# Nova função para pegar o centro exato da célula
func _calc_pos_center(x, y, data, radius, height, axisA, axisB):
	# Soma 0.5 para pegar o meio do quadrado
	var percent = (Vector2(x, y) + Vector2(0.5, 0.5)) / float(data.resolution)
	var global_percent = data.origin_uv + (percent * data.chunk_size)
	var point_cube = data.normal + (global_percent.x - 0.5) * 2.0 * axisA + (global_percent.y - 0.5) * 2.0 * axisB
	return point_cube.normalized() * (radius + height)
