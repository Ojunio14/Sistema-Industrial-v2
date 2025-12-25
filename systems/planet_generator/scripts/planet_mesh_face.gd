extends MeshInstance3D
class_name PlanetMeshFace

# --- CONFIGURAÇÃO DE VISUALIZAÇÃO ---
enum ViewMode { SOLID, WIREFRAME, HYBRID }
const CURRENT_MODE : ViewMode = ViewMode.SOLID

# Material com o Shader dos Biomas
var custom_material : Material 

var normal : Vector3
var chunk_origin : Vector2
var chunk_size : float
var resolution : int = 18

func _ready() -> void:
	# Camadas de visibilidade (Ajuste conforme seu projeto)
	set_layer_mask_value(1, false)
	set_layer_mask_value(2, true)
	
	if not custom_material:
		# CERTIFIQUE-SE QUE ESTE CAMINHO ESTÁ CERTO NO SEU PROJETO!
		custom_material = load("res://systems/planet_generator/materials/planet_shader.tres") 

#func regenerate_mesh(planet_data : PlanetData):
	#var arrays := []
	#arrays.resize(Mesh.ARRAY_MAX)
	#
	#var vertex_array := PackedVector3Array()
	#var index_array := PackedInt32Array()
	#var uv_array := PackedVector2Array()
	#var normal_array := PackedVector3Array()
	#var color_array := PackedColorArray()
	#
	## Eixos auxiliares para construir o cubo
	#var axisA := Vector3(normal.y, normal.z, normal.x)
	#var axisB : Vector3 = normal.cross(axisA)
	#
	## --- CÁLCULO DINÂMICO DA SAIA (SKIRT) ---
	## Quanto maior o chunk, maior a saia.
	## Multiplicamos por 0.1 do raio para garantir que cubra fendas gigantes de longe.
	## O max(1.0, ...) garante que chunks pequenos de perto tenham pelo menos 1m de saia.
	#var relative_skirt_size = chunk_size * planet_data.radius * 0.1
	#var current_skirt_length = max(1.0, relative_skirt_size)
	#
	## ==========================================
	## 1. GERAÇÃO DA MALHA PRINCIPAL (O CHÃO)
	## ==========================================
	#for y in range(resolution + 1):
		#for x in range(resolution + 1):
			#var percent = Vector2(x, y) / float(resolution)
			#var global_percent = chunk_origin + (percent * chunk_size)
			#
			#var pointOnUnitCube : Vector3 = normal + (global_percent.x - 0.5) * 2.0 * axisA + (global_percent.y - 0.5) * 2.0 * axisB
			#var pointOnUnitSphere : Vector3 = pointOnUnitCube.normalized()
			#
			## Posição Real
			#var pointOnPlanet := planet_data.point_on_planet(pointOnUnitSphere)
			#
			## Normal Analítica (Aponta para o céu - Essencial para luz perfeita)
			#var analytical_normal = pointOnUnitSphere
			## Calcula a altura relativa (0.0 = Nível do Mar base)
			## Se seu raio é 50 e o ponto está em 52, a altura é 2.
			#var height_val = pointOnPlanet.length() - planet_data.radius
#
			## Normaliza para enviar pro shader (ajuste o divisor 20.0 conforme a altura máxima das suas montanhas)
			#var normalized_height = clamp(height_val / 20.0, 0.0, 1.0)
#
			## SALVA NO COLOR.a (Canal Alpha)
			##COLOR.r = ID do Bioma
			##COLOR.a = Altura do Terreno
			#var biome_id = planet_data.get_biome_id_for_shader(pointOnUnitSphere).r
			#color_array.append(Color(biome_id, 0, 0, normalized_height))
			#vertex_array.append(pointOnPlanet)
			#normal_array.append(analytical_normal)
			##color_array.append(planet_data.get_biome_id_for_shader(pointOnUnitSphere))
			#uv_array.append(global_percent)
			#
			## Triângulos do Chão
			#if x < resolution and y < resolution:
				#var i = x + y * (resolution + 1)
				#
				## Triângulo 1
				#index_array.append(i)
				#index_array.append(i + (resolution + 1))
				#index_array.append(i + 1)
				#
				## Triângulo 2
				#index_array.append(i + 1)
				#index_array.append(i + (resolution + 1))
				#index_array.append(i + (resolution + 1) + 1)
#
	## ==========================================
	## 2. GERAÇÃO DAS SAIAS (SKIRTS)
	## ==========================================
	## Identificamos os índices das bordas do grid
	#var edge_indices = []
	#for x in range(resolution + 1): edge_indices.append(x) # Topo
	#for y in range(resolution + 1): edge_indices.append(resolution + y * (resolution + 1)) # Direita
	#for x in range(resolution, -1, -1): edge_indices.append(x + resolution * (resolution + 1)) # Baixo (Invertido)
	#for y in range(resolution, -1, -1): edge_indices.append(y * (resolution + 1)) # Esquerda (Invertido)
