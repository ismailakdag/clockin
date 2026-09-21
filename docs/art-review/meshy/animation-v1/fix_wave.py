from inspect_rig import *
import copy,hashlib
out=copy.deepcopy(j);data=bytearray(binary)
for c in out['animations'][2]['channels']:
 if c['target']=={'node':11,'path':'rotation'}:
  s=out['animations'][2]['samplers'][c['sampler']];ts=arr(s['input'])[:,0];vals=np.array([corrected(*pose(float(t)),float(t))[11] for t in ts],dtype='<f4');vals/=np.linalg.norm(vals,axis=1)[:,None]
  for i in range(1,len(vals)):
   if np.dot(vals[i-1],vals[i])<0:vals[i]=-vals[i]
  data.extend(b'\0'*((-len(data))%4));off=len(data);data.extend(vals.tobytes());out['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':vals.nbytes});out['accessors'].append({'bufferView':len(out['bufferViews'])-1,'componentType':5126,'count':len(vals),'type':'VEC4'});s['output']=len(out['accessors'])-1
out['buffers'][0]['byteLength']=len(data);s=json.dumps(out,separators=(',',':')).encode();s+=b' '*((-len(s))%4);data.extend(b'\0'*((-len(data))%4));result=struct.pack('<III',0x46546c67,2,28+len(s)+len(data))+struct.pack('<II',len(s),0x4e4f534a)+s+struct.pack('<II',len(data),0x004e4942)+data
Path(__file__).with_name('animated-wave-v1.glb').write_bytes(result)
assert bytes(data[:len(binary)])==binary
for k in ['meshes','skins','nodes','materials','images']:assert j[k]==out[k]
for i in [0,1,3]:assert j['animations'][i]==out['animations'][i]
print('Only Wave_One_Hand right forearm rotation sampler changed. Original binary retained. Output',len(result))
