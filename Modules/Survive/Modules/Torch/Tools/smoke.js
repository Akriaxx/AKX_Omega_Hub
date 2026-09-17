// Soft overlapping density lobes for the runtime smoke particles.
const fs=require('fs'),path=require('path'),sharp=require(process.env.OMEGA_SHARP||'sharp');
const root=path.join(__dirname,'../Media');
(async()=>{
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><defs><radialGradient id="s"><stop stop-color="#b9b4ab" stop-opacity=".5"/><stop offset=".35" stop-color="#a9a59e" stop-opacity=".3"/><stop offset=".72" stop-color="#a09d97" stop-opacity=".09"/><stop offset="1" stop-color="#a09d97" stop-opacity="0"/></radialGradient></defs><ellipse cx="57" cy="77" rx="34" ry="42" fill="url(#s)"/><ellipse cx="78" cy="55" rx="36" ry="33" fill="url(#s)"/><ellipse cx="47" cy="38" rx="30" ry="28" fill="url(#s)"/><ellipse cx="38" cy="66" rx="24" ry="30" fill="url(#s)"/></svg>`;
 fs.writeFileSync(path.join(root,'smoke-puff.svg'),svg);
 const image=sharp(Buffer.from(svg));await image.clone().png().toFile(path.join(root,'smoke-puff.png'));
 const data=await image.ensureAlpha().raw().toBuffer();
 for(let i=0;i<data.length;i+=4){const r=data[i];data[i]=data[i+2];data[i+2]=r;}
 const header=Buffer.alloc(18);header[2]=2;header.writeUInt16LE(128,12);header.writeUInt16LE(128,14);header[16]=32;header[17]=40;
 fs.writeFileSync(path.join(root,'smoke-puff.tga'),Buffer.concat([header,data]));
})();
