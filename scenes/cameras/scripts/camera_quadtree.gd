extends Camera3D

# --- ADICIONADO: Posição do Planeta ---
@export var planet_center : Vector3 = Vector3.ZERO

# Configurações de Sensibilidade e Velocidade
@export_group("Controles da Câmera")
@export var mouse_sensitivity : float = 0.002
@export var base_speed : float = 10.0
@export var boost_multiplier : float = 5.0  # Multiplicador ao segurar Shift
@export var max_speed_scale : float = 100.0 # Para viajar rápido pelo planeta

@export var my_id : CameraManager.my_id



# Variáveis internas
var current_speed_scale : float = 1.0


var grid_calc = GridCalculator.new()

@onready var cursor_3d: MeshInstance3D = $"../../../Cursor3D"


func _ready():
	CameraManager.register_camera(my_id, self,self)
	# Captura o mouse para ele não sair da tela
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# 1. Rotação da Câmera (Mouse)
	if event is InputEventMouseMotion:
		# --- MUDANÇA AQUI ---
		# Em vez de rotate_y (global), giramos em torno do eixo "Cima" local da câmera
		# Isso permite virar a cabeça esquerda/direita independente da gravidade
		rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
		
		# Rotação vertical (X) - Gira a câmera localmente (Olhar pra cima/baixo)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
		
		# Removemos o "rotation.z = 0" daqui porque ele quebra a rotação esférica.
		# A correção do horizonte será feita no _process.

	# 2. Controle de Velocidade (Scroll do Mouse)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_speed_scale = min(current_speed_scale * 1.1, max_speed_scale)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_speed_scale = max(current_speed_scale * 0.9, 0.1)
	
	# 3. Sair do modo captura (Tecla ESC)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	if Input.is_action_just_pressed("G"):
		var meshIns : MeshInstance3D = MeshInstance3D.new()
		var boxMesh : BoxMesh = BoxMesh.new()
		boxMesh.size = Vector3(4,5,4)
		var capsuleMesh : CapsuleMesh = CapsuleMesh.new()
		capsuleMesh.radius = 3
		capsuleMesh.height = 16
		meshIns.mesh = boxMesh#capsuleMesh
		meshIns.set_layer_mask_value(1, false)
		meshIns.set_layer_mask_value(2, true)
		#get_tree().get_first_node_in_group("Teste").add_child(meshIns)
		
		var result = RayCast()
		if result.has("position"):
			get_tree().get_first_node_in_group("teste_cons").add_child(meshIns)
			print(result)
			var NormalSphere = result["normal"]
			var rotFinal = Quaternion(Vector3.UP,NormalSphere)
			meshIns.global_position = result["position"]
			meshIns.quaternion = rotFinal
			
	# Se o mouse não estiver capturado, não move
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	# --- 1. MOVIMENTAÇÃO ---
	var speed = base_speed * current_speed_scale
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= boost_multiplier

	var velocity = Vector3.ZERO

	# Movimentação WASD (Local)
	if Input.is_key_pressed(KEY_W): velocity += Vector3.FORWARD
	if Input.is_key_pressed(KEY_S): velocity += Vector3.BACK
	if Input.is_key_pressed(KEY_A): velocity += Vector3.LEFT
	if Input.is_key_pressed(KEY_D): velocity += Vector3.RIGHT
	
	# Movimentação Vertical (Q/E)
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE): 
		velocity += Vector3.UP
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL): 
		velocity += Vector3.DOWN

	velocity = velocity.normalized()

	# Aplica o movimento na direção que a câmera está olhando
	# Usamos Basis local para garantir que W vá para frente da lente
	var global_velocity = transform.basis * (velocity * speed * delta)
	global_position += global_velocity

	# --- 2. CORREÇÃO DE HORIZONTE (A Mágica do Planeta) ---
	# Chamamos a função que recalcula a rotação para alinhar com o planeta
	align_horizon_to_planet()


<<<<<<< Updated upstream
const RAY_LENGTH : = 4000
=======

const RAY_LENGTH = 1000
#
#func _physics_process(delta):
	#var result = RayCast()
## No seu script principal
#
#
	#if result.has("collider"):
		#var planet_mesh = result["collider"].get_parent() # ou o mesh face
		#
		## 1. Pega os dados do Grid (Face, X, Y)
		#var grid_data = grid_calc.get_grid_position(planet_mesh.to_local(result.position))
		#
		## 2. CALCULAR A POSIÇÃO REVERSA (Do Grid para o Mundo 3D)
		## Precisamos perguntar pro planeta: "Onde fica o centro da célula X:50, Y:20?"
		## Você precisará criar uma funçãozinha simples para isso ou usar a normal do raycast.
		#
		## Truque rápido: Alinhar com a normal do Raycast
		#cursor_3d.global_position = result.position
		#
		## Alinha a rotação do cursor para ficar "de pé" na esfera
		#var up = result.normal
		#var right = up.cross(Vector3.UP).normalized() # Cria um vetor lateral provisório
		#if up.is_equal_approx(Vector3.UP): right = Vector3.RIGHT # Evita erro nos polos
		#var fwd = right.cross(up).normalized()
		#
		#cursor_3d.look_at(cursor_3d.global_position - fwd, up)
