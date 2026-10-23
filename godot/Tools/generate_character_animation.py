"""Build original vector animation atlases; run with Python 3, no dependencies."""
from pathlib import Path
from math import sin, cos, pi
OUT=Path(__file__).resolve().parents[1]/'Assets/Art/Characters'
OUT.mkdir(parents=True,exist_ok=True)
def line(points,color,width):
 return '<path d="M'+' L'.join(f'{x:.2f} {y:.2f}' for x,y in points)+f'" fill="none" stroke="{color}" stroke-width="{width}"/>'
def circle(x,y,r,color):return f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r}" fill="{color}"/>'
def character(role,pose,t):
 crew=role=='rescuer'; coat='#568f9a' if crew else '#da823e'; skin='#e1bb96'; parts=[]
 gait=pose in ('walk','run'); running=pose=='run'; work=pose=='help'
 bob=(-abs(sin(t))*1.6 if running else -abs(sin(t))*.6) if gait else sin(t)*.35
 lean=2.0 if running else 0
 # Separate legs and boots, with alternating foot contact and lifted recovery.
 for side in (-1,1):
  phase=t+(pi if side==1 else 0)
  stride=sin(phase)*(9 if running else 6) if gait else side*1.5
  lift=max(0,cos(phase))*(6 if running else 3) if gait else 0
  hip=(side*2,-13+bob); foot=(side*2+stride,-1-lift)
  knee=((hip[0]+foot[0])/2+(-3 if running else 1),-7-lift*.5)
  if work: hip=(side*2,-12);knee=(side*7,-6);foot=(side*8,0)
  parts.append(line([hip,knee,foot],'#263f43',4))
  parts.append(line([(foot[0]-1,foot[1]),(foot[0]+3,foot[1])],'#193136',2.8))
 upper=4 if work else bob
 headx=lean+(3 if work else 0)
 parts.append(f'<g transform="translate({headx:.2f} {upper:.2f})">')
 parts.append(f'<path d="M-6-26Q0-29 6-26L6-13Q0-11-6-13Z" fill="{coat}" stroke="'+('#356775' if crew else '#ae5d33')+'"/>')
 parts.append(line([(-4,-25),(-4,-14)],'#d6dcb4' if crew else '#f1c47a',1.5))
 parts.append(line([(4,-25),(4,-14)],'#d6dcb4' if crew else '#f1c47a',1.5))
 if crew:parts.append(line([(-5,-18),(5,-18)],'#d6dcb4',1.5))
 for side in (-1,1):
  shoulder=(side*5,-24)
  if pose=='wave' and side==1:
   elbow=(10,-29);hand=(11+sin(t)*4,-37+cos(t)*1.5)
  elif work:
   elbow=(side*5+4,-18);hand=(side*3+9,-13+sin(t+side)*2)
  elif gait:
   swing=-sin(t+(pi if side==1 else 0))*(8 if running else 5)
   elbow=(side*5+swing,-19);hand=(side*5+swing+ (4 if running else 0),-16 if running else -13)
  else:elbow=(side*7,-19);hand=(side*7,-14)
  parts.append(line([shoulder,elbow,hand],coat,3.5));parts.append(circle(*hand,1.8,skin))
 parts.append('<path d="M-2-28v-3h4v3" fill="#d5ad8b"/>')
 parts.append('<ellipse cx="0" cy="-34" rx="4.2" ry="4.8" fill="#e1bb96"/>')
 if crew:
  parts.append('<path d="M-5-34q0-7 5-7t5 7Z" fill="#e8dfb6" stroke="#a9b696"/><path d="M-4-34H5" stroke="#537077" stroke-width="2"/><path d="M-4-33v4l4 1" fill="none" stroke="#42606a"/>')
 else:parts.append('<path d="M-4-35q-1-5 4-5 5 0 5 5l-3-2-5 1Z" fill="#5c4b3a"/>')
 parts.append('</g>');return ''.join(parts)
for role,poses in [('survivor',['idle','wave','walk']),('rescuer',['idle','run','walk','help'])]:
 for pose in poses:
  count=12
  frames=''.join(f'<g transform="translate({i*50+25} 46)">{character(role,pose,i*2*pi/count)}</g>' for i in range(count))
  (OUT/f'{role}-{pose}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{count*150}" height="150" viewBox="0 0 {count*50} 50"><g stroke-linecap="round" stroke-linejoin="round">{frames}</g></svg>\n')
print('Generated seven 12-frame character atlases.')
