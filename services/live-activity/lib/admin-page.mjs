export const html = `<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>Clockin · Servis durumu</title><link rel="stylesheet" href="/admin/style.css"><script src="/admin/app.js" defer></script></head>
<body><main><header><a class="brand" href="/admin/">Clockin<span>Servis durumu</span></a><button id="logout" class="quiet" hidden>Çıkış yap</button></header>
<section id="login" class="login"><span class="clock" aria-hidden="true">◷</span><h1>Clockin’in nabzı.</h1><form id="loginForm"><label for="password">Panel parolası</label><input id="password" name="password" type="password" autocomplete="current-password" required maxlength="256"><button id="submit" type="submit">Giriş yap</button></form><p id="loginError" class="error" role="alert"></p></section>

<section id="dashboard" hidden aria-label="Clock durumu">
<div class="dial"><strong id="active">—</strong><span>cihazda clock açık</span></div>
<p id="health" class="health">Ölçüm bekleniyor</p><p id="age" class="age muted">—</p>
<p id="notice" class="notice" role="status" aria-live="polite"></p>

<section class="card">
<div class="cardhead"><h2>Clock açık cihaz</h2><div class="ranges" role="group" aria-label="Zaman aralığı"><button id="range2" class="range on" type="button">2 saat</button><button id="range24" class="range" type="button">24 saat</button></div></div>
<figure class="plot"><div id="chart" class="chart" role="img" aria-label="Clock açık cihaz sayısının zaman içindeki grafiği"></div><div id="tip" class="tip" hidden aria-hidden="true"></div></figure>
<p id="chartEmpty" class="muted small" hidden>Henüz yeterli geçmiş yok. Servis her dakika bir nokta ekliyor.</p>
<button id="tableToggle" class="quiet small" type="button" aria-expanded="false">Tabloyu göster</button>
<div id="tableWrap" hidden><table id="table"><caption class="sr">Clock açık cihaz sayısı, zamana göre</caption><thead><tr><th scope="col">Saat</th><th scope="col">Clock açık</th><th scope="col">Hata</th></tr></thead><tbody id="tableBody"></tbody></table></div>
</section>

<section class="card">
<div class="cardhead"><h2>Son turda bakılan kayıt</h2><strong id="processed" class="total">—</strong></div>
<dl><div><dt><i class="dot live" aria-hidden="true"></i>Clock açık</dt><dd id="bActive">—</dd></div><div><dt><i class="dot wait" aria-hidden="true"></i>Clock açılıyor</dt><dd id="bPending">—</dd></div><div><dt><i class="dot stop" aria-hidden="true"></i>Clock kapandı</dt><dd id="bStopped">—</dd></div><div><dt><i class="dot gone" aria-hidden="true"></i>Clock kapandı, haber gelmedi, silindi</dt><dd id="bExpired">—</dd></div></dl>
<p id="sumNote" class="small muted">Bu dört satır üstteki toplamı verir. Bir kayıt kaybolduysa bu satırlardan birindedir.</p>
</section>

<section class="card">
<div class="cardhead"><h2>Gönderim ve yapı</h2></div>
<dl><div><dt>Apple’a iletilen</dt><dd id="accepted">—</dd></div><div><dt>Hata</dt><dd id="failed">—</dd></div><div><dt>TestFlight yapısı</dt><dd id="sandbox">—</dd></div><div><dt>App Store yapısı</dt><dd id="production">—</dd></div></dl>
</section>

<footer><button id="refresh" class="quiet">Yenile</button><span>Cihaz sayar, kişi değil. Sunucu kimlik, kazanç ve not almaz.</span></footer>
</section></main></body></html>`;

