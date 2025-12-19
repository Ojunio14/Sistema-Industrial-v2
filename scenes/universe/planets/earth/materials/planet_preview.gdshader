shader_type spatial;
// render_mode unshaded; // Descomente se quiser sem sombras

uniform sampler2D planeta_textura : source_color, filter_linear_mipmap;



// Criamos uma variável para transportar dados do Vertex para o Fragment
varying vec3 normal_objeto;

void vertex() {
	// Aqui o NORMAL é relativo ao objeto (Object Space).
	// Nós salvamos ele na nossa variável para usar depois.
	normal_objeto = NORMAL;
}

void fragment() {
	// Usamos a normal que veio do vertex (que está presa ao objeto)
	vec3 direcao = normalize(normal_objeto);

	// O resto da matemática continua igual
	float u = 0.5 + atan(direcao.z, direcao.x) / TAU;
	float v = 0.5 - asin(direcao.y) / PI;

	vec2 uv_sferico = vec2(u, v);

	vec4 cor_da_imagem = texture(planeta_textura, uv_sferico);
	
	ALBEDO = cor_da_imagem.rgb;
}