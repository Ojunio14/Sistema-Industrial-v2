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
#@export var my_id : CameraManager.Cam_Id

# Variáveis internas
var target_zoom : float = 20.0
var current_zoom : float = 20.0
var camera_angle : float = -45.0 # Angulo padrão RTS

@onready var gimbal = $GimbalElevation
@onready var camera: Camera3D = $GimbalElevation/Camera

func _ready():
	#CameraManager.register_camera(my_id,camera)
	# Configuração inicial dos nós filhos
	if gimbal: gimbal.rotation_degrees.x = camera_angle
	if camera: camera.position.z = current_zoom
	
	# Alinha imediatamente ao iniciar
	align_to_planet()

func _process(delta):
	
	_handle_zoom(delta)
	_apply_movement(delta)
	
	# A mágica que mantém o RTS colado na esfera
	align_to_planet()

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
