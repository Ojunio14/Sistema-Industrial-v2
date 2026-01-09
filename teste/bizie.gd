#extends Node3D
#
#@export var planet_center : Vector3 = Vector3(0, 0, 0)
#@export var planet_radius : float = 400.0 # Altura do chão
#
#@onready var preview_path = $PreviewPath
#@onready var preview_mesh = $PreviewMesh
#
#var is_building = false
#var start_point : Vector3
#var current_mouse_point : Vector3
#
## Controla a "curvatura" automática (Tangente)
#var start_tangent : Vector3 = Vector3.ZERO 
#
#func _process(delta):
	## Supondo que você tem uma função que pega onde o mouse está no planeta
	## current_mouse_point = get_mouse_planet_position() 
	#
	#if is_building:
		#_update_preview_curve(start_point, current_mouse_point)
#
#func _input(event):
	#if event.is_action_pressed("click_build"):
		#if not is_building:
			## PRIMEIRO CLIQUE: Começa a estrada
			#is_building = true
			#start_point = current_mouse_point
			#
			## Define uma tangente inicial (ex: apontando para frente da câmera ou da ultima estrada)
			## Por enquanto, vamos deixar zero (reta)
			#start_tangent = Vector3.ZERO 
			#
		#else:
			## SEGUNDO CLIQUE: Finaliza a estrada
			#finalize_road()
			#is_building = false
			## Limpa o preview
			#preview_mesh.mesh.clear_surfaces() # Ou esconda o mesh
#
#func _update_preview_curve(p_start: Vector3, p_end: Vector3):
	#var curve = Curve3D.new()
	#
	## 1. Adiciona o Ponto Inicial
	## "in" é a tangente de entrada, "out" é a de saída
	## Se start_tangent for Vector3.ZERO, sai reto. Se tiver valor, faz curva.
	#curve.add_point(p_start, Vector3.ZERO, start_tangent)
	#
	## 2. Adiciona o Ponto Final (onde o mouse está)
	## Calculamos uma tangente automática para ficar suave
	#var dist = p_start.distance_to(p_end)
	#var auto_tangent = (p_start - p_end).normalized().cross(Vector3.UP) * (dist * 0.5)
	#
	## Adiciona o ponto final na curva matemática
	#curve.add_point(p_end, -auto_tangent, Vector3.ZERO)
	#
	## 3. A MÁGICA: Tesselação e Projeção Esférica
	## tessellate() quebra a curva matemática em vários pontinhos
	#var points = curve.tessellate(5, 1) 
	#
	## Agora criamos a malha visual baseada nesses pontos
	#var surface_tool = SurfaceTool.new()
	#surface_tool.begin(Mesh.PRIMITIVE_LINE_STRIP) # Desenha linhas conectadas
	#
	#for p in points:
		## TRUQUE: Normaliza cada ponto intermediário para colar no planeta
		## Se não fizer isso, a curva corta por dentro da terra
		#var sphere_p = (p - planet_center).normalized() * (planet_radius + 1.0) # +1m para não z-fight
		#
		#surface_tool.add_vertex(sphere_p)
		#
	## Aplica ao MeshInstance para vermos
	#preview_mesh.mesh = surface_tool.commit()
#
## Variável para carregar o modelo da estrada real (com asfalto, colisão, etc)
#@export var road_scene_prefab : PackedScene 
#
#func finalize_road():
	## 1. Verifica se pode construir (tem dinheiro? não tem obstáculo?)
	##if not check_can_build():
		##return # Cancela se não der
	#
	## 2. Instancia a estrada real
	#var new_road = road_scene_prefab.instantiate()
	#
	## 3. Adiciona ela na cena do jogo (No nó "Roads" ou "World")
	#get_parent().add_child(new_road)
	#
	## 4. Configura a curva da estrada real IGUAL à do preview
	## (Supomos que o script da estrada real tenha uma função 'set_curve')
	#
	## Recalcula a curva final baseada no ponto onde você clicou
	#var final_curve = _calculate_curve_math(start_point, current_mouse_point)
	#
	## Manda essa curva para o objeto novo
	#new_road.set_curve(final_curve)
	#
	## 5. Efeitos sonoros e visuais
	#print("Estrada Construída! Gastou 100 de Concreto.")
	#
	## O Preview será limpo/escondido logo depois no _input



extends Path3D

# --- CONFIGURAÇÕES ---
@export var raio_planeta : float = 400.0
@export var ponto_A : Vector3
@export var ponto_B : Vector3
@export_range(-2.0, 2.0) var curvatura : float = 0.5 
@export var largura_estrada : float = 4.0

func _ready():
	# Assim que o jogo começa (ou script recarrega), cria o visualizador se não existir
	if not has_node("VisualRoad"):
		_criar_visualizador()

func _process(delta):
	if not ponto_A or not ponto_B: return
	
	# 1. ATUALIZA A MATEMÁTICA DA CURVA (Igual antes)
	var inicio = ponto_A#.global_position
	var fim = ponto_B#.global_position
	var meio = (inicio + fim) / 2.0
	
	var up = meio.normalized()
	var direcao = (fim - inicio).normalized()
	var direita = direcao.cross(up)
	var ponto_controle = meio + (direita * (curvatura * 100.0))
	
	var p1 = inicio.normalized() * raio_planeta
	var p2 = ponto_controle.normalized() * raio_planeta
	var p3 = fim.normalized() * raio_planeta
	
	curve.clear_points()
	curve.add_point(p1, Vector3.ZERO, (p2 - p1) * 0.5)
	curve.add_point(p3, (p2 - p3) * 0.5, Vector3.ZERO)

# --- AQUI ESTÁ O CÓDIGO QUE VOCÊ PEDIU ---
func _criar_visualizador():
	var visual_road = CSGPolygon3D.new()
	visual_road.name = "VisualRoad" # Damos um nome para não criar duplicado
	
	# Configurações importantes para funcionar na esfera
	visual_road.mode = CSGPolygon3D.MODE_PATH
	visual_road.set_layer_mask_value(1,true)
	visual_road.set_layer_mask_value(2,true)
	visual_road.path_node = self.get_path() # Diz para seguir ESTE Path3D
	visual_road.path_interval = 1.0 # Precisão da curva (menor = mais suave)
	visual_road.path_rotation = CSGPolygon3D.PATH_ROTATION_POLYGON
	visual_road.path_joined = false
	
	# Define o formato do asfalto (Corte transversal)
	visual_road.polygon = _get_road_profile()
	
	# Define o material (Opcional - cor cinza asfalto)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2) # Cinza escuro
	visual_road.material = material
	
	get_tree().get_first_node_in_group("teste_cons").add_child(visual_road)

# Define o formato 2D da estrada (Perfil)
func _get_road_profile() -> PackedVector2Array:
	var metade = largura_estrada / 2.0
	return PackedVector2Array([
		Vector2(-metade, 0.2), # Canto superior esquerdo (+0.2 pra não clipar no chão)
		Vector2(metade, 0.2),  # Canto superior direito
		Vector2(metade, -0.5), # Grossura pra baixo
		Vector2(-metade, -0.5)
	])
