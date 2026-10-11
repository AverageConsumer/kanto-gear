from px import *
D={}
def reg(f): D[f.__name__]=f; return f

@reg
def map():
    c=C()
    # tri-fold map: three panels, middle one slightly darker
    pan=[(2,5,7,15),(8,3,7,15),(14,5,8,15)]
    c.fill(c.mask_poly([(2,6),(9,4),(9,19),(2,21)]),'#a8dc90')
    c.fill(c.mask_poly([(8,4),(15,6),(15,21),(8,19)]),'#88c8e8')
    c.fill(c.mask_poly([(14,6),(21,4),(21,19),(14,21)]),'#a8dc90')
    # road
    c.flat(c.mask_line(4,16,8,12,1.4),'#f0d890'); c.flat(c.mask_line(8,12,14,15,1.4),'#f0d890'); c.flat(c.mask_line(14,15,19,10,1.4),'#f0d890')
    # water bits
    c.flat({(10,8),(11,8),(12,9),(10,10),(11,10)},'#5aa8d8')
    # pin
    c.fill(c.mask_circle(16.5,7.5,3.6),'#f05040')
    c.fill(c.mask_poly([(14.2,9),(18.8,9),(16.5,13.5)]),'#f05040',shade=False)
    c.fill(c.mask_circle(16.5,7.5,3.6),'#f05040')
    c.flat({(16,7),(17,7),(16,8),(17,8)},'#ffffff'); c.flat({(15,6)},'#ffd0c8')
    return c

@reg
def tools():
    c=C()
    # field kit: red toolbox with handle and latch
    c.fill(c.mask_rrect(7,3,10,7,3),'#8890a0')
    c.flat(c.mask_rect(10,6,4,4),(0,0,0,0)) if False else None
    for p in [(i,j) for i in range(10,14) for j in range(6,10)]: c.px[p[1]][p[0]]=None
    c.fill(c.mask_rrect(2,8,20,13,2),'#e05040')
    c.fill(c.mask_rect(2,8,20,5),'#f06850')
    c.fill(c.mask_rrect(9,10,6,5,1),'#f8c840')
    c.flat({(11,12),(12,12)},'#7a5010')
    c.flat({(4,17),(5,17),(18,17),(19,17)},'#a82818')
    return c

@reg
def store():
    c=C()
    # shop: building, striped awning, door, window
    c.fill(c.mask_rect(3,9,18,12),'#f4f0e0')
    c.fill(c.mask_poly([(1,9),(4,3),(20,3),(23,9)]),'#e05040')
    for k in range(4):
        c.flat(c.mask_poly([(4+k*4+1,4),(6+k*4+1,4),(5+k*4+0.4,8.6),(3+k*4+0.4,8.6)]),'#f8f0e0')
    c.fill(c.mask_rect(1,8,22,3),'#c03828')
    c.fill(c.mask_rect(13,13,6,8),'#4888e0')
    c.flat({(17,17)},'#f8d040')
    c.fill(c.mask_rect(5,13,6,5),'#88d0f0')
    c.flat({(6,14),(7,14),(6,15)},'#ffffff')
    return c

@reg
def settings():
    c=C()
    # cog wheel with teeth + center hub
    teeth=set()
    for k in range(8):
        a=k*math.pi/4
        cx,cy=12+math.cos(a)*8.2,12+math.sin(a)*8.2
        teeth|=c.mask_circle(cx,cy,2.6)
    body=c.mask_circle(12,12,8.2)|teeth
    c.fill(body,'#8a98b0')
    c.fill(c.mask_circle(12,12,4.2),'#5a6c88')
    c.fill(c.mask_circle(12,12,2.2),'#f8f8f8',shade=False)
    return c

@reg
def bag():
    c=C()
    # backpack: top flap, body, pocket, straps
    c.fill(c.mask_rrect(9,1,6,5,2),'#c08030')
    for p in [(i,j) for i in range(11,13) for j in range(3,5)]: c.px[p[1]][p[0]]=None
    c.fill(c.mask_rrect(3,4,18,18,4),'#e8a030')
    c.fill(c.mask_rrect(3,4,18,8,4),'#d08020')
    c.fill(c.mask_rrect(6,13,12,7,2),'#c88028')
    c.fill(c.mask_rect(10,9,4,6),'#f8d860')
    c.flat({(11,11),(12,11)},'#805010')
    return c

@reg
def pokedex():
    c=C()
    # red handheld: hinge, big lens, small lights, screen
    c.fill(c.mask_rrect(3,1,18,22,3),'#e04838')
    c.fill(c.mask_rect(3,11,18,2),'#a82818',shade=False,outline=False)
    c.fill(c.mask_circle(8,6,3.6),'#ffffff')
    c.fill(c.mask_circle(8,6,2.6),'#58b8f0')
    c.flat({(7,5)},'#ffffff')
    c.fill(c.mask_circle(14,4,1.6),'#f86858',shade=False); c.fill(c.mask_circle(17,4,1.6),'#f8d040',shade=False)
    c.fill(c.mask_rrect(6,14,12,6,1),'#a8e090')
    c.flat({(8,16),(9,16),(10,16),(8,18),(9,18),(12,17),(13,17),(14,17)},'#4a8a40')
    return c

