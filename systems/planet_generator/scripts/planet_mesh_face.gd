extends MeshInstance3D
class_name PlanetMeshFace

enum ViewMode { SOLID, WIREFRAME, HYBRID }
const CURRENT_MODE : ViewMode = ViewMode.SOLID

var custom_material : Material 
var resolution : int = 64 # Apenas para fins de info, não é mais usado no cálculo aqui

# Dados para debug se precisar
var normal : Vector3
var chunk_origin : Vector2
var chunk_size : float

func _ready() -> void:
	set_layer_mask_value(1, false)
	set_layer_mask_value(2, true)
	
	if not custom_material:
		custom_material = load("res://systems/planet_generator/materials/planet_shader.tres") 

# NOVA FUNÇÃO: Recebe os dados da Thread e aplica
# Lembre-se de manter o 'p_collision' aqui nos parênteses!
func apply_mesh_data(arrays: Array, p_resolution: int, p_collision: bool):
	self.resolution = p_resolution
	
	var new_mesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Configurações visuais (AABB, Culling)
	self.extra_cull_margin = 1000.0 
	var box = new_mesh.get_aabb()
	new_mesh.custom_aabb = box.grow(100.0)
	
	self.mesh = new_mesh
	
	_setup_materials()
	
	# Limpa colisões antigas
	for child in get_children():
		if child is StaticBody3D:
			child.queue_free()
			
	# --- MUDANÇA AQUI: SISTEMA DE FILA ---
	if p_collision:
		# Em vez de criar agora e travar o jogo, pedimos pro Planeta agendar
		var planet_node = get_parent().parent_planet # Acessa o nó Planet pai do Quadtree
		if planet_node and planet_node.has_method("request_collision"):
			planet_node.request_collision(self)
		else:
			# Fallback de segurança se não achar o planeta
			create_trimesh_collision()

# Esta função será chamada pelo Planet.gd quando chegar sua vez (1 por frame)
func create_collision_now():
	create_trimesh_collision()

func _setup_materials():
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
