const path=require('path'),sharp=require(process.env.OMEGA_SHARP||'sharp');
const root=path.join(__dirname,'..');
const fonts=[['Marcellus','Sanctuaire'],['CormorantSC','Poétique'],['Almendra','Conte ancien'],['Amiri','Lettré'],['Tajawal','Épuré'],['Rajdhani','Futuriste'],['Rye','Western'],['Forum','Antique'],['BarlowCondensed','Survie'],['Philosopher','Voyage'],['Caudex','Chronique']];
(async()=>{
 const layers=[];
 for(let i=0;i<fonts.length;i++){
  const [font,label]=fonts[i],x=i%2*560,y=Math.floor(i/2)*130;
  for(const [text,size,top,color] of [[font+' · '+label,15,12,'#b9a47b'],['Les Portes d’Astralune',30,43,'#ede5d2'],['Échos oubliés · Forêt sacrée · Cœur de jade',15,92,'#a6b4b6']]){
   const family=({CormorantSC:'Cormorant SC',BarlowCondensed:'Barlow Condensed'})[font]||font;
   const input=await sharp({text:{text:`<span foreground="${color}">${text}</span>`,font:family+' '+size,fontfile:path.join(root,'Fonts',font+'-Regular.ttf'),rgba:true}}).png().toBuffer();
   layers.push({input,left:x+25,top:y+top});
  }
 }
 await sharp({create:{width:1120,height:780,channels:4,background:'#15191b'}}).composite(layers).png().toFile(path.join(root,'Fonts/font-gallery.png'));
})();
