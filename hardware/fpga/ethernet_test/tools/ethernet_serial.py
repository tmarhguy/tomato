#!/usr/bin/env python3
"""Read Ethernet diagnostic status, without transmitting to the board."""
import argparse,time,serial
p=argparse.ArgumentParser();p.add_argument('--port',default='/dev/cu.usbserial-210292C0AF6F1');p.add_argument('--seconds',type=float,default=15);a=p.parse_args()
with serial.Serial(a.port,115200,timeout=1) as s:
 end=time.monotonic()+a.seconds
 while time.monotonic()<end:
  line=s.readline().decode('ascii',errors='replace').strip()
  if line:print(line,flush=True)
