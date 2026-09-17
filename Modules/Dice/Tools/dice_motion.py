"""Trajectoires continues, évaluées dans Blender (mathutils)."""
import math
from bisect import bisect_left
from mathutils import Vector, Quaternion

ROLL_SECONDS = 1.56
LAND_SECONDS = .84
JOIN_SPEED = 12.0  # radians/s, identique des deux côtés du raccord
AXIS = Vector((.8, .5, .3)).normalized()

def distance(a, b):
    # atan2 est stable près de zéro, contrairement à acos(dot) en float32.
    delta = b @ a.conjugated()
    return 2 * math.atan2(Vector((delta.x,delta.y,delta.z)).length, abs(delta.w))

ROLL_VARIANTS = ((3.6,2.7),(-4.4,3.4),(4.8,-2.6),(-3.8,-3.2))

class FullRoll:
    """Intègre un seul mouvement amorti depuis la pose finale, sans raccord."""
    duration=2.4
    steps=1440

    def __init__(self, profile):
        phase=(profile-1)*1.4
        self.poses=[None]*(self.steps+1)
        self.poses[-1]=Quaternion((1,0,0,0))
        for i in range(self.steps-1,-1,-1):
            t=(i+.5)/self.steps
            axis=Vector((.85*math.cos(4*t+phase),.85*math.sin(3.3*t+phase),.65)).normalized()
            speed=22*(1-t)**1.5
            self.poses[i]=Quaternion(axis,-speed*self.duration/self.steps) @ self.poses[i+1]

    def at(self, t, target):
        if t>=1:return target.copy()
        position=max(0,t)*self.steps
        index=min(self.steps-1,int(position))
        return self.poses[index].slerp(self.poses[index+1],position-index) @ target

    def verify(self):
        target=Quaternion((1,0,0,0))
        poses=[self.at(i/143,target) for i in range(144)]
        speeds=[distance(a,b)*143/self.duration for a,b in zip(poses,poses[1:])]
        directions=[]
        for a,b in zip(poses[:120],poses[1:121]):
            delta=b @ a.conjugated()
            if delta.w<0:delta.negate()
            directions.append(delta.to_exponential_map().normalized())
        assert max(b-a for a,b in zip(speeds,speeds[1:]))<.02
        assert min(speeds[:120])>.5
        assert speeds[-1]<.03
        spread=min(a.dot(b) for a in directions for b in directions)
        assert spread<.5
        return {'max_speed_increase':max(b-a for a,b in zip(speeds,speeds[1:])),
                'first_speed':speeds[0],'last_speed':speeds[-1],'direction_spread':spread}

def rolling(start, t, variant=1):
    remaining = 1 - t
    # Quatre tours avec une vitesse qui diminue sans atteindre zéro au raccord.
    angle = -JOIN_SPEED * ROLL_SECONDS * remaining
    angle -= (8 * math.pi - JOIN_SPEED * ROLL_SECONDS) * remaining**2
    # Retrouver la culbute sur plusieurs axes. Les rotations secondaires
    # disparaissent progressivement avec leur vitesse au raccord : toutes
    # les variantes rejoignent ainsi les mêmes arrêts sans à-coup.
    pitch,yaw=ROLL_VARIANTS[variant-1]
    drift=remaining*remaining
    return (Quaternion(Vector((0,1,0)),pitch*drift)
            @ Quaternion(Vector((0,0,1)),yaw*drift)
            @ Quaternion(AXIS,angle) @ start)

def verify_roll(start, variant):
    dt=.001
    before=rolling(start,1-dt/ROLL_SECONDS,variant)
    delta=start @ before.conjugated()
    if delta.w<0:delta.negate()
    velocity=delta.to_exponential_map()/dt
    assert velocity.normalized().dot(AXIS)>.999
    assert abs(velocity.length-JOIN_SPEED)<.05
    assert distance(rolling(start,1,variant),start)<1e-6
    directions=[];speeds=[]
    poses=[rolling(start,i/95,variant) for i in range(96)]
    for a,b in zip(poses,poses[1:]):
        delta=b @ a.conjugated()
        if delta.w<0:delta.negate()
        vector=delta.to_exponential_map()
        directions.append(vector.normalized());speeds.append(vector.length*95/ROLL_SECONDS)
    spread=min(a.dot(b) for a in directions for b in directions)
    assert spread<.5,'Rotation trop proche d’un axe fixe'
    assert sum(speeds[:20])>sum(speeds[-20:]),'La culbute doit perdre son élan'
    return {'variant':variant,'direction_spread':spread,'join_speed':velocity.length}

