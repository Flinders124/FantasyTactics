shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(.5,.6,.7,1);
uniform float metalness = 0.0;
uniform float surface_roughness = .85;
uniform float treatment = 2.0;
uniform float variation = .025;
uniform bool use_vertex_color = false;
uniform float rim_strength = 0.0;
uniform float sway = 0.0;
uniform float fade_opacity = 1.0;
uniform float surface_kind = 0.0;
varying vec3 world;
void vertex(){VERTEX.x+=sin(TIME*1.15+VERTEX.y*2.0+NODE_POSITION_WORLD.x*1.7+NODE_POSITION_WORLD.z)*clamp(VERTEX.y,0.0,1.0)*sway;world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 vec3 c=base_color.rgb;
 if(use_vertex_color){c*=mix(.78,1.12,clamp(dot(COLOR.rgb,vec3(.2126,.7152,.0722)),0.0,1.0));}
 // Sparse, broad chisel bands, kept off skin and cloth. No high-frequency noise.
 if(surface_kind<.5){c*=.96+.04*sin(world.y*9.0+world.x*.4);}
 if(surface_kind>1.5 && surface_kind<2.5){
  float wear=sin(world.x*.41+sin(world.z*.23))*sin(world.z*.36);
  c*=.95+.065*wear;
  c=mix(c,c*vec3(1.07,1.025,.96),smoothstep(.2,.85,wear)*.36);
 }
 ALPHA=fade_opacity;ALBEDO=c;ROUGHNESS=surface_roughness;METALLIC=metalness;SPECULAR=.32;
 float edge=pow(1.0-max(dot(NORMAL,VIEW),0.0),3.0);
 EMISSION=c*edge*rim_strength;
}
void light(){
 float nd=dot(NORMAL,LIGHT);
 float band=nd>.62?1.0:(nd>.08?.56:.16);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*band*ATTENUATION/PI;
 if(metalness>.15){
  vec3 half_vector=normalize(LIGHT+VIEW);
  float glint=pow(max(dot(NORMAL,half_vector),0.0),mix(70.0,10.0,surface_roughness));
  SPECULAR_LIGHT+=LIGHT_COLOR*glint*metalness*ATTENUATION*.38;
 }
}
