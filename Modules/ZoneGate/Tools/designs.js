// Original monochrome compositions. Runtime tint remains fully editable.
const fs=require('fs'),path=require('path'),sharp=require(process.env.OMEGA_SHARP||'sharp');
const dir=path.join(__dirname,'../Media/Designs');fs.mkdirSync(dir,{recursive:true});
const brush=(y,h)=>`<path d="M28 ${y+14} L106 ${y+4} L193 ${y+8} L284 ${y} L417 ${y+7} L564 ${y+3} L690 ${y+9} L832 ${y+2} L986 ${y+13} L961 ${y+h-16} L995 ${y+h-6} L862 ${y+h-2} L704 ${y+h-8} L578 ${y+h} L390 ${y+h-4} L230 ${y+h-1} L117 ${y+h-10} L42 ${y+h-3} L66 ${y+h-19}Z" fill="white"/>`;
const grain=Array.from({length:160},(_,i)=>`<path d="M${36+(i*137)%946} ${38+(i*47)%168}h${2+(i*7)%22}" stroke="black" stroke-width="${1+i%2}" opacity=".24"/>`).join('');
const designs={
 western:brush(24,202)+grain+`<path d="M96 49H929 M92 196H925" stroke="black" stroke-width="3"/><path d="M506 34l6 -10 6 10-6 10Z M506 210l6 -10 6 10-6 10Z" fill="black"/>`,
 sumi:brush(44,155)+brush(63,123)+grain+`<path d="M4 72L92 57 M8 179L80 161 M966 82l52 -12 M940 189l72 -10" stroke="white" stroke-width="4"/>`,
 souls:`<defs><radialGradient id="g"><stop stop-color="white" stop-opacity=".6"/><stop offset="1" stop-color="white" stop-opacity="0"/></radialGradient></defs><ellipse cx="512" cy="128" rx="510" ry="110" fill="url(#g)"/><path d="M80 56H944 M80 207H944" stroke="white" opacity=".48"/><path d="M304 58H720 M304 205H720" stroke="white" opacity=".22"/>`,
 scifi:`<path d="M14 53L45 22H978L1010 54V202L978 234H45L14 202Z" fill="white" opacity=".12"/><path d="M14 85V53L45 22H190 M834 22H978L1010 54V85 M14 171V202L45 234H190 M834 234H978L1010 202V171" fill="none" stroke="white" stroke-width="4"/><path d="M66 41H190 M834 215H958 M38 70V124 M986 132V186" stroke="white" stroke-width="2"/>`,
 deco:`<g fill="none" stroke="white"><path d="M45 52H410L512 13L614 52H979V204H614L512 243L410 204H45Z" stroke-width="2"/><path d="M66 65H414L512 30L610 65H958V191H610L512 226L414 191H66Z" opacity=".4"/><path d="M450 51L512 13L574 51 M477 51L512 13L547 51 M512 13V52 M450 205L512 243L574 205 M477 205L512 243L547 205 M512 205V243"/><path d="M18 104L43 128L18 152 M1006 104L981 128L1006 152" stroke-width="3"/></g>`,
 minimal:`<path d="M100 202H445 M579 202H924" stroke="white" stroke-width="2"/><path d="M500 202L512 190L524 202L512 214Z" fill="none" stroke="white" stroke-width="2"/>`
};
Object.assign(designs,require('./landscapes'));
Object.assign(designs,require('./quiet'));
(async()=>{for(const [name,body] of Object.entries(designs)){
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="256">${body}</svg>`;
 fs.writeFileSync(path.join(dir,name+'.svg'),svg);
 const rgba=await sharp(Buffer.from(svg)).ensureAlpha().raw().toBuffer();
 for(let i=0;i<rgba.length;i+=4){const r=rgba[i];rgba[i]=rgba[i+2];rgba[i+2]=r;}
 const h=Buffer.alloc(18);h[2]=2;h.writeUInt16LE(1024,12);h.writeUInt16LE(256,14);h[16]=32;h[17]=40;
 fs.writeFileSync(path.join(dir,name+'.tga'),Buffer.concat([h,rgba]));
} console.log(Object.keys(designs).length+' original banner compositions ready');})();
