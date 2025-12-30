extends Resource
class_name MaterialStack

# --- ESTRUTURA DE DADOS ---
# Lista de Dicionários. Cada dicionário é uma camada:
# { "def": MaterialDefinition, "vol": float }
#
# IMPORTANTE: O índice [0] é o TOPO (Superfície).
# O último índice é o fundo do buraco.
@export var layers : Array[Dictionary] = []

# --- FUNÇÃO 1: ADICIONAR MATERIAL (DUMPING) ---
# Chamada quando um caminhão despeja terra nesta célula.
func add_material(material_def: MaterialDefinition, amount: float) -> void:
	if amount <= 0: return # Segurança: não adiciona nada se for zero

	# Cenário A: O chão está vazio (primeira vez que cai algo aqui)
	if layers.is_empty():
		# Cria a primeira camada
		layers.append({ "def": material_def, "vol": amount })
		return

	# Cenário B: Já tem algo. Vamos ver o que tem no TOPO (índice 0).
	var top_layer = layers[0]

	# Verifica se o material do topo é IGUAL ao que estamos jogando
	if top_layer["def"] == material_def:
		# Se for igual, a gente só aumenta o volume da camada existente (mistura).
		top_layer["vol"] += amount
	else:
		# Se for diferente (ex: jogando Areia em cima de Rocha),
		# criamos uma NOVA camada e inserimos na posição 0 (Topo).
		var new_layer = { "def": material_def, "vol": amount }
		layers.insert(0, new_layer) # push_front

# --- FUNÇÃO 2: ESCAVAR (MINING) ---
# Chamada pela escavadeira. Tenta remover 'amount_requested'.
# Retorna um Dicionário com o que foi extraído: { "mat": MaterialDefinition, "amount": float }
func remove_volume(amount_requested: float) -> Dictionary:
	# Segurança: Se não tem nada, retorna vazio.
	if layers.is_empty():
		return {} 

	var top_layer = layers[0]
	var current_vol = top_layer["vol"]
	var extracted_amount = 0.0
	
	# Cenário A: A camada tem MAIS ou IGUAL ao que pedimos.
	# Ex: Tem 5.0 de terra, pedimos 2.0.
	if current_vol > amount_requested:
		top_layer["vol"] -= amount_requested
		extracted_amount = amount_requested
		# A camada continua existindo, só ficou mais fina.
		
	# Cenário B: A camada tem MENOS ou EXATAMENTE o que pedimos.
	# Ex: Tem 2.0 de terra, pedimos 5.0.
	else:
		# Pegamos tudo o que tinha
		extracted_amount = current_vol
		# Removemos a camada inteira do array, pois ela acabou.
		layers.remove_at(0) # pop_front
	
	# Retorna o resultado para a escavadeira colocar no inventário dela
	return { 
		"mat": top_layer["def"], 
		"amount": extracted_amount 
	}

# --- FUNÇÃO 3: CONSULTA VISUAL ---
# O jogo precisa saber qual cor pintar no chão.
# Retorna o MaterialDefinition que está visível no topo.
func get_top_material() -> MaterialDefinition:
	if layers.is_empty():
		return null # Chão vazio/buraco infinito
	return layers[0]["def"]

# --- FUNÇÃO 4: ALTURA TOTAL ---
# Soma todas as camadas para saber a altura física dessa pilha
func get_total_height() -> float:
	var total = 0.0
	for layer in layers:
		total += layer["vol"]
	return total
