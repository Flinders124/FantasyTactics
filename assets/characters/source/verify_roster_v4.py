"""Offline deterministic checks for the three additive character assets."""
import json, math, struct
import build_roster_v4 as roster
s=roster.source
for role in roster.IDS:
 model=roster.RosterCharacter(role).build()
 data=(s.OUT/(role+'.glb')).read_bytes()
 size,kind=struct.unpack_from('<II',data,12)
 doc=json.loads(data[20:20+size])
 assert len(doc['skins'][0]['joints'])==18
 assert [x['name'] for x in doc['animations']]==['Idle','Walk','Run','Attack','Cast','Hit','Death']
 assert len(doc['meshes'][0]['primitives'])==7
 assert all(c['target']['path'] in ('rotation','translation') for a in doc['animations'] for c in a['channels'])
 assert len(data)==struct.unpack_from('<I',data,8)[0]
 ground=math.inf
 for t in [.2/.85,.4/.85,.6/.85,1.0]:
  q,pos=s.pose(model,'Death',t);gp,gq=s.fk(q,pos)
  for mat,verts in model.parts.items():
   for p,n,b in verts:
    bones,weights=s.weights(p,b,mat)
    assert abs(sum(weights)-1)<1e-6 and min(weights)>=0
    transformed=(0,0,0)
    for bone,w in zip(bones,weights):
     transformed=s.add(transformed,s.mul(s.add(gp[bone],s.qrot(gq[bone],s.sub(p,s.RIG[bone][2]))),w))
    ground=min(ground,transformed[1])
 assert ground>-.08,(role,'death-floor',ground)
 print(role, 'rig/weights/clips/indexed geometry PASS; collapse minimum Y',round(ground,4))
print('ROSTER OFFLINE RESULT: 0 failures')
