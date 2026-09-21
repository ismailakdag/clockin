const fs=require('fs');const v=require('gltf-validator');
(async()=>{const r=await v.validateBytes(new Uint8Array(fs.readFileSync('/private/tmp/clockin-robot-review/animated-mobile-v3.glb')),{maxIssues:30});fs.writeFileSync('/private/tmp/clockin-robot-review/gltf-validation.json',JSON.stringify(r,null,2));console.log(JSON.stringify(r.issues,null,2));if(r.issues.numErrors)process.exitCode=1;})();
