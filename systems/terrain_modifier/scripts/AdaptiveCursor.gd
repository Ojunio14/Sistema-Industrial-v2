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

# Substitua a função update_gizmo inteira por esta:

func update_gizmo(start: Vector2i, end: Vector2i, data: ActiveZoneData, radius: float, start_height: float, end_height: float):
	if mesh == null: mesh = ImmediateMesh.new()
	mesh.clear_surfaces()
	_hide_all_labels()
	
	if start == Vector2i(-1, -1): return

	var min_x = min(start.x, end.x)
	var max_x = max(start.x, end.x)
	var min_y = min(start.y, end.y)
	var max_y = max(start.y, end.y)
	
	# Dados para calcular inclinação visual (Rampa)
# --- CORREÇÃO: ALINHAMENTO DE EIXO (SNAP VISUAL) ---
	var diff = end - start
	var ramp_vec = Vector2.ZERO
	
	if abs(diff.x) > abs(diff.y):
		ramp_vec = Vector2(diff.x, 0)
	else:
		ramp_vec = Vector2(0, diff.y)
		
	var ramp_len_sq = ramp_vec.length_squared()
	
	# Otimização de área
	var area = (max_x - min_x) * (max_y - min_y)
	var step = 1
	if area > 800: step = 2
	
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material_override)
	mesh.surface_set_color(line_color)
	
	var axes = _get_axis(data)
	var axisA = axes[0]
	var axisB = axes[1]
	
	var label_count = 0
	
	for y in range(min_y, max_y + 1, step):
		for x in range(min_x, max_x + 1, step):
			if x >= data.vertex_resolution or y >= data.vertex_resolution: continue
			
			var current_h = data.get_height_safe(x, y)
			
			# --- 1. CALCULA ALTURA ALVO DESTE PONTO (Interpolação da Rampa) ---
			var target_h_here = start_height
			if ramp_len_sq > 0:
				var curr_vec = Vector2(x - start.x, y - start.y)
				# Projeção escalar clampada entre 0 e 1
				var t = clamp(curr_vec.dot(ramp_vec) / ramp_len_sq, 0.0, 1.0)
				target_h_here = lerp(start_height, end_height, t)
			
			# --- 2. POSIÇÕES 3D ---
			var pos_top = _calc_pos(x, y, data, radius, current_h, axisA, axisB)
			var pos_bottom = _calc_pos(x, y, data, radius, target_h_here, axisA, axisB)
			
			# --- 3. DESENHO VERTICAL (PAREDES) ---
			# Desenha nos cantos da seleção OU se houver diferença de altura
			var is_corner = (x == min_x or x == max_x) and (y == min_y or y == max_y)
			if is_corner or abs(target_h_here - current_h) > 0.1:
				mesh.surface_add_vertex(pos_bottom)
				mesh.surface_add_vertex(pos_top)
			
			# --- 4. CONEXÕES COM VIZINHO DA DIREITA (X + step) ---
			if x < max_x:
				# Altura REAL do vizinho (para o teto)
				var next_h = data.get_height_safe(x + step, y)
				var next_p_top = _calc_pos(x + step, y, data, radius, next_h, axisA, axisB)
				
				# Altura ALVO do vizinho (para o chão da rampa)
				var next_t_h = start_height
				if ramp_len_sq > 0:
					var next_vec = Vector2((x + step) - start.x, y - start.y)
					var t_next = clamp(next_vec.dot(ramp_vec) / ramp_len_sq, 0.0, 1.0)
					next_t_h = lerp(start_height, end_height, t_next)
				var next_p_bottom = _calc_pos(x + step, y, data, radius, next_t_h, axisA, axisB)
				
				# Desenha Teto (Top -> Next Top)
				mesh.surface_add_vertex(pos_top)
				mesh.surface_add_vertex(next_p_top)
				
				# Desenha Chão (Bottom -> Next Bottom)
				mesh.surface_add_vertex(pos_bottom)
				mesh.surface_add_vertex(next_p_bottom)
				
			# --- 5. CONEXÕES COM VIZINHO DE BAIXO (Y + step) ---
			if y < max_y:
				# Altura REAL do vizinho (para o teto)
				var next_h = data.get_height_safe(x, y + step)
				var next_p_top = _calc_pos(x, y + step, data, radius, next_h, axisA, axisB)
				
				# Altura ALVO do vizinho (para o chão da rampa)
				var next_t_h_y = start_height
				if ramp_len_sq > 0:
					var next_vec_y = Vector2(x - start.x, (y + step) - start.y)
					var t_next_y = clamp(next_vec_y.dot(ramp_vec) / ramp_len_sq, 0.0, 1.0)
					next_t_h_y = lerp(start_height, end_height, t_next_y)
				var next_p_bottom_y = _calc_pos(x, y + step, data, radius, next_t_h_y, axisA, axisB)
				
				# Desenha Teto
				mesh.surface_add_vertex(pos_top)
				mesh.surface_add_vertex(next_p_top)
				
				# Desenha Chão
				mesh.surface_add_vertex(pos_bottom)
				mesh.surface_add_vertex(next_p_bottom_y)

			# --- 6. LABELS (Opcional - se estiver usando) ---
			if x < max_x and y < max_y and label_count < MAX_LABELS:
				var center_pos = _calc_pos_center(x, y, data, radius, target_h_here, axisA, axisB)
				var lbl = _get_label_from_pool(label_count)
				lbl.visible = true
				lbl.position = to_local(center_pos)
				lbl.text = "%d" % int(target_h_here)
				label_count += 1

	mesh.surface_end()

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
