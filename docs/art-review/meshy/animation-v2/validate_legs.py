from inspect_rig import *
import hashlib
b2=Path(__file__).with_name('animated-wave-v2.glb').read_bytes();n2=struct.unpack_from('<I',b2,12)[0];j2=json.loads(b2[20:20+n2]);bin2=b2[28+n2:]
def read(i):
 a=j2['accessors'][i];v=j2['bufferViews'][a['bufferView']];sz={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']];return np.frombuffer(bin2,dtype='<f4',count=a['count']*sz,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,sz)
assert bin2[:len(binary)]==binary
for k in ['meshes','skins','nodes','materials','images']:assert j[k]==j2[k]
for i in [0,1,3]:assert j['animations'][i]==j2['animations'][i]
foot=(weights*np.isin(nodes,[17,18,19,22,23,24])).sum(1)>.95
hmask=(weights*np.isin(nodes,[9,10])).sum(1)>.8
maxdrift=0;maxbinderr=0;collisions=0;baseline=None;minsole=100;maxsole=-100
for t in np.linspace(0,duration,253):
 tr,q=pose(t)
 for c in j2['animations'][2]['channels']:
  s=j2['animations'][2]['samplers'][c['sampler']];ts=read(s['input'])[:,0];vals=read(s['output']);i=c['target']['node'];path=c['target']['path'];t0=np.clip(t,ts[0],ts[-1])
  if path=='rotation':q[i]=slerp(ts,vals,t0)
  elif path=='translation':tr[i]=np.array([np.interp(t0,ts,vals[:,k]) for k in range(3)])
 m=matrices(tr,q);v=skinned(m)
 if baseline is None:baseline=v[foot].copy()
 maxdrift=max(maxdrift,float(np.linalg.norm(v[foot]-baseline,axis=1).max()));maxbinderr=max(maxbinderr,float(np.linalg.norm(v[foot]-pos[foot],axis=1).max()));minsole=min(minsole,float(v[foot,1].min()));maxsole=max(maxsole,float(v[foot,1].min()))
 loc=(np.c_[v,np.ones(len(v))]@np.linalg.inv(m[2]).T)[:,:3];lo=loc[head].min(0);hi=loc[head].max(0);collisions+=bool(np.all((loc[hmask]>lo)&(loc[hmask]<hi),axis=1).any())
assert maxdrift<.001 and maxbinderr<.001 and collisions==0
report={'sampleCount':253,'footVertexCount':int(foot.sum()),'maximumFootDriftMeters':maxdrift,'maximumFootDeviationFromOriginalMeshMeters':maxbinderr,'soleHeightRangeMeters':[minsole,maxsole],'sampledHandHeadOverlapFrames':collisions,'geometryTexturesSkinAndOtherClipsUnchanged':True,'sha256':hashlib.sha256(b2).hexdigest()}
Path(__file__).with_name('legs-validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
