// Tiny deterministic encoders for our code-drawn UI textures and review images.
const fs=require('node:fs'),zlib=require('node:zlib');
function bitmap(width,height,sample,aa=1) {
  const pixels=Buffer.alloc(width*height*4);
  for(let y=0;y<height;y++) for(let x=0;x<width;x++) {
    const sum=[0,0,0,0];
    for(let sy=0;sy<aa;sy++) for(let sx=0;sx<aa;sx++) {
      const c=sample(x+(sx+.5)/aa,y+(sy+.5)/aa),alpha=c[3]/255;
      for(let n=0;n<3;n++) sum[n]+=c[n]*alpha;
      sum[3]+=alpha;
    }
    const offset=(y*width+x)*4;
    for(let n=0;n<3;n++) pixels[offset+n]=sum[3]?Math.round(sum[n]/sum[3]):0;
    pixels[offset+3]=Math.round(sum[3]/(aa*aa)*255);
  }
  return {width,height,pixels};
}
function writeTGA(file,{width,height,pixels}) {
  const header=Buffer.alloc(18);header[2]=2;header.writeUInt16LE(width,12);header.writeUInt16LE(height,14);header[16]=32;header[17]=8;
  const bgra=Buffer.alloc(pixels.length);
  for(let y=0;y<height;y++) for(let x=0;x<width;x++) {
    const src=(y*width+x)*4,dst=((height-1-y)*width+x)*4;
    bgra[dst]=pixels[src+2];bgra[dst+1]=pixels[src+1];bgra[dst+2]=pixels[src];bgra[dst+3]=pixels[src+3];
  }
  fs.writeFileSync(file,Buffer.concat([header,bgra]));
}
function crc32(data) {
  let crc=0xffffffff;
  for(const byte of data) {crc^=byte;for(let bit=0;bit<8;bit++) crc=(crc>>>1)^((crc&1)?0xedb88320:0);}
  return (crc^0xffffffff)>>>0;
}
function writePNG(file,{width,height,pixels}) {
  function chunk(name,data) {
    const bytes=Buffer.concat([Buffer.from(name),data]),size=Buffer.alloc(4),crc=Buffer.alloc(4);
    size.writeUInt32BE(data.length);crc.writeUInt32BE(crc32(bytes));return Buffer.concat([size,bytes,crc]);
  }
  const header=Buffer.alloc(13);header.writeUInt32BE(width);header.writeUInt32BE(height,4);header[8]=8;header[9]=6;
  const scan=Buffer.alloc((width*4+1)*height);
  for(let y=0;y<height;y++) pixels.copy(scan,y*(width*4+1)+1,y*width*4,(y+1)*width*4);
  fs.writeFileSync(file,Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',zlib.deflateSync(scan)),chunk('IEND',Buffer.alloc(0))]));
}
module.exports={bitmap,writeTGA,writePNG};
