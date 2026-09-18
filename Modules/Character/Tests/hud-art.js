// Original vector UI materials shared by the game assets and layout preview.
const fs=require('fs'),path=require('path');
const metal=`<linearGradient id="m" x1="0" y1="0" x2=".3" y2="1"><stop stop-color="#eed39a"/><stop offset=".27" stop-color="#a78950"/><stop offset=".52" stop-color="#453625"/><stop offset=".78" stop-color="#b08c51"/><stop offset="1" stop-color="#51402a"/></linearGradient>`;
const ticks=Array.from({length:32},(_,i)=>`<path d="M64 13V${i%4?16:19}" transform="rotate(${i*11.25} 64 64)" stroke="#ead2a0" opacity="${i%4?.35:.8}"/>`).join('');
const svg=(w,h,body)=>`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
const designs={
 'PortraitRing':svg(128,128,`<defs>${metal}</defs><circle cx="64" cy="64" r="52" fill="none" stroke="#101112" stroke-width="12"/><circle cx="64" cy="64" r="51" fill="none" stroke="url(#m)" stroke-width="8"/><circle cx="64" cy="64" r="46" fill="none" stroke="#e3c789" stroke-width="1"/><circle cx="64" cy="64" r="56" fill="none" stroke="#58472f"/>${ticks}<g fill="url(#m)" stroke="#33271a"><path d="M53 10L64 0L75 10L64 21Z M53 118L64 107L75 118L64 128Z M10 53L21 64L10 75L0 64Z M118 53L128 64L118 75L107 64Z"/></g><path d="M59 10L64 5L69 10L64 15Z" fill="#638c87"/><path d="M59 118L64 113L69 118L64 123Z" fill="#638c87"/>`),
 'ResourcePanel':svg(512,160,`<defs>${metal}<linearGradient id="p" x2="0" y2="1"><stop stop-color="#24251f"/><stop offset=".5" stop-color="#0d1314"/><stop offset="1" stop-color="#161712"/></linearGradient></defs><path d="M2 8H474Q504 8 504 38V122Q504 152 474 152H2Z" fill="url(#p)" stroke="#080a0b" stroke-width="8"/><path d="M2 8H474Q504 8 504 38V122Q504 152 474 152H2" fill="none" stroke="url(#m)" stroke-width="3"/><path d="M18 17H473Q493 17 493 39V121Q493 143 473 143H18" fill="none" stroke="#76603b"/><path d="M488 59L496 80L488 101L481 80Z" fill="#211e17" stroke="#b89a60"/><path d="M486 80L489 74L492 80L489 86Z" fill="#b99b63"/>`),
 'ResourceFill':svg(256,32,`<defs><linearGradient id="f" x2="0" y2="1"><stop stop-color="#777"/><stop offset=".25" stop-color="#eee"/><stop offset=".48" stop-color="#bbb"/><stop offset="1" stop-color="#555"/></linearGradient></defs><rect width="256" height="32" fill="url(#f)"/><path d="M0 6Q60 2 115 7T256 5" stroke="white" fill="none" opacity=".2"/>`),
 'ResourceBorder':svg(256,24,`<defs>${metal}</defs><path d="M1 4L5 1H251L255 4V20L251 23H5L1 20Z" fill="none" stroke="#0c0c0c" stroke-width="3"/><path d="M1 4L5 1H251L255 4V20L251 23H5L1 20Z" fill="none" stroke="url(#m)"/><path d="M4 5V19 M252 5V19" stroke="#dfc089" opacity=".5"/>`)
};
module.exports=designs;
if(require.main===module){
 const sharp=require(process.env.OMEGA_SHARP||'sharp');
 const dir=path.join(__dirname,'../Media');fs.mkdirSync(dir,{recursive:true});
 (async()=>{for(const [name,source] of Object.entries(designs)){
  const meta=await sharp(Buffer.from(source)).metadata();
  const {data,info}=await sharp(Buffer.from(source)).resize(2**Math.ceil(Math.log2(meta.width)),2**Math.ceil(Math.log2(meta.height)),{fit:'fill'}).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  for(let i=0;i<data.length;i+=4){const r=data[i];data[i]=data[i+2];data[i+2]=r;}
  const header=Buffer.alloc(18);header[2]=2;header.writeUInt16LE(info.width,12);header.writeUInt16LE(info.height,14);header[16]=32;header[17]=40;
  fs.writeFileSync(path.join(dir,(name==='ResourcePanel'?'ResourcePanelRounded':name)+'.tga'),Buffer.concat([header,data]));
 }})();
}
