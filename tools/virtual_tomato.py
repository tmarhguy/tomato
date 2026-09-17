#!/usr/bin/env python3
"""Interactive Tomato RTL simulator. Local-only browser UI; no FPGA required."""
import argparse
import json
from pathlib import Path
import re
import secrets
import subprocess
import threading
from collections import deque
from remote_compile import compile_job, CompileError, interpret
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT=Path(__file__).resolve().parents[1]
CORE=ROOT/"hardware/fpga/core"
BINARY=CORE/"sim/virtual_obj/Vvirtual_tomato"

def build():
    subprocess.run(["make","tb/mem/tomato_os.mem"],cwd=CORE,check=True)
    sources=list((CORE/"rtl").glob("*.v"))+[CORE/"tb/virtual_tomato.v",ROOT/"tools/virtual_tomato.cpp"]
    sources+=list((CORE/"rtl/burn").glob("mc_*.vh"))
    if not BINARY.exists() or any(p.stat().st_mtime>BINARY.stat().st_mtime for p in sources):
        log=CORE/"sim/virtual-build.log"
        cmd=["verilator","--cc","--exe","--build","-j","4","-Wno-fatal","-DTOMATO_SIM",
             "-Irtl","--top-module","virtual_tomato","--Mdir","sim/virtual_obj","-CFLAGS","-O2"]
        cmd += [str(p.relative_to(CORE)) for p in (CORE/"rtl").glob("*.v")]
        cmd += ["tb/virtual_tomato.v",str(ROOT/"tools/virtual_tomato.cpp")]
        print("Compiling CPU simulation (cached for future runs)...",flush=True)
        with log.open("w") as f:
            result=subprocess.run(cmd,cwd=CORE,stdout=f,stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(f"Verilator build failed; see {log}")
    # OS RAM is loaded at runtime: assembly changes never require RTL compilation.

def assets():
    board=CORE/"rtl/board"
    font=[0]*2048
    for a,b in re.findall(r"mem\[11'h([0-9A-F]+)\] = 8'h([0-9A-F]+)",(board/"font_rom.v").read_text()):
        font[int(a,16)]=int(b,16)
    palette=[None]*16
    pattern=r"(4'h[0-9A-Fa-f]|default): begin pr = 4'h([0-9A-Fa-f]); pg = 4'h([0-9A-Fa-f]); pb = 4'h([0-9A-Fa-f]);"
    for i,r,g,b in re.findall(pattern,(board/"videoout.v").read_text()):
        palette[15 if i=="default" else int(i[3:],16)]=[int(v,16)*17 for v in (r,g,b)]
    if any(p is None for p in palette):raise ValueError("FPGA palette format changed")
    paper=[int(v,16) for v in (board/"wallpaper.mem").read_text().split()]
    assert len(paper)==320*240
    return {"font":font,"palette":palette,"paper":paper}

class Machine:
    def __init__(self):
        self.lock=threading.Lock()
        self.history=deque(maxlen=100)
        self.proc=subprocess.Popen([str(BINARY)],cwd=CORE,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        threading.Thread(target=self.read_replies,daemon=True).start()
        self.last=self.step("boot")
    def read_replies(self):
        for line in self.proc.stderr:
            if not line.startswith(b'TX '): continue
            _,route,kind,payload=line.decode().split()
            data=bytes.fromhex(payload)
            if kind=='8': text=data[4:].decode('ascii',errors='replace')
            elif len(data)==9:
                errors={1:'INVALID_OPCODE',2:'PROGRAM_TOO_LONG',3:'REGISTER_RANGE',4:'MEMORY_RANGE',5:'MISSING_RETURN',6:'UNSUPPORTED_RAW_LUT',7:'MALFORMED_PROGRAM'}
                v=int.from_bytes(data[5:9],'big')
                text=('ERR '+errors.get(data[4],'UNKNOWN')) if data[4] else f'Result: {v} / 0x{v:08X} (Tomato RTL simulation)'
            else: continue
            self.history.append({'from':'Tomato','route':int(route),'text':text,'type':int(kind)})
    def step(self,command):
        with self.lock:
            self.proc.stdin.write((command+"\n").encode("ascii"));self.proc.stdin.flush()
            result=bytearray()
            while len(result)<19208:
                part=self.proc.stdout.read(19208-len(result))
                if not part:raise RuntimeError("RTL simulator stopped")
                result.extend(part)
            if result[:4]!=b"TOM1":raise RuntimeError("Invalid simulator output")
            self.last=bytes(result)
            return self.last
    def close(self):
        if self.proc.poll() is None:
            self.proc.stdin.write(b"quit\n");self.proc.stdin.flush()
            self.proc.wait(timeout=5)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port",type=int,default=8766)
    args=ap.parse_args()
    build()
    machine=Machine()
    token=secrets.token_urlsafe(24)
    allowed_hosts={f"127.0.0.1:{args.port}",f"localhost:{args.port}"}
    allowed_origins={f"http://127.0.0.1:{args.port}",f"http://localhost:{args.port}"}
    static=(ROOT/"tools/virtual_tomato.html").read_text().replace("__TOKEN__",token).encode()
    data=json.dumps(assets()).encode()
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args):pass
        def reply(self,status,body,kind):
            self.send_response(status);self.send_header("Content-Type",kind)
            self.send_header("Content-Length",str(len(body)))
            self.send_header("Cache-Control","no-store")
            self.send_header("X-Content-Type-Options","nosniff")
            self.end_headers();self.wfile.write(body)
        def trusted_request(self):
            host=self.headers.get("Host","").lower()
            origin=self.headers.get("Origin")
            return host in allowed_hosts and (origin is None or origin in allowed_origins)
        def request_json(self):
            size=int(self.headers.get("Content-Length","0"))
            if size<1 or size>4096:raise ValueError("Invalid request size")
            return json.loads(self.rfile.read(size))
        def do_GET(self):
            if not self.trusted_request():
                self.reply(403,b"Forbidden","text/plain");return
            if self.path=="/":self.reply(200,static,"text/html; charset=utf-8")
            elif self.path=="/assets":self.reply(200,data,"application/json")
            elif self.path=="/frame":self.reply(200,machine.last,"application/octet-stream")
            elif self.path=="/chat":self.reply(200,json.dumps(list(machine.history)).encode(),"application/json")
            elif self.path=="/session":
                self.reply(200,json.dumps({"token":token}).encode(),"application/json")
            else:self.reply(404,b"Not found","text/plain")
        def do_POST(self):
            if not self.trusted_request() or not secrets.compare_digest(
                    self.headers.get("X-Tomato-Token",""),token):
                self.reply(403,b"Forbidden","text/plain");return
            if self.path in ("/interpret","/execute"):
                runner=None
                try:
                    plan=interpret(self.request_json()["text"])
                    if self.path=="/interpret":
                        self.reply(200,json.dumps(plan).encode(),"application/json");return
                    if not plan["job"]:raise CompileError("ERR COMPUTE_REQUIRED")
                    runner=Machine()
                    runner.step("reset")
                    runner.step("key 30")
                    runner.step("key 13")
                    runner.step("demo")
                    for _ in range(220):runner.step("tick")
                    before=len(runner.history)
                    runner.step(f"job 1 {plan['job']}")
                    replies=[]
                    for _ in range(80):
                        runner.step("tick")
                        replies=list(runner.history)[before:]
                        if any(x["type"]==33 for x in replies):break
                    if not any(x["type"]==33 for x in replies):
                        raise RuntimeError("RTL result timeout")
                    result={**plan,"target":"Tomato RTL simulation","replies":replies}
                    self.reply(200,json.dumps(result).encode(),"application/json")
                except CompileError as e:self.reply(400,str(e).encode(),"text/plain")
                except (ValueError,KeyError,TypeError) as e:self.reply(400,str(e).encode(),"text/plain")
                except (RuntimeError,BrokenPipeError) as e:self.reply(500,str(e).encode(),"text/plain")
                finally:
                    if runner is not None:runner.close()
                return
            if self.path!="/step":
                self.reply(404,b"Not found","text/plain");return
            try:
                request=self.request_json()
                cmd=request["command"]
                allowed={"tick","boot","reset","demo","disconnect"}
                if cmd=="key":
                    code=int(request["key"])
                    if code not in (30,31,17,16,13):raise ValueError("Invalid key")
                    cmd=f"key {code}"
                elif cmd=="contact":
                    route=int(request.get("route",4));name=request["name"]
                    if not 1<=route<=8 or not 1<=len(name)<=32 or any(not 32<=ord(c)<=126 for c in name):
                        raise ValueError("Contact requires route 1-8 and 1-32 ASCII characters")
                    cmd=f"contact {route} {name}"
                elif cmd=="message":
                    route=int(request.get("route",1));text=request["text"]
                    if route not in (1,2,3):raise ValueError("Unknown route")
                    if text.startswith('/') and text.strip()!='/help':
                        machine.history.append({'from':'You','route':route,'text':text})
                        try: cmd=f"job {route} {compile_job(text).hex()}"
                        except CompileError as e:
                            machine.history.append({'from':'Compiler','route':route,'text':str(e)})
                            self.reply(200,machine.last,"application/octet-stream");return
                    elif not 1<=len(text)<=256 or any(not 32<=ord(c)<=126 for c in text):
                        raise ValueError("Use 1-256 printable ASCII characters")
                    else:
                        machine.history.append({'from':'You','route':route,'text':text})
                        cmd=f"message {route} {text}"
                elif cmd not in allowed:raise ValueError("Invalid command")
                result=machine.step(cmd)
                self.reply(200,result,"application/octet-stream")
            except (ValueError,KeyError,TypeError) as e:self.reply(400,str(e).encode(),"text/plain")
            except (RuntimeError,BrokenPipeError) as e:self.reply(500,str(e).encode(),"text/plain")
    server=ThreadingHTTPServer(("127.0.0.1",args.port),Handler)
    print(f"Tomato virtual FPGA: http://127.0.0.1:{args.port}",flush=True)
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:server.server_close();machine.close()
if __name__=="__main__":main()
