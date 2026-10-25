"""Read-only source geometry audit for the fitted rigid equipment regions."""
import json
from pathlib import Path
import sys
import numpy as np
from PIL import Image,ImageDraw

base = Path(__file__).resolve().parents[1] / 'art/asset_review/equipment'
for identity in sys.argv[1:]:
    surfaces = json.loads((base / (identity + '_source.json')).read_text())
    all_points=[]
    for surface in surfaces:
        p=np.array(surface['points'])
        all_points.append(p)
        parents=list(range(len(p)))
        def find(x):
            while parents[x]!=x:
                parents[x]=parents[parents[x]]
                x=parents[x]
            return x
        def union(a,b):
            a,b=find(a),find(b)
            if a!=b: parents[a]=b
        faces=np.array(surface['indices']).reshape(-1,3)
        for a,b,c in faces:
            union(int(a),int(b)); union(int(a),int(c))
        welded={}
        for n,key in enumerate(map(tuple,np.round(p,4))):
            if key in welded: union(n,welded[key])
            else: welded[key]=n
        components={}
        for n in range(len(p)): components.setdefault(find(n),[]).append(n)
        components=sorted(components.values(),key=len,reverse=True)
        print(identity,'components',len(components))
        for component in components[:12]:
            q=p[component]
            print(len(q),np.round(q.min(axis=0),3),np.round(q.max(axis=0),3))
    p=np.concatenate(all_points)
    img=Image.new('RGB',(1800,900),'white');d=ImageDraw.Draw(img)
    for panel,(x,y,c) in enumerate([(0,1,2),(2,1,0),(0,2,1)]):
        order=np.argsort(p[:,c])[::-1]
        cmin,cmax=p[:,c].min(),p[:,c].max()
        scale=250;cx=panel*600+300;cy=790 if y==1 else 450
        for tick in np.arange(-1.4,2.5,.2):
            xx=cx+tick*scale; yy=cy-tick*scale
            if panel*600<xx<(panel+1)*600:
                d.line((xx,60,xx,840),fill='#dddddd');d.text((xx,850),f'{tick:.1f}',fill='black')
            if 60<yy<840:
                d.line((panel*600+20,yy,(panel+1)*600-20,yy),fill='#dddddd');d.text((panel*600+2,yy),f'{tick:.1f}',fill='black')
        for n in order:
            xx=int(cx+p[n,x]*scale); yy=int(cy-p[n,y]*scale)
            value=(p[n,c]-cmin)/(cmax-cmin)
            color=(int(230*value),int(100*(1-value)),int(230*(1-value)))
            if panel*600+20<xx<(panel+1)*600-20 and 60<yy<840:d.point((xx,yy),fill=color)
        d.text((panel*600+220,25),identity+' '+ 'XYZ'[x]+' / '+'XYZ'[y],fill='black')
    img.save(base/(identity+'_coordinates.png'))
