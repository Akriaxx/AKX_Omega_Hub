// Contact sheet of the original compositions, using the bundled fonts.
const fs=require('fs'),path=require('path'),sharp=require(process.env.OMEGA_SHARP||'sharp');
const root=path.join(__dirname,'..');
const styles=[
 ['souls','Cendres','LA CITADELLE OUBLIÉE','Dark fantasy','Cinzel-Regular.ttf',[.12,.11,.09],[.88,.85,.77]],
 ['western','Frontière','BLACKWATER','Western','Cinzel-Regular.ttf',[.48,.045,.025],[1,.93,.78]],
 ['sumi','Encre','LE COL DES BRUMES','Samouraï','Metamorphous-Regular.ttf',[.12,.10,.09],[.96,.92,.82]],
 ['scifi','Signal','SECTEUR OMEGA','Science-fiction','Cinzel-Regular.ttf',[.04,.35,.40],[.60,.96,1]],
 ['deco','Éclipse','LES PORTES DU PALACE','Art déco','Cinzel-Regular.ttf',[.68,.49,.20],[1,.86,.53]],
 ['minimal','Horizon','LA DERNIÈRE FRONTIÈRE','Cinéma','Cinzel-Regular.ttf',[.55,.58,.62],[.94,.92,.83]]
];
const studio=fs.readFileSync(path.join(root,'Studio.lua'),'utf8');
for(const match of studio.matchAll(/\{"([a-z_]+)","([^"]+)","([^"]+)",\{([\d.,]+)\}\}/g)){
 styles.push([match[1],match[2],match[2],match[3],'Cinzel-Regular.ttf',match[4].split(',').map(Number),[.92,.90,.82]]);
}
(async()=>{
 if(process.argv.includes('--regional')) styles.splice(0,styles.length-10);
 if(process.argv.includes('--quiet')) styles.splice(0,styles.length,...styles.filter(s=>s[0].startsWith('quiet_')));
 const layers=[];
 for(let i=0;i<styles.length;i++){
  const [key,name,title,subtitle,font,bg,fg]=styles[i],x=(i%2)*480,y=Math.floor(i/2)*190;
  const {data,info}=await sharp(path.join(root,'Media/Designs',key+'.svg')).resize(440,110).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  for(let k=0;k<data.length;k+=4)for(let c=0;c<3;c++)data[k+c]*=bg[c];
  layers.push({input:await sharp(data,{raw:info}).png().toBuffer(),left:x+20,top:y+44});
  const color='#'+fg.map(v=>Math.round(v*255).toString(16).padStart(2,'0')).join('');
  for(const [label,size,top] of [[name+' / '+subtitle,12,18],[title,22,77],['Une nouvelle destination',12,112]]){
   const text=await sharp({text:{text:`<span foreground="${color}">${label}</span>`,font:'serif '+size,fontfile:path.join(root,'Fonts',font),rgba:true}}).png().toBuffer();
   const m=await sharp(text).metadata();layers.push({input:text,left:x+Math.round((480-m.width)/2),top:y+top});
  }
 }
 await sharp({create:{width:960,height:Math.ceil(styles.length/2)*190,channels:4,background:'#17171b'}}).composite(layers).png().toFile(path.join(root,'Media/Designs',process.argv.includes('--regional')?'regional-gallery.png':process.argv.includes('--quiet')?'quiet-gallery.png':'gallery.png'));
})();