@reg
def trainer():
    c=C()
    # trainer card with portrait + lines + star
    c.fill(c.mask_rrect(1,4,22,16,2),'#4888e0')
    c.fill(c.mask_rrect(3,6,18,12,1),'#f8f8f0',shade=False)
    c.fill(c.mask_rect(4,7,7,9),'#f8d8a8',shade=False)
    c.fill(c.mask_circle(7.5,10,2.2),'#f8c8a0',shade=False)
    c.flat(c.mask_rect(5,7,5,2),'#e04838'); c.flat(c.mask_rect(5,13,5,3),'#e04838')
    for y in (9,12,15): c.flat(c.mask_rect(13,y,6,1),'#a0b0c0')
    c.flat({(19,7),(18,8),(19,8),(20,8),(19,9)},'#f8c840')
    return c

@reg
def steps():
    c=C()
    # sneaker with motion lines
    c.fill(c.mask_poly([(6,8),(12,8),(14,12),(21,14),(22,18),(4,18),(4,10)]),'#4888e0')
    c.fill(c.mask_rect(3,18,20,3),'#f8f8f8')
    c.flat({(8,12),(10,12),(9,13),(11,13)},'#ffffff')
    c.flat(c.mask_rect(15,14,5,1),'#e04838')
    for y,(x,w) in zip((6,10,14),((1,3),(0,2),(0,2))): c.flat(c.mask_rect(x,y,w,1),'#80a0c0')
    return c

@reg
def party():
    c=C()
    def ball(cx,cy,r):
        m=c.mask_circle(cx,cy,r)
        c.fill(m,'#f8f8f8')
        top={p for p in m if p[1]+0.5<cy}
        c.fill(top,'#e84838',outline=False)
        c.fill(c.mask_circle(cx,cy,r),'#000000',shade=False) if False else None
        for (i,j) in m:
            if abs(j+0.5-cy)<1: c.px[j][i]=OUT
        edge={(i,j) for (i,j) in m if any((i+di,j+dj) not in m for di,dj in ((1,0),(-1,0),(0,1),(0,-1)))}
        for (i,j) in edge: c.px[j][i]=OUT
        c.fill(c.mask_circle(cx,cy,2.1),'#f8f8f8',shade=False)
    ball(7,15,6); ball(17,15,6); ball(12,8,6)
    return c

@reg
def explorer():
    c=C()
    # compass: bezel, face, needle
    c.fill(c.mask_circle(12,12,11),'#d8a838')
    c.fill(c.mask_circle(12,12,8.5),'#f8f4e8',shade=False)
    for (x,y) in [(12,4),(12,19),(4,12),(19,12)]: c.flat({(x,y),(x-1 if x==12 else x, y if x==12 else y-1)},'#a0a8b0')
    c.flat(c.mask_poly([(12,5),(14.2,12),(9.8,12)]),'#e84838')
    c.flat(c.mask_poly([(12,19),(14.2,12),(9.8,12)]),'#5a6c88')
    c.fill(c.mask_circle(12,12,1.6),'#f8d040',shade=False)
    return c

@reg
def notes():
    c=C()
    # spiral notepad + pencil
    c.fill(c.mask_rrect(3,3,15,19,1),'#fff8e0')
    for x in (5,9,13): c.fill(c.mask_rrect(x,1,2,4,1),'#a0a8b8',shade=False)
    for y in (8,11,14,17): c.flat(c.mask_rect(5,y,10,1),'#98b8d8')
    c.flat(c.mask_rect(6,8,1,1),'#e05848')
    m=c.mask_line(20,6,12,19,3)
    c.fill(m,'#f8c040')
    c.fill(c.mask_circle(20.2,5.5,1.8),'#f08898',shade=False)
    c.flat({(12,19),(12,18),(13,19)},'#404040')
    return c

@reg
def pss():
    c=C()
    # two handhelds and signal arcs between them
    c.fill(c.mask_rrect(1,8,9,13,2),'#58b078')
    c.fill(c.mask_rect(3,10,5,4),'#d8f0e0',shade=False)
    c.fill(c.mask_rrect(14,8,9,13,2),'#4888e0')
    c.fill(c.mask_rect(16,10,5,4),'#d8e8f8',shade=False)
    for r in (3,6):
        c.flat({p for p in c.mask_ring(12,9,r,1) if p[1]<8},'#f8a030')
    c.flat({(11,8),(12,8)},'#f8a030')
    return c

