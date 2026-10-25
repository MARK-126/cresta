import json, math, zlib, struct, os
def png(path):
    d=open(path,'rb').read(); i=8; idat=b''; 
    while i<len(d):
        l,=struct.unpack('>I',d[i:i+4]); t=d[i+4:i+8]; c=d[i+8:i+8+l]
        if t==b'IHDR': w,h,bd,ct=struct.unpack('>IIBB',c[:10])
        if t==b'IDAT': idat+=c
        i+=12+l
    bpp={2:3,6:4}[ct]; raw=zlib.decompress(idat); st=w*bpp; out=bytearray(); prev=bytearray(st); p=0
    for y in range(h):
        f=raw[p]; line=bytearray(raw[p+1:p+1+st]); p+=1+st
        for x in range(st):
            a=line[x-bpp] if x>=bpp else 0; b=prev[x]; c=prev[x-bpp] if x>=bpp else 0
            if f==1: line[x]=(line[x]+a)&255
            elif f==2: line[x]=(line[x]+b)&255
            elif f==3: line[x]=(line[x]+(a+b)//2)&255
            elif f==4:
                pa=abs(b-c); pb=abs(a-c); pc=abs(a+b-2*c)
                pr=a if pa<=pb and pa<=pc else (b if pb<=pc else c); line[x]=(line[x]+pr)&255
        out+=line; prev=line
    return w,h,bpp,out
Z=12; N=2**Z; cache={}
def tile(x,y):
    if (x,y) not in cache:
        w,h,bpp,px=png(f'tiles/dem/{Z}/{x}/{y}')
        cache[(x,y)]=[ (px[i]*256+px[i+1]+px[i+2]/256-32768) for i in range(0,len(px),bpp)]
    return cache[(x,y)]
def gpx(lat,lon):
    X=(lon+180)/360*N*256; r=math.radians(lat); Y=(1-math.log(math.tan(r)+1/math.cos(r))/math.pi)/2*N*256; return X,Y
def epx(X,Y):
    X=int(X); Y=int(Y); return tile(X//256,Y//256)[(Y%256)*256+X%256]
def elev(lat,lon):
    X,Y=gpx(lat,lon); X-=.5; Y-=.5; x0=math.floor(X); y0=math.floor(Y); fx=X-x0; fy=Y-y0
    return (epx(x0,y0)*(1-fx)*(1-fy)+epx(x0+1,y0)*fx*(1-fy)+epx(x0,y0+1)*(1-fx)*fy+epx(x0+1,y0+1)*fx*fy)
def hav(a,b):
    R=6371000; p1,p2=map(math.radians,(a[1],b[1])); dl=math.radians(b[0]-a[0]); dp=p2-p1
    return 2*R*math.asin(math.sqrt(math.sin(dp/2)**2+math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2))
osm=json.load(open('osm.json'))['elements']; ways={e['id']:e for e in osm if e['type']=='way'}
g=lambda wid: [[p['lon'],p['lat']] for p in ways[wid]['geometry']]
route=g(266213395)[::-1]+g(266213409)[::-1]+g(732156492)[1:]
dist=[0]; 
for i in range(1,len(route)): dist.append(dist[-1]+hav(route[i-1],route[i]))
ele=[elev(p[1],p[0]) for p in route]
# smoothed gain
sm=[sum(ele[max(0,i-3):i+4])/len(ele[max(0,i-3):i+4]) for i in range(len(ele))]
gain=sum(max(0,sm[i]-sm[i-1]) for i in range(1,len(sm)))
print('route pts',len(route),'km',dist[-1]/1000,'gain',gain,'min',min(ele),'max',max(ele), 'start',ele[0],'end',ele[-1])
r5=lambda v: round(v,5)
others=[[[r5(a),r5(b)] for a,b in g(w)] for w in ways if w not in (266213395,266213409,732156492)]
# contours
S_,W_,N_,E_=18.97,-98.74,19.22,-98.54
X0,Y0=gpx(N_,W_); X1,Y1=gpx(S_,E_); X0,Y0,X1,Y1=int(X0),int(Y0),int(X1),int(Y1)
step=2
xs=list(range(X0,X1,step)); ys=list(range(Y0,Y1,step))
grid=[[epx(x,y) for x in xs] for y in ys]
def ll(X,Y):
    lon=X/(N*256)*360-180; n=math.pi-2*math.pi*Y/(N*256); return [r5(lon),r5(math.degrees(math.atan(math.sinh(n))))]
contours=[]
H=len(ys); Wd=len(xs)
for lev in range(2300,5500,100):
    segs={}
    adj={}
    def pt(key):
        k,i,j=key
        if k=='h': a=grid[i][j]; b=grid[i][j+1]; t=(lev-a)/(b-a); return ll(xs[j]+t*step+.5, ys[i]+.5)
        a=grid[i][j]; b=grid[i+1][j]; t=(lev-a)/(b-a); return ll(xs[j]+.5, ys[i]+t*step+.5)
    for i in range(H-1):
        for j in range(Wd-1):
            a,b,c,d=grid[i][j],grid[i][j+1],grid[i+1][j+1],grid[i+1][j]
            e=[]
            if (a<lev)!=(b<lev): e.append(('h',i,j))
            if (b<lev)!=(c<lev): e.append(('v',i,j+1))
            if (d<lev)!=(c<lev): e.append(('h',i+1,j))
            if (a<lev)!=(d<lev): e.append(('v',i,j))
            for k in range(0,len(e)-1,2):
                adj.setdefault(e[k],[]).append(e[k+1]); adj.setdefault(e[k+1],[]).append(e[k])
    seen=set()
    for start in list(adj):
        if start in seen: continue
        # walk to an end
        line=[start]; seen.add(start)
        for direction in (0,1):
            cur=line[-1] if direction==0 else line[0]
            while True:
                nxt=[n for n in adj[cur] if n not in seen]
                if not nxt: break
                cur=nxt[0]; seen.add(cur)
                if direction==0: line.append(cur)
                else: line.insert(0,cur)
        if len(line)<4: continue
        coords=[pt(k) for k in line]
        # thin
        coords=coords[::2]+([coords[-1]] if len(coords)%2==0 else [])
        contours.append({'type':'Feature','properties':{'ele':lev,'idx':lev%500==0},'geometry':{'type':'LineString','coordinates':coords}})
print('contours',len(contours), sum(len(f['geometry']['coordinates']) for f in contours))
# simplified profile
prof=[]; last=-1e9
for d_,e_ in zip(dist,ele):
    if d_-last>=40: prof.append([round(d_),round(e_)]); last=d_
prof.append([round(dist[-1]),round(ele[-1])])
nodes=[e for e in osm if e['type']=='node']
data={'route':[[r5(a),r5(b)] for a,b in route],'routeDist':[round(x) for x in dist],'routeEle':[round(x) for x in ele],'profile':prof,'gain':round(gain),'trails':others,'contours':contours,
 'osmNodes':[{'name':e['tags'].get('name'),'lat':e['lat'],'lon':e['lon'],'ele':e['tags'].get('ele'),'kind':e['tags'].get('natural') or e['tags'].get('tourism')} for e in nodes]}
# sample elevations for POIs
extra={'pdc':(19.08844,-98.64714)}
data['pdcEle']=round(elev(*extra['pdc']))
json.dump(data,open('data.json','w'),separators=(',',':'))
print('data.json',os.path.getsize('data.json'))