class Landing:
    def __init__(self, start, target):
        side=AXIS.cross(Vector((0,0,1))).normalized()
        # Éviter les courbes en épingle lorsque le résultat est derrière
        # l'orientation du raccord. Seules les trajectoires sans ralentissement
        # suivi d'une reprise visible sont acceptées.
        for angle in (1.0,1.6,2.2):
            for twist in (0,.8,-.8,1.4,-1.4):
                self.controls = [start, Quaternion(AXIS, angle) @ start,
                    Quaternion(side, twist) @ Quaternion(AXIS, -.5) @ target, target]
                self.controls=[q.copy() for q in self.controls]
                for q in self.controls:
                    if q.dot(start)<0:q.negate()
                self.samples = [self.curve(i / 2048) for i in range(2049)]
                self.lengths = [0.0]
                for a,b in zip(self.samples,self.samples[1:]):
                    self.lengths.append(self.lengths[-1]+distance(a,b))
                self.length=self.lengths[-1]
                self.power=JOIN_SPEED*LAND_SECONDS/self.length
                if self.power<=1:continue
                try:self.verify(start)
                except AssertionError:continue
                return
        raise AssertionError('Aucune trajectoire continue sans reprise trouvée')

    def curve(self, t):
        weights=((1-t)**3,3*t*(1-t)**2,3*t*t*(1-t),t**3)
        return Quaternion(tuple(sum(w*q[k] for w,q in zip(weights,self.controls))
                                for k in range(4))).normalized()

    def at(self, t):
        if t <= 0: return self.controls[0].copy(), 0.0
        if t >= 1: return self.controls[-1].copy(), 1.0
        progress = 1 - (1 - t)**self.power
        length = progress * self.length
        index = max(1, min(2048, bisect_left(self.lengths, length)))
        before, after = self.lengths[index-1:index+1]
        fraction = (length-before) / max(after-before, 1e-12)
        return self.samples[index-1].slerp(self.samples[index], fraction), progress

    def verify(self, start):
        dt = .001
        before = rolling(start, 1-dt/ROLL_SECONDS)
        after = self.at(dt/LAND_SECONDS)[0]
        incoming_q = start @ before.conjugated()
        outgoing_q = after @ start.conjugated()
        if incoming_q.w < 0: incoming_q.negate()
        if outgoing_q.w < 0: outgoing_q.negate()
        incoming = incoming_q.to_exponential_map() / dt
        outgoing = outgoing_q.to_exponential_map() / dt
        assert incoming.normalized().dot(outgoing.normalized()) > .995, (incoming[:],outgoing[:])
        assert abs(outgoing.length-incoming.length) < .15
        poses = [self.at(i/120)[0] for i in range(121)]
        speeds = [distance(a,b)/(LAND_SECONDS/120) for a,b in zip(poses,poses[1:])]
        # Tolérance aux arrondis float32 et au dernier mouvement subpixel.
        assert max(b-a for a,b in zip(speeds,speeds[1:])) < .08, 'Reprise de vitesse'
        assert min(speeds[:100]) > .001, 'Arrêt prématuré'
        rendered=[self.at(i/47)[0] for i in range(48)]
        rendered_speeds=[distance(a,b)/(LAND_SECONDS/47) for a,b in zip(rendered,rendered[1:])]
        assert max(b-a for a,b in zip(rendered_speeds,rendered_speeds[1:])) < .08, 'Reprise dans les poses rendues'
        return {'join_speed':outgoing.length, 'path_length':self.length,
                'max_speed_increase':max(b-a for a,b in zip(speeds,speeds[1:])),
                'rendered_max_speed_increase':max(b-a for a,b in zip(rendered_speeds,rendered_speeds[1:]))}
