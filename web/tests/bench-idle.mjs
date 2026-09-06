import test from 'node:test';
import assert from 'node:assert/strict';
import { createBenchIdle } from '../js/bench-idle.js';
function clock(delayMs = 15000) {
  let now=0, next=0, resets=0;
  const timers=new Map();
  const idle=createBenchIdle({delayMs,onIdle:()=>resets++,setTimer:(fn,delay)=>{const id=++next;timers.set(id,{fn,at:now+delay});return id;},clearTimer:id=>timers.delete(id)});
  return {idle,get resets(){return resets;},advance(ms){now+=ms;for(const [id,t] of [...timers]) if(t.at<=now){timers.delete(id);t.fn();}}};
}
test('board resumes only after 15 seconds of actual inactivity',()=>{
  const c=clock();c.idle.activity();c.advance(14000);assert.equal(c.resets,0);
  c.idle.activity();c.advance(14000);assert.equal(c.resets,0);c.advance(1000);assert.equal(c.resets,1);
  c.advance(30000);assert.equal(c.resets,1);
});
test('held drags defer reset until 15 seconds after release',()=>{
  const c=clock();c.idle.activity();c.idle.begin();c.advance(30000);assert.equal(c.resets,0);
  c.idle.end();c.advance(15000);assert.equal(c.resets,1);
});
test('pause, invisibility, reduced motion and disposal suppress idle resets',()=>{
  const c=clock();c.idle.activity();c.idle.hold(true);c.advance(30000);assert.equal(c.resets,0);
  c.idle.hold(false);c.idle.setActive(false);c.advance(30000);assert.equal(c.resets,0);
  c.idle.setActive(true);c.advance(15000);assert.equal(c.resets,1);
  c.idle.activity();c.idle.dispose();c.advance(30000);assert.equal(c.resets,1);
  const reduced=clock(0);reduced.idle.activity();reduced.advance(30000);assert.equal(reduced.resets,0);
});
