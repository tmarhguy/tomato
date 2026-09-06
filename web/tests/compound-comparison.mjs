import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {aluEval} from '../js/alu.js';
const examples=JSON.parse(readFileSync(new URL('../data/compound-comparison.json',import.meta.url),'utf8'));
const choose=(a,b,c)=>((a&b)|(~a&c))>>>0;
const majority=(a,b,c)=>((a&b)|(a&c)|(b&c))>>>0;
function expected(id,{A:a,B:b,C:c,D:d,E:e}) {
 switch(id) {
 case 'add':return (a+b)>>>0;
 case 'slt':return (a|0)<(b|0)?1:0;
 case 'maskadd':return (a+(b&c))>>>0;
 case 'masksub':return (a-(b&c))>>>0;
 case 'choose':return choose(a,b,c);
 case 'majority':return majority(a,b,c);
 case 'xorand':return ((a^b^c)+(a&b&c))>>>0;
 case 'select2':return choose(d,choose(a,b,c),e);
 case 'votemask':return (d+(majority(a,b,c)&e))>>>0;
 case 'vote2':return majority(majority(a,b,c),d,e);
 default:throw Error(id);
 }
}
function rv(sequence,input) {
 const r={...input};
 for(const line of sequence) {
  const [op,dest,a,b]=line.replaceAll(',','').split(/\s+/);const x=r[a],y=r[b];
  assert.notEqual(x,undefined,line);assert.notEqual(y,undefined,line);
  const operations={ADD:()=>x+y,SUB:()=>x-y,AND:()=>x&y,OR:()=>x|y,XOR:()=>x^y,SLT:()=>(x|0)<(y|0)?1:0};
  r[dest]=operations[op]()>>>0;
 }
 return r.out;
}
function tomato(sequence,input) {
 const r={...input};let flags=0;
 for(const step of sequence) {
  const [A,B,C]=step.inputs.map(n=>r[n]);
  assert.ok([A,B,C].every(x=>x!==undefined));
  const result=aluEval({width:32,A,B,C,lutA:step.lutF,lutB:step.lutG,cin:step.carry==='LT'?(flags>>>5)&1:step.carry});
  r[step.dest]=result.out;
  if(step.latchFlags)flags=result.flags;
 }
 return r.out;
}
const vectors=[];
const edges=[0,1,0x7fffffff,0x80000000,0xffffffff,0xaaaaaaaa,0x55555555];
for(const A of edges)for(const B of edges)for(const C of edges)vectors.push({A,B,C,D:B,E:A});
let seed=123456789;const next=()=>seed=(Math.imul(seed,1664525)+1013904223)>>>0;
for(let i=0;i<500;i++)vectors.push({A:next(),B:next(),C:next(),D:next(),E:next()});
for(const example of examples)test(`comparison sequences implement ${example.label} at 32 bits`,()=>{
 for(const input of vectors){const value=expected(example.id,input);assert.equal(rv(example.rv,input),value,JSON.stringify(input));assert.equal(tomato(example.tomato,input),value,JSON.stringify(input));}
});
test('comparison includes ties, RV32I advantage, two-step Tomato work and a zero baseline',()=>{
 assert.ok(examples.some(e=>e.rv.length===e.tomato.length));
 assert.ok(examples.some(e=>e.rv.length<e.tomato.length));
 assert.ok(examples.some(e=>e.tomato.length===2&&e.rv.length===8));
 const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
 for(const row of examples)assert.ok(html.includes(`data-comparison="${row.id}"`));
 assert.match(html,/<text[^>]*y="299"[^>]*>0<\/text>/);
});
