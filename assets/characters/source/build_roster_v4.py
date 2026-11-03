"""Original CC0 Milestone 4 recruit and approved A/B character profiles.
Additive build: python assets/characters/source/build_roster_v4.py
Never rewrites historical character assets. Shared editable mesh/rig math is in
build_characters.py; no external art, runtime geometry, or combat event tracks.
"""
import json, math, argparse
import build_characters as source

IDS = ['recruit', 'aegisbearer', 'chainbinder']

class RosterCharacter(source.Character):
 def __init__(self, role):
  super().__init__(role)
  self.palette[1] = ('cloth', source.rgb({'recruit':'638e83','aegisbearer':'2d8091','chainbinder':'536c86'}[role]),0,.95)
 def build(self):
  # Reuse the original continuous anatomical loops and shared skinning rules.
  # Only the protector uses the full plate profile; equipment is authored below.
  original = self.job
  if original == 'aegisbearer': self.job = 'knight'
  super().build()
  self.job = original
  return self
 def identity(self, armored):
  role=self.role
  if role=='recruit':
   # Plain folded collar and leather belt: no class badge, shield or magic.
   self.panel([(-.13,1.36),(0,1.28),(.13,1.36),(.09,1.25),(0,1.20),(-.09,1.25)],-.16,.025,6,'chest')
   self.shell([(0,1.78,.024,.145,.122),(0,1.84,.025,.12,.105),(0,1.87,.025,.04,.04)],5,'head',12)
  elif role=='aegisbearer':
   # Low angular brow, broad overlapping pauldrons, stone-rune breastplate.
   self.shell([(0,1.75,.025,.163,.145),(0,1.84,.035,.16,.145),(0,1.91,.04,.10,.095),(0,1.94,.04,.025,.025)],2,'head',8)
   self.panel([(-.16,1.78),(-.16,1.84),(.16,1.84),(.16,1.78),(0,1.80)],-.13,.035,4,'head')
   for s in [-1,1]:
    self.panel([(s*.14,1.34),(s*.27,1.52),(s*.49,1.43),(s*.48,1.27),(s*.31,1.23)],-.13,.20,2,'L_arm' if s<0 else 'R_arm')
   self.panel([(-.045,1.09),(.045,1.09),(.06,1.28),(0,1.35),(-.06,1.28)],-.255,.025,4,'chest')
  else:
   # Open face, short swept hair, asymmetric shoulder and chain-working glove.
   self.shell([(0,1.76,.04,.15,.13),(-.025,1.84,.06,.13,.115),(-.055,1.90,.10,.05,.05)],5,'head',12)
   self.panel([(-.12,1.34),(-.29,1.43),(-.39,1.32),(-.31,1.18),(-.17,1.21)],-.13,.16,2,'L_arm')
   self.tube([(-.19,1.34,-.18),(.17,.97,-.18)],[.032,.032],3,'chest',6)
   self.shell([(-.46,.80,-.02,.065,.055),(-.46,.88,-.02,.072,.06),(-.435,1.01,-.01,.084,.085)],2,'L_forearm',8)
   # Individually hollow interlocking links on a belt coil, not a solid torus.
   for k in range(11):
    angle=k*math.tau/11
    center=(-.19+.12*math.cos(angle),.93+.15*math.sin(angle),-.22)
    self.link(center, k%2==0, 'hips')
 def link(self,center,alternate,bone):
  cx,cy,cz=center
  points=[]
  for k in range(9):
   t=k*math.tau/8
   points.append((cx+.025*math.cos(t),cy+(.034*math.sin(t) if alternate else .014*math.sin(t)),cz+(.014*math.sin(t) if alternate else .034*math.sin(t))))
  self.tube(points,[.008]*9,2,bone,5)
 def weapons(self):
  x=.46;z=-.065
  if self.role=='recruit':
   self.tube([(x,.75,z),(x,1.04,z)],[.025,.025],3,'R_hand',8)
   self.tube([(x-.11,1.02,z),(x+.11,1.02,z)],[.018,.018],2,'R_hand',6)
   self.panel([(x-.035,1.05),(x+.035,1.05),(x+.032,1.48),(x,1.58),(x-.032,1.48)],z-.012,.035,2,'R_hand',.012)
  elif self.role=='aegisbearer':
   self.tube([(x,.38,z),(x,1.56,z)],[.025,.025],3,'R_hand',8)
   self.tube([(x,1.40,z),(x,1.49,z)],[.036,.036],4,'R_hand',8)
   self.panel([(x-.045,1.51),(x+.045,1.51),(x,1.82)],z-.02,.04,2,'R_hand')
   self.tube([(-.46,.84,-.03),(-.46,.84,-.22)],[.028,.028],3,'L_hand',8)
   self.panel([(-.78,.39),(-.80,1.38),(-.67,1.49),(-.26,1.49),(-.13,1.38),(-.15,.39),(-.30,.31),(-.63,.31)],-.24,.10,2,'L_hand',.035)
   self.panel([(-.71,.45),(-.73,1.34),(-.63,1.41),(-.30,1.41),(-.20,1.34),(-.22,.45)],-.29,.025,1,'L_hand')
   for yy in [.61,.88,1.15]:
    self.panel([(-.55,yy),(-.46,yy-.06),(-.37,yy),(-.46,yy+.12)],-.33,.018,4,'L_hand')
  else:
   self.tube([(x,.16,z),(x,1.79,z)],[.025,.025],3,'R_hand',10)
   for y in [.78,1.43]:self.tube([(x,y,z),(x,y+.10,z)],[.032,.032],4,'R_hand',8)
   self.panel([(x-.04,1.70),(x+.045,1.70),(x+.045,1.91),(x+.20,1.91),(x+.22,1.78),(x+.28,1.91),(x+.23,2.06),(x+.03,2.06),(x-.04,1.98)],z-.02,.06,2,'R_hand',.02)
   for k in range(7):self.link((-.46,.85+k*.045,-.07),k%2==0,'L_hand')

def roster_pose(model, clip, t):
 q,pos=BASE_POSE(model,clip,t)
 if model.role not in IDS or clip not in ('Attack','Cast'): return q,pos
 strength=math.cos(min(t/.60,1)*math.pi/2)**2
 if model.role=='aegisbearer':
  # Spear thrust and shield-forward ward brace have separate recoveries.
  source.solve(q,pos,'R','arm',source.mix((.43,.91,-.10),(.28,1.13,-.39),strength),(1,-.1,.35),source.qaxis((1,0,0),-76*strength) if clip=='Attack' else source.I)
  source.solve(q,pos,'L','arm',source.mix((-.43,.91,-.10),(-.30,1.09,-.34),strength),(-1,-.1,.35))
 elif model.role=='chainbinder' and clip=='Cast':
  # A hooked polearm remains upright while the chain gauntlet hauls back.
  source.solve(q,pos,'R','arm',(.36,1.04,-.15),(1,-.1,.35),source.qaxis((0,0,1),12*strength))
  source.solve(q,pos,'L','arm',source.mix((-.43,.91,-.10),(-.20,1.20,-.25),strength),(-1,-.1,.35))
 return q,pos

BASE_POSE=source.pose
source.pose=roster_pose

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--roles',nargs='+',choices=IDS,default=IDS);args=parser.parse_args()
 report=[source.export(RosterCharacter(role).build()) for role in args.roles]
 (source.OUT.parent/'manifest-v4.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
