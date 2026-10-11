import math
from PIL import Image
OUT=(32,40,48)
def hexc(h):
    h=h.lstrip('#'); return tuple(int(h[i:i+2],16) for i in (0,2,4))
def mixc(a,b,t): return tuple(int(round(a[i]+(b[i]-a[i])*t)) for i in range(3))
def ramp(base):
    b=hexc(base) if isinstance(base,str) else base
    return {'M':b,'L':mixc(b,(255,255,255),0.45),'H':mixc(b,(255,255,255),0.75),'D':mixc(b,(0,0,0),0.32)}
class C:
    def __init__(s,n=24): s.n=n; s.px=[[None]*n for _ in range(n)]
    def mask_rect(s,x,y,w,h): return {(i,j) for i in range(x,x+w) for j in range(y,y+h)}
    def mask_circle(s,cx,cy,r):
        return {(i,j) for i in range(s.n) for j in range(s.n) if (i+0.5-cx)**2+(j+0.5-cy)**2<=r*r}
    def mask_ellipse(s,cx,cy,rx,ry):
        return {(i,j) for i in range(s.n) for j in range(s.n) if ((i+0.5-cx)/rx)**2+((j+0.5-cy)/ry)**2<=1}
    def mask_rrect(s,x,y,w,h,r):
        m=set()
        for i in range(x,x+w):
            for j in range(y,y+h):
                dx=max(x+r-0.5-i,0,i-(x+w-r-0.5)); dy=max(y+r-0.5-j,0,j-(y+h-r-0.5))
                if dx*dx+dy*dy<=r*r+0.3: m.add((i,j))
        return m
    def mask_poly(s,pts):
        m=set()
        for i in range(s.n):
            for j in range(s.n):
                x,y=i+0.5,j+0.5; inside=False
                for k in range(len(pts)):
                    x1,y1=pts[k]; x2,y2=pts[(k+1)%len(pts)]
                    if (y1>y)!=(y2>y) and x < (x2-x1)*(y-y1)/(y2-y1)+x1: inside=not inside
                if inside: m.add((i,j))
        return m
    def mask_line(s,x1,y1,x2,y2,w=2):
        m=set(); L=max(abs(x2-x1),abs(y2-y1))*4+1
        for k in range(int(L)+1):
            t=k/L; x=x1+(x2-x1)*t; y=y1+(y2-y1)*t
            for i in range(int(x-w/2+0.5),int(x+w/2+0.5)):
                for j in range(int(y-w/2+0.5),int(y+w/2+0.5)): m.add((i,j))
        return m
    def mask_ring(s,cx,cy,r,w):
        return {(i,j) for i in range(s.n) for j in range(s.n) if r-w<=math.hypot(i+0.5-cx,j+0.5-cy)<=r}
    def fill(s,m,color,shade=True,outline=True,light='tl'):
        rp=ramp(color) if isinstance(color,str) else {'M':color,'L':color,'D':color,'H':color}
        m={p for p in m if 0<=p[0]<s.n and 0<=p[1]<s.n}
        edge=set()
        if outline:
            edge={(i,j) for (i,j) in m if any((i+di,j+dj) not in m for di,dj in ((1,0),(-1,0),(0,1),(0,-1)))}
        inner=m-edge
        for (i,j) in inner:
            c=rp['M']
            if shade:
                up=(i,j-1) not in inner; lf=(i-1,j) not in inner
                dn=(i,j+1) not in inner; rt=(i+1,j) not in inner
                if up or lf: c=rp['L']
                if dn or rt: c=rp['D']
                if up and lf: c=rp['H']
            s.px[j][i]=c
        for (i,j) in edge: s.px[j][i]=OUT
        return m
    def flat(s,m,color):
        c=hexc(color) if isinstance(color,str) else color
        for (i,j) in m:
            if 0<=i<s.n and 0<=j<s.n: s.px[j][i]=c
    def outer_outline(s):
        add=[]
        for j in range(s.n):
            for i in range(s.n):
                if s.px[j][i] is None and any(0<=i+di<s.n and 0<=j+dj<s.n and s.px[j+dj][i+di] not in (None,) and s.px[j+dj][i+di]!=OUT for di,dj in ((1,0),(-1,0),(0,1),(0,-1))):
                    add.append((i,j))
        for i,j in add: s.px[j][i]=OUT
    def image(s,scale=1):
        im=Image.new('RGBA',(s.n,s.n),(0,0,0,0))
        for j in range(s.n):
            for i in range(s.n):
                if s.px[j][i]: im.putpixel((i,j),s.px[j][i]+(255,))
        return im.resize((s.n*scale,s.n*scale),Image.NEAREST)
