// Preserve the native compressed atlas; clear only the turn-in sprite's alpha.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const sourceHash='e8c77616646421d77f3892c3f61678e1c0bbf527db6fa34b0cf7d9fb262c36e7';
function hideTurnIn(source) {
  if(crypto.createHash('sha256').update(source).digest('hex')!==sourceHash)
    throw new Error('Unexpected native ObjectIcons atlas');
  const output=Buffer.from(source);
  // BLP2 DXT3: each 4x4 block starts with eight bytes of explicit alpha.
  // The turn-in sprite is the top-right cell in a 4x4 atlas.
  for(let mip=0;mip<16;mip++) {
    const offset=source.readUInt32LE(20+mip*4);
    const width=Math.max(1,source.readUInt32LE(12)>>>mip);
    const height=Math.max(1,source.readUInt32LE(16)>>>mip);
    if(!offset||width<4||height<4) continue; // Tiny mips mix unrelated cells.
    for(let y=0;y<height/4;y++) for(let x=width*3/4;x<width;x++) {
      const pixel=(y%4)*4+x%4;
      const byte=offset+(Math.floor(y/4)*Math.ceil(width/4)+Math.floor(x/4))*16+Math.floor(pixel/2);
      output[byte]&=~(15<<((pixel%2)*4));
    }
  }
  return output;
}
function build() {
  const source=fs.readFileSync(path.join(__dirname,'sources/minimap-objecticons.blp'));
  fs.writeFileSync(path.join(__dirname,'../Textures/minimap-blips.blp'),hideTurnIn(source));
}
if(require.main===module) build();
module.exports={hideTurnIn,build};
