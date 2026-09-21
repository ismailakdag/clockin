import {NodeIO} from '@gltf-transform/core';
import {ALL_EXTENSIONS} from '@gltf-transform/extensions';
import {prune,dedup,textureCompress} from '@gltf-transform/functions';
import sharp from '/Users/erdemincedere/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp/dist/index.mjs';
import fs from 'node:fs';
const root='/private/tmp/clockin-robot-review/';
const io=new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc=await io.read(root+'animated-material-v3.glb');
const snapshot=d=>({animations:d.getRoot().listAnimations().map(a=>({name:a.getName(),channels:a.listChannels().map(c=>({node:c.getTargetNode().getName(),path:c.getTargetPath(),interpolation:c.getSampler().getInterpolation(),input:Array.from(c.getSampler().getInput().getArray()),output:Array.from(c.getSampler().getOutput().getArray())}))})),meshes:d.getRoot().listMeshes().map(m=>m.listPrimitives().map(p=>({indices:Array.from(p.getIndices().getArray()),attributes:Object.fromEntries(p.listSemantics().sort().map(s=>[s,Array.from(p.getAttribute(s).getArray())]))})))});
let repairedTangents=0;
for(const m of doc.getRoot().listMeshes())for(const p of m.listPrimitives()){
 const t=p.getAttribute('TANGENT'),n=p.getAttribute('NORMAL'); if(!t||!n)continue;
 const ta=t.getArray(),na=n.getArray();
 for(let i=0;i<t.getCount();i++)if(Math.hypot(...ta.slice(i*4,i*4+3))<1e-6){
  const [x,y,z]=na.slice(i*3,i*3+3);let a=Math.abs(x)<.9?[0,z,-y]:[-z,0,x];const len=Math.hypot(...a);a=a.map(v=>v/len);ta.set(a,i*4);repairedTangents++;
 }
}
const before=snapshot(doc);
await doc.transform(dedup(),prune(),textureCompress({encoder:sharp,resize:[1024,1024],slots:/baseColorTexture/,targetFormat:'jpeg',quality:92,chromaSubsampling:'4:4:4'}),textureCompress({encoder:sharp,resize:[1024,1024],slots:/normalTexture|metallicRoughnessTexture/,targetFormat:'png'}));
await io.write(root+'animated-mobile-v3.glb',doc);
const after=await io.read(root+'animated-mobile-v3.glb');
if(JSON.stringify(before)!==JSON.stringify(snapshot(after)))throw Error('Animation or geometry changed');
const report={inputBytes:fs.statSync(root+'animated-material-v3.glb').size,outputBytes:fs.statSync(root+'animated-mobile-v3.glb').size,geometryAndAllAnimationSamplesUnchanged:true,repairedSourceZeroTangents:repairedTangents,textures:after.getRoot().listTextures().map(t=>({name:t.getName(),size:t.getSize(),format:t.getMimeType()}))};
fs.writeFileSync(root+'mobile-validation.json',JSON.stringify(report,null,2));console.log(report);
