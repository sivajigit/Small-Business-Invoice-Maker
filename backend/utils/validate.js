const emailOk=x=>typeof x==='string'&&/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(x)&&x.length<=254;
const str=(x,n=150)=>typeof x==='string'&&x.trim().length>0&&x.trim().length<=n;
const money=x=>typeof x==='number'&&Number.isFinite(x)&&x>=0&&x<=100000000;
module.exports={emailOk,str,money};
