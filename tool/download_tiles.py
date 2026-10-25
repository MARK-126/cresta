import math, os, subprocess, sys
def t(lat,lon,z):
    n=2**z; x=int((lon+180)/360*n); r=math.radians(lat)
    y=int((1-math.log(math.tan(r)+1/math.cos(r))/math.pi)/2*n); return x,y
def rng(b,z):
    s,w,n,e=b; x0,y0=t(n,w,z); x1,y1=t(s,e,z); return [(x,y) for x in range(x0,x1+1) for y in range(y0,y1+1)]
jobs=[]
WIDE=(18.92,-98.82,19.24,-98.46); CORE=(18.99,-98.70,19.21,-98.58)
for z in (10,11,12): jobs+= [('dem',z,x,y) for x,y in rng(WIDE,z)]
for z in (10,11,12,13): jobs+= [('sat',z,x,y) for x,y in rng(WIDE,z)]
jobs+= [('sat',14,x,y) for x,y in rng(CORE,14)]
print(len(jobs), {k:sum(1 for j in jobs if j[0]==k) for k in ('dem','sat')})
for k,z,x,y in jobs:
    p=f'tiles/{k}/{z}/{x}/{y}'; os.makedirs(os.path.dirname(p),exist_ok=True)
    if os.path.exists(p): continue
    u=f'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png' if k=='dem' else f'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
    subprocess.run(['curl','-s','-f','-m','30','-o',p,u])