#
	#
	#
	##if result.has("collider"):
		##var planet_mesh = result["collider"].get_parent()
		##var PosSphere = result["position"]
		##var NormalSphere = result["normal"]
			##
		### Usa nossa calculadora lógica
		##var resultado = grid_calc.get_grid_position(PosSphere)
		##print(resultado)
			### resultado é algo como: { "face": 4, "x": 50, "y": 20 }
		###print(PosSphere)
		##
		##var material = planet_mesh.material_override as ShaderMaterial
		##
		##if material:
			### --- MUDANÇA AQUI ---
			### NÃO divida por float(GridCalculator.GRID_SIZE).
			### Envie o valor INTEIRO direto (Ex: Vector2(52, 41))
			##var grid_pos = Vector2(resultado.x, resultado.y)
##
			##material.set_shader_parameter("cursor_grid_id", grid_pos)
			##material.set_shader_parameter("cursor_face", resultado.face)
			##material.set_shader_parameter("show_cursor", true)
		##else:
			##print("ERRO: Nenhum material no Geometry Override!")
	##
	##
	#
	#if Input.is_action_just_pressed("G"):
		#var meshIns : MeshInstance3D = MeshInstance3D.new()
		#var boxMesh : BoxMesh = BoxMesh.new()
		#boxMesh.size = Vector3(50,5,50)
		##var capsuleMesh : CapsuleMesh = CapsuleMesh.new()
		##capsuleMesh.radius = 3
		##capsuleMesh.height = 16
		#meshIns.mesh = boxMesh#capsuleMesh
		#meshIns.set_layer_mask_value(1,false)
		#meshIns.set_layer_mask_value(2,true)
		#get_tree().get_first_node_in_group("teste_cons").add_child(meshIns)
		#
		##var result = RayCast()
		#
		##print(result)
		#if result.has("position"):
			#var planet_mesh = result["collider"].get_parent()
			#var PosSphere = result["position"]
			#var NormalSphere = result["normal"]
			#
			##print($grid.get_grid_position(PosSphere))# Usa nossa calculadora lógica
			#var resultado = grid_calc.get_grid_position(PosSphere)
			#
			## resultado é algo como: { "face": 4, "x": 50, "y": 20 }
			#
			## Agora enviamos isso para o Shader pintar!
			##var material = planet_mesh.get_active_material(0) as ShaderMaterial
			##if material:
				### Convertemos X/Y (inteiros 0-100) de volta para UV (0.0-1.0) para o shader
				##var uv_normalizado = Vector2(resultado.x, resultado.y) / 100.0 # 100 é o tamanho do grid
				##
				##material.set_shader_parameter("cursor_uv", uv_normalizado)
				##material.set_shader_parameter("cursor_face", resultado.face)
					##
			##
			#if result["position"] != Vector3.ZERO:
				#var rotFinal = Quaternion(Vector3.UP,NormalSphere)
				#meshIns.global_position = PosSphere
				#meshIns.quaternion = rotFinal
>>>>>>> Stashed changes

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



func align_horizon_to_planet():
	# SEGURANÇA 1: Não calcular se estivermos muito perto do centro (evita divisão por zero)
	if global_position.distance_squared_to(planet_center) < 1.0:
		return 

	# 1. Descobrir onde é "Cima" no planeta
	var planet_up = (global_position - planet_center).normalized()
	
	# SEGURANÇA 2: Se a normalização falhou (deu zero), aborta
	if planet_up.is_zero_approx():
		return

	# 2. Descobrir para onde a câmera está olhando agora (Frente)
	var camera_forward = -transform.basis.z
	
	# PREVENÇÃO DE GIMBAL LOCK
	# Se a câmera estiver olhando quase perfeitamente para cima/baixo em relação ao planeta
	if abs(camera_forward.dot(planet_up)) > 0.99:
		return

	# 3. Recalcular o vetor "Direita"
	var new_right = camera_forward.cross(planet_up).normalized()
	
	# SEGURANÇA 3: Se o cross product deu zero (vetores paralelos que passaram pelo check), aborta
	if new_right.is_zero_approx():
		return
	
	# 4. Recalcular o vetor "Cima" da câmera
	var new_camera_up = new_right.cross(camera_forward).normalized()
	
	# 5. Aplicar a nova base
	# Nota: Criar uma Basis assim reseta a escala da Câmera para (1,1,1). Isso é bom.
	var nova_basis = Basis(new_right, new_camera_up, -camera_forward)
	
	# SEGURANÇA FINAL: Verifica se a nova base é válida (determinante != 0)
	if not is_zero_approx(nova_basis.determinant()):
		transform.basis = nova_basis

func mouse_captured():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

#func _exit_tree():
	## Avisa o gerente que eu fui destruída (mudei de cena)
	#CameraManager.unregister_camera(my_id)
