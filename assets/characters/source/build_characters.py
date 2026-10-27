"""Lantern Oath character source: authored cross-section topology and pose targets.
Standard-library GLB exporter. No runtime construction, external art or bitmap maps.
Run with --representatives to validate four characters before compiling the roster.
"""
import math,json,struct,argparse
from pathlib import Path
import build_roster as legacy
RIG=legacy.RIG; J=legacy.J
OUT=Path(__file__).resolve().parents[1]/'oath_models'
IDS=['knight','ranger','mage','cleric','raider','sentinel','ashfang_raider','ashfang_shieldguard','ashfang_bowhunter','ashfang_shaman','ashfang_chieftain','hollow_gravebound','hollow_archer','hollow_adept','hollow_warden','hollow_castellan','verdant_thornblade','verdant_stalker','verdant_tender','verdant_sentinel','verdant_grovekeeper']
BOW={'ranger','sentinel','bowhunter','archer','stalker'}
STAFF={'mage','shaman','adept','tender','grovekeeper'}
SHIELD={'knight','raider','shieldguard','warden','sentinel'}
add,sub,mul,cross,norm=legacy.add,legacy.sub,legacy.mul,legacy.cross,legacy.norm
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def length(a):return math.sqrt(dot(a,a))
def mix(a,b,t):return add(mul(a,1-t),mul(b,t))
def clamp(x,a,b):return max(a,min(b,x))
def qmul(a,b):
 x,y,z,w=a;u,v,s,t=b
 return (w*u+x*t+y*s-z*v,w*v-x*s+y*t+z*u,w*s+x*v-y*u+z*t,w*t-x*u-y*v-z*s)
def qi(q):return (-q[0],-q[1],-q[2],q[3])
def qrot(q,v):return qmul(qmul(q,(*v,0)),qi(q))[:3]
def qaxis(axis,deg):return tuple(legacy.quat(axis,deg))
def qfrom(a,b):
 a,b=norm(a),norm(b);c=cross(a,b);q=(*c,1+dot(a,b));d=math.sqrt(dot(q,q))
 return tuple(x/d for x in q) if d>.00001 else qaxis((0,1,0),180)
I=(0,0,0,1)
def rgb(h):return tuple(int(h[i:i+2],16)/255 for i in (0,2,4))

