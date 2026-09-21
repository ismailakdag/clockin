import json,struct
from pathlib import Path
import numpy as np
def qm(q):
 x,y,z,w=q/np.linalg.norm(q);return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def slerp(ts,vals,t):
 k=min(np.searchsorted(ts,t,side='right')-1,len(ts)-2);k=max(0,k)
 if len(ts)==1:return vals[0]
 a=vals[k].astype(float);b=vals[k+1].astype(float);u=(t-ts[k])/(ts[k+1]-ts[k]);dot=np.dot(a,b)
 if dot<0:b=-b;dot=-dot
 if dot>.9995:q=a+(b-a)*u;return q/np.linalg.norm(q)
 theta=np.arccos(np.clip(dot,-1,1));return (a*np.sin((1-u)*theta)+b*np.sin(u*theta))/np.sin(theta)

p=Path(__file__).with_name('animated-original.glb');b=p.read_bytes();n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n]);binary=b[28+n:]
def arr(i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']];size={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];return np.frombuffer(binary,dtype=dtype,count=a['count']*size,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(a['count'],size).copy()
anim=j['animations'][2];duration=max(arr(s['input'])[-1,0] for s in anim['samplers'])
parents={c:i for i,node in enumerate(j['nodes']) for c in node.get('children',[])}
def pose(t):
 tr=[np.array(x.get('translation',[0,0,0])) for x in j['nodes']];rot=[np.array(x.get('rotation',[0,0,0,1])) for x in j['nodes']]
 for c in anim['channels']:
  s=anim['samplers'][c['sampler']];ts=arr(s['input'])[:,0];vals=arr(s['output']);t0=np.clip(t,ts[0],ts[-1]);node=c['target']['node'];path=c['target']['path']
  if path=='rotation':rot[node]=slerp(ts,vals,t0)
  elif path=='translation':tr[node]=np.array([np.interp(t0,ts,vals[:,k]) for k in range(3)])
 return tr,rot
def matrices(tr,rot):
 world={}
 def one(i):
  if i in world:return world[i]
  m=np.eye(4);m[:3,:3]=qm(rot[i]);m[:3,3]=tr[i];world[i]=one(parents[i])@m if i in parents else m;return world[i]
 return np.array([one(i) for i in range(len(tr))])
def mul(a,b):
 av,aw=a[:3],a[3];bv,bw=b[:3],b[3];return np.r_[aw*bv+bw*av+np.cross(av,bv),aw*bw-np.dot(av,bv)]
def corrected(tr,rot,t):
 rot=[q.copy() for q in rot];m=matrices(tr,rot)
 # Lifted wave only, smooth transition; rotation about character-forward axis at elbow.
 def smooth(x):x=np.clip(x,0,1);return x*x*(3-2*x)
 wrist=m[10,:3,3];elbow=m[11,:3,3];v=wrist-elbow
 # Move the forearm direction away from the head as it enters the upper body zone.
 weight=smooth((max(wrist[1],elbow[1])-.70)/.28)
 desired=v+np.array([-.25*weight,0,0]);v=v/np.linalg.norm(v);desired=desired/np.linalg.norm(desired)
 axis=np.cross(v,desired);delta=np.r_[axis,1+np.dot(v,desired)];delta/=np.linalg.norm(delta)
 # Convert world-space delta to parent-local coordinates.
 delta[:3]=m[12,:3,:3].T@delta[:3]
 rot[11]=mul(delta,rot[11]);return rot

pos=arr(0);joints=arr(4).astype(int);weights=arr(5);skin=j['skins'][0];ibm=arr(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1);ids=np.array(skin['joints']);nodes=ids[joints]
head=(weights*np.isin(nodes,[0,1,2])).sum(1)>.8
hand=(weights*np.isin(nodes,[9,10,11])).sum(1)>.6
hp=np.c_[pos,np.ones(len(pos))]
def skinned(m):
 mats=m[ids]@ibm
 return sum(np.einsum('nij,nj->ni',mats[joints[:,k]],hp)*weights[:,k,None] for k in range(4))[:,:3]
