// Grimoire vectoriel : cuir, tranches de papier et reliure. Sans texte incrusté.
const fs=require('fs'),path=require('path');
const sharp=require(process.env.OMEGA_SHARP || 'sharp');
const out=path.resolve(process.env.OMEGA_BOOK_OUT || path.resolve(__dirname,'../Media/Book'));
const specks=Array.from({length:230},(_,i)=>`<circle cx="${40+i*137%860}" cy="${35+i*83%580}" r="${.3+i%3*.24}" fill="#73542c" opacity=".08"/>`).join('');
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="940" height="650" viewBox="0 0 940 650"><defs>
<linearGradient id="leather" x1="0%" y1="0%" x2="0%" y2="100%"><stop stop-color="#826347"/><stop offset=".015" stop-color="#4c392b"/><stop offset=".06" stop-color="#30231c"/><stop offset=".9" stop-color="#34271f"/><stop offset=".975" stop-color="#59422f"/><stop offset="1" stop-color="#1b1512"/></linearGradient>
<linearGradient id="left"><stop stop-color="#ddcda8"/><stop offset=".95" stop-color="#ddcda8"/><stop offset="1" stop-color="#bda67a"/></linearGradient>
<linearGradient id="right"><stop stop-color="#bda67a"/><stop offset=".05" stop-color="#ddcda8"/><stop offset="1" stop-color="#ddcda8"/></linearGradient>
<linearGradient id="spine"><stop stop-color="#b39768"/><stop offset=".42" stop-color="#5f4930"/><stop offset=".5" stop-color="#30241a"/><stop offset=".6" stop-color="#735735"/><stop offset="1" stop-color="#b39768"/></linearGradient>
</defs>
<!-- Le contour, le biseau et le filet suivent tous la même charnière. -->
<path d="M17 5 H420 C443 5 451 8 470 8 C489 8 497 5 520 5 H923 Q936 5 936 18 V632 Q936 645 923 645 H520 C497 645 489 642 470 642 C451 642 443 645 420 645 H17 Q4 645 4 632 V18 Q4 5 17 5Z" fill="url(#leather)" stroke="#80633c" stroke-width="2"/>
<path d="M18 8 H420 C443 8 452 11 470 11 C488 11 497 8 520 8 H922 Q933 8 933 19 V631 Q933 642 922 642 H520 C497 642 488 639 470 639 C452 639 443 642 420 642 H18 Q7 642 7 631 V19 Q7 8 18 8Z" fill="none" stroke="#b49262" stroke-width="1" opacity=".45"/>
<path d="M10 630 Q10 640 20 640 H420 C443 640 452 637 470 637 C488 637 497 640 520 640 H922 Q932 640 932 630 V20" fill="none" stroke="#100e0c" stroke-width="2" opacity=".45"/>
<path d="M20 13 H420 C442 13 452 16 470 16 C488 16 498 13 520 13 H920 Q928 13 928 21 V629 Q928 637 920 637 H520 C498 637 488 634 470 634 C452 634 442 637 420 637 H20 Q12 637 12 629 V21 Q12 13 20 13Z" fill="none" stroke="#ac8951" opacity=".6"/>
<!-- Départs de charnière : joints verticaux limités à l'épaisseur du cuir. -->
<path d="M420 6 V29 M520 6 V29 M420 619 V644 M520 619 V644" fill="none" stroke="#20160f" stroke-width="1.4" opacity=".8"/>
<path d="M421.5 7 V29 M521.5 7 V29 M421.5 619 V643 M521.5 619 V643" fill="none" stroke="#b08c58" stroke-width=".7" opacity=".5"/>
<path d="M22 28 Q245 15 469 29 L469 621 Q240 611 22 628Z M471 29 Q690 15 918 28 L918 628 Q698 611 471 621Z" fill="#8e7957" stroke="#b6a079"/>
<path d="M25 24 Q244 13 469 28 L469 618 Q240 606 25 620Z M471 28 Q694 13 915 24 L915 620 Q695 606 471 618Z" fill="#c1ac83" stroke="#e3cfaa"/>
<path d="M29 23 Q244 12 469 29 L469 615 Q240 601 29 615Z" fill="url(#left)" stroke="#aa9063"/>
<path d="M471 29 Q694 12 911 23 L911 615 Q698 601 471 615Z" fill="url(#right)" stroke="#aa9063"/>
${specks}
<path d="M470 30 C469 190 471 440 470 615" fill="none" stroke="#675039" stroke-width="1.5"/>
<g fill="none" stroke="#b08d53" stroke-width="1.4"><path d="M17 65 V20 H62 M878 20 H923 V65 M17 585 V631 H62 M878 631 H923 V585"/><path d="M20 45 L40 23 M900 23 L920 45 M20 606 L40 628 M900 628 L920 606"/></g>
</svg>`;
const baseCover=`<svg xmlns="http://www.w3.org/2000/svg" width="470" height="650"><defs><linearGradient id="c"><stop stop-color="#201a16"/><stop offset=".07" stop-color="#574130"/><stop offset=".13" stop-color="#30251e"/><stop offset=".9" stop-color="#392b22"/><stop offset="1" stop-color="#594432"/></linearGradient></defs><rect x="4" y="5" width="462" height="640" rx="12" fill="url(#c)" stroke="#917145" stroke-width="2"/><rect x="24" y="25" width="420" height="598" rx="5" fill="none" stroke="#ab8850"/><rect x="33" y="34" width="402" height="580" rx="3" fill="none" stroke="#755b37"/><path d="M42 105 V45 H102 M370 45 H428 V105 M42 543 V604 H102 M370 604 H428 V543" fill="none" stroke="#b7975d" stroke-width="2"/><path d="M235 231 L302 321 L235 411 L168 321Z" fill="none" stroke="#aa8850" stroke-width="2"/><circle cx="235" cy="321" r="47" fill="none" stroke="#7e6138"/><path d="M214 339 A29 29 0 1 1 256 339 L271 339 M214 339 H199" fill="none" stroke="#c3a56b" stroke-width="3"/><path d="M15 104 H31 M15 294 H31 M15 488 H31" stroke="#bb9962" stroke-width="5"/></svg>`;

const cover=baseCover
 .replace('</defs>', `<radialGradient id="dome" cx="38%" cy="30%" r="75%"><stop stop-color="#b58a58" stop-opacity=".32"/><stop offset=".6" stop-color="#8d6742" stop-opacity=".10"/><stop offset="1" stop-color="#080706" stop-opacity=".62"/></radialGradient></defs>`)
 .replace('<rect x="24"', `<rect x="8" y="9" width="454" height="632" rx="10" fill="url(#dome)"/>
 <path d="M12 626 V20 Q12 13 22 13 H447" fill="none" stroke="#bb9768" stroke-width="3" opacity=".65"/>
 <path d="M17 632 H450 Q458 632 458 622 V20" fill="none" stroke="#100d0a" stroke-width="6" opacity=".8"/>
 <path d="M36 45 V600" stroke="#160f0b" stroke-width="8" opacity=".55"/>
 <path d="M43 45 V600" stroke="#c79a63" stroke-width="2" opacity=".28"/>
 <path d="M235 234 L305 324 L235 414 L171 324Z" fill="#1b1410" fill-opacity=".3" stroke="#100d0a" stroke-width="4"/>
 <path d="M235 229 L301 319 L235 409 L167 319Z" fill="none" stroke="#c4a16b" stroke-width="1.5" opacity=".65"/>
 <rect x="24"`);

(async()=>{fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'grimoire.svg'),svg);await sharp(Buffer.from(svg)).resize(2048,2048,{fit:'fill'}).png().toFile(path.join(out,'grimoire.png'));fs.writeFileSync(path.join(out,'cover.svg'),cover);await sharp(Buffer.from(cover)).resize(512,1024,{fit:'fill'}).png().toFile(path.join(out,'cover.png'));})();
