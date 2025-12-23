shader_type spatial;

// --- CONFIGURAÇÃO DAS TEXTURAS ---
group_uniforms Texturas;

// A Textura "Padrão" (Onde não tem cor pintada)
uniform sampler2D tex_base : source_color, filter_linear_mipmap_anisotropic;

// As Texturas dos Biomas (ID 0 a 6)
uniform sampler2D tex_0 : source_color, filter_linear_mipmap_anisotropic; // Vermelho
uniform sampler2D tex_1 : source_color, filter_linear_mipmap_anisotropic; // Verde
uniform sampler2D tex_2 : source_color, filter_linear_mipmap_anisotropic; // Azul
uniform sampler2D tex_3 : source_color, filter_linear_mipmap_anisotropic; // Amarelo
uniform sampler2D tex_4 : source_color, filter_linear_mipmap_anisotropic; // Ciano
uniform sampler2D tex_5 : source_color, filter_linear_mipmap_anisotropic; // Magenta
uniform sampler2D tex_6 : source_color, filter_linear_mipmap_anisotropic; // Laranja

group_uniforms Ajustes;
uniform float uv_scale : hint_range(0.001, 1.0) = 0.05;
uniform float blend_sharpness : hint_range(1.0, 20.0) = 4.0;

// Variáveis de Transporte (Vertex -> Fragment)
varying vec3 v_pos_local;
varying vec3 v_normal_local;

void vertex() {
	// Trava a posição e normal para a textura não "nadar"
	v_pos_local = VERTEX;
	v_normal_local = NORMAL;
}

vec3 triplanar(sampler2D t, vec3 pos, vec3 normal) {
	vec3 weights = abs(normal);
	weights = pow(weights, vec3(blend_sharpness));
	weights = weights / (weights.x + weights.y + weights.z);

	vec3 tex_x = texture(t, pos.yz * uv_scale).rgb * weights.x;
	vec3 tex_y = texture(t, pos.xz * uv_scale).rgb * weights.y;
	vec3 tex_z = texture(t, pos.xy * uv_scale).rgb * weights.z;

	return tex_x + tex_y + tex_z;
}

void fragment() {
	// Recupera o ID (0 a 255)
	int id = int((COLOR.r * 255.0) + 0.1);

	vec3 cor_final = vec3(0.0);

	// A GRANDE ÁRVORE DE DECISÃO
	if (id == 255) {
		cor_final = triplanar(tex_base, v_pos_local, v_normal_local);
	}
	else if (id == 0) {
		cor_final = triplanar(tex_0, v_pos_local, v_normal_local);
	}
	else if (id == 1) {
		cor_final = triplanar(tex_1, v_pos_local, v_normal_local);
	}
	else if (id == 2) {
		cor_final = triplanar(tex_2, v_pos_local, v_normal_local);
	}
	else if (id == 3) {
		cor_final = triplanar(tex_3, v_pos_local, v_normal_local);
	}
	else if (id == 4) {
		cor_final = triplanar(tex_4, v_pos_local, v_normal_local);
	}
	else if (id == 5) {
		cor_final = triplanar(tex_5, v_pos_local, v_normal_local);
	}
	else if (id == 6) {
		cor_final = triplanar(tex_6, v_pos_local, v_normal_local);
	}
	else {
		// Se der erro (ID desconhecido), pinta de rosa
		cor_final = vec3(1.0, 0.0, 1.0);
	}

	ALBEDO = cor_final;
	ROUGHNESS = 0.8;
}