export const css = `:root{color-scheme:light;--paper:#f5f6f8;--card:#ffffff;--ink:#20242b;--muted:#626873;--line:#dde0e6;--grid:#e8ebf0;--orange:#f78a18;--navy:#172237;--green:#237256;--red:#a72b21;--series:#2a78d6}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font:17px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
main{max-width:720px;margin:auto;padding:32px 40px}
header{display:flex;align-items:center;justify-content:space-between;gap:20px;padding-bottom:28px;border-bottom:1px solid var(--line)}
.brand{color:var(--navy);text-decoration:none;font-size:25px;font-weight:750;letter-spacing:-.8px}.brand span{display:block;font-size:13px;font-weight:500;letter-spacing:0;color:var(--muted)}
button,input{font:inherit}button{cursor:pointer;min-height:46px;border:0;border-radius:10px;padding:10px 20px;background:var(--navy);color:white;font-weight:600}button:disabled{opacity:.55;cursor:wait}
.quiet{background:transparent;color:var(--navy);border:1px solid #bac1cc;min-height:38px;padding:7px 16px;font-weight:600}
button:hover{filter:brightness(.94)}:focus-visible{outline:3px solid var(--orange);outline-offset:3px}
h1{font-size:clamp(28px,4vw,40px);line-height:1.12;letter-spacing:-1.2px;font-weight:650;margin:12px 0 18px}
h2{font-size:17px;font-weight:650;margin:0}
.login{max-width:410px;margin:65px auto}.clock{font-size:58px;color:var(--orange);line-height:1}
form{display:flex;flex-direction:column;gap:10px;margin-top:30px}label{font-size:15px;font-weight:600}
input{border:1px solid #bac1cc;background:white;padding:12px;border-radius:10px;min-width:0}form button{margin-top:6px}
.muted{color:var(--muted)}.small{font-size:13px}.error{color:var(--red)!important;min-height:24px}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
.dial{width:240px;height:240px;margin:44px auto 20px;border-radius:50%;border:9px solid #e2e6ed;border-top-color:var(--orange);display:flex;flex-direction:column;align-items:center;justify-content:center;background:var(--card);box-shadow:inset 0 0 0 8px var(--paper)}
.dial strong{font-size:86px;font-weight:550;letter-spacing:-5px;line-height:1.1;font-variant-numeric:tabular-nums}.dial span{font-size:15px;color:var(--muted)}
.health{text-align:center;color:var(--green);font-size:15px;font-weight:650;margin:0 0 4px}.health.warn{color:#8b4b11}.health.bad{color:var(--red)}
.age{text-align:center;font-size:14px;margin:0 0 24px;font-variant-numeric:tabular-nums}
.notice{margin:0 0 24px;padding:14px 18px;border-left:3px solid var(--orange);background:#fff4e6;border-radius:0 8px 8px 0;font-size:15px}.notice:empty{display:none}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:18px 20px;margin:0 0 16px}
.cardhead{display:flex;align-items:center;justify-content:space-between;gap:16px;min-height:38px}
.total{font-size:26px;font-weight:650;font-variant-numeric:tabular-nums}
.ranges{display:flex;gap:6px}.range{min-height:32px;padding:5px 12px;font-size:13px;border-radius:8px;background:transparent;color:var(--muted);border:1px solid transparent}
.range.on{background:var(--paper);color:var(--ink);border-color:var(--line)}
.plot{position:relative;margin:14px 0 6px}.chart{width:100%}.chart svg{display:block;width:100%;height:auto;touch-action:pan-y}
.tip{position:absolute;pointer-events:none;background:var(--navy);color:#fff;font-size:13px;line-height:1.35;padding:7px 10px;border-radius:8px;white-space:nowrap;transform:translate(-50%,-115%);font-variant-numeric:tabular-nums;z-index:2}
dl{margin:12px 0 0}dl div{display:flex;justify-content:space-between;gap:24px;padding:11px 0;border-bottom:1px solid var(--line)}dl div:last-child{border-bottom:0;padding-bottom:0}
dt{color:var(--muted);display:flex;align-items:center;gap:9px}dd{margin:0;font-weight:650;font-variant-numeric:tabular-nums}
.dot{width:9px;height:9px;border-radius:50%;display:inline-block;flex:none}.dot.live{background:var(--series)}.dot.stop{background:#8e96a3}.dot.wait{background:var(--orange)}.dot.gone{background:#c6ccd6}
#sumNote{margin:14px 0 0}
#tableToggle{margin-top:4px}
table{width:100%;border-collapse:collapse;margin-top:12px;font-size:14px}
th,td{text-align:right;padding:7px 0;border-bottom:1px solid var(--line);font-variant-numeric:tabular-nums}
th:first-child,td:first-child{text-align:left;color:var(--muted)}
th{font-weight:600;color:var(--muted)}
footer{display:flex;align-items:center;justify-content:space-between;gap:16px;font-size:12px;color:var(--muted);margin-top:20px}
[hidden]{display:none!important}
@media(max-width:650px){main{padding:20px}header{padding-bottom:20px}.dial{width:208px;height:208px;margin:28px auto 18px}.dial strong{font-size:72px}.login{margin:40px auto}.card{padding:16px}footer{flex-direction:column;align-items:flex-start;gap:10px}dt{font-size:15px}.brand{font-size:23px}}`;