@reg
def achievements():
    c=C()
    # medal: ribbon + round seal with star
    c.fill(c.mask_poly([(6,1),(11,1),(13,9),(8,9)]),'#4888e0')
    c.fill(c.mask_poly([(18,1),(13,1),(11,9),(16,9)]),'#e04838')
    c.fill(c.mask_circle(12,15,8),'#f8c840')
    c.fill(c.mask_circle(12,15,5.5),'#f0b020',shade=False,outline=False)
    star=c.mask_poly([(12,10),(13.4,13.4),(17,13.6),(14.2,15.8),(15.2,19.4),(12,17.4),(8.8,19.4),(9.8,15.8),(7,13.6),(10.6,13.4)])
    c.flat(star,'#fff4c0')
    return c

def sheet(names,scale=4,bg=(232,239,232)):
    from PIL import Image
    cols=8; rows=(len(names)+cols-1)//cols
    W=Image.new('RGBA',(cols*(26*scale),rows*(26*scale)),bg+(255,))
    for k,n in enumerate(names):
        im=D[n]().image(scale)
        W.paste(im,((k%cols)*26*scale+scale,(k//cols)*26*scale+scale),im)
    return W
if __name__=='__main__':
    import sys
    sheet(list(D)).save('icons_preview.png')

# ---------------- field tools ----------------
@reg
def bicycle():
    c=C()
    for cx in (5.5,18.5):
        c.flat(c.mask_ring(cx,17,5.5,1.6),OUT)
        c.flat(c.mask_ring(cx,17,4.4,0.9),'#788898')
        c.flat({(int(cx),17),(int(cx)-1,17),(int(cx),16),(int(cx)-1,16)},'#384858')
    fr='#e84838'
    for (a,b,cc,d) in [(5,16,9,9),(9,9,17,9),(9,9,12,16),(12,16,5,16),(17,9,18,16),(12,16,17,9)]:
        m=c.mask_line(a,b,cc,d,1)
        c.flat({(i,j+1) for (i,j) in m}|{(i+1,j) for (i,j) in m},OUT)
    for (a,b,cc,d) in [(5,16,9,9),(9,9,17,9),(9,9,12,16),(12,16,5,16),(17,9,18,16),(12,16,17,9)]:
        c.flat(c.mask_line(a,b,cc,d,1),fr)
    c.fill(c.mask_rect(6,6,5,3),'#384858',shade=False)
    c.flat(c.mask_line(17,9,18,5,1),'#384858'); c.fill(c.mask_rect(16,3,6,3),'#384858',shade=False)
    c.fill(c.mask_circle(12,16,1.6),'#c0c8d0',shade=False)
    return c

@reg
def fish():
    c=C()
    # rod with reel, line and a hooked fish
    c.flat(c.mask_line(3,21,16,4,2),'#a87038')
    c.flat(c.mask_line(3,21,7,16,2.2),'#384858')
    c.fill(c.mask_circle(7.5,15.5,2.6),'#c0c8d0',shade=False)
    c.flat(c.mask_line(16,4,19,9,1),'#e8f0f8'); c.flat(c.mask_line(19,9,19,13,1),'#e8f0f8')
    c.fill(c.mask_ellipse(18.5,17,4.2,2.8),'#58a8e8')
    c.fill(c.mask_poly([(14,17),(11.5,14.5),(11.5,19.5)]),'#3888d0',shade=False)
    c.flat({(20,16)},'#ffffff')
    c.outer_outline()
    return c

@reg
def cut():
    c=C()
    # scissors / cutting leaf
    c.fill(c.mask_poly([(4,3),(19,16),(16,18),(3,6)]),'#c8d0d8')
    c.fill(c.mask_poly([(20,3),(5,16),(8,18),(21,6)]),'#e0e6ec')
    for cx in (5,19):
        c.fill(c.mask_ring(cx,19,4,1.8),'#e84838',shade=False)
    c.flat({(12,10),(11,10),(12,11),(11,11)},'#384858')
    c.outer_outline()
    return c

@reg
def surf():
    c=C()
    # cresting wave
    c.fill(c.mask_poly([(1,22),(1,14),(5,9),(11,6),(17,7),(21,11),(18,12),(15,10),(12,11),(11,15),(14,18),(22,18),(23,22)]),'#3888d8')
    c.flat(c.mask_line(5,10,11,7,1),'#a8d8f8'); c.flat(c.mask_line(11,7,17,8,1),'#a8d8f8')
    c.flat({(18,12),(19,12),(16,10),(15,11),(13,12),(12,13)},'#f8f8f8')
    c.flat(c.mask_rect(2,20,20,1),'#68b0e8')
    return c

@reg
def strength():
    c=C()
    # boulder + flexed arm hint: big rock with cracks
    c.fill(c.mask_poly([(3,20),(4,11),(9,5),(16,4),(21,9),(22,20)]),'#a89880')
    c.flat(c.mask_line(10,8,12,13,1),'#706050'); c.flat(c.mask_line(12,13,9,17,1),'#706050'); c.flat(c.mask_line(12,13,17,15,1),'#706050')
    c.flat(c.mask_rect(1,20,23,2),'#384858')
    return c

@reg
def flash():
    c=C()
    # starburst bulb
    rays=set()
    for k in range(8):
        a=k*math.pi/4
        rays|=c.mask_line(12,12,12+math.cos(a)*11,12+math.sin(a)*11,2)
    c.flat(rays,'#f8e070')
    c.fill(c.mask_circle(12,12,6.5),'#f8d040')
    c.fill(c.mask_circle(11,11,2.5),'#fffbe0',shade=False,outline=False)
    c.outer_outline()
    return c

@reg
def headbutt():
    c=C()
    # tree with shaking marks
    c.fill(c.mask_rect(10,14,5,8),'#a06830')
    c.fill(c.mask_circle(12.5,9,8),'#48a850')
    c.fill(c.mask_circle(8,11,4),'#48a850')
    c.fill(c.mask_circle(17,11,4),'#48a850')
    c.fill(c.mask_circle(12.5,8,6.5),'#58b860',outline=False)
    c.flat({(16,6),(15,7),(9,5)},'#f05848')
    for (x,y) in [(1,6),(1,9),(22,6),(22,9)]: c.flat({(x,y),(x,y+1)},'#384858')
    return c

@reg
def whirlpool():
    c=C()
    c.fill(c.mask_circle(12,12,11),'#3888d8')
    # spiral arm
    pts=[]
    for k in range(70):
        t=k/69*3.2*math.pi
        r=1.2+t*0.9
        pts.append((12+math.cos(t)*r,12+math.sin(t)*r))
    arm=set()
    for (x,y) in pts: arm|={(int(x),int(y))}
    c.flat(arm,'#a8dcfc')
    c.flat({(int(x)+1,int(y)) for (x,y) in pts[10:]} - arm,'#2868b8')
    c.flat({(11,11),(12,11),(11,12),(12,12)},'#ffffff')
    return c

@reg
def waterfall():
    c=C()
    c.fill(c.mask_rect(2,1,6,14),'#887868'); c.fill(c.mask_rect(16,1,6,14),'#887868')
    c.fill(c.mask_rect(7,1,10,16),'#58a8e8',shade=False)
    for x in (9,12,15): c.flat(c.mask_rect(x,2,1,13),'#d0ecfc')
    c.fill(c.mask_ellipse(12,19,10,4),'#3888d8')
    c.flat({(7,18),(9,17),(15,17),(17,18),(12,17)},'#ffffff')
    return c

@reg
def sweet_scent():
    c=C()
    # flower with scent swirls
    for k in range(5):
        a=k*2*math.pi/5-math.pi/2
        c.fill(c.mask_circle(11+math.cos(a)*5,13+math.sin(a)*5,3.6),'#f080a8')
    c.fill(c.mask_circle(11,13,3),'#f8d040')
    c.flat({p for p in c.mask_ring(19,5,3,1) if p[0]>18 or p[1]<5},'#e868a8')
    c.flat({(17,1),(18,1),(20,2)},'#e868a8')
    return c

@reg
def dig():
    c=C()
    # shovel in a dirt mound
    c.fill(c.mask_ellipse(12,20,11,4),'#a07040')
    c.flat(c.mask_line(17,2,11,13,2),'#a87038')
    c.fill(c.mask_poly([(9,11),(14,13.5),(10,20),(6,17)]),'#c8d0d8')
    c.fill(c.mask_rrect(15,1,5,3,1),'#384858',shade=False)
    c.flat({(4,19),(7,21),(18,19),(20,21)},'#704820')
    c.outer_outline()
    return c

@reg
def teleport():
    c=C()
    # warp: concentric diamond portal with sparkle
    for r,col in ((11,'#8858d8'),(8,'#a878f0'),(5,'#c8a0f8')):
        c.fill(c.mask_poly([(12,12-r),(12+r,12),(12,12+r),(12-r,12)]),col)
    c.fill(c.mask_poly([(12,9),(15,12),(12,15),(9,12)]),'#f8f0ff',shade=False)
    c.flat({(19,3),(18,4),(19,4),(20,4),(19,5)},'#f8e070')
    return c

@reg
def softboiled():
    c=C()
    c.fill(c.mask_ellipse(12,13,8,10),'#fff8e8')
    c.fill(c.mask_circle(12,15,4),'#f8b030',outline=False)
    c.flat({(9,7),(10,7),(9,8)},'#ffffff')
    c.fill(c.mask_poly([(18,2),(22,2),(22,6)]),'#f06898',shade=False) if False else None
    for (x,y) in [(18,3),(19,2),(20,3),(19,4)]: pass
    # heart sparkle
    c.flat({(18,3),(20,3),(17,4),(18,4),(19,4),(20,4),(21,4),(18,5),(19,5),(20,5),(19,6)},'#f06090')
    return c

@reg
def squirtbottle():
    c=C()
    c.fill(c.mask_rrect(6,8,10,14,2),'#68b8f0')
    c.fill(c.mask_rect(9,4,4,5),'#a0a8b8')
    c.fill(c.mask_rect(12,4,7,2),'#a0a8b8',shade=False)
    for (x,y) in [(20,8),(21,10),(22,7),(20,12)]: c.flat({(x,y)},'#68b8f0')
    c.fill(c.mask_rect(8,12,6,5),'#f8f8f8',shade=False)
    c.flat({(10,13),(11,14),(10,15)},'#48a858')
    return c

@reg
def itemfinder():
    c=C()
    # handheld finder: antenna with a lit tip, body, round radar screen with a blip
    c.flat(c.mask_line(15,8,18,4,1),'#384858')
    c.fill(c.mask_circle(19,3.6,2.1),'#f8d040',shade=False)
    c.fill(c.mask_rrect(4,7,15,15,3),'#e86838')
    c.fill(c.mask_circle(11.5,13.5,5.2),'#2f5f48',shade=False)
    c.flat(c.mask_ring(11.5,13.5,3.2,0.8),'#58b878')
    c.flat(c.mask_line(11.5,13.5,15,10.5,1),'#a8f0b8')
    c.flat({(13,15),(14,15),(13,16),(14,16)},'#f8f070')
    c.fill(c.mask_rect(7,19,3,2),'#384858',shade=False)
    c.fill(c.mask_rect(13,19,3,2),'#384858',shade=False)
    c.outer_outline()
    return c

@reg
def pg_clock():
    c=C()
    # gear clock: red rim, cream face, two hands and tick marks
    c.fill(c.mask_circle(12,12.5,10.5),'#e05040')
    c.fill(c.mask_circle(12,12.5,7.6),'#fff8e8',shade=False)
    for (x,y) in [(11,5),(12,5),(18,12),(18,13),(11,19),(12,19),(5,12),(5,13)]: c.flat({(x,y)},'#a09080')
    c.flat(c.mask_line(12,12.5,12,7.5,1),'#384858')
    c.flat(c.mask_line(12,12.5,15.5,14.5,1),'#384858')
    c.flat({(11,12),(12,12),(11,13),(12,13)},'#e05040')
    c.flat({(7,6),(8,5)},'#ffffff')
    return c

@reg
def pg_phone():
    c=C()
    # Gen 2 cell phone: antenna, lit screen, keypad
    c.flat(c.mask_line(16,6,16,1,1),'#384858'); c.fill(c.mask_circle(16.5,1.8,1.4),'#e05040',shade=False)
    c.fill(c.mask_rrect(6,5,12,18,3),'#5878c8')
    c.fill(c.mask_rect(8,7,8,6),'#b8f0a0',shade=False)
    c.flat(c.mask_rect(9,9,4,1),'#307040'); c.flat(c.mask_rect(9,11,6,1),'#307040')
    for j in (15,17,19):
        for i in (8,11,14): c.flat({(i,j),(i+1,j)},'#e8f0f8')
    c.outer_outline()
    return c

@reg
def pg_radio():
    c=C()
    # pocket radio: antenna, speaker grille, tuning dial
    c.flat(c.mask_line(5,9,9,2,1),'#384858'); c.flat({(9,1),(10,2)},'#f8d040')
    c.fill(c.mask_rrect(2,8,20,14,3),'#f0a030')
    c.fill(c.mask_rrect(4,10,9,10,2),'#704820',shade=False)
    for j in (12,14,16,18):
        c.flat(c.mask_rect(5,j,7,1),'#c08848')
    c.fill(c.mask_circle(17.5,13.5,2.8),'#fff8e8',shade=False)
    c.flat({(17,12),(17,13)},'#e05040')
    c.fill(c.mask_rect(15,18,6,2),'#384858',shade=False)
    c.outer_outline()
    return c

@reg
def runner():
    c=C()
    c.fill(c.mask_circle(14,4,2.6),'#f8f8f8')
    c.flat(c.mask_line(13,7,11,14,2.4),'#f8f8f8')
    c.flat(c.mask_line(12,9,17,11,2),'#f8f8f8'); c.flat(c.mask_line(12,9,7,11,2),'#f8f8f8')
    c.flat(c.mask_line(11,14,16,18,2.2),'#f8f8f8'); c.flat(c.mask_line(16,18,16,22,2),'#f8f8f8')
    c.flat(c.mask_line(11,14,8,19,2.2),'#f8f8f8'); c.flat(c.mask_line(8,19,4,20,2),'#f8f8f8')
    for y in (8,12,16): c.flat(c.mask_rect(1,y,3,1),'#f8f8f8')
    c.outer_outline()
    return c

# ---------------- 16px set: start menu + settings categories ----------------
def ball16(c,cx,cy,r,top='#e84838'):
    m=c.mask_circle(cx,cy,r)
    c.fill(m,'#f8f8f8')
    c.fill({p for p in m if p[1]+0.5<cy},top,outline=False)
    for (i,j) in m:
        if abs(j+0.5-cy)<0.9: c.px[j][i]=OUT
    edge={(i,j) for (i,j) in m if any((i+di,j+dj) not in m for di,dj in ((1,0),(-1,0),(0,1),(0,-1)))}
    for (i,j) in edge: c.px[j][i]=OUT
    c.fill(c.mask_circle(cx,cy,1.9),'#f8f8f8',shade=False)

@reg
def s_pokedex():
    c=C(16)
    c.fill(c.mask_rrect(2,1,12,14,2),'#e04838')
    c.fill(c.mask_circle(6,5,2.6),'#58b8f0')
    c.flat({(5,4)},'#ffffff')
    c.fill(c.mask_rect(4,9,8,4),'#a8e090',shade=False)
    c.flat({(10,3),(12,3)},'#f8d040')
    return c
@reg
def s_pokemon():
    c=C(16); ball16(c,8,8,7); return c
@reg
def s_pack():
    c=C(16)
    c.fill(c.mask_rrect(5,1,6,4,1),'#c08030')
    c.fill(c.mask_rrect(2,3,12,12,3),'#e8a030')
    c.fill(c.mask_rect(2,3,12,5),'#d08020',outline=False)
    c.fill(c.mask_rect(6,6,4,4),'#f8d860')
    return c
@reg
def s_pokegear():
    c=C(16)
    c.fill(c.mask_rrect(2,1,12,14,2),'#38a8a0')
    c.fill(c.mask_rect(4,3,8,6),'#c4f5a6',shade=False)
    c.flat({(5,5),(6,5),(7,5),(5,7),(6,7)},'#2b4d3b')
    for x in (4,7,10): c.fill(c.mask_rect(x,11,2,2),'#e8f0f0',shade=False)
    return c
@reg
def s_status():
    c=C(16)
    c.fill(c.mask_rrect(1,3,14,10,1),'#4888e0')
    c.fill(c.mask_rect(3,5,10,6),'#f8f8f0',shade=False,outline=False)
    c.fill(c.mask_rect(3,5,4,6),'#f8c8a0',shade=False,outline=False)
    c.flat(c.mask_rect(3,5,4,2),'#e04838')
    for y in (6,8,10): c.flat(c.mask_rect(8,y,5,1),'#a0b0c0')
    return c
@reg
def s_save():
    c=C(16)
    c.fill(c.mask_rrect(1,1,14,14,1),'#48a858')
    c.fill(c.mask_rect(4,1,8,5),'#f8f8f8',shade=False)
    c.flat(c.mask_rect(9,2,2,3),'#384858')
    c.fill(c.mask_rect(3,9,10,6),'#e8f0e8',shade=False)
    for y in (11,13): c.flat(c.mask_rect(5,y,6,1),'#a0b0a8')
    return c
@reg
def s_option():
    c=C(16)
    teeth=set()
    for k in range(8):
        a=k*math.pi/4; teeth|=c.mask_circle(8+math.cos(a)*5.6,8+math.sin(a)*5.6,1.9)
    c.fill(c.mask_circle(8,8,5.6)|teeth,'#8a98b0')
    c.fill(c.mask_circle(8,8,2.6),'#f8f8f8',shade=False)
    return c
@reg
def s_mods():
    c=C(16)
    # puzzle piece
    m=c.mask_rect(2,5,10,9)|c.mask_circle(7,4,2.4)|c.mask_circle(12.5,9.5,2.4)
    m-=c.mask_circle(2,9.5,1.8)
    c.fill(m,'#a868c8')
    return c
@reg
def s_quit():
    c=C(16)
    c.fill(c.mask_rect(2,1,9,14),'#c87858')
    c.fill(c.mask_rect(4,3,5,10),'#e8a878',shade=False)
    c.flat({(8,8)},'#f8e070')
    c.flat(c.mask_line(10,8,15,8,1.4),'#e04838')
    c.flat({(13,6),(14,7),(13,10),(14,9)},'#e04838')
    return c
@reg
def s_map():
    c=C(16)
    c.fill(c.mask_poly([(1,3),(6,1),(6,14),(1,15)]),'#a8dc90')
    c.fill(c.mask_poly([(5,1),(11,3),(11,15),(5,13)]),'#88c8e8')
    c.fill(c.mask_poly([(10,3),(15,1),(15,13),(10,15)]),'#a8dc90')
    c.fill(c.mask_circle(11,5,2.4),'#f05040',shade=False)
    c.flat({(11,5)},'#ffffff')
    return c
@reg
def c_appearance():
    c=C(16)
    c.fill(c.mask_ellipse(8,8,7,6.5),'#f0e0c0')
    c.flat(c.mask_circle(10.5,11,1.6),(0,0,0)) if False else None
    for (x,y,col) in [(5,5,'#f05848'),(9,4,'#48a8f0'),(12,7,'#58c060'),(5,9,'#f8c838')]:
        c.fill(c.mask_circle(x,y,1.8),col,shade=False)
    c.fill(c.mask_circle(10.5,11,1.6),'#c8b088',shade=False)
    return c
@reg
def c_display():
    c=C(16)
    c.fill(c.mask_rrect(1,2,14,10,1),'#5a6c88')
    c.fill(c.mask_rect(3,4,10,6),'#88d0f0',shade=False)
    c.flat({(4,5),(5,5),(4,6)},'#ffffff')
    c.fill(c.mask_rect(6,12,4,2),'#5a6c88',shade=False)
    c.fill(c.mask_rect(4,13,8,2),'#5a6c88',shade=False)
    return c
@reg
def c_battle():
    c=C(16)
    for (a,b,cc,d) in [(2,2,12,12),(14,2,4,12)]:
        c.flat(c.mask_line(a,b,cc,d,2.2),'#d8e0e8')
    c.outer_outline()
    c.fill(c.mask_rect(10,11,5,2),'#e04838',shade=False); c.fill(c.mask_rect(1,11,5,2),'#4888e0',shade=False)
    c.fill(c.mask_rect(12,12,2,3),'#a06830',shade=False); c.fill(c.mask_rect(2,12,2,3),'#a06830',shade=False)
    return c
@reg
def c_research():
    c=C(16)
    c.flat(c.mask_line(10,10,14,14,2.4),'#a06830')
    c.outer_outline()
    c.fill(c.mask_circle(6.5,6.5,5.5),'#a0a8b8')
    c.fill(c.mask_circle(6.5,6.5,3.6),'#c8ecfc',shade=False)
    c.flat({(5,5),(4,6)},'#ffffff')
    return c
@reg
def c_controls():
    c=C(16)
    c.fill(c.mask_rrect(0,4,16,9,4),'#4888e0')
    c.flat(c.mask_rect(3,8,4,1)|c.mask_rect(4,7,2,3),'#f8f8f8')
    c.fill(c.mask_circle(11,7.5,1.4),'#f05848',shade=False); c.fill(c.mask_circle(13,9.5,1.4),'#f8d040',shade=False)
    return c
@reg
def c_system():
    c=C(16)
    teeth=set()
    for k in range(6):
        a=k*math.pi/3; teeth|=c.mask_circle(8+math.cos(a)*5.6,8+math.sin(a)*5.6,2)
    c.fill(c.mask_circle(8,8,5.4)|teeth,'#40b0a0')
    c.fill(c.mask_circle(8,8,2.4),'#f8f8f8',shade=False)
    return c

# ---------------- PokéNav (Ruby/Sapphire/Emerald) ----------------
@reg
def pn_map():
    c=C()
    # Hoenn at a glance: sea, a long island with a mountain, a pin
    c.fill(c.mask_rrect(1,3,22,18,3),'#58a8e0')
    c.flat({(4,7),(5,7),(17,17),(18,17),(19,6),(20,6)},'#88c8f0')
    isl=c.mask_poly([(3,15),(6,9),(11,7),(16,9),(19,13),(15,17),(8,18)])
    c.fill(isl,'#88c860')
    c.fill(c.mask_poly([(9,13),(12,8),(15,13)]),'#a08060')
    c.flat({(12,9),(11,10),(12,10)},'#f8f8f8')
    c.flat(c.mask_line(5,15,9,14,1),'#f0d890'); c.flat(c.mask_line(15,14,18,13,1),'#f0d890')
    pin=c.mask_circle(17.5,6.5,4.2)|c.mask_poly([(14.6,8.5),(20.4,8.5),(17.5,14)])
    c.fill(pin,'#f05040')
    c.fill(c.mask_circle(17.5,6.5,1.7),'#ffffff',shade=False,outline=False)
    return c

@reg
def pn_condition():
    c=C()
    # the condition pentagon: frame, five-coloured sheen, filled stats
    pts=[(12+math.sin(k*2*math.pi/5)*10,12.5-math.cos(k*2*math.pi/5)*10) for k in range(5)]
    c.fill(c.mask_poly(pts),'#f0f0f8')
    inner=[(12+math.sin(k*2*math.pi/5)*r,12.5-math.cos(k*2*math.pi/5)*r) for k,r in enumerate((8,5,7,4,6.5))]
    c.fill(c.mask_poly(inner),'#e868a8',outline=False)
    cols=['#e85030','#3880e8','#f080b0','#48b048','#e8c030']
    for k,(x,y) in enumerate(pts):
        c.flat(c.mask_circle(x,y,1.6),cols[k])
    return c

@reg
def pn_matchcall():
    c=C()
    # PokéNav handset with signal waves
    c.fill(c.mask_rrect(2,7,12,16,3),'#e86030')
    c.fill(c.mask_rect(4,10,8,6),'#c4f0b0',shade=False)
    c.flat({(5,12),(6,12),(7,12),(5,14),(6,14)},'#2b4d3b')
    c.fill(c.mask_circle(8,19.5,1.8),'#f8f0e0',shade=False)
    for k,r in enumerate((3.5,6.5,9.5)):
        ring=c.mask_ring(13,10,r,1.3)
        c.flat({(i,j) for (i,j) in ring if i>=14 and j<=9 and i<24 and j>=0},'#2890e0' if k<2 else '#68b8f0')
    return c

@reg
def pn_eyes():
    c=C()
    # Trainer's Eyes: an eye with a red iris
    eye=c.mask_ellipse(12,12,10.5,6.5)
    c.fill(eye,'#f8f8f8')
    c.fill(c.mask_circle(12,12,5),'#e04838')
    c.fill(c.mask_circle(12,12,2.4),'#302830',shade=False,outline=False)
    c.flat({(10,10),(11,10),(10,9)},'#ffffff')
    return c

@reg
def pn_ribbons():
    c=C()
    # ribbon rosette with two tails
    c.fill(c.mask_poly([(8,12),(5,22),(9,20),(11,13)]),'#3880e8')
    c.fill(c.mask_poly([(16,12),(19,22),(15,20),(13,13)]),'#3880e8')
    petals=set()
    for k in range(10):
        a=k*math.pi/5
        petals|=c.mask_circle(12+math.cos(a)*6.4,9.5+math.sin(a)*6.4,2.6)
    c.fill(petals|c.mask_circle(12,9.5,6.4),'#f8c838')
    c.fill(c.mask_circle(12,9.5,3.6),'#e86030')
    c.flat({(11,8),(12,8)},'#f8b090')
    return c

@reg
def pn_off():
    c=C()
    # power key: red disc with the standby symbol
    c.fill(c.mask_circle(12,12,10),'#e04838')
    ring=c.mask_ring(12,13,6,1.8)
    gap={(i,j) for (i,j) in ring if j<10 and abs(i+0.5-12)<3.2}
    c.flat(ring-gap,'#f8f8f8')
    c.flat(c.mask_rect(11,5,2,8),'#f8f8f8')
    return c

@reg
def pn_party():
    c=C()
    def ball(cx,cy,r):
        m=c.mask_circle(cx,cy,r); c.fill(m,'#f8f8f8')
        c.fill({p for p in m if p[1]+0.5<cy},'#e84838',outline=False)
        for (i,j) in m:
            if abs(j+0.5-cy)<0.8: c.px[j][i]=OUT
        edge={(i,j) for (i,j) in m if any((i+di,j+dj) not in m for di,dj in ((1,0),(-1,0),(0,1),(0,-1)))}
        for (i,j) in edge: c.px[j][i]=OUT
        c.fill(c.mask_circle(cx,cy,1.6),'#f8f8f8',shade=False)
    ball(7,15,5.5); ball(17,15,5.5); ball(12,8,5.5)
    return c

@reg
def pn_search():
    c=C()
    c.fill(c.mask_line(15,15,21,21,3.2),'#8a6040')
    c.fill(c.mask_circle(10,10,7.5),'#5a6c88')
    c.fill(c.mask_circle(10,10,5),'#b8e0f8')
    c.flat({(8,7),(7,8),(8,8)},'#ffffff')
    return c

@reg
def pn_back():
    c=C()
    # return arrow on a grey key
    c.fill(c.mask_rrect(2,3,20,18,4),'#8a98b0')
    arr=c.mask_poly([(5,11),(11,5),(11,9),(17,9),(17,17),(13,17),(13,13),(11,13),(11,17)])
    c.flat(arr,'#f8f8f8')
    return c

def gem(c,col,shape):
    if shape=='star':
        pts=[]
        for k in range(10):
            r=10 if k%2==0 else 4.3; a=-math.pi/2+k*math.pi/5
            pts.append((12+math.cos(a)*r,12.5+math.sin(a)*r))
        c.fill(c.mask_poly(pts),col)
    elif shape=='flower':
        pet=set()
        for k in range(5):
            a=-math.pi/2+k*2*math.pi/5
            pet|=c.mask_circle(12+math.cos(a)*5.5,12+math.sin(a)*5.5,4.2)
        c.fill(pet,col); c.fill(c.mask_circle(12,12,3),'#f8d040')
    elif shape=='heart':
        m=c.mask_circle(8,9,5)|c.mask_circle(16,9,5)|c.mask_poly([(3.4,11),(20.6,11),(12,21)])
        c.fill(m,col)
    elif shape=='bulb':
        c.fill(c.mask_circle(12,10,7.5),col)
        c.fill(c.mask_rect(9,16,6,5),'#a8b0b8')
        c.flat({(9,18),(10,18),(11,18),(12,18),(13,18),(14,18)},'#788088')
        c.flat({(10,7),(9,8),(10,8)},'#ffffff')
    elif shape=='shield':
        c.fill(c.mask_poly([(4,4),(20,4),(20,12),(12,21),(4,12)]),col)
        c.flat(c.mask_rect(11,6,2,11),'#f8f0d0'); c.flat(c.mask_rect(7,10,10,2),'#f8f0d0')
    return c

@reg
def pn_cool(): return gem(C(),'#e85030','star')
@reg
def pn_beauty(): return gem(C(),'#3880e8','flower')
@reg
def pn_cute(): return gem(C(),'#f070a8','heart')
@reg
def pn_smart(): return gem(C(),'#48b048','bulb')
@reg
def pn_tough(): return gem(C(),'#e8b020','shield')

if __name__=='__main__':
    sheet([n for n in D if n.startswith('pn_')],scale=6).save('/home/claude/shots/pn_icons.png')
