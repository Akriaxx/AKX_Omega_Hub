// Vector artwork -> small uncompressed BGRA textures supported by WoW.
const fs = require('fs'), path = require('path');
const sharp = require(process.env.OMEGA_SHARP || 'sharp');
const out = path.join(__dirname, '../Media');
fs.mkdirSync(out, {recursive:true});
const art = {
  handle: `<defs><linearGradient id="wood"><stop stop-color="#281912"/><stop offset=".38" stop-color="#97603b"/><stop offset=".65" stop-color="#533421"/><stop offset="1" stop-color="#201512"/></linearGradient><linearGradient id="gold"><stop stop-color="#503321"/><stop offset=".4" stop-color="#e1bb71"/><stop offset=".65" stop-color="#a7763e"/><stop offset="1" stop-color="#39251e"/></linearGradient></defs><path d="M52 60 L77 60 L72 241 Q64 254 56 241Z" fill="url(#wood)" stroke="#1e1513" stroke-width="3"/><path d="M59 99 L61 228 M69 108 L66 242" stroke="#d49a58" opacity=".28" stroke-width="2"/><path d="M45 23 Q64 10 83 23 L78 73 L49 73Z" fill="#39251e" stroke="#ab7d49" stroke-width="3"/><path d="M47 28 L81 37 M46 40 L80 49 M48 52 L79 61" stroke="#91704b" stroke-width="7"/><path d="M44 67 L83 67 L79 83 L49 83Z M54 225 L74 225 L73 237 L55 237Z" fill="url(#gold)" stroke="#4f3527" stroke-width="2"/><path d="M64 68 L69 75 L64 82 L59 75Z" fill="#f9d18a"/>`,
  flame: `<defs><linearGradient id="fire" x2="0" y2="1"><stop stop-color="#ffca55"/><stop offset=".5" stop-color="#ff851f"/><stop offset="1" stop-color="#d73b0c"/></linearGradient></defs><path d="M65 250 C12 238 13 189 32 153 C40 175 47 179 43 149 C32 96 81 71 70 5 C113 65 79 96 97 123 C106 107 111 102 109 87 C145 158 119 238 65 250Z" fill="url(#fire)"/><path d="M64 244 C34 226 40 199 52 174 C57 160 54 145 59 129 C82 155 71 183 85 178 C103 211 85 236 64 244Z" fill="#ffdb73"/><path d="M64 244 Q47 224 63 201 Q83 226 64 244" fill="#fff3c5"/>`,
  glow: `<defs><radialGradient id="g"><stop stop-color="#ffaf45" stop-opacity=".65"/><stop offset=".4" stop-color="#ff7922" stop-opacity=".2"/><stop offset="1" stop-color="#ff6419" stop-opacity="0"/></radialGradient></defs><ellipse cx="64" cy="128" rx="64" ry="128" fill="url(#g)"/>`,
  smoke: `<path d="M63 249 C18 200 105 179 61 129 C23 91 94 69 72 14" fill="none" stroke="#b6a895" stroke-opacity=".22" stroke-width="15" stroke-linecap="round"/>`
};
(async()=>{
 for (const [name,body] of Object.entries(art)) {
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="128" height="256" viewBox="0 0 128 256">${body}</svg>`;
  fs.writeFileSync(path.join(out,name+'.svg'),svg);
  const rgba=await sharp(Buffer.from(svg)).ensureAlpha().raw().toBuffer();
  for(let i=0;i<rgba.length;i+=4){const r=rgba[i];rgba[i]=rgba[i+2];rgba[i+2]=r;}
  const h=Buffer.alloc(18);h[2]=2;h.writeUInt16LE(128,12);h.writeUInt16LE(256,14);h[16]=32;h[17]=40;
  fs.writeFileSync(path.join(out,name+'.tga'),Buffer.concat([h,rgba]));
 }
 const states=[1,.5,.1,0];
 const sample=states.map((ratio,i)=>{
  const heat=ratio?(.18+.82*ratio**.65):0;
  const place=(name,x,y,w,h)=>`<svg x="${x}" y="${y}" width="${w}" height="${h}" viewBox="0 0 128 256" preserveAspectRatio="none">${art[name].replaceAll('id="','id="s'+i+name).replaceAll('url(#','url(#s'+i+name)}</svg>`;
  const w=46*(.5+.5*heat),h=72*heat;
  return `<g transform="translate(${i*190+5} 14)"><rect width="180" height="206" rx="8" fill="#211c19" stroke="#765839"/>${ratio?place('glow',28,4,124,152):''}${place('handle',69,65,42,84)}${ratio?place('flame',90-w/2,76-h,w,h):''}<text x="90" y="179" text-anchor="middle" fill="#edd096" font-family="Georgia" font-size="14">${Math.round(ratio*100)} %</text></g>`;
 }).join('');
 await sharp(Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="770" height="236"><rect width="770" height="236" fill="#101012"/>${sample}</svg>`)).png().toFile(path.join(out,'preview.png'));
})();
