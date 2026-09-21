from inspect_rig import *
import hashlib
b2=Path(__file__).with_name('animated-wave-v1.glb').read_bytes();n2=struct.unpack_from('<I',b2,12)[0];j2=json.loads(b2[20:20+n2]);data2=b2[28+n2:]
assert struct.unpack_from('<I',b2,8)[0]==len(b2)
assert data2[:len(binary)]==binary
for k in ['meshes','skins','nodes','materials','images']:assert j[k]==j2[k]
for i in [0,1,3]:assert j['animations'][i]==j2['animations'][i]
c=next(c for c in j2['animations'][2]['channels'] if c['target']=={'node':11,'path':'rotation'});s=j2['animations'][2]['samplers'][c['sampler']];a=j2['accessors'][s['output']];v=j2['bufferViews'][a['bufferView']];vals=np.frombuffer(data2,dtype='<f4',count=a['count']*4,offset=v['byteOffset']).reshape(-1,4);ts=arr(s['input'])[:,0]
assert np.isfinite(vals).all() and np.allclose(np.linalg.norm(vals,axis=1),1,atol=1e-5)
hand=(weights*np.isin(nodes,[9,10])).sum(1)>.8
report={'triangles':j['accessors'][6]['count']//3,'vertices':len(pos),'clipNames':[x['name'] for x in j['animations']],'unchangedGeometrySkinTexturesOtherClips':True,'sampleCount':253,'sourceSHA256':hashlib.sha256(b).hexdigest(),'outputSHA256':hashlib.sha256(b2).hexdigest(),'metric':'Strongly hand-weighted vertices inside head-local bounding box; conservative sampled regression, not continuous full-body collision proof'}
for label in ['original','corrected']:
 frames=0
 for t in np.linspace(0,duration,253):
  tr,q=pose(t)
  if label=='corrected':q[11]=slerp(ts,vals,t)
  m=matrices(tr,q);v=skinned(m);v=(np.c_[v,np.ones(len(v))]@np.linalg.inv(m[2]).T)[:,:3];lo=v[head].min(0);hi=v[head].max(0);num=np.all((v[hand]>lo)&(v[hand]<hi),axis=1).sum();frames+=bool(num)
 report[label+'HandOverlapFrames']=frames
assert report['originalHandOverlapFrames']>0 and report['correctedHandOverlapFrames']==0
Path(__file__).with_name('animation-validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
