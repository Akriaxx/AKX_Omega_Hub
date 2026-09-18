// Static layout preview at 2x. Portrait is illustrative, not a game capture.
const fs=require('fs'),path=require('path');
const sharp=require(process.env.OMEGA_SHARP||'sharp');
const out=path.join(__dirname,'hud-preview.png');
const art=require('./hud-art');
const asset=(name,x,y,w,h)=>`<image x="${x}" y="${y}" width="${w}" height="${h}" preserveAspectRatio="none" href="data:image/svg+xml;base64,${Buffer.from(art[name]).toString('base64')}"/>`;
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="900" height="370" viewBox="0 0 450 185">
<defs>
 <radialGradient id="back"><stop stop-color="#283235"/><stop offset="1" stop-color="#101416"/></radialGradient>
 <linearGradient id="portrait" x2="0" y2="1"><stop stop-color="#667574"/><stop offset="1" stop-color="#18272c"/></linearGradient>
 <clipPath id="circle"><circle cx="40" cy="50" r="37"/></clipPath>
</defs>
<rect width="450" height="185" rx="10" fill="url(#back)"/>
<text x="28" y="25" fill="#a9aaa5" font-family="Segoe UI" font-size="9" letter-spacing="1.2">CHARACTER · APERÇU DE DISPOSITION</text>
<g transform="translate(62 43)">
 ${asset('ResourcePanel',42,8,284,84)}
 <circle cx="40" cy="50" r="40" fill="#ad8c52"/>
 <g clip-path="url(#circle)">
  <rect y="10" width="80" height="80" fill="url(#portrait)"/>
  <path d="M3 94Q8 67 27 68L31 58H49L53 68Q74 70 80 94Z" fill="#28333b"/>
  <path d="M28 59V74L40 85L52 73L49 59Z" fill="#b69b84"/>
  <ellipse cx="40" cy="43" rx="16" ry="22" fill="#c3ac91"/>
  <path d="M23 49Q16 15 40 15Q68 17 56 55L54 35Q40 40 32 29L26 50Z" fill="#272a30"/>
  <path d="M29 45H35 M44 45H50" stroke="#56504b" stroke-width="1.3"/>
  <path d="M36 58Q41 61 46 57" fill="none" stroke="#896e60"/>
  <path d="M10 79L26 70L40 86L53 70L72 81V95H10Z" fill="#384650"/>
  <path d="M27 72L40 87L53 72" fill="none" stroke="#a68e62"/>
 </g>
 ${asset('PortraitRing',-10,0,100,100)}
 <g font-family="Segoe UI" font-size="10">
  <text x="90" y="22" fill="#e8d4a6">Aelys · exemple</text>
  <rect x="90" y="29" width="226" height="17" fill="#220708"/>
  <rect x="90" y="29" width="147.4" height="17" fill="#ad2428"/>
  <rect x="237.4" y="29" width="29.5" height="17" fill="#ebB845"/>
  <rect x="90" y="49" width="226" height="17" fill="#071424"/>
  <rect x="90" y="49" width="135.6" height="17" fill="#2665ba"/>
  <rect x="90" y="69" width="226" height="17" fill="#0b1e12"/>
  <rect x="90" y="69" width="180.8" height="17" fill="#38995e"/>
  ${[29,49,69].map(y=>asset('ResourceBorder',88,y-2,230,21)).join('')}
  <path d="M90 29H316 M90 49H316 M90 69H316" stroke="white" stroke-opacity=".14"/>
  <g fill="white"><text x="95" y="42">Vie</text><text x="95" y="62">Mana</text><text x="95" y="82">Endurance</text>
  <text x="311" y="42" text-anchor="end">75 / 100 <tspan fill="#ffd36b">+15</tspan></text>
  <text x="311" y="62" text-anchor="end">60 / 100</text><text x="311" y="82" text-anchor="end">80 / 100</text></g>
 </g>
</g>
<text x="225" y="160" text-anchor="middle" fill="#b7b9b6" font-family="Segoe UI" font-size="10">Portrait illustratif · valeurs d’exemple · bonus temporaires en doré</text>
</svg>`;
sharp(Buffer.from(svg)).png().toFile(out).then(()=>process.stdout.write(out));
