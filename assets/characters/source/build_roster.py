"""Original low-poly roster. Python 3 standard library only; rebuilds skinned GLBs.
Editable loft profiles, silhouettes, palette, bind rig and animation curves live here.
Coordinates: metres, Y up, face -Z. No third-party art or generated bitmap assets.
"""
import json, math, struct
from pathlib import Path
from collections import defaultdict

OUT = Path(__file__).resolve().parents[1] / 'models'
ROLES = ['knight', 'ranger', 'mage', 'cleric', 'raider', 'sentinel']
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def add(a,b): return tuple(x+y for x,y in zip(a,b))
def mul(a,s): return tuple(x*s for x in a)
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(a):
    d=math.sqrt(sum(x*x for x in a)); return mul(a,1/d) if d else (0,1,0)
def quat(axis,degrees):
    s=math.sin(math.radians(degrees)/2); return [axis[0]*s,axis[1]*s,axis[2]*s,math.cos(math.radians(degrees)/2)]

# Shared 20-joint hierarchy; equipment is weighted to hand/back joints.
RIG=[('root',-1,(0,0,0)),('hips',0,(0,.85,0)),('spine',1,(0,1.03,0)),('chest',2,(0,1.24,0)),('neck',3,(0,1.43,0)),('head',4,(0,1.50,0))]
for side,s in [('L',-1),('R',1)]:
    base=len(RIG)
    RIG += [(side+'_arm',3,(s*.29,1.32,0)),(side+'_forearm',base,(s*.40,1.08,-.015)),(side+'_hand',base+1,(s*.46,.88,-.04))]
for side,s in [('L',-1),('R',1)]:
    base=len(RIG)
    RIG += [(side+'_thigh',1,(s*.14,.82,0)),(side+'_shin',base,(s*.15,.46,0)),(side+'_foot',base+1,(s*.15,.12,-.025))]
J={name:i for i,(name,_,_) in enumerate(RIG)}