class Character(legacy.Model):
 def __init__(self,id):
  self.role=id;self.parts=legacy.defaultdict(list);self.faction=id.split('_')[0] if '_' in id else 'watch';self.job=id.split('_',1)[-1]
  self.bow=id in {'ranger','sentinel'} or self.job in {'bowhunter','archer','stalker'}
  self.staff=self.job in STAFF
  self.shield=(id in {'knight','raider'} or self.job in {'shieldguard','warden','sentinel'}) and not self.bow
  self.elite=self.job in {'chieftain','castellan','grovekeeper'}
  f=self.faction
  skin='e6bc94' if f=='watch' else 'ba7055' if f=='ashfang' else 'd5cfac' if f=='hollow' else '6ca49a'
  cloth={'knight':'2d8091','ranger':'638e83','mage':'b95e50','cleric':'d8cfab','raider':'99484a','sentinel':'536c86'}.get(id,'963f43' if f=='ashfang' else '344665' if f=='hollow' else '447f7c')
  steel='a0c5c9' if f=='watch' else '705665' if f=='ashfang' else '728eaa' if f=='hollow' else '508681'
  self.palette=[(n,rgb(c),metal,rough) for n,c,metal,rough in [('skin',skin,0,.88),('cloth',cloth,0,.95),('steel',steel,.55,.50),('leather','344352',0,.90),('gold','d8a568',.45,.58),('hair','303541',0,.98),('light','eee0b6',0,.86),('magic','9cddd4' if f=='hollow' else 'd7e7ad' if f=='verdant' else 'f3c581',.05,.62)]]
 def tri(self,a,b,c,mat,bone):
  n=norm(cross(sub(b,a),sub(c,a)))
  if length(cross(sub(b,a),sub(c,a)))<1e-10:return
  self.parts[mat].extend([(p,n,J[bone]) for p in (a,b,c)])
 def shell(self,rings,mat,bone,n=12):
  # Explicit horizontal edge loops: (x,y,z,half_width,half_depth).
  # Welded smooth normals for fabric/anatomy; armour has deliberate planes.
  rows=[[(x+rx*math.cos(2*math.pi*i/n),y,z+rz*math.sin(2*math.pi*i/n)) for i in range(n)] for x,y,z,rx,rz in rings]
  for a,b in zip(rows,rows[1:]):
   for i in range(n):
    k=(i+1)%n;self.tri(a[i],b[i],b[k],mat,bone);self.tri(a[i],b[k],a[k],mat,bone)
  for row,top in [(rows[0],False),(rows[-1],True)]:
   center=tuple(sum(p[j] for p in row)/n for j in range(3))
   for i in range(n):
    a,b=row[i],row[(i+1)%n];self.tri(center,b,a,mat,bone) if top else self.tri(center,a,b,mat,bone)
 def panel(self,outline,z,depth,mat,bone,ridge=.02):
  # Individually authored silhouette, inset front face and bevel ring.
  cx=sum(x for x,y in outline)/len(outline);cy=sum(y for x,y in outline)/len(outline)
  a=[(x,y,z) for x,y in outline];b=[(cx+(x-cx)*.88,cy+(y-cy)*.90,z-ridge) for x,y in outline];c=[(x,y,z+depth) for x,y in outline]
  center=(cx,cy,z-ridge)
  for i in range(len(a)):
   k=(i+1)%len(a);self.tri(center,b[k],b[i],mat,bone)
   self.tri(a[i],b[i],b[k],mat,bone);self.tri(a[i],b[k],a[k],mat,bone)
   self.tri(a[i],a[k],c[k],mat,bone);self.tri(a[i],c[k],c[i],mat,bone)
  rear=(cx,cy,z+depth)
  for i in range(len(a)):self.tri(rear,c[i],c[(i+1)%len(a)],mat,bone)
 def build(self):
  f,j=self.faction,self.job
  armored=j in {'knight','cleric','raider','shieldguard','chieftain','gravebound','warden','castellan','sentinel'} and not self.bow
  robe=self.staff or j=='cleric'
  mass=1.16 if f=='ashfang' else .87 if f=='hollow' else .93 if f=='verdant' else 1.0
  # Continuous hip and ribcage contours; waist, oblique, rib and clavicle loops.
  if f=='hollow':
   self.tube([(0,.86,.045),(0,1.12,.05),(0,1.40,.04)],[.035,.032,.038],6,'chest',8)
   self.shell([(0,.78,0,.16,.10),(0,.87,0,.20,.11),(0,.93,0,.14,.08)],6,'hips',12)
   for yy in [1.05,1.14,1.23,1.32]:
    for ss in [-1,1]:self.tube([(0,yy,.04),(ss*.17,yy+.035,.005),(ss*.22,yy,-.085),(ss*.13,yy-.026,-.15),(ss*.035,yy-.025,-.15)],[.020,.022,.021,.018,.012],6,'chest',7)
   self.panel([(-.24,1.39),(.24,1.39),(.28,.84),(.16,.58),(0,.72),(-.21,.60),(-.28,.90)],.16,.035,1,'chest')
  else:
   self.shell([(0,.76,.015,.18*mass,.13),(0,.84,0,.235*mass,.145),(0,.95,0,.20*mass,.14),(0,1.04,0,.185*mass,.13),(0,1.16,0,.25*mass,.17),(0,1.28,.01,.285*mass,.17),(0,1.36,.015,.23*mass,.13),(0,1.405,.01,.09,.08)],1 if not armored else 3,'chest',16)
  for side,s in [('L',-1),('R',1)]:
   x=s*.145
   # Continuous thigh-to-ankle topology is blended across the actual knee.
   self.shell([(x,.19,.005,.062,.068),(x,.29,.025,.08,.082),(x,.38,.02,.085,.082),(x,.445,-.018,.072,.075),(x,.49,-.014,.073,.075),(x,.58,.00,.10*mass,.104),(x,.73,.015,.119*mass,.13),(x,.85,0,.119*mass,.125)],1 if f!='verdant' else 0,side+'_thigh',12)
   if f=='verdant':
    for toe in [-.055,0,.055]:self.tube([(x,.21,.01),(x+toe,.085,-.10),(x+toe*1.4,.026,-.24)],[.038,.033,.009],3,side+'_foot',7)
   else:self.shell([(x,.025,-.08,.09,.18),(x,.055,-.09,.105,.195),(x,.115,-.07,.10,.18),(x,.16,-.015,.073,.095),(x,.26,.005,.068,.078)],3,side+'_foot',12)
   self.panel([(x-.078,.20),(x+.078,.20),(x+.085,.41),(x,.49),(x-.085,.41)],-.084,.03,2 if armored else 3,side+'_shin')
   # Deltoid/elbow/ulna edge loops; no capped disconnected elbow primitives.
   self.shell([(s*.46,.865,-.04,.052,.055),(s*.445,.95,-.025,.065,.072),(s*.413,1.055,-.012,.074,.078),(s*.40,1.085,-.015,.069,.071),(s*.379,1.13,0,.075*mass,.078),(s*.34,1.23,.005,.095*mass,.10),(s*.29,1.335,.01,.11*mass,.12)],0 if f=='ashfang' else 1,side+'_arm',12)
   self.shell([(s*.46,.86,-.04,.06,.062),(s*.435,.98,-.02,.082,.084),(s*.418,1.04,-.014,.077,.080)],2 if armored else 3,side+'_forearm',10)
   # Palm, then continuous curling finger loops enclosing the grip at z=-.06.
   self.shell([(s*.46,.785,-.010,.047,.035),(s*.46,.815,-.015,.059,.043),(s*.46,.865,-.009,.057,.040),(s*.46,.89,-.02,.048,.038)],3 if armored else 0,side+'_hand',10)
   for finger in range(4):
    xx=s*.46-.040+finger*.024
    self.tube([(xx,.84,-.034),(xx,.835,-.077),(xx,.805,-.09),(xx,.786,-.055)],[.014,.016,.015,.012],3 if armored else 0,side+'_hand',6)
   self.tube([(s*.46+s*.05,.86,-.015),(s*.46+s*.06,.842,-.059),(s*.46+s*.025,.823,-.085)],[.022,.019,.014],3 if armored else 0,side+'_hand',7)
   if armored:
    self.shell([(s*.29,1.28,0,.12,.13),(s*.29,1.32,-.005,.165*mass,.17),(s*.29,1.39,0,.145*mass,.15),(s*.29,1.45,.01,.07,.08)],2,side+'_arm',10)
    self.shell([(s*.29,1.28,0,.126,.135),(s*.29,1.30,0,.168*mass,.174)],4,side+'_arm',10)
  self.shell([(0,1.37,0,.074,.07),(0,1.52,0,.076,.072)],0,'neck',12)
  self.face()
  self.shell([(0,.91,0,.218*mass,.151),(0,.96,0,.22*mass,.153)],3,'hips',16)
  self.panel([(-.045,.915),(.045,.915),(.045,.97),(-.045,.97)],-.16,.022,4,'hips')
  if armored and f!='hollow':
   self.panel([(-.16,1.03),(0,1.0),(.16,1.03),(.255*mass,1.28),(.20,1.36),(0,1.31),(-.20,1.36),(-.255*mass,1.28)],-.17,.048,2,'chest',.035)
   self.panel([(-.09,1.09),(0,1.04),(.09,1.09),(.10,1.32),(-.10,1.32)],-.23,.018,1,'chest')
  if robe:
   # Split front leaves the boots and stride readable. The side folds deform
   # toward the thigh joints; no cloth simulation or rigid cone around legs.
   for s in [-1,1]:
    self.panel([(s*.025,.92),(s*.19,.94),(s*.29,.38),(s*.17,.23),(s*.04,.33)],-.16,.045,1,'hips',.025)
   self.panel([(-.21,1.33),(.21,1.33),(.30,.75),(.21,.42),(0,.34),(-.21,.42),(-.30,.75)],.18,.03,1,'chest')
  else:
   for s in [-1,1]:self.panel([(s*.02,.92),(s*.22,.94),(s*.265,.70),(s*.13,.64),(s*.04,.73)],-.165,.035,1,'hips')
  self.identity(armored)
  self.weapons()
  return self
 def face(self):
  f=self.faction;wide=1.12 if f=='ashfang' else .88 if f=='verdant' else 1.0
  # Twenty-four-sided head topology, with explicit cheek/jaw/temple profiles.
  self.shell([(0,1.49,-.015,.072,.075),(0,1.535,-.025,.097*wide,.096),(0,1.59,-.006,.138*wide,.117),(0,1.66,.005,.154*wide,.125),(0,1.73,.014,.151*wide,.123),(0,1.80,.025,.129*wide,.108),(0,1.85,.028,.078,.067),(0,1.865,.025,.014,.015)],0,'head',24)
  # Faceted bridge joins brow and muzzle along shared landmarks, rather than
  # an attached cone/sphere. Lips and orbital planes are low-relief surfaces.
  pts=[(-.034,1.72,-.120),(.034,1.72,-.120),(-.022,1.64,-.157),(.022,1.64,-.157),(0,1.628,-.185),(0,1.72,-.132),(-.055,1.60,-.115),(.055,1.60,-.115),(0,1.586,-.126)]
  for a,b,c in [(0,5,2),(5,3,2),(5,1,3),(2,3,4),(2,4,6),(4,7,6),(6,7,8)]:self.tri(pts[a],pts[b],pts[c],0,'head')
  for s in [-1,1]:
   self.panel([(s*.032,1.678),(s*.112,1.689),(s*.105,1.724),(s*.035,1.715)],-.117,.012,3 if f=='hollow' else 5,'head',.002)
   self.panel([(s*.042,1.687),(s*.097,1.696),(s*.094,1.711),(s*.042,1.707)],-.134,.006,7 if f!='watch' else 6,'head',.001)
   if f=='watch':self.panel([(s*.063,1.687),(s*.079,1.691),(s*.078,1.711),(s*.063,1.709)],-.143,.003,5,'head',.001)
   self.panel([(s*.028,1.725),(s*.114,1.739),(s*.113,1.754),(s*.035,1.743)],-.115,.025,5 if f=='watch' else 3,'head',.008)
   self.panel([(s*.13,1.63),(s*.205,1.73),(s*.172,1.60)],-.005,.05,0,'head')
  self.panel([(-.038,1.586),(.038,1.586),(.027,1.577),(-.028,1.577)],-.122,.004,3,'head',.001)
  # Hair cap with swept front, sideburn silhouette and an occipital back.
  self.shell([(0,1.745,.04,.149,.100),(0,1.81,.04,.137,.110),(0,1.88,.045,.072,.067),(0,1.89,.035,.012,.016)],5,'head',16)
  if f=='ashfang':
   for s in [-1,1]:self.tube([(s*.075,1.578,-.10),(s*.085,1.625,-.155),(s*.072,1.657,-.16)],[.025,.018,.001],6,'head',7)
  if f=='hollow':
   # Skull-like cheek openings and a narrow nasal bridge, with a crown/back
   # rather than a humanoid helmet. Bone is a distinct material, not colour only.
   for s in [-1,1]:self.panel([(s*.04,1.56),(s*.10,1.57),(s*.13,1.64),(s*.07,1.62)],-.117,.02,3,'head')
  if f=='verdant':
   for s in [-1,1]:
    self.tube([(s*.105,1.80,.02),(s*.22,1.97,.01),(s*.29,2.12,-.01)],[.045,.025,.002],3,'head',7)
    self.tube([(s*.20,1.96,.01),(s*.35,2.01,-.03)],[.023,.001],3,'head',6)
 def identity(self,armored):
  j,f=self.job,self.faction
  if self.bow:
   # Open hood framing the face, broad asymmetric mantle and quiver.
   self.tube([(-.16,1.55,.03),(-.185,1.78,.04),(-.11,1.92,.035),(0,1.96,.04),(.11,1.92,.035),(.185,1.78,.04),(.16,1.55,.03)],[.035,.048,.055,.052,.055,.048,.035],1,'head',8)
   self.panel([(-.28,1.35),(.20,1.35),(.25,.78),(0,.65),(-.31,.80)],.18,.035,1,'chest')
   self.tube([(-.22,1.34,-.17),(.17,1.02,-.17)],[.028,.028],3,'chest',6)
   self.tube([(.19,.95,.25),(.23,1.43,.25)],[.072,.09],3,'chest',10)
   for k in range(4):self.tube([(.18+k*.028,1.32,.25),(.20+k*.028,1.68,.25)],[.007,.007],4,'chest',5)
  elif self.staff:
   # Bent brim and a swept cap, broad collar and split robe.
   self.shell([(0,1.80,.02,.205,.18),(0,1.84,.02,.205,.18),(0,1.90,.04,.13,.12),(.045,2.05,.09,.07,.065),(.105,2.14,.11,.012,.012)],1,'head',16)
   self.shell([(0,1.84,.02,.175,.155),(0,1.875,.025,.155,.14)],4,'head',16)
   for s in [-1,1]:self.panel([(s*.06,1.35),(s*.30,1.45),(s*.29,1.19),(s*.16,1.12)],-.13,.04,1,'chest')
  elif j in {'knight','raider','shieldguard','chieftain','gravebound','castellan','sentinel','warden','cleric'}:
   self.shell([(0,1.76,.02,.16,.14),(0,1.83,.03,.158,.14),(0,1.92,.04,.085,.08),(0,1.94,.04,.012,.015)],2,'head',16)
   if j=='knight':self.panel([(-.025,1.86),(.025,1.86),(.035,2.10),(-.025,2.14)],.01,.12,1,'head')
   if f=='ashfang':
    for s in [-1,1]:self.tube([(s*.14,1.84,.02),(s*.24,1.94,.01),(s*.30,2.04,-.01)],[.05,.032,.001],6,'head',8)
   if f=='hollow':
    for x in [-.10,0,.10]:self.panel([(x-.035,1.88),(x+.035,1.88),(x,2.08)],-.04,.07,2,'head')
  if f=='verdant':
   for s in [-1,1]:self.panel([(s*.12,1.30),(s*.38,1.47),(s*.35,1.23),(s*.16,1.10)],-.10,.045,1,'chest')
  if self.elite:
   for x in [-.18,-.09,0,.09,.18]:self.panel([(x-.035,1.88),(x+.035,1.88),(x*1.3,2.19-abs(x)*.5)],-.03,.06,4,'head')
   self.panel([(-.10,1.25),(.10,1.25),(.145,.62),(0,.50),(-.145,.62)],-.245,.025,1,'chest')
  self.panel([(-.055,1.19),(0,1.13),(.055,1.19),(0,1.28)],-.254 if armored else -.187,.025,4,'chest')
 def weapons(self):
  x=.46;z=-.065
  if self.bow:
   # True handle at the left grip, recurved limbs and a taut string.
   x=-.46
   self.tube([(x,.24,z),(x-.12,.40,z-.02),(x-.16,.65,z-.04),(x,.84,z),(x-.16,1.10,z-.04),(x-.12,1.36,z-.02),(x,1.51,z)],[.012,.023,.030,.030,.030,.023,.012],3,'L_hand',10)
   self.tube([(x,.24,z),(x,1.51,z)],[.0035,.0035],6,'L_hand',4)
   self.tube([(x,.79,z),(x,.90,z)],[.034,.034],4,'L_hand',10)
   self.tube([(.46,.83,-.065),(.46,.83,-.80)],[.007,.007],3,'R_hand',6)
   self.panel([(.44,.83),(.48,.83),(.46,.89)],-.82,.04,2,'R_hand')
  elif self.staff:
   self.tube([(x,.07,z),(x,.45,z),(x,1.18,z),(x+.025,1.64,z),(x,1.88,z)],[.024,.028,.027,.04,.025],3,'R_hand',10)
   for y in [.80,1.01]:self.tube([(x,y,z),(x,y+.075,z)],[.031,.031],4,'R_hand',8)
   for s in [-1,1]:self.tube([(x,1.70,z),(x+s*.14,1.84,z),(x+s*.10,2.04,z)],[.028,.025,.005],4,'R_hand',7)
   self.shell([(x,1.78,z,.025,.025),(x,1.91,z,.095,.075),(x+.02,2.08,z,.008,.008)],7,'R_hand',8)
  else:
   self.tube([(x,.76,z),(x,1.05,z)],[.026,.026],3,'R_hand',10)
   self.tube([(x,.755,z),(x,.78,z)],[.041,.041],4,'R_hand',10)
   self.tube([(x-.17,1.01,z),(x,1.035,z-.02),(x+.17,1.01,z)],[.02,.028,.02],4,'R_hand',8)
   if self.job in {'cleric','warden'}:
    self.shell([(x,1.32,z,.06,.06),(x,1.36,z,.14,.12),(x,1.53,z,.13,.11),(x,1.57,z,.045,.045)],2,'R_hand',10)
   else:
    outline=[(x-.048,1.07),(x+.048,1.07),(x+.055,1.62),(x,1.83),(x-.055,1.62)]
    if self.faction=='ashfang':outline=[(x-.04,1.08),(x+.045,1.08),(x+.045,1.40),(x+.26,1.53),(x+.24,1.76),(x+.06,1.70),(x-.04,1.57)]
    self.panel(outline,z-.015,.045,2,'R_hand',.025)
   if self.shield:
    self.tube([(-.46,.84,-.03),(-.46,.84,-.21)],[.028,.028],3,'L_hand',8)
    self.panel([(-.70,1.17),(-.46,1.28),(-.22,1.17),(-.25,.71),(-.46,.54),(-.67,.71)],-.235,.075,2,'L_hand',.035)
    self.panel([(-.65,1.13),(-.46,1.22),(-.27,1.13),(-.30,.75),(-.46,.61),(-.62,.75)],-.282,.018,1,'L_hand',.016)
    self.panel([(-.53,.90),(-.46,.82),(-.39,.90),(-.46,1.05)],-.315,.015,4,'L_hand')