#
	## Onde começam os vértices da saia no array
	#var skirt_start_idx = vertex_array.size()
	#
	#for i in range(edge_indices.size()):
		#var original_idx = edge_indices[i]
		#
		## Pega dados do vértice original da borda
		#var v_pos = vertex_array[original_idx]
		#var v_norm = normal_array[original_idx] # Normal aponta pro céu
		#var v_col = color_array[original_idx]
		#var v_uv = uv_array[original_idx]
		#
		## TRUQUE 1: Posição
		## Empurra para baixo usando o tamanho DINÂMICO calculado lá em cima
		#var skirt_pos = v_pos - (v_norm * current_skirt_length)
		#
		## TRUQUE 2: Iluminação
		## Usamos a MESMA normal do chão. A luz "acha" que ainda é chão plano.
		## Isso faz a emenda sumir visualmente.
		#var skirt_norm = v_norm 
		#
		#vertex_array.append(skirt_pos)
		#normal_array.append(skirt_norm)
		#color_array.append(v_col)
		#uv_array.append(v_uv) # Mantém UV para textura não distorcer tanto
		#
		## Cria os quadrados da saia
		#if i > 0:
			#var curr_edge = original_idx
			#var prev_edge = edge_indices[i-1]
			#
			#var curr_skirt = skirt_start_idx + i
			#var prev_skirt = skirt_start_idx + (i-1)
			#
			## Conecta Borda -> Saia
			#index_array.append(prev_edge); index_array.append(curr_skirt); index_array.append(prev_skirt)
			#index_array.append(prev_edge); index_array.append(curr_edge); index_array.append(curr_skirt)
#
	## ==========================================
	## 3. FINALIZAÇÃO
	## ==========================================
	#arrays[Mesh.ARRAY_VERTEX] = vertex_array
	#arrays[Mesh.ARRAY_COLOR] = color_array
	#arrays[Mesh.ARRAY_NORMAL] = normal_array
	#arrays[Mesh.ARRAY_TEX_UV] = uv_array
	#arrays[Mesh.ARRAY_INDEX] = index_array
	#
	#call_deferred("_update_mesh", arrays)

