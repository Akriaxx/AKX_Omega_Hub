const fs=require('fs'),path=require('path'),sharp=require(process.env.OMEGA_SHARP||'sharp');
const root=path.join(__dirname,'../Media'),motion=require('./fire-motion');
(async()=>{
 const seed=await sharp(path.join(root,'fire-frame-0.png')).ensureAlpha().raw().toBuffer();
 const poses=Array.from({length:64},(_,i)=>motion(seed,i/32,1));
 const body=await sharp(path.join(root,'torch-painted.png')).resize(80,160).png().toBuffer();
 const ember=await sharp(path.join(root,'wick-ember.png')).resize(80,53).png().toBuffer();
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="480" height="352"><rect x="1" y="1" width="478" height="350" rx="5" fill="#181719" stroke="#6b5940"/><path d="M0 35H480 M240 35V352" stroke="#615039"/><g fill="#e4cfa7" font-family="Georgia" font-size="14"><text x="216" y="24">Torche</text><text x="254" y="66">Torche</text><text x="254" y="128">Combustible</text><text x="254" y="190">Variateur de temps</text><text x="254" y="250">État : ON</text></g><g fill="#242225" stroke="#66553d"><rect x="254" y="78" width="212" height="25"/><rect x="254" y="140" width="212" height="25"/><rect x="254" y="202" width="212" height="25"/><rect x="254" y="268" width="212" height="22"/><rect x="254" y="296" width="212" height="22"/></g><g fill="#d7c6a9" font-size="12" font-family="Arial"><text x="264" y="95">Torche</text><text x="264" y="157">Combustible sélectionné</text><text x="264" y="219">x1.0</text><text x="339" y="284">Éteindre</text><text x="332" y="312">Recharger</text></g></svg>`;
 const bg=await sharp(Buffer.from(svg)).png().toBuffer(),frames=[];
 async function alpha(input,value){const {data,info}=await sharp(input).ensureAlpha().raw().toBuffer({resolveWithObject:true});for(let i=3;i<data.length;i+=4)data[i]*=value;return sharp(data,{raw:info}).png().toBuffer();}
 for(let n=0;n<180;n++){
  const t=n/30,ratio=1,h=.06+.94*ratio**.7,index=Math.floor(t*32)%64,opacity=Math.min(1,h*5);
  const layers=[];
  async function flame(offset,w,height,x,bottom,a){const input=await sharp(poses[(index+offset)%64],{raw:{width:128,height:128,channels:4}}).resize(Math.round(w),Math.round(height)).png().toBuffer();layers.push({input:await alpha(input,a),left:Math.round(120+x-w/2),top:Math.round(343-bottom-height)});}
  await flame(0,76+24*h,42+116*h,0,142,opacity);
  layers.push({input:body,left:80,top:155});
  layers.push({input:await alpha(ember,(.9+.06*Math.sin(t*7.1)+.04*Math.sin(t*12.3))*.85),left:80,top:155});
  await flame(21,26+11*h,34+84*h,-10,142,opacity*.78);
  await flame(43,24+10*h,36+74*h,10,145,opacity*.68);
  const frame=await sharp(bg).composite(layers).ensureAlpha().raw().toBuffer();frames.push(frame);
  if(n===30) await sharp(frame,{raw:{width:480,height:352,channels:4}}).png().toFile(path.join(root,'panel-live.png'));
 }
 await sharp(Buffer.concat(frames),{raw:{width:480,height:352*frames.length,channels:4,pageHeight:352}}).gif({delay:33,loop:0,dither:.2}).toFile(path.join(root,'panel-live.gif'));
 console.log('Panel animation rendered');
})();
