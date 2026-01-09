shader_type spatial;

// Parâmetros que você pode mudar no Inspector
uniform vec3 albedo_color : source_color = vec3(0.1, 0.1, 0.1); // Cor do chão
uniform vec3 grid_color : source_color = vec3(0.5, 0.8, 1.0);   // Cor da linha
uniform float grid_size = 100.0; // TEM QUE SER IGUAL AO SEU SCRIPT GDSCRIPT
uniform float line_thickness = 0.02; // Grossura da linha (0 a 1)

// Variáveis para o cursor (Highlight)
uniform bool show_cursor = true;
uniform int cursor_face = -1; // Qual face o mouse está?
uniform vec2 cursor_uv = vec2(0.0, 0.0); // Onde na face (0 a 1)?
// Vamos usar as coordenadas inteiras (Ex: 50.0, 50.0)
uniform vec2 cursor_grid_id = vec2(-1.0, -1.0);
// Função para desenhar linhas
float grid(vec2 uv, float size, float thickness) {
	vec2 grid = fract(uv * size);
	float lines = step(thickness, grid.x) * step(thickness, grid.y);
	return 1.0 - lines;
}

void fragment() {
	// 1. Cor base do planeta
	ALBEDO = albedo_color;
	
	// 2. Desenhar o Grid
	// IMPORTANTE: Isso assume que seu CubeSphere gera UVs corretamente para cada face
	float is_grid = grid(UV, grid_size, line_thickness);
	
	// Mistura a cor do chão com a cor do grid
	ALBEDO = mix(ALBEDO, grid_color, is_grid);
	
	// 3. Desenhar o Cursor (O quadrado selecionado)
	if (show_cursor) {
        // Calcula o ID do pixel atual (0 a 99)
        // Adicionamos um tiquinho (0.001) para corrigir erros de arredondamento da GPU
        vec2 my_cell_id = floor(UV * grid_size + 0.001);

        // Compara direto: "Eu sou a casa 50? O mouse está na casa 50?"
        // Usamos uma margem de erro de 0.1 para segurança, mas matematicamente é igual
        if (abs(my_cell_id.x - cursor_grid_id.x) < 0.5 && abs(my_cell_id.y - cursor_grid_id.y) < 0.5) {
             ALBEDO = mix(ALBEDO, vec3(1.0, 0.0, 0.0), 0.5); // Vermelhoelho
		}
	}
}