func regenerate_mesh(planet_data : PlanetData):
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertex_array := PackedVector3Array()
	var index_array := PackedInt32Array()
	var uv_array := PackedVector2Array()
	var normal_array := PackedVector3Array()
	var color_array := PackedColorArray()
	
	var axisA := Vector3(normal.y, normal.z, normal.x)
	var axisB : Vector3 = normal.cross(axisA)
	
	var relative_skirt_size = chunk_size * planet_data.radius * 0.1
	var current_skirt_length = max(1.0, relative_skirt_size)
	
	# Epsilon: Distância minúscula para calcular a inclinação matemática
	var e = 0.001 
	
	# ==========================================
	# 1. LOOP PRINCIPAL (VÉRTICES)
	# ==========================================
	for y in range(resolution + 1):
		for x in range(resolution + 1):
			var percent = Vector2(x, y) / float(resolution)
			var global_percent = chunk_origin + (percent * chunk_size)
			
			# A. Ponto Central (O Vértice Real)
			var pointOnUnitCube : Vector3 = normal + (global_percent.x - 0.5) * 2.0 * axisA + (global_percent.y - 0.5) * 2.0 * axisB
			var p_center = pointOnUnitCube.normalized()
			var pos_center = planet_data.point_on_planet(p_center)
			
			# B. Pontos Vizinhos (Para calcular a Normal Matemática)
			# Vizinho Direito
			var p_right = (pointOnUnitCube + (axisA * e)).normalized()
			var pos_right = planet_data.point_on_planet(p_right)
			# Vizinho Baixo
			var p_down = (pointOnUnitCube + (axisB * e)).normalized()
			var pos_down = planet_data.point_on_planet(p_down)
			
			# C. Cálculo da Normal (Cruzamento dos vizinhos)
			var tangent_x = pos_right - pos_center
			var tangent_y = pos_down - pos_center
			var final_normal = tangent_y.cross(tangent_x).normalized()
			
			# PROTEÇÃO: Se a normal apontar para dentro do planeta, inverte ela.
			if final_normal.dot(p_center) < 0:
				final_normal = -final_normal
			
			# D. Dados Finais
			var height_val = pos_center.length() - planet_data.radius
			var normalized_height = clamp(height_val / 20.0, 0.0, 1.0)
			
			# Normalizamos o UV para o shader não esticar nas saias
			# (Isso não afeta o UV do Quadtree, é só pro Vertex Shader se precisar)
			
			# COLOR: R=BiomeID, A=Altura
			var biome_id = planet_data.get_biome_id_for_shader(p_center).r
			
			vertex_array.append(pos_center)
			normal_array.append(final_normal) # <--- SALVAMOS A NORMAL AQUI!
			color_array.append(Color(biome_id, 0, 0, normalized_height))
			uv_array.append(global_percent)
			
			# Triângulos
			if x < resolution and y < resolution:
				var i = x + y * (resolution + 1)
				index_array.append(i); index_array.append(i + (resolution + 1)); index_array.append(i + 1)
				index_array.append(i + 1); index_array.append(i + (resolution + 1)); index_array.append(i + (resolution + 1) + 1)

	# ==========================================
	# 2. LOOP DAS SAIAS (SKIRTS)
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
		
		# --- CORREÇÃO DA SAIA SUBINDO ---
		# Usamos a direção do centro (v_pos normalizado) para puxar para baixo.
		# Ignoramos a normal da superfície para calcular a posição.
		var gravity_direction = -v_pos.normalized() # Aponta para o centro
		var skirt_pos = v_pos + (gravity_direction * current_skirt_length)
		
		vertex_array.append(skirt_pos)
		normal_array.append(v_norm) # Mantém a normal da superfície para iluminação contínua
		color_array.append(v_col)
		uv_array.append(v_uv)
		
		if i > 0:
			var curr_edge = original_idx
			var prev_edge = edge_indices[i-1]
			var curr_skirt = skirt_start_idx + i
			var prev_skirt = skirt_start_idx + (i-1)
			
			index_array.append(prev_edge); index_array.append(curr_skirt); index_array.append(prev_skirt)
			index_array.append(prev_edge); index_array.append(curr_edge); index_array.append(curr_skirt)

	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_COLOR] = color_array
	arrays[Mesh.ARRAY_NORMAL] = normal_array
	arrays[Mesh.ARRAY_TEX_UV] = uv_array
	arrays[Mesh.ARRAY_INDEX] = index_array
	
	call_deferred("_update_mesh", arrays)
	
func _update_mesh(arrays : Array):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var vertex_array = arrays[Mesh.ARRAY_VERTEX]
	var uv_array = arrays[Mesh.ARRAY_TEX_UV]
	var color_array = arrays[Mesh.ARRAY_COLOR]
	var normal_array = arrays[Mesh.ARRAY_NORMAL] # <--- PEGAMOS O ARRAY DE NORMAIS
	var index_array = arrays[Mesh.ARRAY_INDEX]
	
	for i in range(vertex_array.size()):
		st.set_uv(uv_array[i])
		st.set_color(color_array[i])
		st.set_normal(normal_array[i]) # <--- USAMOS A NORMAL PERFEITA AQUI
		st.add_vertex(vertex_array[i])
	
	for idx in index_array:
		st.add_index(idx)
	
	# --- IMPORTANTE: REMOVI O st.generate_normals() ---
	# Se você deixar ele aqui, ele vai estragar o trabalho que fizemos no script anterior
	# e as costuras vão voltar.
	# st.generate_tangents() # Tangents você pode deixar se usar Normal Map
	
	self.mesh = st.commit()
	
	# ... (Resto do código de Materiais igual) ...
	var final_material = custom_material
	if not final_material:
		final_material = StandardMaterial3D.new()
		final_material.albedo_color = Color.MAGENTA
		final_material.vertex_color_use_as_albedo = true

	final_material = final_material.duplicate()
	if final_material is BaseMaterial3D:
		final_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var wire_mat = ShaderMaterial.new()
	var wire_shader = Shader.new()
	wire_shader.code = """
	shader_type spatial;
	render_mode wireframe, cull_back, unshaded;
	uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
	void fragment() { ALBEDO = line_color.rgb; }
	"""
	wire_mat.shader = wire_shader

	match CURRENT_MODE:
		ViewMode.SOLID:
			self.material_override = final_material
		ViewMode.WIREFRAME:
			wire_mat.set_shader_parameter("line_color", Color(0, 1, 0))
			self.material_override = wire_mat
		ViewMode.HYBRID:
			if final_material:
				final_material.next_pass = wire_mat
				self.material_override = final_material
			else:
				self.material_override = wire_mat
	
	# Colisão (Código original)
	if get_parent() and "depth" in get_parent() and get_parent().depth > 5:
		create_trimesh_collision()
	else:
		for child in get_children():
			if child is StaticBody3D:
				child.queue_free()
