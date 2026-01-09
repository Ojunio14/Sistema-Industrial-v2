extends Node3D

@export_group("Configurações do Planeta")
@export var planet_center : Vector3 = Vector3.ZERO
@export var planet_radius : float = 100.0 # Ajuste para o tamanho do seu planeta ou calcule auto



@export_group("Movimento RTS")
@export var pan_speed : float = 20.0
@export var rotation_speed : float = 2.0
@export var zoom_speed : float = 2.0
@export var min_zoom : float = 5.0  # Perto do chão
@export var max_zoom : float = 50.0 # Longe (quase mapa tático)
@export var smooth_speed : float = 10.0 # Suavização do movimento
@export var mouse_sensitivity : float = 0.005
@export_group("Limites da Câmera")
@export var min_pitch : float = -80.0 # Quase olhando de cima (Top-down)
@export var max_pitch : float = -20.0 # Quase no horizonte (não deixe chegar a 0)
<<<<<<< Updated upstream
#@export var my_id : CameraManager.Cam_Id

@export var my_id : String = "Rts"

=======
#@export var my_id : String = "Rts"
@export var my_id : CameraManager.my_id
>>>>>>> Stashed changes
# Variáveis internas
var target_zoom : float = 20.0
var current_zoom : float = 20.0
var camera_angle : float = -45.0 # Angulo padrão RTS






# Variáveis internas
var current_speed_scale : float = 1.0


var grid_calc = GridCalculator.new()

@onready var cursor_3d: MeshInstance3D = $"../../../Cursor3D"

@onready var gimbal = $GimbalElevation
@onready var camera: Camera3D = $GimbalElevation/Camera

func _ready():
<<<<<<< Updated upstream
	CameraManager.register_camera(my_id, camera)
	#CameraManager.register_camera(my_id,camera)
	 #Configuração inicial dos nós filhos
=======
	CameraManager.register_camera(my_id,camera,self)
	# Configuração inicial dos nós filhos
>>>>>>> Stashed changes
	if gimbal: gimbal.rotation_degrees.x = camera_angle
	if camera: camera.position.z = current_zoom
	
	# Alinha imediatamente ao iniciar
	align_to_planet()

func _process(delta):
	
	_handle_zoom(delta)
	_apply_movement(delta)
	
	# A mágica que mantém o RTS colado na esfera
	align_to_planet()



const RAY_LENGTH = 1000

func _physics_process(delta):
	var result = RayCast()
# No seu script principal


	if result.has("collider"):
		var planet_mesh = result["collider"].get_parent() # ou o mesh face
		
		# 1. Pega os dados do Grid (Face, X, Y)
		var grid_data = grid_calc.get_grid_position(planet_mesh.to_local(result.position))
		
		# 2. CALCULAR A POSIÇÃO REVERSA (Do Grid para o Mundo 3D)
		# Precisamos perguntar pro planeta: "Onde fica o centro da célula X:50, Y:20?"
		# Você precisará criar uma funçãozinha simples para isso ou usar a normal do raycast.
		
		# Truque rápido: Alinhar com a normal do Raycast
		cursor_3d.global_position = result.position
		
		# Alinha a rotação do cursor para ficar "de pé" na esfera
		var up = result.normal
		var right = up.cross(Vector3.UP).normalized() # Cria um vetor lateral provisório
		if up.is_equal_approx(Vector3.UP): right = Vector3.RIGHT # Evita erro nos polos
		var fwd = right.cross(up).normalized()
		
		cursor_3d.look_at(cursor_3d.global_position - fwd, up)

	
	
	#if result.has("collider"):
		#var planet_mesh = result["collider"].get_parent()
		#var PosSphere = result["position"]
		#var NormalSphere = result["normal"]
			#
		## Usa nossa calculadora lógica
		#var resultado = grid_calc.get_grid_position(PosSphere)
		#print(resultado)
			## resultado é algo como: { "face": 4, "x": 50, "y": 20 }
		##print(PosSphere)
		#
		#var material = planet_mesh.material_override as ShaderMaterial
		#
		#if material:
			## --- MUDANÇA AQUI ---
			## NÃO divida por float(GridCalculator.GRID_SIZE).
			## Envie o valor INTEIRO direto (Ex: Vector2(52, 41))
			#var grid_pos = Vector2(resultado.x, resultado.y)
#
			#material.set_shader_parameter("cursor_grid_id", grid_pos)
			#material.set_shader_parameter("cursor_face", resultado.face)
			#material.set_shader_parameter("show_cursor", true)
		#else:
			#print("ERRO: Nenhum material no Geometry Override!")
	#
	#
	
	if Input.is_action_just_pressed("G"):
		var meshIns : MeshInstance3D = MeshInstance3D.new()
		var boxMesh : BoxMesh = BoxMesh.new()
		boxMesh.size = Vector3(50,5,50)
		#var capsuleMesh : CapsuleMesh = CapsuleMesh.new()
		#capsuleMesh.radius = 3
		#capsuleMesh.height = 16
		meshIns.mesh = boxMesh#capsuleMesh
		meshIns.set_layer_mask_value(1,false)
		meshIns.set_layer_mask_value(2,true)
		get_tree().get_first_node_in_group("teste_cons").add_child(meshIns)
		
		#var result = RayCast()
		
		#print(result)
		if result.has("position"):
			var planet_mesh = result["collider"].get_parent()
			var PosSphere = result["position"]
			var NormalSphere = result["normal"]
			
			#print($grid.get_grid_position(PosSphere))# Usa nossa calculadora lógica
			var resultado = grid_calc.get_grid_position(PosSphere)
			
			# resultado é algo como: { "face": 4, "x": 50, "y": 20 }
			
			# Agora enviamos isso para o Shader pintar!
			#var material = planet_mesh.get_active_material(0) as ShaderMaterial
			#if material:
				## Convertemos X/Y (inteiros 0-100) de volta para UV (0.0-1.0) para o shader
				#var uv_normalizado = Vector2(resultado.x, resultado.y) / 100.0 # 100 é o tamanho do grid
				#
				#material.set_shader_parameter("cursor_uv", uv_normalizado)
				#material.set_shader_parameter("cursor_face", resultado.face)
					#
			#
			if result["position"] != Vector3.ZERO:
				var rotFinal = Quaternion(Vector3.UP,NormalSphere)
				meshIns.global_position = PosSphere
				meshIns.quaternion = rotFinal