# FK and analytical two-bone pose targets. Every track contains a complete pose;
# action clips have no method/event tracks and can never apply gameplay damage.
def fk(q,pos):
 gp=[];gq=[]
 for i,(_,parent,p) in enumerate(RIG):
  local=pos.get(i,sub(p,RIG[parent][2]) if parent>=0 else p)
  gp.append(add(gp[parent],qrot(gq[parent],local)) if parent>=0 else local)
  gq.append(qmul(gq[parent],q[i]) if parent>=0 else q[i])
 return gp,gq
def solve(q,pos,side,limb,target,pole,orientation=I):
 a,b,c=[J[side+'_'+x] for x in (('arm','forearm','hand') if limb=='arm' else ('thigh','shin','foot'))]
 gp,gq=fk(q,pos);origin=gp[a];v1=sub(RIG[b][2],RIG[a][2]);v2=sub(RIG[c][2],RIG[b][2]);l1,l2=length(v1),length(v2)
 d=sub(target,origin);dist=clamp(length(d),abs(l1-l2)+.001,l1+l2-.0002);direction=norm(d)
 u=norm(sub(pole,mul(direction,dot(pole,direction))));along=(l1*l1-l2*l2+dist*dist)/(2*dist);height=math.sqrt(max(0,l1*l1-along*along))
 elbow=add(origin,add(mul(direction,along),mul(u,height)))
 parent=RIG[a][1];global_a=qfrom(v1,sub(elbow,origin));q[a]=qmul(qi(gq[parent]),global_a)
 global_b=qfrom(v2,sub(target,elbow));q[b]=qmul(qi(global_a),global_b);q[c]=qmul(qi(global_b),orientation)