export const javascript = `const $=id=>document.getElementById(id);
let timer, clockTimer, busy=false, loggedIn=false, checkedAt=null, span=120, series=[], points=[];
const fmt=new Intl.NumberFormat('tr-TR');
const cells=['active','accepted','failed','processed','bActive','bStopped','bPending','bExpired','sandbox','production'];
const clock=t=>new Date(t*1000).toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'});

function view(inside){loggedIn=inside;$('login').hidden=inside;$('dashboard').hidden=!inside;$('logout').hidden=!inside;
 if(!inside){clearTimeout(timer);clearInterval(clockTimer);checkedAt=null;series=[];points=[];for(const id of cells)$(id).textContent='—';$('chart').innerHTML='';}}

async function api(path,options={}){const r=await fetch('/api/admin/'+path,{...options,credentials:'same-origin',cache:'no-store',signal:AbortSignal.timeout(15000)});
 let data={};try{data=await r.json()}catch{}
 if(!r.ok){const e=new Error(r.status===429?'Çok sık deneme yapıldı. Bir dakika sonra tekrar dene.':data.error||'Bağlantı kurulamadı. Tekrar dene.');e.status=r.status;throw e;}
 return data;}

function age(){if(!checkedAt){$('age').textContent='Ölçüm yok';return;}
 const s=Math.max(0,Math.round((Date.now()-checkedAt)/1000));
 $('age').textContent=s<90?s+' saniye önce ölçüldü':Math.round(s/60)+' dakika önce ölçüldü';}

function render(d){const live=d.status==='ok'&&!d.stale;const partial=(d.remaining||0)>0;
 const n=(id,v)=>$(id).textContent=v===null||v===undefined?'—':fmt.format(v);
 n('active',live?d.active:null);n('accepted',d.apnsAccepted);n('failed',d.failed);n('processed',d.processed);
 n('bActive',d.active);n('bStopped',d.stopped);n('bPending',d.pending);n('bExpired',d.expired);
 n('sandbox',d.sandbox);n('production',d.production);
 const state=d.status==='waiting'?['Ölçüm bekleniyor','warn','Servis henüz hiç ölçüm yazmadı.']
 :d.status==='unconfigured'?['Servis yapılandırılmamış','bad','Gönderim anahtarları eksik; servis hiçbir şey göndermiyor.']
 :d.status==='error'?['Servis hata verdi','bad','Son tur tamamlanamadı. Sayılar bu yüzden boş.']
 :d.stale?['Ölçüm güncel değil','bad','Servis bir dakikadır ölçüm yazmadı. Yukarıdaki sayıyı anlık kabul etme.']
 :partial?['Sayım kısmi','warn','Kayıtların tamamı bu turda sayılamadı; sayı olduğundan düşük ve grafiğe eklenmedi.']
 :d.failed>0?['Çalışıyor, gönderim hatası var','warn','']:['Çalışıyor','',''];
 $('health').textContent=state[0];$('health').className='health'+(state[1]?' '+state[1]:'');$('notice').textContent=state[2];
 checkedAt=d.checkedAt||null;age();clearInterval(clockTimer);if(live)clockTimer=setInterval(age,1000);}

function plot(){const wrap=$('chart');const rows=series;
 $('chartEmpty').hidden=rows.length>1;$('tip').hidden=true;points=[];
 if(rows.length<2){wrap.innerHTML='';fill([]);return;}
 const W=680,H=190,L=34,R=8,T=12,B=24;
 const xs=rows.map(r=>r[0]);const ys=rows.map(r=>r[1]);
 const x0=xs[0],x1=xs[xs.length-1],dx=Math.max(1,x1-x0);
 const top=Math.max(1,Math.max.apply(null,ys));
 const px=t=>L+(W-L-R)*(t-x0)/dx, py=v=>T+(H-T-B)*(1-v/top);
 points=rows.map(r=>({t:r[0],v:r[1],f:r[6],x:px(r[0]),y:py(r[1])}));
 let ticks=[0,Math.round(top/2),top];ticks=ticks.filter((v,i,a)=>a.indexOf(v)===i);
 let s='<svg viewBox="0 0 '+W+' '+H+'" aria-hidden="true">';
 for(const v of ticks){const y=py(v);
  s+='<line x1="'+L+'" y1="'+y+'" x2="'+(W-R)+'" y2="'+y+'" stroke="var(--grid)" stroke-width="1"/>';
  s+='<text x="'+(L-8)+'" y="'+(y+4)+'" text-anchor="end" font-size="11" fill="var(--muted)">'+v+'</text>';}
 const area=points.map(p=>p.x.toFixed(1)+','+p.y.toFixed(1)).join(' ');
 s+='<polygon points="'+L+','+py(0)+' '+area+' '+(W-R)+','+py(0)+'" fill="var(--series)" fill-opacity="0.10"/>';
 s+='<polyline points="'+area+'" fill="none" stroke="var(--series)" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>';
 for(const p of points){if(p.f>0)s+='<circle cx="'+p.x.toFixed(1)+'" cy="'+p.y.toFixed(1)+'" r="3.5" fill="var(--red)" stroke="var(--card)" stroke-width="2"/>';}
 const last=points[points.length-1];
 s+='<circle cx="'+last.x.toFixed(1)+'" cy="'+last.y.toFixed(1)+'" r="4" fill="var(--series)" stroke="var(--card)" stroke-width="2"/>';
 s+='<line id="cross" x1="0" y1="'+T+'" x2="0" y2="'+(H-B)+'" stroke="var(--muted)" stroke-width="1" opacity="0"/>';
 s+='<text x="'+L+'" y="'+(H-6)+'" font-size="11" fill="var(--muted)">'+clock(x0)+'</text>';
 s+='<text x="'+(W-R)+'" y="'+(H-6)+'" text-anchor="end" font-size="11" fill="var(--muted)">'+clock(x1)+'</text>';
 s+='</svg>';
 wrap.innerHTML=s;
 fill(rows);}

function fill(rows){const body=$('tableBody');
 body.innerHTML=rows.slice(-40).reverse().map(r=>'<tr><td>'+clock(r[0])+'</td><td>'+fmt.format(r[1])+'</td><td>'+fmt.format(r[6])+'</td></tr>').join('');}

function hover(event){if(!points.length)return;const wrap=$('chart');const svg=wrap.querySelector('svg');if(!svg)return;
 const box=wrap.getBoundingClientRect();const vb=680;const scale=box.width/vb;
 const x=(event.clientX-box.left)/scale;
 let best=points[0];for(const p of points)if(Math.abs(p.x-x)<Math.abs(best.x-x))best=p;
 const cross=svg.querySelector('#cross');if(cross){cross.setAttribute('x1',best.x);cross.setAttribute('x2',best.x);cross.setAttribute('opacity','0.35');}
 const tip=$('tip');tip.hidden=false;
 tip.textContent=clock(best.t)+' · '+fmt.format(best.v)+' clock açık'+(best.f>0?' · '+fmt.format(best.f)+' hata':'');
 tip.style.left=(best.x*scale)+'px';tip.style.top=(best.y*scale)+'px';}

function leave(){const svg=$('chart').querySelector('svg');const cross=svg&&svg.querySelector('#cross');
 if(cross)cross.setAttribute('opacity','0');$('tip').hidden=true;}

async function refresh(initial=false){if(busy||document.hidden)return;busy=true;clearTimeout(timer);$('refresh').disabled=true;
 try{const d=await api('status');view(true);render(d);
  try{const h=await api('history');const rows=span===120?h.minutes:h.buckets;series=Array.isArray(rows)?rows:[];plot();}
  catch(e){if(e.status===401)throw e;}
  $('loginError').textContent='';}
 catch(e){if(e.status===401){view(false);if(!initial)$('loginError').textContent='Oturum sona erdi. Yeniden giriş yap.';}
  else if(loggedIn){clearInterval(clockTimer);$('notice').textContent=e.message;$('health').textContent='Panel bağlantısı kesildi';$('health').className='health bad';$('active').textContent='—';}
  else{$('loginError').textContent=e.message;}}
 finally{busy=false;$('refresh').disabled=false;if(loggedIn&&!document.hidden)timer=setTimeout(refresh,30000);}}

function setSpan(next){span=next;$('range2').classList.toggle('on',next===120);$('range24').classList.toggle('on',next!==120);refresh();}

$('loginForm').addEventListener('submit',async e=>{e.preventDefault();$('submit').disabled=true;$('loginError').textContent='';
 try{await api('session',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({password:$('password').value})});$('password').value='';await refresh();}
 catch(err){$('loginError').textContent=err.message;}finally{$('submit').disabled=false;}});
$('logout').addEventListener('click',async()=>{$('logout').disabled=true;clearTimeout(timer);
 try{await api('session',{method:'DELETE'});view(false);$('password').focus();}
 catch(e){$('notice').textContent='Çıkış tamamlanamadı. '+e.message;}finally{$('logout').disabled=false;}});
$('refresh').addEventListener('click',()=>refresh());
$('range2').addEventListener('click',()=>setSpan(120));
$('range24').addEventListener('click',()=>setSpan(288));
$('tableToggle').addEventListener('click',()=>{const open=$('tableWrap').hidden;$('tableWrap').hidden=!open;
 $('tableToggle').setAttribute('aria-expanded',String(open));$('tableToggle').textContent=open?'Tabloyu gizle':'Tabloyu göster';});
$('chart').addEventListener('pointermove',hover);$('chart').addEventListener('pointerleave',leave);
document.addEventListener('visibilitychange',()=>{clearTimeout(timer);if(!document.hidden&&loggedIn)refresh();});
refresh(true);`;
