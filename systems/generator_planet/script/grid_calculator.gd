extends Node
class_name GridCalculator

# Define o tamanho do seu grid (ex: 100x100 células por face)
const GRID_SIZE = 100 

# Essa função recebe o ponto de impacto do Raycast (Vector3)
# E retorna um Dicionário com {face, x, y}
static func get_grid_position(ponto_global: Vector3) -> Dictionary:
	
	# 1. Normalizar o ponto para trabalhar com direção
	var direcao = ponto_global.normalized()
	
	# Variáveis para guardar o resultado
	var face_index = -1
	var u = 0.0 # Vai ser a coordenada horizontal na face (-1 a 1)
	var v = 0.0 # Vai ser a coordenada vertical na face (-1 a 1)
	
	# 2. Descobrir qual é o eixo dominante
	# DICA: Use abs(direcao.x), abs(direcao.y), etc.
	var abs_x = abs(direcao.x)
	var abs_y = abs(direcao.y)
	var abs_z = abs(direcao.z)
	

	
	# LÓGICA DE DECISÃO DAS FACES (ADAPTADA PARA SUA MALHA)
	if abs_x >= abs_y and abs_x >= abs_z:
		# EIXO X (Direita/Esquerda)
		if direcao.x > 0:
			face_index = 0 # Direita
			# Ajuste: Trocamos os eixos para bater com o axisA da sua malha
			u = direcao.y / abs_x  
			v = direcao.z / abs_x  
		else:
			face_index = 1 # Esquerda
			u = direcao.z / abs_x 
			v = direcao.y / abs_x 
			
	elif abs_y >= abs_x and abs_y >= abs_z:
		# EIXO Y (Cima/Baixo)
		if direcao.y > 0:
			face_index = 2 # Cima
			u = direcao.z / abs_y
			v = direcao.x / abs_y
		else:
			face_index = 3 # Baixo
			u = direcao.x / abs_y
			v = direcao.z / abs_y
			
	else:
		# EIXO Z (Frente/Trás) - Onde você está testando (Face 4)
		if direcao.z > 0:
			face_index = 4 # Frente
			
			# ANTES ESTAVA: u = x, v = y
			# MAS SUA MALHA USA: axisA = Y (u), axisB = -X (v)
			
			u = direcao.y / abs_z        # U segue o Y
			v = -direcao.x / abs_z       # V segue o -X
			
		else:
			face_index = 5 # Trás
			u = direcao.y / abs_z
			v = direcao.x / abs_z # Talvez precise inverter sinal aqui dependendo do teste

	# ... (resto da conversão para inteiros igual) ...
	# 3. Converter de (-1, 1) para (0, GRID_SIZE)
	# O u e v estão entre -1 e 1. Precisamos transformar em 0 a 100 (inteiros)
# Para isso (Floor explícito):
	var raw_x = ((u + 1.0) * 0.5) * GRID_SIZE
	var grid_x = floori(raw_x) # Usa floori para garantir o arredondamento para baixo correto
	var grid_y = int( ((v + 1.0) * 0.5) * GRID_SIZE )
	
	# Proteção para não sair do array (clamp)
	grid_x = clampi(grid_x, 0, GRID_SIZE - 1)
	grid_y = clampi(grid_y, 0, GRID_SIZE - 1)
	
	return {"face": face_index, "x": grid_x, "y": grid_y}



# Função nova para calcular a posição 3D exata do centro de uma célula
static func get_world_position_from_grid(face_index: int, x: int, y: int, grid_size: int, radius: float) -> Vector3:
	# 1. Definir as Normais e Eixos baseados na Face (Igual ao seu script de Malha)
	var normal = Vector3.ZERO
	
	match face_index:
		0: normal = Vector3(1, 0, 0)  # Direita
		1: normal = Vector3(-1, 0, 0) # Esquerda
		2: normal = Vector3(0, 1, 0)  # Cima
		3: normal = Vector3(0, -1, 0) # Baixo
		4: normal = Vector3(0, 0, 1)  # Frente
		5: normal = Vector3(0, 0, -1) # Trás
	
	# Recalcula os eixos locais da face (Copiado da sua lógica de MeshFace)
	var axisA = Vector3(normal.y, normal.z, normal.x)
	var axisB = normal.cross(axisA)
	
	# 2. Calcular a porcentagem (UV) do CENTRO da célula (+0.5)
	# Usamos o mesmo cálculo linear do seu mesh generator
	var percent_x = (float(x) + 0.5) / float(grid_size)
	var percent_y = (float(y) + 0.5) / float(grid_size)
	
	# 3. Projetar no Cubo Unitário
	var pointOnUnitCube = normal + (percent_x - 0.5) * 2.0 * axisA + (percent_y - 0.5) * 2.0 * axisB
	
	# 4. Normalizar para esfera e multiplicar pelo raio
	return pointOnUnitCube.normalized() * radius
