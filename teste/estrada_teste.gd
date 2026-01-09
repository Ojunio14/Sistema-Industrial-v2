extends Node3D

@export var planet_center : Vector3 = Vector3(0, 0, 0)
@export var planet_radius : float = 400.0 # Ajuste para o raio real com relevo

func create_road(start_pos: Vector3, end_pos: Vector3):
	var path_node = Path3D.new()
	var curve = Curve3D.new()
	
	# Precisamos normalizar para garantir que a matemática esférica funcione
	var v_start = (start_pos - planet_center).normalized()
	var v_end = (end_pos - planet_center).normalized()
	
	# Quantos segmentos a estrada terá? 
	# Quanto mais segmentos, mais suave a curva, mas mais pesado.
	var steps = 20 
	
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		
		# A MÁGICA: slerp cria o arco perfeito na esfera unitária
		var sphere_point = v_start.slerp(v_end, t)
		
		# Agora projetamos esse ponto para a altura real do terreno
		# Se você tiver um script que retorna a altura do terreno (noise), use aqui.
		# Por enquanto, vamos usar o raio fixo + um pouquinho pra não z-fight
		var final_point = planet_center + (sphere_point * (planet_radius + 0.5))
		
		# Adiciona o ponto na curva
		curve.add_point(final_point)
	
	path_node.curve = curve
	get_tree().get_first_node_in_group("teste_cons").add_child(path_node)
	
	# --- VISUALIZAÇÃO ---
	# Aqui você adicionaria o código para gerar a malha da estrada (MeshInstance)
	# baseada nessa curva. O jeito mais fácil é usar CSGPolygon no modo Path.
	var visual_road = CSGPolygon3D.new()
	visual_road.set_layer_mask_value(1,true)
	visual_road.set_layer_mask_value(2,true)
	visual_road.mode = CSGPolygon3D.MODE_PATH
	visual_road.path_node = path_node.get_path()
	visual_road.polygon = _get_road_profile() # Uma forma 2D (corte transversal da estrada)
	path_node.add_child(visual_road)

func _get_road_profile() -> PackedVector2Array:
	# Cria o formato da estrada (corte lateral)
	# Exemplo: uma estrada plana de 4 metros de largura
	return PackedVector2Array([
		Vector2(-2, 0), # Esquerda
		Vector2(2, 0),  # Direita
		Vector2(2, -0.5), # Grossura pra baixo
		Vector2(-2, -0.5)
	])