def pose(model,clip,t):
 q=[I for _ in RIG];pos={};phase=t*2*math.pi;f=model.faction
 pos[J['hips']]=(0,.825,0)
 q[J['chest']]=qaxis((0,1,0),2*math.sin(phase) if clip=='Idle' else 0)
 q[J['head']]=qaxis((1,0,0),-2+math.sin(phase)*.6)
 feet={s:(k*.145,.12,0) for s,k in [('L',-1),('R',1)]}
 if clip in ('Walk','Run'):
  q[J['chest']]=qmul(qaxis((0,1,0),math.sin(phase)*5),qaxis((1,0,0),5 if clip=='Run' else 0));pos[J['hips']]=(0,.80+abs(math.sin(phase))*.018,0)
  for s,k in [('L',0),('R',.5)]:
   p=(t+k)%1;z=-.25+p if p<.5 else .25-(p-.5);y=.12+(math.sin((p-.5)*2*math.pi)*(.15 if clip=='Run' else .11) if p>=.5 else 0)
   feet[s]=((-1 if s=='L' else 1)*.145,y,z)
 for s in ['L','R']:solve(q,pos,s,'leg',feet[s],(0,0,-1))
 # Ready poses put the grip into the hand, with class-specific silhouettes.
 hands={'R':(.43,.91,-.10),'L':(-.43,.91,-.10)}
 if model.staff:
  hands={'R':(.105,.97,-.17)};hands['L']=add(hands['R'],qrot(qaxis((0,0,1),-10),(0,.21,0)))
 if model.bow:hands={'L':(-.37,1.03,-.19),'R':(.33,.94,-.23)}
 if clip in ('Walk','Run') and not model.staff:
  hands['R']=add(hands['R'],(0,0,math.sin(phase)*.08));hands['L']=add(hands['L'],(0,0,-math.sin(phase)*.08))
 if clip in ('Attack','Cast'):
  # Damage is authoritative at t=0. Contact/aim is the opening pose; recovery
  # is visual-only and interruptible. No fictitious late hit event is added.
  strength=math.cos(min(t/.60,1)*math.pi/2)**2
  if model.bow and clip=='Attack':
   hands['L']=mix(hands['L'],(-.12,1.39,-.43),strength);hands['R']=mix(hands['R'],(.13,1.42,-.20),strength)
  elif model.staff or clip=='Cast':
   if model.staff:
    hands={'R':(.105,.97+strength*.12,-.17-strength*.03)};hands['L']=add(hands['R'],qrot(qaxis((0,0,1),-10),(0,.21,0)))
   else:hands['L']=mix(hands['L'],(-.22,1.41,-.36),strength)
  else:
   hands['R']=mix(hands['R'],(.19,1.17,-.42),strength);q[J['chest']]=qaxis((0,1,0),15*strength)
 if clip=='Hit':
  recoil=math.sin(t*math.pi)*(-13 if f!='hollow' else -9);q[J['chest']]=qaxis((1,0,0),recoil);q[J['head']]=qaxis((1,0,0),recoil*.6)
 for s in ['L','R']:
  orientation=qaxis((0,0,1),-10) if model.staff else I
  if clip=='Attack' and not model.staff:
   strength=math.cos(min(t/.60,1)*math.pi/2)**2
   if not model.bow and s=='R':orientation=qaxis((1,0,0),(-105 if f=='ashfang' else -82)*strength)
   if model.bow and s=='R':orientation=qfrom((0,0,-1),sub(hands['L'],hands['R']))
  solve(q,pos,s,'arm',hands[s],(-1 if s=='L' else 1,-.1,.35),orientation)
 if clip=='Death':
  # Staged collapse to a side/back resting pose, all motion visual only.
  v=clamp(t,0,1);smooth=v*v*(3-2*v)
  pos[J['hips']]=(smooth*.13,.825-smooth*.54+.21*math.sin(math.pi*smooth),smooth*.02)
  q[J['hips']]=qmul(qaxis((1,0,0),-86*smooth),qaxis((0,0,1),12*smooth))
  q[J['chest']]=qaxis((1,0,0),12*math.sin(v*math.pi));q[J['head']]=qaxis((1,0,0),-8*smooth)
  # Fold knees and elbows, rather than dragging a rigid mannequin down.
  for s in ['L','R']:
   q[J[s+'_thigh']]=qaxis((1,0,0),-15*smooth);q[J[s+'_shin']]=qaxis((1,0,0),26*smooth)
   q[J[s+'_arm']]=qmul(qaxis((0,0,1),(-1 if s=='L' else 1)*25*smooth),qaxis((1,0,0),25*smooth))
   q[J[s+'_forearm']]=qaxis((1,0,0),-35*smooth);q[J[s+'_hand']]=I
  gp,gq=fk(q,pos)
  for s in ['L','R']:
   # Lay shields/blades/staves face-up instead of pushing their front faces
   # through the floor. An archer's arrow remains horizontal in the right hand.
   desired=I if model.bow and s=='R' else qaxis((1,0,0),90*smooth)
   q[J[s+'_hand']]=qmul(qi(gq[J[s+'_forearm']]),desired)
 return q,pos

