const fs=require('fs'),path=require('path'),sharp=require(process.env.OMEGA_SHARP||'sharp');
const root=path.join(__dirname,'../Media');
const fireMotion=require('./fire-motion');
(async()=>{
 const frames=[],fire=[];
 for(let i=0;i<16;i++) fire.push(await sharp(path.join(root,`fire-frame-${i}.png`)).ensureAlpha().raw().toBuffer());
 const body=await sharp(path.join(root,'torch-painted.png')).png().toBuffer();
 for(let n=0;n<200;n++){
  const t=n/20,ratio=Math.max(0,1-Math.max(0,t-1)/7.5),heat=ratio>0?.13+.87*Math.pow(ratio,.65):0;
  const data=fireMotion(fire[0],t,heat);
  const w=Math.round(92*(.65+.35*heat)),h=Math.max(1,Math.round(126*heat));
  const layers=[{input:body,left:116,top:190}];
  if(heat>0){
   const flame=await sharp(data,{raw:{width:128,height:128,channels:4}}).resize(w,h).png().toBuffer();
   // The charred crown is at y=193, not at the linen collar (y=223).
   // Overlap the crown so the rounded fire base sits inside the fuel bed.
   layers.push({input:flame,left:180-Math.floor(w/2),top:210-Math.round(h*122/128)});
  }
  const frame=await sharp({create:{width:360,height:480,channels:4,background:'#141217'}}).composite(layers).raw().toBuffer();
  frames.push(frame);
  if(n===10) await sharp(frame,{raw:{width:360,height:480,channels:4}}).png().toFile(path.join(root,'preview-painted.png'));
 }
 await sharp(Buffer.concat(frames),{raw:{width:360,height:480*frames.length,channels:4,pageHeight:480}}).gif({delay:50,loop:0,dither:.3}).toFile(path.join(root,'torch-burning-v2.gif'));
 console.log('Animation ready');
})();
