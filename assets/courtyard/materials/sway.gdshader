shader_type spatial;
render_mode cull_disabled;
void vertex() {
 VERTEX.x += sin(TIME * 1.15 + VERTEX.y * 2.0 + NODE_POSITION_WORLD.x * 1.7 + NODE_POSITION_WORLD.z) * clamp(VERTEX.y, 0.0, 1.0) * 0.025;
}
void fragment() { ALBEDO = COLOR.rgb; ROUGHNESS = 0.95; }
