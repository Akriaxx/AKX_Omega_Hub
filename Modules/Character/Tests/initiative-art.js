const fs=require('fs'),path=require('path');
const sharp=require(process.env.OMEGA_SHARP||'sharp');
const designs={
 InitiativeRing:'<circle cx="32" cy="32" r="30" fill="none" stroke="#c6ad76" stroke-width="1.8"/>',
 StateSigil:'<circle cx="32" cy="32" r="26" fill="#111b1d" stroke="#b69759" stroke-width="3"/><path d="M32 10L49 32L32 54L15 32Z" fill="#233c3e" stroke="#e2c789" stroke-width="3"/><path d="M32 20L40 32L32 44L24 32Z" fill="#83cbc2"/><path d="M6 32H13M51 32H58" stroke="#f1d9a4" stroke-width="3"/>',
 ResolutionSigil:'<circle cx="32" cy="32" r="27" fill="#141b1c" stroke="#a58b56" stroke-width="2"/><path d="M20 15H44M20 49H44M23 16C23 26 27 27 32 32C37 37 41 38 41 48M41 16C41 26 37 27 32 32C27 37 23 38 23 48" fill="none" stroke="#e6cb8a" stroke-width="4" stroke-linecap="round"/><path d="M26 44L32 37L38 44Z" fill="#83cbc2"/>'
};
(async()=>{for(const [name,body] of Object.entries(designs)){
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">${body}</svg>`;
const data=await sharp(Buffer.from(svg)).ensureAlpha().raw().toBuffer();
for(let i=0;i<data.length;i+=4){const r=data[i];data[i]=data[i+2];data[i+2]=r;}
const h=Buffer.alloc(18);h[2]=2;h.writeUInt16LE(64,12);h.writeUInt16LE(64,14);h[16]=32;h[17]=40;
fs.writeFileSync(path.join(__dirname,'../Media',name+'.tga'),Buffer.concat([h,data]));
}})();
