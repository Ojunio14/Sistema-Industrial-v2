extends Node

# Dicionário para guardar as câmeras registradas: {"FreeFly": CameraNode, "Orbital": CameraNode}
var cameras : Dictionary = {}


# Dicionário para guardar o node main da câmeras registradas: {"FreeFly": CameraNode, "Orbital": CameraNode}
var main : Dictionary = {}


var current_camera : Camera3D = null
var Camera

enum my_id {Orbital,FreeFly_Quadtree,Rts}

#func _ready() -> void:
	#switch_to_camera(my_id.Orbital)


func switch_to_camera(value):
	match value:
	
		my_id.Orbital:
			active_camera(value)
			desativar_camera(value)
			switch_to(value)
			
		my_id.FreeFly_Quadtree:
			active_camera(value)
			desativar_camera(value)
			switch_to(value)
			
		my_id.Rts:
			active_camera(value)
			desativar_camera(value)
			switch_to(value)
			
func active_camera(value):
	
	if value == my_id.Orbital:
		main[my_id.Orbital].process_mode = Node.PROCESS_MODE_INHERIT
		
	elif  value == my_id.FreeFly_Quadtree:
		
		main[my_id.FreeFly_Quadtree].process_mode = Node.PROCESS_MODE_INHERIT
	elif value == my_id.Rts:
		
		main[my_id.Rts].process_mode = Node.PROCESS_MODE_INHERIT

func desativar_camera(value):
	
	if !value == my_id.Orbital:
		main[my_id.Orbital].process_mode = Node.PROCESS_MODE_DISABLED
		
	if  !value == my_id.FreeFly_Quadtree:
		main[my_id.FreeFly_Quadtree].process_mode = Node.PROCESS_MODE_DISABLED
		
	if !value == my_id.Rts:
		main[my_id.Rts].process_mode = Node.PROCESS_MODE_DISABLED
	
func switch_scaled_to_local():
	
<<<<<<< Updated upstream
	switch_to("Rts")
=======
	#switch_to("FreeFly")
>>>>>>> Stashed changes
	
	pass

# Registra uma câmera nova (A câmera chama isso quando nasce)
func register_camera(camera_name: int, camera_node: Camera3D, node):
	cameras[camera_name] = camera_node
	main[camera_name] = node
	#print("Camera Manager: Câmera '" + camera_name + "' registrada.")

# Remove (A câmera chama isso quando morre/é destruída)
func unregister_camera(camera_name: String):
	if cameras.has(camera_name):
		cameras.erase(camera_name)

# A função mágica que troca a visão
func switch_to(camera_name: int):
	if not cameras.has(camera_name):
		push_error("Camera Manager: Câmera '" , camera_name , "' não encontrada!")
		return
	
	var next_cam = cameras[camera_name]
	
	# Desativa a anterior (opcional, dependendo da sua lógica)
	# if current_camera: current_camera.current = false
	
	# Ativa a nova
	next_cam.make_current() # Função nativa da Godot que assume o controle
	#if next_cam.my_id == "FreeFly" and next_cam != null :
		#print(next_cam.my_id)
		#next_cam.mouse_captured()
		#next_cam.Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	current_camera = next_cam
	
	print("Camera Manager: Trocado para " , camera_name)

# Exemplo: Alternar entre câmeras com uma tecla
#func _unhandled_input(event):
	#if event.is_action_pressed("change_cam_view"): # Crie esse input map
		## Exemplo simples de toggle
		#if current_camera == cameras.get("FreeFly"):
			#switch_to("Orbital")
		##elif current_camera == cameras.get
		#else:
			#switch_to("Rts")#switch_to("FreeFly")