func RayCast() -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	var cam = get_viewport().get_camera_3d()
	var mousepos = get_viewport().get_mouse_position()

	var origin = cam.project_ray_origin(mousepos)
	var end = origin + cam.project_ray_normal(mousepos) * RAY_LENGTH
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	#query.collide_with_areas = true

	var result = space_state.intersect_ray(query)
	return result


func _handle_input(delta):
	# 1. Rotação da Câmera (Girar o tabuleiro com Q/E ou Botão do Meio)
	if Input.is_key_pressed(KEY_Q):
		rotate_object_local(Vector3.UP, rotation_speed * delta)
	if Input.is_key_pressed(KEY_E):
		rotate_object_local(Vector3.UP, -rotation_speed * delta)

	# Se quiser girar com botão do meio do mouse (estilo Factorio/Captain of Industry)
	if Input.is_action_pressed("middle_click"): # Crie esse input map ou use if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		var mouse_axis = Input.get_last_mouse_velocity().x
		rotate_object_local(Vector3.UP, mouse_axis * 0.001 * delta)

func _unhandled_input(event):
	# 1. Rotação com BOTÃO DIREITO (Segurar e Arrastar)
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			# --- Rotação Horizontal (Gira o Rig inteiro) ---
			rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
			
			# --- Rotação Vertical (Gira apenas o suporte da câmera) ---
			# Aqui está a novidade: mudamos o 'gimbal', não o rig.
			if gimbal:
				# Aplica a rotação
				gimbal.rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
				
				# TRAVA DE SEGURANÇA (Clamp)
				# Impede que a câmera dê cambalhota.
				var current_rot_x = gimbal.rotation_degrees.x
				gimbal.rotation_degrees.x = clamp(current_rot_x, min_pitch, max_pitch)

	# 2. Zoom e Captura (Mantém igual)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = max(target_zoom - zoom_speed, min_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = min(target_zoom + zoom_speed, max_zoom)
			
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _handle_zoom(delta):
	# Interpolação suave do zoom
	current_zoom = lerp(current_zoom, target_zoom, smooth_speed * delta)
	if camera:
		camera.position.z = current_zoom

func _apply_movement(delta):
	var move_dir = Vector3.ZERO
	
	# Para mover, precisamos saber onde é "Frente" na visão da câmera, 
	# mas achatado no chão do Rig.
	var forward = -transform.basis.z 
	var right = transform.basis.x
	
	if Input.is_key_pressed(KEY_W): move_dir += forward
	if Input.is_key_pressed(KEY_S): move_dir -= forward
	if Input.is_key_pressed(KEY_A): move_dir -= right
	if Input.is_key_pressed(KEY_D): move_dir += right
	
	# Normaliza e aplica velocidade
	# O zoom afeta a velocidade (mais longe = mais rápido)
	var dynamic_speed = pan_speed * (current_zoom / 10.0) 
	
	# Move o Rig globalmente
	global_position += move_dir.normalized() * dynamic_speed * delta

func align_to_planet():
	# PREVENÇÃO 1: Se o Rig estiver exatamente no centro do planeta (0,0,0),
	# a direção "Cima" não existe (divisão por zero).
	if global_position.distance_to(planet_center) < 0.1:
		return # Não faz nada até sair do centro

	# 1. Calcular o vetor "Cima" real
	var up_direction = (global_position - planet_center).normalized()
	
	# PREVENÇÃO 2: Evitar que a escala do objeto se perca
	# Se a escala for (0,0,0), força para (1,1,1)
	if scale.length_squared() < 0.01:
		scale = Vector3.ONE

	# 3. Matemática de Vetores (Cross Product)
	var new_y = up_direction
	var current_x = transform.basis.x
	
	# Tenta calcular o Z (Frente) baseado no X atual
	var new_z = current_x.cross(new_y).normalized()
	
	# PREVENÇÃO 3: A Morte Súbita (Gimbal Lock)
	# Se o X estiver alinhado com o Y (resultado zero), usamos o Z antigo como fallback
	if new_z.is_zero_approx():
		new_z = transform.basis.z.cross(new_y).normalized()
		
	# Recalcula o X baseado no novo Z e Y
	var new_x = new_y.cross(new_z).normalized()
	
	# Aplica a nova base ortonormalizada
	transform.basis = Basis(new_x, new_y, new_z)
