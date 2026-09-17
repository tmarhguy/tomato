#!/usr/bin/env python3
"""Live virtual FPGA regression: real boot/key polling plus simulated ACI phone."""
import struct
from virtual_tomato import Machine, build

def main():
    build()
    m=Machine()
    def step(command):
        return struct.unpack("<4802I",m.step(command))[2:]
    def text(words,x,y,n):
        return "".join(chr(w&255) for w in words[y*80+x:y*80+x+n])
    def settle(count):
        for _ in range(count): words=step("tick")
        return words
    fixed = [
        "I reply from a dorm table I call home.",
        "Tyrone Marhguy built me transistor-up!",
        "Try 23 + 19 on my dual-LUT ALU!",
    ]
    def tomato_texts(route, start=0):
        return [x["text"] for x in list(m.history)[start:]
                if x.get("from") == "Tomato" and x.get("route") == route]
    try:
        step("key 30");step("key 13");step("demo")
        words=settle(220)
        assert text(words,2,11,3)=="Ama"
        assert text(words,29,23,5)=="Hello"
        assert tomato_texts(1)==["Hello, Ama! I'm Tomato.", *fixed]
        before=len(m.history)
        long_name="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef"
        step(f"contact 3 {long_name}");settle(12)
        step("message 3 Hello");settle(220)
        assert tomato_texts(3,before)==[
            "Hello, ABCDEFGHIJKLMNOPQRST! I'm Tomato.", *fixed]
        step("contact 4 New friend");words=settle(12)
        assert text(words,2,20,10)=="New friend"
        step("contact 4 Renamed");words=settle(12)
        assert text(words,2,20,7)=="Renamed"
        step("key 13");step("key 13");step("key 16")
        words=settle(30)
        assert text(words,33,32,1)=="a"
        assert text(words,27,50,7)!="Waiting"
        step("key 17");step("key 31");step("key 13")
        step("message 2 Hey")
        before=len(m.history)
        words=settle(220)
        assert text(words,27,7,4)=="Kofi"
        assert tomato_texts(2,before)==["Hello, Kofi! I'm Tomato.", *fixed]
        step("disconnect");words=settle(10)
        assert text(words,52,2,14)=="Bridge offline"
        step("demo");words=settle(220)
        assert text(words,2,11,3)=="Ama"
        # Reconnect clears editing; Left returns to launcher.
        step("key 17");words=settle(3)
        assert text(words,9,54,7)=="Envelop"
        # Wrap to the new second app, then check its keyboard-controlled value.
        step("key 31");step("key 31");step("key 13");words=settle(3)
        assert text(words,8,16,1)=="0"
        step("key 16");words=settle(3)
        assert text(words,8,16,2)=="81"
        step("key 17")
        for _ in range(5):step("key 31")
        step("key 13");words=settle(2)
        assert (words[25*80+50]&255)==0xb3
        assert text(words,33,25,14)=="press to start", "centered start prompt"
        step("key 13");words=settle(2)
        assert (words[25*80+50]&255)==0xb3, "start prompt erased right border"
        step("reset");settle(4)
        step("key 30");step("key 30");step("key 30");step("key 13");words=settle(3)
        assert words[15*80+12]==12 and words[30*80+36]==14, "two staggered traffic cars"
        assert words[42*80+28]==11, "player starts in center of five lanes"
        step("key 16");step("key 16");words=settle(1)
        assert words[42*80+44]==11, "fifth lane reachable"
        step("key 16");words=settle(1)
        assert words[42*80+44]==11, "right road bound"
        print("PASS: virtual FPGA boot, keys, demo handshake, bounded personalized greeting sequence, contacts, send/ACK, reconnect, launcher")
    finally:
        m.close()
if __name__=="__main__":main()
