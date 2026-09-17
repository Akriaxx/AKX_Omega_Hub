// Convert generated transparent sources into persistent WoW textures.
const fs=require('fs'),path=require('path');
const sharp=require(process.env.OMEGA_SHARP||'sharp');
const root=path.join(__dirname,'../Media');
async function tga(input,name,w,h){
 const data=await sharp(input).resize(w,h).ensureAlpha().raw().toBuffer();
 for(let i=0;i<data.length;i+=4){const r=data[i];data[i]=data[i+2];data[i+2]=r;}
 const head=Buffer.alloc(18);head[2]=2;head.writeUInt16LE(w,12);head.writeUInt16LE(h,14);head[16]=32;head[17]=40;
 fs.writeFileSync(path.join(root,name+'.tga'),Buffer.concat([head,data]));
}
(async()=>{
 const handle=await sharp(path.join(root,'torch-source.png')).trim({threshold:12}).resize(128,256,{fit:'contain',background:'#00000000'}).png().toBuffer();
 fs.writeFileSync(path.join(root,'torch-painted.png'),handle);
 await tga(handle,'torch-painted',128,256);
 const source=path.join(root,'fire-source.png'),meta=await sharp(source).metadata();
 if(!meta.hasAlpha) throw new Error('Fire source must have transparency');
 const size=Math.floor(meta.width/4),frames=[];
 for(let i=0;i<16;i++){
  const cell=await sharp(source).extract({left:(i%4)*size,top:Math.floor(i/4)*size,width:size,height:size}).png().toBuffer();
  // Transparent padding is normalized to keep the burning base stationary.
  const trimmed=await sharp(cell).trim({threshold:10}).png().toBuffer();
  const info=await sharp(trimmed).metadata();
  frames.push({data:trimmed,width:info.width,height:info.height});
 }
 const maxW=Math.max(...frames.map(f=>f.width)),maxH=Math.max(...frames.map(f=>f.height));
 const scale=Math.min(92/maxW,112/maxH),tiles=[];
 for(let i=0;i<16;i++){
  const w=Math.round(frames[i].width*scale),h=Math.round(frames[i].height*scale);
  const tile=await sharp({create:{width:128,height:128,channels:4,background:'#00000000'}}).composite([{input:await sharp(frames[i].data).resize(w,h).png().toBuffer(),left:Math.floor((128-w)/2),top:122-h}]).png().toBuffer();
  fs.writeFileSync(path.join(root,`fire-frame-${i}.png`),tile);
  tiles.push({input:tile,left:(i%4)*128,top:Math.floor(i/4)*128});
 }
 const atlas=await sharp({create:{width:512,height:512,channels:4,background:'#00000000'}}).composite(tiles).png().toBuffer();
 fs.writeFileSync(path.join(root,'fire-loop.png'),atlas);
 await tga(atlas,'fire-loop',512,512);
 console.log('Compiled torch and 16 fire frames (1.125 MiB TGA).');
})();
