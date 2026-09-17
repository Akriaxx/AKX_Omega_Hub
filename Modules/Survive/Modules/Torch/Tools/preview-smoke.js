const fs=require('fs'),path=require('path'),sharp=require(process.env.OMEGA_SHARP||'sharp');
const root=path.join(__dirname,'../Media');
(async()=>{
 const frames=[],body=await sharp(path.join(root,'torch-painted.png')).resize(80,160).png().toBuffer();
 for(let n=0;n<120;n++){
  const t=n/24,layers=[{input:body,left:60,top:112}];
  for(let i=1;i<=9;i++){
   const age=t-(i-1)*.13,life=2.25+(i%3)*.18;
   if(age<=0||age>=life||t>=4)continue;
   const u=age/life,size=10+34*u,drift=Math.sin(age*1.8+i*.7)*u*12+u*u*9;
   const {data,info}=await sharp(path.join(root,'smoke-puff.png')).resize(Math.round(size),Math.round(size*(1.2+.15*Math.sin(i)))).rotate(-(i*.8+age*(i%2===0?.3:-.25))*180/Math.PI,{background:'#00000000'}).ensureAlpha().raw().toBuffer({resolveWithObject:true});
   const alpha=Math.min(1,age/.28)*Math.pow(1-u,1.6)*.65;
   for(let k=3;k<data.length;k+=4)data[k]*=alpha;
   layers.push({input:await sharp(data,{raw:info}).png().toBuffer(),left:Math.round(100+drift-info.width/2),top:Math.round(300-188-age*23-info.height/2)});
  }
  const raw=await sharp({create:{width:200,height:300,channels:4,background:'#101112'}}).composite(layers).raw().toBuffer();frames.push(raw);
  if(n===24)await sharp(raw,{raw:{width:200,height:300,channels:4}}).png().toFile(path.join(root,'smoke-preview.png'));
 }
 await sharp(Buffer.concat(frames),{raw:{width:200,height:300*frames.length,channels:4,pageHeight:300}}).gif({delay:42,loop:0,dither:.5}).toFile(path.join(root,'smoke-preview.gif'));
})();
