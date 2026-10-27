shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.6,0.5,0.4,1.0);
uniform float treatment = 0.0;
uniform float metalness = 0.0;
uniform float surface_roughness = 0.85;
uniform float variation = 0.06;
uniform bool use_vertex_color = false;
varying vec3 world;
float hash3(vec3 p){return fract(sin(dot(p,vec3(12.9898,78.233,45.164)))*43758.5453);}
float noise3(vec3 p){vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 c=base_color.rgb;
 if(use_vertex_color){c*=mix(vec3(1.0),COLOR.rgb,0.3);}
 float n=noise3(world*2.4);
 if(treatment>0.5 && treatment<1.5){
  float brush=noise3(world*vec3(23.0,3.0,7.0));
  float grain=noise3(world*vec3(85.0,55.0,85.0));
  c*=1.0+variation*((n-.5)*.9+(brush-.5)*.7+(grain-.5)*.25);
  ROUGHNESS=clamp(surface_roughness+(brush-.5)*.15,.15,1.0);
 }else{c*=1.0+variation*(n-.5);ROUGHNESS=surface_roughness;}
 ALBEDO=c;METALLIC=metalness;SPECULAR=0.35;
}
void light(){
 float nd=max(dot(NORMAL,LIGHT),0.0);
 if(treatment>1.5){
  float band=nd>0.65?1.0:(nd>0.12?.52:.08);
  DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*band*ATTENUATION/PI;
 }else if(treatment<.5){
  float soft=smoothstep(-.12,.95,dot(NORMAL,LIGHT));
  DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*soft*ATTENUATION/PI;
 }else{
  DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*nd*ATTENUATION/PI;
 }
 if(metalness>.1){vec3 h=normalize(LIGHT+VIEW);SPECULAR_LIGHT+=LIGHT_COLOR*pow(max(dot(NORMAL,h),0.0),mix(64.0,8.0,surface_roughness))*metalness*ATTENUATION*.45;}
}
