// Original tintable silhouettes: the middle stays open for the two text lines.
const line=(d,o=.7,w=2)=>`<path d="${d}" fill="none" stroke="white" opacity="${o}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
const shape=(d,o=.5)=>`<path d="${d}" fill="white" opacity="${o}"/>`;
const mirror=s=>s+`<g transform="translate(1024 0) scale(-1 1)">${s}</g>`;
const base=`<defs><linearGradient id="mist"><stop stop-color="white" stop-opacity="0"/><stop offset=".5" stop-color="white" stop-opacity=".09"/><stop offset="1" stop-color="white" stop-opacity="0"/></linearGradient></defs><path d="M0 204Q210 170 512 201Q820 170 1024 204V244H0Z" fill="url(#mist)"/>`;
const ground=line('M30 224Q116 201 210 221L360 224 M664 224L814 221Q910 201 994 224',.4);
function tree(x,y,s,season){
 let art=line('M0 152Q-5 83 3 14 M0 106L-30 78L-39 41 M0 84L28 57L36 22 M-2 64L-19 44L-16 12 M-1 124L27 105',.9,4);
 if(season!=='winter')for(let j=0;j<22;j++){
  const a=j*2.4,r=12+(j%4)*8,cx=Math.cos(a)*r,cy=42+Math.sin(a)*r;
  art+=`<ellipse cx="${cx}" cy="${cy}" rx="${season==='summer'?18:12}" ry="${season==='summer'?14:8}" fill="white" opacity="${.2+j%4*.13}" transform="rotate(${j*29} ${cx} ${cy})"/>`;
 }
 if(season==='spring')for(let j=0;j<9;j++)art+=`<circle cx="${Math.sin(j*3)*30}" cy="${20+j*6}" r="3" fill="white"/>`;
 if(season==='autumn')art+=shape('M36 105q14 -10 7 5q-6 7 -7 -5 M-26 136q12 -9 8 5q-10 5 -8 -5 M45 145q13 -7 5 7Z',.8);
 if(season==='winter')art+=line('M-38 42L-28 76 M5 18L1 48 M28 56L36 25',1,5);
 return `<g transform="translate(${x} ${y}) scale(${s})">${art}</g>`;
}
const pine=(x,y,s)=>`<g transform="translate(${x} ${y}) scale(${s})">${shape('M0 0L-19 37H-10L-29 64H-17L-38 97H-5V127H5V97H38L17 64H29L10 37H19Z',.7)}${line('M0 18V108',.7)}</g>`;
const rock=shape('M8 220L70 73L107 130L142 27L221 219Z',.25)+line('M8 220L70 73L107 130L142 27L221 219 M142 27L128 161L152 196 M70 73L61 178',.85);
const snow=shape('M118 89L142 27L171 97L151 83L143 99L135 77Z M48 123L70 73L94 110L74 104L65 117Z',.9);
const themes={};
for(const season of ['spring','summer','autumn','winter']) themes['forest_'+season]=base+mirror(tree(74,26,1.25,season)+tree(163,103,.69,season))+ground;
themes.mountains=base+mirror(rock)+ground;
themes.snowpeaks=base+mirror(rock+snow+pine(202,150,.5))+ground;
themes.desert=base+mirror(shape('M0 222Q65 104 242 216L315 229Z',.25)+line('M8 208Q92 128 244 218 M38 222Q160 181 288 228',.7)+line('M80 192V116Q80 108 85 116V157Q104 160 103 139 M83 174Q58 178 59 150',.9,5))+`<circle cx="115" cy="72" r="24" fill="white" opacity=".5"/>`+ground;
themes.ocean=base+mirror(line('M5 177Q54 125 96 165Q134 206 169 174Q105 211 72 181Q44 154 5 177 M10 201Q70 181 139 210Q190 234 254 212 M17 222Q80 206 142 225',.8,3))+line('M81 71l10 -6 10 6 M122 95l8 -5 8 5',.7)+ground;
themes.marsh=base+mirror(tree(55,56,1,'winter')+line('M26 99Q38 152 48 119 M65 85Q87 163 91 120 M136 220L131 155 M131 192L114 175 M137 209L157 180',.65,3)+`<g fill="white"><circle cx="120" cy="117" r="2"/><circle cx="164" cy="166" r="2"/><circle cx="100" cy="181" r="3"/></g>`)+ground;
themes.ruins=base+mirror(shape('M35 221V82H25V68H83V82H74V218 M114 219V119L129 112V87H151L168 116V219Z',.28)+line('M35 220V82H74V218 M25 68H83V82H25Z M48 95V202 M61 95V171 M117 215V126L137 132L130 165L145 184 M82 68Q114 21 172 74L161 87Q126 54 95 89',.85))+ground;
themes.volcano=base+mirror(shape('M4 220L88 103L118 119L138 106L219 221Z',.25)+line('M4 220L88 103L118 119L138 106L219 221 M114 127L101 155L125 174L116 204 M145 141L169 172',.95,3)+line('M109 84Q71 62 108 45Q135 30 112 13 M144 91Q169 62 151 47',.35,5)+`<circle cx="58" cy="83" r="2" fill="white"/><circle cx="178" cy="35" r="3" fill="white"/>`)+ground;
themes.cavern=base+mirror(shape('M0 8L57 14L75 70L99 29L151 38L176 104L209 37L235 27L192 12Z M0 240L57 212L75 133L92 193L123 167L146 220L217 240Z',.35)+line('M57 212L75 133L80 219 M99 29L75 70 M151 38L176 104L170 47 M105 205L123 167L142 219',.8))+ground;
themes.relic=base+mirror(line('M35 128L83 59L131 128L83 197Z M52 128L83 84L113 128L83 172Z M83 59V31 M83 197V225 M131 128H206 M83 98L98 128L83 158L68 128Z',.85,2)+line('M149 84Q175 53 224 60 M152 172Q179 206 231 194',.5))+line('M246 221H456L512 238L568 221H778',.7);
themes.crystal=base+mirror(shape('M76 20L113 78L88 213L44 128Z M131 80L160 112L141 204L112 152Z',.16)+line('M76 20L113 78L88 213L44 128Z M76 20L72 116L88 213 M44 128L72 116L113 78 M131 80L160 112L141 204L112 152Z M131 80L132 138L141 204 M132 138L160 112',.95)+line('M169 187Q193 133 220 142 M36 54L27 45 M144 31V43 M138 37H150',.5))+ground;
themes.hunt=base+mirror(shape('M48 205L60 126L26 51L78 90L112 53L124 128L154 91L139 185L96 224Z',.25)+line('M48 205L60 126L26 51L78 90L112 53L124 128L154 91L139 185L96 224Z M62 128L90 152L123 129 M90 152L96 224 M68 173L79 195 M118 171L108 196 M166 66L189 39L177 92 M189 102L208 82L195 130',.85,3))+line('M208 223H446L469 213L489 229L512 217L535 229L555 213L578 223H816',.7);
themes.gothic=base+mirror(line('M35 225V85Q65 54 89 24Q113 54 143 85V225 M49 217V92Q73 68 89 48Q105 68 129 92V217 M89 48V204 M49 117H129 M60 181L89 150L118 181L89 212Z M162 223V133Q178 105 195 94Q212 107 227 133V223',.7)+shape('M49 92L89 48L129 92V117H49Z',.12))+ground;
themes.runes=base+mirror(line('M31 210L47 52L108 24L157 77L148 220Z M47 52L84 72L108 24 M84 72L70 206 M102 89V163L126 144 M101 109L128 90 M170 111L192 92L215 111L192 132Z M181 154L202 174L181 195',.8,3))+line('M245 223H456 M568 223H779 M487 223L512 198L537 223L512 248Z M512 209V237',.7);
themes.portal=base+mirror(line('M182 29A125 125 0 0 0 182 227 M175 46A104 104 0 0 0 175 210 M93 71L76 59 M68 112L46 109 M76 169L55 180 M119 211L108 230 M118 42L107 23',.8,3)+line('M158 72L179 107L150 128L177 151L156 184 M23 128L37 114L51 128L37 142Z',.5))+line('M234 222H450 M574 222H790 M485 222L512 205L539 222L512 239Z',.7);
module.exports=themes;
