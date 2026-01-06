class_name ChunkJob
extends RefCounted

static func generate_mesh_data(
	origin: Vector2, 
	size: float, 
	resolution: int, 
	normal: Vector3,
	# --- PACOTE DE DADOS ---
	radius: float,
	min_height: float,
	amplitude: float,
	sea_level: float,
	mask_threshold: float,
	mountain_strength: float,
	terrace_steps: float,
	height_map: PlanetHeightMap,
	mountain_noise: FastNoiseLite,
	# NOVO ARGUMENTO AQUI:
	noise_mult: float 
) -> Array:
	
	var vertex_array := PackedVector3Array()
	var normal_array := PackedVector3Array()
	var uv_array := PackedVector2Array()
	var color_array := PackedColorArray()
	var index_array := PackedInt32Array()
	
	var axisA := Vector3(normal.y, normal.z, normal.x)
	var axisB : Vector3 = normal.cross(axisA)
	var e = 0.001 
	
	# Saia (Skirt)
	var relative_skirt_size = size * radius * 0.1
	var current_skirt_length = max(1.0, relative_skirt_size)
	
	# ==========================================
	# 1. MALHA PRINCIPAL
	# ==========================================
	for y in range(resolution + 1):
		for x in range(resolution + 1):
			var percent = Vector2(x, y) / float(resolution)
			var global_percent = origin + (percent * size)
			
			var pointOnUnitCube : Vector3 = normal + (global_percent.x - 0.5) * 2.0 * axisA + (global_percent.y - 0.5) * 2.0 * axisB
			var p_center = pointOnUnitCube.normalized()
			
			# --- AQUI ESTAVA O ERRO ---
			# Precisamos passar 'noise_mult' para a função de cálculo
			var pos_center = _calculate_point(p_center, radius, min_height, amplitude, sea_level, mask_threshold, mountain_strength, terrace_steps, height_map, mountain_noise, noise_mult)
			
			# Vizinhos (Normal)
			var p_right = (pointOnUnitCube + (axisA * e)).normalized()
			var pos_right = _calculate_point(p_right, radius, min_height, amplitude, sea_level, mask_threshold, mountain_strength, terrace_steps, height_map, mountain_noise, noise_mult)
			
			var p_down = (pointOnUnitCube + (axisB * e)).normalized()
			var pos_down = _calculate_point(p_down, radius, min_height, amplitude, sea_level, mask_threshold, mountain_strength, terrace_steps, height_map, mountain_noise, noise_mult)
			
			var tangent_x = pos_right - pos_center
			var tangent_y = pos_down - pos_center
			var final_normal = tangent_y.cross(tangent_x).normalized()
			if final_normal.dot(p_center) < 0: final_normal = -final_normal
			
			# Cor baseada na altura
			var height_val = pos_center.length() - radius
			var normalized_height = clamp(height_val / 20.0, 0.0, 1.0)
			
			vertex_array.append(pos_center)
			normal_array.append(final_normal)
			color_array.append(Color(1, 0, 0, normalized_height)) 
			uv_array.append(global_percent)
			
			if x < resolution and y < resolution:
				var i = x + y * (resolution + 1)
				index_array.append(i); index_array.append(i + (resolution + 1)); index_array.append(i + 1)
				index_array.append(i + 1); index_array.append(i + (resolution + 1)); index_array.append(i + (resolution + 1) + 1)

	# ==========================================
	# 2. GERAÇÃO DAS SAIAS
	# ==========================================
	var edge_indices = []
	for x in range(resolution + 1): edge_indices.append(x)
	for y in range(resolution + 1): edge_indices.append(resolution + y * (resolution + 1))
	for x in range(resolution, -1, -1): edge_indices.append(x + resolution * (resolution + 1))
	for y in range(resolution, -1, -1): edge_indices.append(y * (resolution + 1))

	var skirt_start_idx = vertex_array.size()
	
	for i in range(edge_indices.size()):
		var original_idx = edge_indices[i]
		
		var v_pos = vertex_array[original_idx]
		var v_norm = normal_array[original_idx]
		var v_col = color_array[original_idx]
		var v_uv = uv_array[original_idx]
		
		var gravity_direction = -v_pos.normalized() 
		var skirt_pos = v_pos + (gravity_direction * current_skirt_length)
		
		vertex_array.append(skirt_pos)
		normal_array.append(v_norm)
		color_array.append(v_col)
		uv_array.append(v_uv)
		
		if i > 0:
			var curr_edge = original_idx
			var prev_edge = edge_indices[i-1]
			var curr_skirt = skirt_start_idx + i
			var prev_skirt = skirt_start_idx + (i-1)
			
			index_array.append(prev_edge); index_array.append(curr_skirt); index_array.append(prev_skirt)
			index_array.append(prev_edge); index_array.append(curr_edge); index_array.append(curr_skirt)

	var final_arrays = []
	final_arrays.resize(Mesh.ARRAY_MAX)
	final_arrays[Mesh.ARRAY_VERTEX] = vertex_array
	final_arrays[Mesh.ARRAY_NORMAL] = normal_array
	final_arrays[Mesh.ARRAY_TEX_UV] = uv_array
	final_arrays[Mesh.ARRAY_COLOR] = color_array
	final_arrays[Mesh.ARRAY_INDEX] = index_array
	
	return final_arrays

# LÓGICA MATEMÁTICA
static func _calculate_point(p: Vector3, radius: float, min_h: float, amp: float, sea: float, mask_thr: float, m_str: float, t_steps: float, h_map: PlanetHeightMap, m_noise: FastNoiseLite, noise_mult: float) -> Vector3:
	var u = (atan2(p.x, p.z) / (2.0 * PI)) + 0.5; u = 1.0 - u
	var v = (asin(p.y) / PI) + 0.5; v = 1.0 - v
	
	var mask_val = 0.0
	if h_map: mask_val = h_map.get_height_at_uv_smooth(u, v)
	
	var final_h = 0.0
	
	if mask_val > sea:
		var land_base = (mask_val - sea) / (1.0 - sea)
		var mountain_detail = 0.0
		
		# Só calcula se noise_mult for > 0 (Otimização)
		if mask_val > mask_thr and m_noise and noise_mult > 0.001:
			var n = m_noise.get_noise_3dv(p * radius)
			n = 1.0 - abs(n)
			n = pow(n, 2.0)
			
			var n_stepped = floor(n * t_steps) / t_steps
			n = lerp(n, n_stepped, 0.6)
			
			var mountain_weight = (mask_val - mask_thr) / (1.0 - mask_thr)
			mountain_weight = clamp(mountain_weight, 0.0, 1.0)
			mountain_weight = pow(mountain_weight, 0.5)
			
			# Multiplicador Aplicado Aqui
			mountain_detail = n * m_str * mountain_weight * noise_mult
			
		final_h = land_base + mountain_detail
		
	return p * (radius + min_h + (final_h * amp))
