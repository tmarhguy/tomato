#!/usr/bin/env python3
"""Independent Python packet oracle driving the real RMII RTL via Icarus."""
import pathlib, struct, subprocess, tempfile, zlib
HW = pathlib.Path(__file__).resolve().parents[1]
MAC = bytes.fromhex('02544f4d4154'); HOST = bytes.fromhex('02aabbccddee')
IP = bytes([192,168,1,10]); PEER = bytes([192,168,1,20])
def checksum(b):
    b += b'\0' * (len(b) % 2)
    n = sum(struct.unpack('!%dH' % (len(b)//2), b))
    while n >> 16: n = (n & 65535) + (n >> 16)
    return (~n) & 65535

def packet(payload, checked=True):
    udp = struct.pack('!HHHH',1234,5000,len(payload)+8,0)+payload
    if checked:
        c = checksum(PEER+IP+b'\0\x11'+struct.pack('!H',len(udp))+udp) or 65535
        udp = udp[:6]+struct.pack('!H',c)+udp[8:]
    ip = struct.pack('!BBHHHBBH4s4s',0x45,0,20+len(udp),0x1234,0x4000,64,17,0,PEER,IP)
    ip = ip[:10]+struct.pack('!H',checksum(ip))+ip[12:]
    return bytearray((MAC+HOST+b'\x08\0'+ip+udp).ljust(60,b'\0'))

def main():
    vectors=[]
    # 522 carries the complete PG/v1 maximum: 512-byte application payload
    # plus its 10-byte envelope in one UDP datagram.
    for n in (0,1,2,9,100,256,511,512,522):
        payload=bytes((i*73+n)%256 for i in range(n))
        vectors.append((f'valid-{n}',packet(payload),payload))
    vectors.append(('checksum-disabled',packet(b'hello',False),b'hello'))
    for name,offset,value,fix in [('bad-ip-checksum',24,1,False),('bad-udp-checksum',40,1,False),('fragment',20,0x20,True),('reserved-fragment',20,0x80,True),('wrong-ip',33,1,True),('wrong-mac',0,1,False),('udp-length',39,1,False),('ip-length',17,1,True)]:
        p=packet(b'hello'); p[offset]^=value
        if fix: p[24:26]=b'\0\0';p[24:26]=struct.pack('!H',checksum(bytes(p[14:34])))
        vectors.append((name,p,None))
    vectors.append(('oversize',packet(bytes(523)),None))
    vectors.append(('truncated',packet(bytes(100))[:60],None))
    with tempfile.TemporaryDirectory(prefix='tomato-lan-test-') as tmp:
        tmp=pathlib.Path(tmp)
        source=(HW/'tb/echo_tb.v').read_text().split('    initial begin')[0].replace("28'd50000","28'd250000000")
        source+='\n integer out; initial begin\n repeat(4) @(negedge clk); reset=0; enable=1; repeat(10) @(negedge clk);\n'
        for i,(name,p,expected) in enumerate(vectors):
            (tmp/f'{i}.hex').write_text('\n'.join(f'{b:02x}' for b in p))
            source+=f'$readmemh("{tmp}/{i}.hex",txpkt,0,{len(p)-1}); txlen={len(p)};\n'
            source+='fork send_frame(0); expect_tx(14000,gotit); join\n'
            source+=f'if (gotit != {int(expected is not None)}) $fatal(1,"{name}: wrong response");\n'
            if expected is not None:
                source+=f'out=$fopen("{tmp}/{i}.out","w"); for(a=0;a<rxlen;a=a+1) $fwrite(out,"%02x",rxpkt[a]); $fclose(out);\n'
            source+='wait(!tx_busy); repeat(64) @(negedge clk);\n'
        source+='$finish; end initial begin #100000000; $fatal(1,"watchdog"); end endmodule\n'
        (tmp/'test.v').write_text(source)
        subprocess.run(['iverilog','-g2012','-s','echo_tb','-o',str(tmp/'sim'),str(tmp/'test.v'),*[str(HW/'rtl'/f) for f in ('lan_min.v','rmii_tx.v','rmii_rx.v')]],check=True)
        subprocess.run(['vvp','-n',str(tmp/'sim')],check=True,stdout=subprocess.DEVNULL,timeout=20)
        for i,(name,p,expected) in enumerate(vectors):
            if expected is not None:
                raw=bytes.fromhex((tmp/f'{i}.out').read_text())
                assert struct.unpack('<I',raw[-4:])[0]==zlib.crc32(raw[:-4]),name+' FCS'
                assert raw[:12]==HOST+MAC,name+' MAC'
                assert checksum(raw[14:34])==0,name+' IP checksum'
                assert raw[26:34]==IP+PEER,name+' IP addresses'
                assert struct.unpack('!HHH',raw[34:40])==(5000,1234,len(expected)+8),name+' ports/length'
                assert raw[42:42+len(expected)]==expected,name+' payload'
                assert len(raw)==max(60,42+len(expected))+4,name+' frame length'
            print('PASS',name)
    print(f'PASS {len(vectors)} independent packet cases; actual RTL RX -> TX -> Python decode')
if __name__=='__main__': main()
