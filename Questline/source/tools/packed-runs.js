// Each scanline triple uses six ASCII bytes, without per-number Lua table slots.
const alphabet='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_';
function packRuns(runs) {
  return runs.map(n=>{
    if(!Number.isInteger(n)||n<0||n>=4096)throw Error('Area coordinate exceeds packed range: '+n);
    return alphabet[Math.floor(n/64)]+alphabet[n%64];
  }).join('');
}
function unpackRuns(data) {
  if(typeof data!=='string')return Object.values(data);
  if(data.length%6)throw Error('Truncated area scanline');
  const runs=[];
  for(let i=0;i<data.length;i+=2) {
    const high=alphabet.indexOf(data[i]),low=alphabet.indexOf(data[i+1]);
    if(high<0||low<0)throw Error('Invalid area coordinate');
    runs.push(high*64+low);
  }
  return runs;
}
module.exports={packRuns,unpackRuns};
