extends MeshInstance3D
class_name ActiveZoneMesh

# Referência aos dados puros (O "Save Game" em memória)
var zone_data: ActiveZoneData

# Precisamos do raio do planeta para reconstruir a curvatura base
var planet_radius: float = 50.0 

# Material visual básico (Shader)
var material_override_ref: Material

func _ready() -> void:
	set_layer_mask_value(1, false)
	set_layer_mask_value(2, true)


func initialize(data: ActiveZoneData, radius: float, mat: Material):
	zone_data = data
	planet_radius = radius
	material_override_ref = mat
	
	# Garante que usamos o material certo
	self.material_override = material_override_ref
	if not zone_data.is_connected("data_changed", Callable(self, "update_mesh_from_data")):
		zone_data.connect("data_changed", Callable(self, "update_mesh_from_data"))
	
	#update_mesh_from_data()
	# Gera a malha pela primeira vez
	update_mesh_from_data()

func update_mesh_from_data():
	if not zone_data:
		return
		
	# Preparação do SurfaceTool (construtor de malha)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Dados para reconstruir a esfera (Matemática inversa)
	var res = zone_data.resolution
	var chunk_size = zone_data.chunk_size
	var origin = zone_data.origin_uv
	var normal = zone_data.normal # A normal da face do cubo (Top, Front, etc)
	
	# Eixos do Cubo (Mesma matemática do PlanetMeshFace)
	var axisA := Vector3(normal.y, normal.z, normal.x)
	var axisB : Vector3 = normal.cross(axisA)
	
	# --- LOOP DOS VÉRTICES ---
	for y in range(res + 1):
		for x in range(res + 1):
			
			# 1. Posição na Esfera Unitária
			var percent = Vector2(x, y) / float(res)
			var global_percent = origin + (percent * chunk_size)
			var pointOnCube = normal + (global_percent.x - 0.5) * 2.0 * axisA + (global_percent.y - 0.5) * 2.0 * axisB
			var sphere_normal = pointOnCube.normalized() # Isso aponta do centro para fora
			
			# 2. Leitura da Altura (DATA LAYER)
			# Aqui está a mágica: não usamos noise, usamos o dado salvo.
			var height = zone_data.get_height_safe(x, y)
			
			# 3. Posição Final 3D
			# Posição = Direção * (Raio Base + Altura Editável)
			var final_pos = sphere_normal * (planet_radius + height)
			
			# 4. Cor do Vértice (Baseada no Material da Célula)
			# Nota: Vértices são esquinas. Vamos pegar a cor da célula vizinha (x,y).
			# Tratamos o limite (bordas) com clamp/min.
			var cell_x = min(x, res - 1)
			var cell_y = min(y, res - 1)
			
			var stack = zone_data.get_stack(cell_x, cell_y)
			var top_mat = stack.get_top_material()
			
			var color = Color.MAGENTA # Cor de erro/debug
			if top_mat:
				color = top_mat.albedo_color
			
			# 5. Adiciona ao SurfaceTool
			st.set_color(color)
			st.set_uv(global_percent) # Útil se usar texturas
			st.add_vertex(final_pos)

	# --- LOOP DOS ÍNDICES (TRIÂNGULOS) ---
	for y in range(res):
		for x in range(res):
			var i = y * (res + 1) + x
			
			# Triângulo 1
			st.add_index(i)
			st.add_index(i + (res + 1))
			st.add_index(i + 1)
			
			# Triângulo 2
			st.add_index(i + 1)
			st.add_index(i + (res + 1))
			st.add_index(i + (res + 1) + 1)

	# Finaliza
	st.generate_normals()
	# st.generate_tangents() # Ative se usar Normal Maps
	self.mesh = st.commit()
	
	# Cria colisão para que o Raycast do mouse funcione depois
	create_trimesh_collision()
