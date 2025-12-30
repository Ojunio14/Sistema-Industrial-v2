# Nome do arquivo: MaterialDefinition.gd
extends Resource
class_name MaterialDefinition

# -- O QUE VOCÊ PRECISA COLOCAR AQUI --
# 1. Uma variável para o ID (String) - para o código saber quem é quem.
# 2. Uma variável para o Nome (String) - para mostrar na UI do jogo.
# 3. Uma variável para a Cor (Color) - para pintar o terreno depois.
# 4. (Opcional) Dureza (float) - para definir velocidade de mineração.

# --- CONFIGURAÇÃO NO INSPECTOR ---

# O ID é crucial para o código (ex: "iron_ore", "dirt"). 
# Usamos StringName porque é mais rápido que String normal para comparações.
@export var id : StringName

# Nome bonitinho para aparecer na UI do jogador (ex: "Minério de Ferro Rico")
@export var display_name : String

# A cor que vai aparecer no chão (Terrain Shader) e no Debug
@export var albedo_color : Color = Color.GRAY

# Quanto pesa por unidade de volume? (Opcional agora, útil para física de caminhões depois)
@export var density : float = 1.0

# Dureza: Define quanto tempo a escavadeira demora para tirar 1 unidade.
# 1.0 = Normal, 2.0 = Demora o dobro, 0.5 = Metade do tempo (areia)
@export var hardness : float = 1.0
