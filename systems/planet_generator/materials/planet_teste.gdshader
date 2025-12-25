shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// --- CONFIGURAÇÕES ---
group_uniforms Texturas;
uniform sampler2D texture_top : source_color, filter_linear_mipmap_anisotropic; // Grama
uniform sampler2D texture_side : source_color, filter_linear_mipmap_anisotropic; // Pedra
uniform float texture_scale = 0.5; // Tente aumentar ou diminuir isso (0.1 a 10.0)

group_uniforms Mistura;
// O PONTO CRÍTICO: 
// 1.0 = Plano perfeito. 0.0 = Parede vertical.
// Se seu terreno for muito suave, tente valores altos (0.8 ou 0.9)
uniform float slope_threshold : hint_range(0.0, 1.0) = 0.7; 
uniform float slope_smoothness : hint_range(0.0, 0.2) = 0.05;

group_uniforms Debug;
uniform bool use_debug_view = false; // ATIVE ISSO NO INSPECTOR SE DER ERRO

// Variáveis
varying vec3 v_world_pos;
varying vec3 v_world_normal;

// Função Triplanar (para não esticar no polo)
vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy) * p_weights.x;
	return samp;
}

void vertex() {
	// Calcula normais globais
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// 1. Define "O que é Cima" neste pixel?
	// Num planeta, Cima é a direção do Centro (0,0,0) para a Posição (v_world_pos)
	vec3 planet_up = normalize(v_world_pos);
	
	// 2. Calcula a inclinação (Slope)
	// Dot Product: 1.0 = Paralelo ao chão. 0.0 = 90 graus (Parede).
	float slope = dot(v_world_normal, planet_up);
	
	// 3. Cria a máscara
	// smoothstep cria a transição suave entre pedra e grama
	float mask = smoothstep(slope_threshold - slope_smoothness, slope_threshold + slope_smoothness, slope);
	
	// --- LÓGICA DE TEXTURA ---
	vec3 blend_weights = abs(v_world_normal);
	blend_weights /= (blend_weights.x + blend_weights.y + blend_weights.z);
	vec3 tex_coords = v_world_pos * texture_scale;
	
	vec3 col_top = triplanar_texture(texture_top, blend_weights, tex_coords).rgb;
	vec3 col_side = triplanar_texture(texture_side, blend_weights, tex_coords).rgb;
	
	// --- SAÍDA ---
	if (use_debug_view) {
		// DEBUG: Vermelho = Pedra, Verde = Grama
		ALBEDO = mix(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), mask);
	} else {
		// VISUAL FINAL
		ALBEDO = mix(col_side, col_top, mask);
	}
}