class Model:
    def __init__(self,role):
        self.role=role; self.parts=defaultdict(list)
        hostile=role in ('raider','sentinel')
        self.palette=[('skin',(.49,.63,.40) if hostile else (.72,.49,.32),0, .9),
          ('cloth', {'knight':(.10,.26,.42),'ranger':(.15,.31,.22),'mage':(.23,.15,.43),'cleric':(.77,.72,.55),'raider':(.39,.10,.08),'sentinel':(.27,.09,.15)}[role],0,.93),
          ('steel',(.24,.29,.32) if hostile else (.45,.56,.62),.65,.38),('leather',(.15,.085,.047),0,.9),
          ('gold',(.74,.46,.12),.65,.35),('hair',(.08,.075,.065) if hostile else (.22,.12,.065),0,.98),
          ('light',(.75,.87,.81),0,.65),('magic',(.16,.72,.85) if not hostile else (.94,.37,.13),.15,.3)]
    def tri(self,a,b,c,mat,bone):
        n=norm(cross(sub(b,a),sub(c,a)))
        if sum(abs(x) for x in sub(a,b))<1e-7:return
        self.parts[mat].extend([(p,n,J[bone]) for p in (a,b,c)])
    def loft(self,rings,mat,bone,n=8):
        # Each ring: centre xyz, elliptical half widths x/z. Shaped, capped solid.
        rows=[]
        for x,y,z,rx,rz in rings:
            rows.append([(x+rx*math.cos(2*math.pi*i/n),y,z+rz*math.sin(2*math.pi*i/n)) for i in range(n)])
        for a,b in zip(rows,rows[1:]):
            for i in range(n):
                k=(i+1)%n
                self.tri(a[i],b[i],b[k],mat,bone);self.tri(a[i],b[k],a[k],mat,bone)
        for row,reverse in [(rows[0],True),(rows[-1],False)]:
            center=tuple(sum(p[j] for p in row)/n for j in range(3))
            for i in range(n):
                a,b=row[i],row[(i+1)%n]
                self.tri(center,b,a,mat,bone) if reverse else self.tri(center,a,b,mat,bone)
    def tube(self,points,radii,mat,bone,n=6):
        # Curved sweep used for bows, fingers, horns, shafts, straps.
        rows=[]
        for i,p in enumerate(points):
            tangent=norm(sub(points[min(i+1,len(points)-1)],points[max(0,i-1)]))
            u=norm(cross(tangent,(0,0,1) if abs(tangent[2])<.9 else (1,0,0)));v=cross(tangent,u)
            rows.append([add(p,add(mul(u,radii[i]*math.cos(2*math.pi*k/n)),mul(v,radii[i]*math.sin(2*math.pi*k/n)))) for k in range(n)])
        for a,b in zip(rows,rows[1:]):
            for i in range(n):
                k=(i+1)%n;self.tri(a[i],a[k],b[k],mat,bone);self.tri(a[i],b[k],b[i],mat,bone)
        for row,p,flip in [(rows[0],points[0],False),(rows[-1],points[-1],True)]:
            for i in range(n):
                a,b=row[i],row[(i+1)%n];self.tri(p,b,a,mat,bone) if flip else self.tri(p,a,b,mat,bone)
    def plate(self,outline,z,depth,mat,bone):
        # Bevelled convex silhouette, front ridge, back and edge faces.
        front=[(x,y,z) for x,y in outline];back=[(x,y,z+depth) for x,y in outline]
        center=(sum(p[0] for p in front)/len(front),sum(p[1] for p in front)/len(front),z-.025)
        rear=(center[0],center[1],z+depth)
        for i in range(len(front)):
            k=(i+1)%len(front)
            self.tri(center,front[i],front[k],mat,bone);self.tri(rear,back[k],back[i],mat,bone)
            self.tri(front[i],back[i],back[k],mat,bone);self.tri(front[i],back[k],front[k],mat,bone)
    def build(self):
        r=self.role;armored=r in ('knight','cleric','raider'); robe=r in ('mage','cleric'); enemy=r in ('raider','sentinel')
        # Anatomical tapered boots, bent calf profiles, thighs, fitted waist and ribcage.
        for side,s in [('L',-1),('R',1)]:
            x=s*.145
            self.loft([(x,.025,-.055,.115,.19),(x,.09,-.065,.12,.20),(x,.18,-.025,.088,.11),(x,.30,0,.077,.08)],3,side+'_foot')
            self.loft([(x,.18,0,.065,.067),(x,.36,.018,.083,.082),(x,.49,-.01,.073,.073)],2 if armored else 1,side+'_shin')
            self.loft([(x,.44,0,.075,.08),(x,.67,0,.11,.105),(x,.87,0,.12,.12)],1,side+'_thigh')
        self.loft([(0,.79,0,.23,.14),(0,.94,0,.21,.13),(0,1.06,0,.185,.125)],3,'hips')
        self.loft([(0,.96,0,.19,.135),(0,1.13,0,.225,.15),(0,1.29,0,.28,.17),(0,1.37,0,.22,.13)],2 if armored else 1,'chest',10)
        self.loft([(0,.94,0,.215,.15),(0,.99,0,.216,.151)],4,'hips',10)
        self.plate([(-.045,.94),(.045,.94),(.045,1.005),(-.045,1.005)],-.159,.025,2,'hips')
        if robe:
            self.loft([(0,.16,0,.32,.24),(0,.22,0,.335,.25),(0,.55,0,.29,.22),(0,.85,0,.23,.16),(0,1.0,0,.205,.14)],1,'hips',12)
            self.loft([(0,.16,0,.323,.243),(0,.21,0,.338,.253)],4,'hips',12)
            self.plate([(-.075,.19),(.075,.19),(.065,.95),(-.065,.95)],-.253,.018,6 if r=='cleric' else 4,'hips')
        else:
            for s in [-1,1]:
                self.plate([(s*.02,.94),(s*.23,.95),(s*.28,.71),(s*.10,.68)],-.16,.05,1,'hips')
        # Neck, angular jaw, cheekbones, ears, brow, eyes, sculpted nose.
        self.loft([(0,1.36,0,.075,.075),(0,1.51,0,.078,.073)],0,'neck')
        self.loft([(0,1.46,-.01,.08,.075),(0,1.50,-.018,.105,.095),(0,1.60,0,.14,.12),(0,1.71,.008,.13,.115),(0,1.77,.012,.075,.075)],0,'head',10)
        self.loft([(0,1.68,.016,.14,.117),(0,1.75,.02,.13,.105),(0,1.80,.018,.065,.06)],5,'head',10)
        for s in [-1,1]:
            self.tube([(s*.115,1.60,0),(s*(.20 if enemy else .155),1.66,-.005),(s*.13,1.55,-.005)],[.037,.008,.025],0,'head',5)
            self.plate([(s*.023,1.633),(s*.093,1.633),(s*.09,1.657),(s*.023,1.66)],-.112,.015,6,'head')
            self.plate([(s*.052,1.637),(s*.071,1.637),(s*.071,1.656),(s*.052,1.656)],-.13,.008,5,'head')
            self.tube([(s*.02,1.675,-.112),(s*.095,1.667,-.11)],[.014,.011],5,'head',4)
        self.plate([(-.025,1.57),(.025,1.57),(0,1.65)],-.157,.05,0,'head')
        self.tube([(-.035,1.533,-.105),(.035,1.533,-.105)],[.008,.008],5,'head',4)
        # Arms have shoulder, elbow, forearm and articulated hand weights.
        for side,s in [('L',-1),('R',1)]:
            self.loft([(s*.40,1.06,-.015,.071,.075),(s*.34,1.19,0,.083,.085),(s*.285,1.34,0,.105,.105)],1,side+'_arm')
            self.loft([(s*.46,.87,-.04,.055,.06),(s*.44,.98,-.025,.075,.075),(s*.40,1.09,-.015,.072,.073)],2 if armored else 3,side+'_forearm')
            self.loft([(s*.46,.78,-.04,.049,.045),(s*.47,.86,-.04,.058,.055),(s*.46,.90,-.04,.05,.045)],3 if armored else 0,side+'_hand')
            for k in range(3):
                self.tube([(s*.44+k*.018,.82,-.083),(s*.44+k*.018,.777,-.087),(s*.44+k*.018,.76,-.06)],[.013,.012,.008],3 if armored else 0,side+'_hand',4)
            if armored:
                self.loft([(s*.29,1.28,0,.14,.15),(s*.29,1.36,0,.145,.155),(s*.29,1.42,0,.08,.095)],2,side+'_arm')
                self.loft([(s*.29,1.275,0,.144,.154),(s*.29,1.30,0,.15,.16)],4 if not enemy else 3,side+'_arm')
        # Tabards, capes, hoods, emblems and headgear define the silhouettes.
        if r in ('knight','cleric'):
            self.plate([(-.10,1.04),(.10,1.04),(.10,1.32),(0,1.37),(-.10,1.32)],-.18,.025,1,'chest')
            self.plate([(-.065,1.18),(.065,1.18),(0,1.30)],-.216,.025,4,'chest')
            self.tube([(0,1.17,-.255),(0,1.31,-.255)],[.014,.014],6,'chest',4)
            self.tube([(-.045,1.25,-.255),(.045,1.25,-.255)],[.014,.014],6,'chest',4)
        if r=='knight':
            self.loft([(0,1.68,.01,.145,.127),(0,1.77,.01,.145,.127),(0,1.84,.02,.07,.07)],2,'head',10)
            self.tube([(0,1.78,.09),(0,1.98,.01),(0,1.86,-.09)],[.045,.04,.02],1,'head',5)
        if r in ('ranger','sentinel'):
            # Hood is open at the face; swept rim outlines hair without covering eyes.
            self.tube([(-.14,1.48,.015),(-.17,1.68,.02),(-.09,1.84,.025),(0,1.87,.025),(.09,1.84,.025),(.17,1.68,.02),(.14,1.48,.015)],[.04,.055,.06,.065,.06,.055,.04],1,'head',6)
            self.plate([(-.24,1.32),(.24,1.32),(.29,.76),(0,.65),(-.29,.76)],.19,.025,1,'chest')
            self.tube([(-.22,1.32,-.18),(.17,1.02,-.17)],[.035,.035],3,'chest',4)
        if r=='mage':
            self.loft([(0,1.75,0,.20,.18),(0,1.80,0,.20,.18),(0,1.88,.025,.125,.12),(0,2.02,.08,.065,.065),(.05,2.13,.10,.008,.008)],1,'head',10)
            self.loft([(0,1.79,0,.195,.175),(0,1.83,.01,.16,.15)],4,'head',10)
            self.plate([(-.22,1.35),(.22,1.35),(.28,.83),(0,.73),(-.28,.83)],.19,.025,1,'chest')
        if r=='cleric':
            self.loft([(0,1.71,.005,.14,.12),(0,1.79,.01,.11,.10),(0,1.84,.01,.07,.06)],6,'head',10)
            self.tube([(-.13,1.74,-.04),(0,1.79,-.12),(.13,1.74,-.04)],[.02,.025,.02],4,'head',5)
        if r=='raider':
            self.loft([(0,1.69,.01,.15,.13),(0,1.77,.01,.13,.12),(0,1.84,.02,.065,.065)],2,'head',8)
            for s in [-1,1]:
                self.tube([(s*.12,1.75,0),(s*.23,1.83,.01),(s*.28,1.99,-.015)],[.055,.04,.003],6,'head',6)
                self.tube([(s*.26,1.40,0),(s*.40,1.55,0)],[.045,.002],2,('L' if s<0 else 'R')+'_arm',5)
        if r in ('knight','raider'):
            # Sword: diamond blade bevel, hilt, guard and pommel all hand-weighted.
            self.tube([(.47,.79,-.045),(.47,1.03,-.045)],[.025,.025],3,'R_hand',6)
            self.tube([(.34,1.01,-.045),(.60,1.01,-.045)],[.025,.025],4 if not enemy else 2,'R_hand',6)
            self.plate([(.425,1.06),(.515,1.06),(.51,1.57),(.47,1.74),(.43,1.57)],-.065,.045,2,'R_hand')
            self.loft([(.47,.77,-.045,.035,.035),(.47,.81,-.045,.035,.035)],4,'R_hand',6)
            self.plate([(-.68,.75),(-.47,.58),(-.26,.75),(-.26,1.12),(-.47,1.23),(-.68,1.12)],-.19,.07,2,'L_hand')
            self.plate([(-.64,.78),(-.47,.64),(-.30,.78),(-.30,1.09),(-.47,1.18),(-.64,1.09)],-.225,.02,1,'L_hand')
            self.plate([(-.53,.87),(-.41,.87),(-.41,1.02),(-.47,1.09),(-.53,1.02)],-.26,.03,4 if not enemy else 6,'L_hand')
        elif r in ('ranger','sentinel'):
            self.tube([(-.46,1.49,-.04),(-.60,1.33,-.11),(-.64,1.10,-.16),(-.47,.87,-.05),(-.62,.62,-.13),(-.57,.41,-.08),(-.46,.30,-.04)],[.012,.023,.027,.032,.027,.023,.012],3,'L_hand',6)
            self.tube([(-.46,1.49,-.04),(-.46,.30,-.04)],[.004,.004],6,'L_hand',4)
            self.tube([(.17,.86,.21),(.27,1.43,.24)],[.08,.095],3,'chest',8)
            for k in range(4):
                x=.20+(k%2)*.055;z=.23+(k//2)*.04
                self.tube([(x,1.28,z),(x+.035,1.66,z)],[.006,.006],4,'chest',4)
                self.plate([(x-.015,1.52),(x+.045,1.52),(x+.035,1.63)],z,.014,6,'chest')
        elif r=='mage':
            self.tube([(.47,.08,-.04),(.47,1.42,-.04),(.51,1.68,-.04)],[.022,.025,.04],3,'R_hand',7)
            self.loft([(.51,1.58,-.04,.02,.02),(.51,1.72,-.04,.09,.09),(.51,1.89,-.04,.008,.008)],7,'R_hand',6)
            for s in [-1,1]:
                self.tube([(.51+s*.07,1.64,-.04),(.51+s*.13,1.78,-.04)],[.023,.006],4,'R_hand',5)
        else:
            self.tube([(.47,.70,-.04),(.47,1.22,-.04)],[.025,.025],3,'R_hand',7)
            self.loft([(.47,1.17,-.04,.045,.045),(.47,1.24,-.04,.115,.115),(.47,1.36,-.04,.10,.10),(.47,1.41,-.04,.025,.025)],2,'R_hand',8)
            for s in [-1,1]:
                self.plate([(.47+s*.03,1.23),(.47+s*.15,1.27),(.47+s*.15,1.36),(.47+s*.03,1.39)],-.08,.075,4,'R_hand')
        return self

def export(model):
    data=bytearray();views=[];access=[]
    def buffer(values,fmt,kind,component=5126,bounds=False):
        while len(data)%4:data.append(0)
        start=len(data);flat=[v for row in values for v in (row if isinstance(row,(list,tuple)) else [row])]
        data.extend(struct.pack('<'+fmt*len(flat),*flat));views.append({'buffer':0,'byteOffset':start,'byteLength':len(data)-start})
        a={'bufferView':len(views)-1,'componentType':component,'count':len(values),'type':kind}
        if bounds:
            a['min']=[min(v[i] for v in values) for i in range(len(values[0]))];a['max']=[max(v[i] for v in values) for i in range(len(values[0]))]
        access.append(a);return len(access)-1
    nodes=[]
    for name,parent,p in RIG:
        local=sub(p,RIG[parent][2]) if parent>=0 else p
        nodes.append({'name':name,'translation':local})
    for i,(_,parent,_) in enumerate(RIG):
        if parent>=0:nodes[parent].setdefault('children',[]).append(i)
    inv=[]
    for _,_,p in RIG:inv.append([1,0,0,0,0,1,0,0,0,0,1,0,-p[0],-p[1],-p[2],1])
    skin={'name':'SharedHumanoid','joints':list(range(len(RIG))),'skeleton':0,'inverseBindMatrices':buffer(inv,'f','MAT4')}
    primitives=[]
    for mat,vertices in sorted(model.parts.items()):
        primitives.append({'attributes':{'POSITION':buffer([v[0] for v in vertices],'f','VEC3',bounds=True),'NORMAL':buffer([v[1] for v in vertices],'f','VEC3'),'JOINTS_0':buffer([(v[2],0,0,0) for v in vertices],'H','VEC4',5123),'WEIGHTS_0':buffer([(1,0,0,0) for v in vertices],'f','VEC4')},'material':mat})
    nodes.append({'name':model.role+'_mesh','mesh':0,'skin':0})
    animations=[]
    def anim(name,length,curves,loop=False):
        samplers=[];channels=[]
        for bone,axis,keys in curves:
            times=[t*length for t,a in keys];values=[quat(axis,a) for t,a in keys]
            inp=buffer([(t,) for t in times],'f','SCALAR',bounds=True);out=buffer(values,'f','VEC4')
            samplers.append({'input':inp,'output':out,'interpolation':'LINEAR'});channels.append({'sampler':len(samplers)-1,'target':{'node':J[bone],'path':'rotation'}})
        animations.append({'name':name,'samplers':samplers,'channels':channels,'extras':{'loop':loop}})
    reset=[(name,(1,0,0),[(0,0),(1,0)]) for name,_,_ in RIG]
    anim('Idle',2.4,[(b,(1,0,0),[(0,0),(.5,a),(1,0)]) for b,a in [('chest',2),('head',-2),('L_arm',-3),('R_arm',-3)]],True)
    walk=[]
    for s,k in [('L',1),('R',-1)]:
        walk += [(s+'_thigh',(1,0,0),[(0,23*k),(.25,0),(.5,-23*k),(.75,0),(1,23*k)]),(s+'_shin',(1,0,0),[(0,0),(.25,26 if k>0 else 0),(.5,0),(.75,26 if k<0 else 0),(1,0)]),(s+'_arm',(1,0,0),[(0,-15*k),(.5,15*k),(1,-15*k)])]
        walk += [(s+'_foot',(1,0,0),[(0,-23*k),(.25,-26 if k>0 else 0),(.5,23*k),(.75,-26 if k<0 else 0),(1,-23*k)])]
    anim('Walk',.8,walk,True)
    if model.role in ('ranger','sentinel'):
        attack=[('L_arm',(1,0,0),[(0,0),(.25,-78),(.7,-78),(1,0)]),('R_arm',(1,0,0),[(0,0),(.25,-65),(.7,-65),(1,0)]),('R_forearm',(0,0,1),[(0,0),(.35,-90),(.65,-90),(.75,-25),(1,0)]),('chest',(0,1,0),[(0,0),(.3,-22),(.7,-22),(1,0)])]
        attack += [('L_hand',(1,0,0),[(0,0),(.25,78),(.7,78),(1,0)])] # Keep bow upright while aiming.
    else:
        attack=[('R_arm',(1,0,0),[(0,0),(.3,65),(.55,-75),(.75,-35),(1,0)]),('R_forearm',(1,0,0),[(0,0),(.3,-55),(.6,-20),(1,0)]),('chest',(0,1,0),[(0,0),(.3,-20),(.6,24),(1,0)]),('L_arm',(1,0,0),[(0,0),(.35,-35),(.7,-35),(1,0)])]
    anim('Attack',.65,attack)
    anim('Cast',.85,[('L_arm',(1,0,0),[(0,0),(.35,-105),(.65,-105),(1,0)]),('R_arm',(1,0,0),[(0,0),(.35,-45),(.65,-45),(1,0)]),('head',(1,0,0),[(0,0),(.5,-12),(1,0)])])
    anim('Hit',.32,[('chest',(1,0,0),[(0,0),(.2,-14),(.55,6),(1,0)]),('head',(1,0,0),[(0,0),(.25,-12),(1,0)])])
    anim('Death',.85,[('hips',(1,0,0),[(0,0),(.25,12),(.75,-78),(1,-88)]),('L_arm',(0,0,1),[(0,0),(.6,32),(1,22)]),('R_arm',(0,0,1),[(0,0),(.6,-32),(1,-22)]),('L_shin',(1,0,0),[(0,0),(.3,30),(1,5)]),('head',(1,0,0),[(0,0),(.4,-20),(1,-8)])])
    # Death lowers the hips as the body falls; all tracks are visual only.
    animdeath=animations[-1];sam=animdeath['samplers'];sam.append({'input':buffer([(0,),(.35,),(.85,)],'f','SCALAR',bounds=True),'output':buffer([(0,.85,0),(0,.55,0),(0,.30,0)],'f','VEC3'),'interpolation':'LINEAR'});animdeath['channels'].append({'sampler':len(sam)-1,'target':{'node':J['hips'],'path':'translation'}})
    materials=[]
    for name,c,metal,rough in model.palette:
        m={'name':name,'pbrMetallicRoughness':{'baseColorFactor':[*c,1],'metallicFactor':metal,'roughnessFactor':rough},'doubleSided':True}
        if name=='magic':m['emissiveFactor']=[x*.35 for x in c]
        materials.append(m)
    doc={'asset':{'version':'2.0','generator':'Fantasy Tactics original loft/sweep roster source'},'scene':0,'scenes':[{'name':model.role,'nodes':[0,len(nodes)-1]}],'nodes':nodes,'skins':[skin],'meshes':[{'name':model.role,'primitives':primitives}],'materials':materials,'animations':animations,'buffers':[{'byteLength':len(data)}],'bufferViews':views,'accessors':access}
    js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4);data+=b'\0'*((-len(data))%4)
    output=struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(data))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(data),0x004e4942)+data
    OUT.mkdir(parents=True,exist_ok=True);(OUT/(model.role+'.glb')).write_bytes(output)
    return {'role':model.role,'triangles':sum(len(v)//3 for v in model.parts.values()),'materials':len(model.parts),'joints':len(RIG),'bytes':len(output),'animations':[a['name'] for a in animations]}

if __name__=='__main__':
    report=[export(Model(role).build()) for role in ROLES]
    (OUT.parent/'manifest.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(report,indent=2))
