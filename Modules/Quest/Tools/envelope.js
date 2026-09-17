// Source vectorielle commune aux images de l'animation. Aucun asset externe.
const fs = require('fs');
const path = require('path');
const sharp = require(process.env.OMEGA_SHARP || 'sharp');
const out = path.resolve(__dirname, '../Media/Envelope');
const ease = t => { t = Math.max(0, Math.min(1, t)); return t*t*(3-2*t); };
function svg(t, blank=false) {
  const flap = ease((t-.04)/.30), lift = ease((t-.30)/.30);
  const unfold = ease((t-.63)/.37), scale = -Math.cos(unfold*Math.PI);
  const tip = 270 + 116*Math.cos(flap*Math.PI), top = 282-222*lift;
  const seal = 1-ease(t/.14), envelope = 1-ease((t-.60)/.25);
  // Marques fixes sur le papier : elles suivent le pli, sans scintiller.
  const speckles=Array.from({length:65},(_,i)=>`<circle cx="${122+(i*73%266)}" cy="${4+(i*47%152)}" r="${.3+(i%4)*.23}" fill="#76522c" opacity="${.05+(i%3)*.025}"/>`).join('');
  const half=(writing)=>`<path d="M119 1 L170 0 L221 1 L286 0 L344 1 L393 0 L394 54 L392 91 L394 130 L393 162 L333 161 L276 162 L210 161 L158 162 L118 161 L119 106 L118 65Z" fill="url(#page)" stroke="#95703e" stroke-width="1.1"/>
    <rect x="124" y="5" width="264" height="152" fill="none" stroke="#8c5c2c" opacity=".16" stroke-width="7"/>
    <ellipse cx="138" cy="33" rx="16" ry="23" fill="url(#stain)"/>
    <ellipse cx="371" cy="133" rx="19" ry="20" fill="url(#stain)"/>
    ${speckles}${blank ? '' : writing}`;
  const upper=half(`<path d="M242 40 A18 18 0 1 1 270 40 L278 40 M242 40 L234 40" fill="none" stroke="#775327" stroke-width="2.3"/><path d="M168 65 H344 M149 84 H361 M149 98 H347 M149 112 H360 M149 126 H318" fill="none" stroke="#725635" stroke-width="1.5" opacity=".7"/>`);
  const lower=half(unfold>.5 ? `<path d="M149 23 H358 M149 37 H344 M149 51 H361 M149 65 H334 M149 79 H354 M149 93 H301 M285 127 q14 -17 17 -4 t24 -4 q-2 14 21 4" fill="none" stroke="#725635" stroke-width="1.5" opacity=".7"/>` : '');
  const letter=`<g transform="translate(0 ${top})">${upper}<path d="M121 160 H391" stroke="#6e4829" opacity="${.12+.16*Math.sin(unfold*Math.PI)}" stroke-width="3"/></g>
    <g transform="translate(0 ${top+162}) scale(1 ${Math.abs(scale)<.005 ? .005 : scale})">${lower}</g>
    <path d="M120 ${top+162} H392" stroke="#855e32" opacity=".32"/><path d="M121 ${top+163.5} H390" stroke="#f6e2b3" opacity=".55"/>`;
  const flapPath = `<path d="M88 270 L424 270 L256 ${tip} Z" fill="url(#flap)" stroke="#ae9664" stroke-width="1.5"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="body" x2=".2" y2="1"><stop stop-color="#d3bc8b"/><stop offset="1" stop-color="#9f7c4f"/></linearGradient>
    <linearGradient id="flap" x2="0" y2="1"><stop stop-color="#ddc69a"/><stop offset="1" stop-color="#b19260"/></linearGradient>
    <radialGradient id="page" cx="47%" cy="43%" r="72%"><stop stop-color="#edd8a7"/><stop offset=".65" stop-color="#d9bc87"/><stop offset="1" stop-color="#ac804a"/></radialGradient>
    <radialGradient id="stain"><stop stop-color="#855426" stop-opacity=".16"/><stop offset="1" stop-color="#855426" stop-opacity="0"/></radialGradient>
    <linearGradient id="gold" x2=".9" y2="1"><stop stop-color="#f3d998"/><stop offset=".42" stop-color="#c4a35d"/><stop offset="1" stop-color="#796032"/></linearGradient>
    <radialGradient id="wax"><stop stop-color="#414843"/><stop offset="1" stop-color="#1c2624"/></radialGradient>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="180%"><feGaussianBlur stdDeviation="5"/></filter>
  </defs>
  <g opacity="${envelope}"><ellipse cx="256" cy="460" rx="163" ry="10" fill="#000" opacity=".22" filter="url(#shadow)"/>
  <rect x="88" y="270" width="336" height="180" rx="5" fill="#73634b" stroke="#ae9664" stroke-width="2"/>
  ${flap>.5 ? flapPath : ''}</g>
  ${letter}
  <g opacity="${envelope}">
  <path d="M88 270 L273 373 L88 448Z" fill="#c6ab7a" stroke="#a48a5d"/>
  <path d="M424 270 L239 373 L424 448Z" fill="#bba070" stroke="#9d7d50"/>
  <path d="M88 448 L239 345 Q256 334 273 345 L424 448Z" fill="url(#body)" stroke="#ae9664" stroke-width="1.5"/>
  <path d="M101 441 L244 349 Q256 342 268 349 L411 441" fill="none" stroke="#f7ecd4" opacity=".7"/>
  ${flap<=.5 ? flapPath : ''}
  <g opacity="${seal}">
    <circle cx="256" cy="376" r="28" fill="#000" opacity=".2"/>
    <circle cx="256" cy="371" r="28" fill="url(#wax)" stroke="url(#gold)" stroke-width="2"/>
    <circle cx="256" cy="371" r="22" fill="none" stroke="#b99a59" stroke-width=".8"/>
    <path d="M247 379 A14 14 0 1 1 265 379 L272 379 M247 379 L240 379" fill="none" stroke="url(#gold)" stroke-width="2.5"/>
    <path d="M255 338 L257 338 M255 404 L257 404" stroke="#dbc38d"/>
  </g></g></svg>`;
}
(async () => {
  fs.mkdirSync(out, {recursive:true});
  fs.writeFileSync(path.join(out,'paper.svg'),svg(1,true));
  await sharp(Buffer.from(svg(1,true))).extract({left:116,top:58,width:280,height:328}).resize(512,1024).png().toFile(path.join(out,'paper.png'));
  for(let i=0;i<64;i++) {
    const source=svg(i/63), name=`frame-${String(i).padStart(2,'0')}`;
    fs.writeFileSync(path.join(out,name+'.svg'),source);
    await sharp(Buffer.from(source)).png().toFile(path.join(out,name+'.png'));
  }
  for(let sheet=0;sheet<4;sheet++) {
    const tiles=Array.from({length:16},(_,i)=>({input:path.join(out,`frame-${String(sheet*16+i).padStart(2,'0')}.png`),left:(i%4)*512,top:Math.floor(i/4)*512}));
    await sharp({create:{width:2048,height:2048,channels:4,background:'#00000000'}}).composite(tiles).png().toFile(path.join(out,`atlas-${sheet+1}.png`));
  }
})();
