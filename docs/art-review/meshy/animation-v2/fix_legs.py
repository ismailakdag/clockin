from inspect_rig import *
import copy
source=Path(__file__).with_name('animated-wave-v1.glb').read_bytes();jl=struct.unpack_from('<I',source,12)[0];out=json.loads(source[20:20+jl]);data=bytearray(source[28+jl:])
bind={int(i):np.linalg.inv(ibm[k]) for k,i in enumerate(ids)}
def quat(m):
 t=np.trace(m)
 if t>0:
  s=np.sqrt(t+1)*2;q=np.array([(m[2,1]-m[1,2])/s,(m[0,2]-m[2,0])/s,(m[1,0]-m[0,1])/s,s/4])
 else:
  i=int(np.argmax(np.diag(m)));k=(i+1)%3;l=(i+2)%3;s=np.sqrt(1+m[i,i]-m[k,k]-m[l,l])*2;q=np.zeros(4);q[i]=s/4;q[k]=(m[k,i]+m[i,k])/s;q[l]=(m[l,i]+m[i,l])/s;q[3]=(m[l,k]-m[k,l])/s
 return q/np.linalg.norm(q)
locals={}
for i in range(17,28):
 local=np.linalg.inv(bind[parents[i]])@bind[i] if parents.get(i) in bind else bind[i]
 locals[i]={'translation':local[:3,3],'rotation':quat(local[:3,:3])}
for c in out['animations'][2]['channels']:
 i=c['target']['node'];path=c['target']['path']
 if i not in locals or path not in locals[i]:continue
 s=out['animations'][2]['samplers'][c['sampler']];count=out['accessors'][s['input']]['count'];vals=np.tile(locals[i][path],(count,1)).astype('<f4');data.extend(b'\0'*((-len(data))%4));off=len(data);data.extend(vals.tobytes());out['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':vals.nbytes});out['accessors'].append({'bufferView':len(out['bufferViews'])-1,'componentType':5126,'count':count,'type':'VEC4' if path=='rotation' else 'VEC3'});s['output']=len(out['accessors'])-1
out['buffers'][0]['byteLength']=len(data);js=json.dumps(out,separators=(',',':')).encode();js+=b' '*((-len(js))%4);data.extend(b'\0'*((-len(data))%4));result=struct.pack('<III',0x46546c67,2,28+len(js)+len(data))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(data),0x004e4942)+data
Path(__file__).with_name('animated-wave-v2.glb').write_bytes(result)
assert bytes(data[:len(binary)])==binary
for k in ['meshes','skins','nodes','materials','images']:assert j[k]==out[k]
for i in [0,1,3]:assert j['animations'][i]==out['animations'][i]
print('Saved v2: wave hips and leg joints use original bind pose; geometry, weights and other clips preserved.')
