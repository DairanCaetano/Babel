shader_type canvas_item;

uniform float spinning_speed = 4.0;
uniform float time_speed = 4.0;
uniform bool is_active = false;

void vertex() {
	if (is_active) {
		VERTEX.y += cos(TIME * time_speed) * spinning_speed;
	}

  //VERTEX += vec2(
		//cos(TIME * time_speed) * spinning_speed,
		//sin(TIME * time_speed) * spinning_speed
	//);
}
