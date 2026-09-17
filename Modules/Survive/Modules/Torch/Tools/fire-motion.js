// Continuous displacement field: fixed fuel bed, rising vortices above it.
// Bilinear premultiplied sampling avoids dark edges on translucent fire.
module.exports=function(source,t,heat){
 const out=Buffer.alloc(128*128*4),tau=Math.PI*2;
 for(let y=0;y<128;y++)for(let x=0;x<128;x++){
  const rise=Math.max(0,(121-y)/112),mobility=Math.pow(rise,1.6);
  const sway=mobility*(7*Math.sin(tau*t/2-rise*7)+3*Math.sin(tau*t*1.5-rise*15));
  const width=1+mobility*.12*Math.sin(tau*t-rise*11);
  const sx=64+(x-64-sway)/width;
  const sy=y+mobility*(3*Math.sin(tau*t-rise*13)+2*Math.sin(tau*t*2-rise*21));
  const ix=Math.floor(sx),iy=Math.floor(sy),fx=sx-ix,fy=sy-iy;
  let a=0,r=0,g=0,b=0;
  for(let dy=0;dy<2;dy++)for(let dx=0;dx<2;dx++){
   const px=ix+dx,py=iy+dy;if(px<0||px>=128||py<0||py>=128)continue;
   const k=(py*128+px)*4,weight=(dx?fx:1-fx)*(dy?fy:1-fy)*source[k+3]/255;
   a+=weight;r+=source[k]*weight;g+=source[k+1]*weight;b+=source[k+2]*weight;
  }
  const k=(y*128+x)*4;
  if(a>0){out[k]=r/a;out[k+1]=g/a;out[k+2]=b/a;
   const turbulence=1-.18*rise*(.5+.5*Math.sin(tau*t*2-rise*26+x*.12));
   out[k+3]=Math.min(255,a*255*turbulence*Math.min(1,heat*6));
  }
 }
 return out;
};
