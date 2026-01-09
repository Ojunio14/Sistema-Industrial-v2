
extends MeshInstance3D
class_name PlanetMeshFace


#vai mostra qual face que queremos renderizar e espicificar qual direçao que ela estar apontando
@export var normal : Vector3

# No topo do script, defina uma constante para a "força" da correção.
# PI / 4.0 (aprox 0.785) é o valor matematicamente ideal para cubos.
const WARP_FACTOR = PI / 4.0




func regenerate_mesh(planet_data : PlanetData):
	
	var arrays := []
	
	arrays.clear()
	
	var resolution  : int = planet_data.resolution
	
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertex_array := PackedVector3Array()
	var uv_array := PackedVector2Array()
	var normal_array := PackedVector3Array()
	var index_array := PackedInt32Array()
	vertex_array.clear()
	uv_array.clear()
	normal_array.clear()
	index_array.clear()
	
	

	
	var num_vertices : int = resolution * resolution
	var num_indices : int = (resolution-1) * (resolution-1) * 6
	
	normal_array.resize(num_vertices)
	uv_array.resize(num_vertices)
	vertex_array.resize(num_vertices)
	index_array.resize(num_indices)
	
	var tri_index : int = 0
	var axisA := Vector3(normal.y, normal.z, normal.x)
	var axisB : Vector3 = normal.cross(axisA)
	for y in range(resolution):
		for x in range(resolution):
			var i : int = x + y * resolution
			var percent := Vector2(x,y) / (resolution-1)
		
		
	# 1. Centralizamos para ficar entre -1.0 e 1.0
			var linear_x = (percent.x - 0.5) * 2.0
			var linear_y = (percent.y - 0.5) * 2.0

			# 2. Aplicamos a Tangente para "pré-esticar" os cantos
			# Isso compensa a distorção esférica que virá depois
			var warped_x = tan(linear_x * WARP_FACTOR)
			var warped_y = tan(linear_y * WARP_FACTOR)

			# 3. Usamos os valores "warped" (esticados) para criar o ponto no cubo
			# Nota: Removemos o "* 2.0" daqui porque já está embutido no cálculo da tangente se usarmos axis normalizados
			var pointOnUnitCube : Vector3 = normal + warped_x * axisA + warped_y * axisB
			uv_array[i] = percent
			# Agora usamos x_warped e y_warped em vez de percent direto
			#var pointOnUnitCube : Vector3 = normal + x_warped * axisA + y_warped * axisB
			var pointOnUnitSphere := pointOnUnitCube.normalized() 
			var pointOnPlanet := planet_data.point_on_planet(pointOnUnitSphere)
			vertex_array[i] = pointOnPlanet

			
			if x != resolution-1 and y != resolution-1:
				index_array[tri_index+2] = i
				index_array[tri_index+1] = i+resolution+1
				index_array[tri_index] = i+resolution
				
				index_array[tri_index+5] = i
				index_array[tri_index+4] = i+1
				index_array[tri_index+3] = i+resolution+1
				tri_index += 6
				
	for a in range(0, index_array.size(), 3):
		var b : int = a + 1
		var c : int = a + 2
		var ab : Vector3 = vertex_array[index_array[b]] - vertex_array[index_array[a]]
		var bc : Vector3 = vertex_array[index_array[c]] - vertex_array[index_array[b]]
		var ca : Vector3 = vertex_array[index_array[a]] - vertex_array[index_array[c]]
		var cross_ab_bc : Vector3 = ab.cross(bc) * -1.0
		var cross_bc_ca : Vector3 = bc.cross(ca) * -1.0
		var cross_ca_ab : Vector3 = ca.cross(ab) * -1.0
		normal_array[index_array[a]] += cross_ab_bc + cross_bc_ca + cross_ca_ab
		normal_array[index_array[b]] += cross_ab_bc + cross_bc_ca + cross_ca_ab
		normal_array[index_array[c]] += cross_ab_bc + cross_bc_ca + cross_ca_ab
	for i in range(normal_array.size()):
		normal_array[i] = normal_array[i].normalized()
		
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normal_array
	arrays[Mesh.ARRAY_TEX_UV] = uv_array
	arrays[Mesh.ARRAY_INDEX] = index_array
	
	call_deferred("_update_mesh", arrays)
	
func _update_mesh(arrays : Array):
	var _mesh := ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	

	
	
	var trimesh_collisions = _mesh.create_trimesh_shape()
	var collisionshape3d : CollisionShape3D = find_child("StaticBody3D").find_child("CollisionShape3D")
	collisionshape3d.set_shape(trimesh_collisions)
	
	
	self.mesh = _mesh
