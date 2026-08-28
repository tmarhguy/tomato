# The Invisible Logic: Driving the Datapath

The catch with designing this board without a Finite State Machine (FSM) is that perhaps only I know how this board works off the top of my head and understand it this intimately.

The job of the FSM was to demonstrate the board crunching numbers—running something cool like the opcode sweep (see the hardware compiler), Fibonacci, or Collatz, among infinite other options.

One solution I'm considering is generating the bit signals for the operands using an external board. I could use an Arduino, an ATmega328PB, a Nexys Artix-A7, or an ESP32.

The requirements are strict: I need at least 8 × 3 (24 parallel signals) for the operands A, B, and C, plus 8 × 2 (16 parallel signals) for the opcodes X and Y. These are just the core pins; others, like the flag write enable, zero in, and carry-in select, may be tied to ground for now. 

In fact, I intentionally designed the carry so that toggling the least significant bit sets it as 0 or 1, provided bit[1] and bit[2] are grounded. This design was made with the intended ripple connection in mind.

The problem with the ESP32 is its 3.3V logic. While 3.3V may be compatible with 5V systems, the voltage drop could introduce garbage logic and make debugging twice as hard.

The general problem with the other boards, especially the Arduino, is the pin count. From a basic count, I need at least 40 pins. That might sound like a lot, but it feels completely justified to me given the enormous 524,288 ALU operations this discrete board can perform.

I have resolved to try this with the ATmega328PB, as I have a few of them on hand and can drive two simultaneously. I can flash and power them together to sync manually. Regardless, the board will run at about 1 Hz or less, meaning every step of the calculation will be extremely visible and deliberate.
