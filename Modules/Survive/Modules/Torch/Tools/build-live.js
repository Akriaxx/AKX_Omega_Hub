const fs=require('fs'),path=require('path'),sharp=require(process.env.OMEGA_SHARP||'sharp');
const motion=require('./fire-motion'),root=path.join(__dirname,'../Media');
async function saveTga(data,w,h,name){
 const bgra=Buffer.from(data);for(let i=0;i<bgra.length;i+=4){const r=bgra[i];bgra[i]=bgra[i+2];bgra[i+2]=r;}
 const head=Buffer.alloc(18);head[2]=2;head.writeUInt16LE(w,12);head.writeUInt16LE(h,14);head[16]=32;head[17]=40;
 fs.writeFileSync(path.join(root,name+'.tga'),Buffer.concat([head,bgra]));
}
(async()=>{
 const seed=await sharp(path.join(root,'fire-frame-0.png')).ensureAlpha().raw().toBuffer(),tiles=[];
 for(let i=0;i<64;i++)tiles.push({input:await sharp(motion(seed,i/32,1),{raw:{width:128,height:128,channels:4}}).png().toBuffer(),left:(i%8)*128,top:Math.floor(i/8)*128});
 const atlas=await sharp({create:{width:1024,height:1024,channels:4,background:'#00000000'}}).composite(tiles).raw().toBuffer();
 await saveTga(atlas,1024,1024,'fire-flow');
 const head=await sharp(path.join(root,'torch-painted.png')).extract({left:0,top:0,width:128,height:84}).resize(128,128).ensureAlpha().raw().toBuffer();
 for(let y=0;y<128;y++)for(let x=0;x<128;x++){
  const k=(y*128+x)*4,luma=(head[k]+head[k+1]+head[k+2])/765;
  const grain=.45+.55*luma,edge=Math.min(1,(128-y)/28);
  head[k]=255;head[k+1]=85+150*luma;head[k+2]=15+55*luma;
  head[k+3]=head[k+3]>100?head[k+3]*grain*edge:0;
 }
 await saveTga(head,128,128,'wick-ember');
 await sharp(head,{raw:{width:128,height:128,channels:4}}).png().toFile(path.join(root,'wick-ember.png'));
 console.log('64 continuous flame poses and fitted ember mask ready');
})();
