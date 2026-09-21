from pathlib import Path
import struct,json,hashlib,copy,io
import numpy as np
from PIL import Image
root=Path(__file__).parent
src=Path('/Users/erdemincedere/Downloads/Meshy_AI_Happy_Robot_0918202115_texture.glb')
b=src.read_bytes();n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n]);binlen=struct.unpack_from('<I',b,20+n)[0];binary=b[28+n:28+n+binlen]
out=copy.deepcopy(j)
v=j['bufferViews'][j['images'][0]['bufferView']];tex=np.array(Image.open(io.BytesIO(binary[v['byteOffset']:v['byteOffset']+v['byteLength']])).convert('RGB'))/255
uvview=j['bufferViews'][j['accessors'][1]['bufferView']];uv=np.frombuffer(binary,dtype='<f4',count=j['accessors'][1]['count']*2,offset=uvview['byteOffset']).reshape(-1,2)
h,w=tex.shape[:2];pix=tex[np.clip((uv[:,1]*h).astype(int),0,h-1),np.clip((uv[:,0]*w).astype(int),0,w-1)]
r,g,bl=pix.T
# Conservative orange selection in the existing UV atlas, used only for vertex tint.
weight=np.clip((r-bl-.2)/.35,0,1)*np.clip((r-g-.12)/.22,0,1)*np.clip((g-bl-.09)/.16,0,1)*np.clip((r-.3)/.25,0,1)
colors=np.ones((len(uv),3),dtype='<f4');colors[:,1]=1-.5*weight;colors[:,2]=1-.65*weight
pad=(-len(binary))%4;offset=len(binary)+pad;data=binary+b'\0'*pad+colors.tobytes()
out['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':colors.nbytes,'target':34962})
out['accessors'].append({'bufferView':len(out['bufferViews'])-1,'componentType':5126,'count':len(uv),'type':'VEC3'})
out['meshes'][0]['primitives'][0]['attributes']['COLOR_0']=len(out['accessors'])-1
out['buffers'][0]['byteLength']=len(data)
m=out['materials'][0];m['name']='Original texture - vivid orange vertex tint and polished ceramic'
m['pbrMetallicRoughness']['metallicFactor']=0.0;m['pbrMetallicRoughness']['roughnessFactor']=0.8;m['normalTexture']['scale']=0.22
m['extensions']={'KHR_materials_specular':{'specularFactor':0.55}};out['extensionsUsed']=['KHR_materials_specular']
s=json.dumps(out,separators=(',',':')).encode();s+=b' '*((-len(s))%4);data+=b'\0'*((-len(data))%4)
result=struct.pack('<III',0x46546c67,2,28+len(s)+len(data))+struct.pack('<II',len(s),0x4e4f534a)+s+struct.pack('<II',len(data),0x004e4942)+data
(root/'happy-robot-material-v1.glb').write_bytes(result);(root/'original.glb').write_bytes(b)
assert data[:len(binary)]==binary
for k in ['nodes','scenes','images','textures']:assert j.get(k)==out.get(k)
assert out['accessors'][:len(j['accessors'])]==j['accessors']
report={'sourceSha256':hashlib.sha256(b).hexdigest(),'outputSha256':hashlib.sha256(result).hexdigest(),'triangles':j['accessors'][3]['count']//3,'vertices':len(uv),'tintedVertices':int((weight>0).sum()),'originalBinaryPrefixPreserved':True,'embeddedTexturesUnchanged':True,'geometryUVsAndNormalsUnchanged':True,'changes':{'orangeVertexTint':[1,.5,.35],'roughnessFactor':.8,'metallicFactor':0,'normalScale':.22,'specularFactor':.55}}
(root/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
