#!/usr/bin/env python3
"""Execute compiler output on actual Tomato RTL; no host-calculated execution."""
import struct,time,random
from virtual_tomato import Machine,build
from remote_compile import compile_job,CompileError,interpret

def main():
 build();m=Machine()
 def tick(n=50):
  for _ in range(n):last=m.step('tick')
  time.sleep(.01)
  return struct.unpack('<4802I',last)[2:]
 def wait_chat(marker,count,cap=280):
  for _ in range(cap):
   history=list(m.history)
   start=next((i+1 for i,x in enumerate(history) if x is marker),0)
   lines=[x['text'] for x in history[start:] if x.get('type')==8]
   if len(lines)>=count:return lines
   m.step('tick')
  time.sleep(.05)
  history=list(m.history)
  start=next((i+1 for i,x in enumerate(history) if x is marker),0)
  return [x['text'] for x in history[start:] if x.get('type')==8]
 def job(src,expected=None,error=None,raw=None):
  before=m.history[-1] if m.history else None
  m.step('job 1 '+(raw if raw is not None else compile_job(src)).hex())
  words=tick()
  history=list(m.history)
  start=next((i+1 for i,x in enumerate(history) if x is before),0)
  got=[x for x in history[start:] if x.get('type')==33]
  assert got, ('no reply',src,list(m.history))
  text=got[-1]['text']
  if error: assert error in text,(src,text,error)
  else:
   assert f'0x{expected:08X}' in text,(src,text,expected)
   screen=''.join(chr(w&255) for w in words[32*80+33:32*80+51])
   assert f'{expected:08X}' in screen,(src,screen)
  print('PASS',src or raw.hex(),text)
 try:
  m.step('key 30');m.step('key 13');m.step('demo');tick(220)
  greeting=[x['text'] for x in m.history if x.get('type')==8 and x.get('route')==1]
  assert greeting==["Hello, Ama! I'm Tomato.",
                    "I reply from a dorm table I call home.",
                    "Tyrone Marhguy built me transistor-up!",
                    "Try 23 + 19 on my dual-LUT ALU!"],greeting
  for source,expected in [('What is (57 + 19) AND 0x3F?',12),('what is 5 plus 7?',12),('what is 783 + and(45, 34)?',815),('and(45, 34)',32),('what is and(or(1, 2), 3)?',3),('what is 5 plus and(1, 2)?',5),('what is 89 + and(34, 84) on tomato?',89),('/calc ~0',0xffffffff),('45 & 19',1),('and(83, 456, 34)',0),('nand(45, 34, 3)',0xffffffff),('and(83, 456, 34) + nand(45, 34, 3)',0xffffffff),('plus(1, 2, 3, 4)',10),('minus(10, 3, 2)',5),('nor(6, 3)',0xfffffff8),('or(1,2,3) + xor(4,5,6) + plus(7,8)',25),('89 + 90',179),('xnor(5, 3)',0xfffffff9),('what is not(5)?',0xfffffffa),('andn(6, 3)',4),('orn(6, 3)',0xfffffffe),('maskadd(1, 2, 3)',3),('andadd(1, 2, 3)',3),('oradd(1, 2, 3)',6),('xoradd(1, 2, 3)',6),('xorand(1, 2, 3)',0),('what is xnor(1, 2, 3) + not(4)?',0xfffffffa),('maskadd(1,2,3)+xorand(4,5,6)',14)]:
    parsed=interpret(source);job(parsed['canonical'],expected)
  for src in ['what is and(1)?','what is nand(7)?','what is and(1, 2, 3, 4, 5, 6, 7, 8, 9)?','what is not(1, 2)?','what is andn(1)?','what is maskadd(1, 2)?','what is xorand(1, 2, 3, 4)?']:
    try:interpret(src)
    except CompileError as e:assert 'FN_ARITY' in str(e),(src,e)
    else:raise AssertionError(src)
  import json as _json,os as _os
  fix=_json.load(open(_os.path.join(_os.path.dirname(__file__),'nl_fixtures.json')))
  assert fix['version']==7
  for c in fix['compute']:
    r=interpret(c['input'])
    assert r['kind']=='compute' and r['understood']==c['understood'] and r['canonical']==c['canonical'],(c['input'],r)
    job(r['canonical'],c['expected'])
  for c in fix['chat']:assert interpret(c['input'])['kind']=='chat',c['input']
  for c in fix['errors']:
    try:interpret(c['input'])
    except CompileError as e:assert c['py_error'] in str(e),(c['input'],e)
    else:raise AssertionError(c['input'])
  print('PASS nl_fixtures: controlled language, understood, fail-closed errors')
  job('/calc 23 + 19',42)
  job('/calc 0xFFFFFFFF + 1',0)
  job('/calc -1 - 1',0xfffffffe)
  job('/run R0=0x49; R1=0x0F; AND R2,R0,R1; RETURN R2',9)
  job('/run R0=0x20;R1=15;R2=3;MASKADD R3,R0,R1,R2;STORE [0],R3;LOAD R4,[0];ADD R5,R4,R2;RETURN R5',38)
  job('/run R0=0xDEADBEEF;STORE [37],R0;LOAD R1,[37];RETURN R1',0xdeadbeef)
  job('/run LOAD R1,[37];RETURN R1',0)
  job('/run R0=0b101;R1=3;R2=7;XORAND R3,R0,R1,R2;RETURN R3',2)
  job('/run '+ ';'.join(['R0=7']*31+['RETURN R0']),7)
  job('/run R0=123;STORE [255],R0;LOAD R7,[255];RETURN R7',123)
  job('/run LD R0, 8; RETURN R0',8)
  job('/run LD R0 8; RETURN R0',8)
  job('/run LI R1, 0xFF; RETURN R1',255)
  job('/run CLR R3; RETURN R3',0)
  job('/run R0=42; MOV R1, R0; RETURN R1',42)
  job('/run R0=0xDEADBEEF;ST [37], R0;LD R1, [37];RETURN R1',0xdeadbeef)
  job('/run R0=1;R1=2;R2=3;ANDADD R3,R0,R1,R2;RETURN R3',3)
  job('/run R0=1;R1=2;R2=3;ORADD R3,R0,R1,R2;RETURN R3',6)
  job('/run R0=1;R1=2;R2=3;XORADD R3,R0,R1,R2;RETURN R3',6)
  job('/run R0=6;R1=3;ANDN R2,R0,R1;RETURN R2',4)
  job('/run R0=6;R1=3;ORN R2,R0,R1;RETURN R2',0xfffffffe)
  rng=random.Random(42)
  for op in ('ADD','SUB','AND','OR','XOR','MASKADD','XORAND'):
   for _ in range(2):
    a,b,c=[rng.getrandbits(32) for _ in range(3)]
    expected={'ADD':a+b,'SUB':a-b,'AND':a&b,'OR':a|b,'XOR':a^b,'MASKADD':a+(b&c),'XORAND':(a^b^c)+(a&b&c)}[op]&0xffffffff
    operands='R3,R0,R1,R2' if op in ('MASKADD','XORAND') else 'R3,R0,R1'
    job(f'/run R0={a};R1={b};R2={c};{op} {operands};RETURN R3',expected)
  for src in ['/run LOAD R0,[256];RETURN R0','/run JMP 0','/run R8=2;RETURN R0','/run R0=1','/run RETURN R0;RETURN R0','/calc 1 / 0','/run LUTCFG F=0xAA G=0xCC H=0;RETURN R0']:
   try:compile_job(src)
   except CompileError:pass
   else:raise AssertionError(src)
  job('',error='REGISTER_RANGE',raw=bytes([1,1,8,0,0,0,1,48,0]))
  job('',error='MISSING_RETURN',raw=bytes([1,1,0,0,0,0,1]))
  job('',error='MALFORMED_PROGRAM',raw=bytes([1,48,0,0]))
  job('',error='UNSUPPORTED_RAW_LUT',raw=bytes([1,16,0,0,0,1,48,0]))
  job('',error='INVALID_OPCODE',raw=bytes([1,99,0,0,0,0,48,0]))
  job('',error='PROGRAM_TOO_LONG',raw=bytes([1])+bytes([32,0,0])*32+bytes([48,0]))
  tick(20)
  before=m.history[-1] if m.history else None
  m.step('message 1 nonsense')
  chat_lines=wait_chat(before,1)
  assert chat_lines==['Try /help. I run bounded integer jobs.'],chat_lines
  before=m.history[-1] if m.history else None
  m.step('message 1 /help')
  chat_lines=wait_chat(before,2)
  assert chat_lines==['/calc 23 + 19; /help for quick tips',
                      '/run: R0=42; RETURN R0. 32 ops max.'],chat_lines
  print('PASS: bounded runtime, native ALU, private memory, validation, chat help')
 finally:m.close()
if __name__=='__main__':main()
