shader_type sky;

uniform vec3 color_top : source_color = vec3(0.91, 0.14, 1);
uniform vec3 color_horizon : source_color = vec3(1, 0.4, 0.42);
uniform vec3 color_bottom : source_color = vec3(1, 0.74, 0.39);

uniform float exponent_factor_top : hint_range(0, 100) = 1.0;
uniform float exponent_factor_bottom : hint_range(0, 100) = 1.0;
uniform float intensity_amp : hint_range(0, 1) = 1.0;

void sky() {
	float p = EYEDIR.y;
	float p1 = 1.0f - pow(min(1.0f, 1.0f - p), exponent_factor_top);
	float p3 = 1.0f - pow(min(1.0f, 1.0f + p), exponent_factor_bottom);
	float p2 = 1.0f - p1 - p3;
	
	COLOR = (
		color_top * p1 +
		color_horizon * p2 +
		color_bottom * p3
	) * intensity_amp;
}