def weights(p,bone,mat):
 name=RIG[bone][0];y=p[1]
 if name=='chest' and mat in (0,1,3):
  w=clamp((y-.92)/.28,0,1);return (J['hips'],J['chest'],0,0),(1-w,w,0,0)
 for s in ['L','R']:
  if name==s+'_arm' and y<1.16:
   w=clamp((y-1.04)/.12,0,1);return (J[s+'_forearm'],bone,0,0),(1-w,w,0,0)
  if name==s+'_thigh':
   w=clamp((y-.40)/.12,0,1);return (J[s+'_shin'],bone,0,0),(1-w,w,0,0)
 if name=='hips' and mat==1 and y<.72:
  leg=J[('L' if p[0]<0 else 'R')+'_thigh'];w=clamp((.72-y)/.35,0,.8);return (bone,leg,0,0),(1-w,w,0,0)
 return (bone,0,0,0),(1,0,0,0)

def export(model):
 data=bytearray();views=[];access=[]
 def buffer(values,fmt,kind,component=5126,bounds=False):
  while len(data)%4:data.append(0)
  start=len(data);flat=[x for row in values for x in (row if isinstance(row,(tuple,list)) else [row])];data.extend(struct.pack('<'+fmt*len(flat),*flat));views.append({'buffer':0,'byteOffset':start,'byteLength':len(data)-start})
  a={'bufferView':len(views)-1,'componentType':component,'count':len(values),'type':kind}
  if bounds:a.update(min=[min(v[i] for v in values) for i in range(len(values[0]))],max=[max(v[i] for v in values) for i in range(len(values[0]))])
  access.append(a);return len(access)-1
 nodes=[]
 for name,parent,p in RIG:nodes.append({'name':name,'translation':sub(p,RIG[parent][2]) if parent>=0 else p})
 for i,(_,parent,_) in enumerate(RIG):
  if parent>=0:nodes[parent].setdefault('children',[]).append(i)
 inv=[[1,0,0,0,0,1,0,0,0,0,1,0,-p[0],-p[1],-p[2],1] for _,_,p in RIG]
 skin={'name':'OathHumanoid18','joints':list(range(len(RIG))),'skeleton':0,'inverseBindMatrices':buffer(inv,'f','MAT4')}
 primitives=[]
 for mat,verts in sorted(model.parts.items()):
  # Weld identical positions within a material, with normals averaged over
  # adjacent anatomical faces. Metal remains flat for clean graphic bevels.
  sums={}
  for p,n,b in verts:
   key=tuple(round(x,6) for x in p);sums[key]=add(sums.get(key,(0,0,0)),n)
  w=[weights(p,b,mat) for p,n,b in verts]
  normals=[norm(sums[tuple(round(x,6) for x in p)]) if mat in (0,1,3,5) else n for p,n,b in verts]
  unique=[];indices=[];lookup={}
  for i,(p,n,b) in enumerate(verts):
   key=tuple(round(x,6) for x in (*p,*normals[i],*w[i][0],*w[i][1]))
   if key not in lookup:lookup[key]=len(unique);unique.append((p,normals[i],w[i]))
   indices.append((lookup[key],))
  primitives.append({'attributes':{'POSITION':buffer([v[0] for v in unique],'f','VEC3',bounds=True),'NORMAL':buffer([v[1] for v in unique],'f','VEC3'),'JOINTS_0':buffer([v[2][0] for v in unique],'H','VEC4',5123),'WEIGHTS_0':buffer([v[2][1] for v in unique],'f','VEC4')},'indices':buffer(indices,'H','SCALAR',5123),'material':mat})
 nodes.append({'name':model.role+'_body','mesh':0,'skin':0,'extras':{'oath_character_v3':True}})
 animations=[]
 for clip,duration in [('Idle',2.8),('Walk',.5),('Run',1/3),('Attack',.38),('Cast',.45),('Hit',.26),('Death',.85)]:
  count=33 if clip in ('Walk','Run') else 25
  poses=[pose(model,clip,i/(count-1)) for i in range(count)];times=buffer([(i*duration/(count-1),) for i in range(count)],'f','SCALAR',bounds=True);sam=[];ch=[]
  for bone in range(len(RIG)):
   if RIG[bone][0] in ('root','spine','neck'):continue # Permanently static across every clip.
   vals=[p[0][bone] for p in poses]
   for k in range(1,len(vals)):
    if dot(vals[k-1],vals[k])<0:vals[k]=tuple(-x for x in vals[k])
   curve_times=times
   if all(max(abs(a-b) for a,b in zip(value,vals[0]))<1e-7 for value in vals):
    vals=[vals[0],vals[-1]];curve_times=buffer([(0,),(duration,)],'f','SCALAR',bounds=True)
   sam.append({'input':curve_times,'output':buffer(vals,'f','VEC4'),'interpolation':'LINEAR'});ch.append({'sampler':len(sam)-1,'target':{'node':bone,'path':'rotation'}})
  hips=J['hips'];sam.append({'input':times,'output':buffer([p[1][hips] for p in poses],'f','VEC3'),'interpolation':'LINEAR'});ch.append({'sampler':len(sam)-1,'target':{'node':hips,'path':'translation'}})
  animations.append({'name':clip,'samplers':sam,'channels':ch})
 mats=[{'name':n,'pbrMetallicRoughness':{'baseColorFactor':[*c,1],'metallicFactor':metal,'roughnessFactor':rough},'doubleSided':True} for n,c,metal,rough in model.palette]
 doc={'asset':{'version':'2.0','generator':'Lantern Oath authored mesh/pose pipeline v3'},'scene':0,'scenes':[{'name':model.role,'nodes':[0,len(nodes)-1]}],'nodes':nodes,'skins':[skin],'meshes':[{'name':model.role,'primitives':primitives}],'materials':mats,'animations':animations,'buffers':[{'byteLength':len(data)}],'bufferViews':views,'accessors':access}
 js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4);data+=b'\0'*((-len(data))%4)
 glb=struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(data))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(data),0x004e4942)+data
 OUT.mkdir(parents=True,exist_ok=True);(OUT/(model.role+'.glb')).write_bytes(glb)
 return {'id':model.role,'triangles':sum(len(v)//3 for v in model.parts.values()),'surfaces':len(primitives),'bones':len(RIG),'bytes':len(glb),'clips':[a['name'] for a in animations]}
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--representatives',action='store_true');args=parser.parse_args()
 ids=['knight','ashfang_raider','hollow_gravebound','verdant_thornblade'] if args.representatives else IDS
 report=[export(Character(id).build()) for id in ids]
 (OUT.parent/('representatives-v3.json' if args.representatives else 'manifest-v3.json')).write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
