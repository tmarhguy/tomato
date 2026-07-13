It quickly gets abstracted and perhaps indistinguishable from a black box if the final design has no reasonably impressive demo. I've considered a lot of ideas ranging from moderate to wild ones. There is Fibonacci, Collatz conjecture, all of which are so trivial it makes tomato severely underused.

I am currently considering a final state machine that gives tomato the capacity to program itself. It will compose of a simple counter, subtractor unit, and test case ROM.

Method: Counter asserts test case operands into A, B, C and if the output matches the expected one from the ROM, the zero flag is asserted, which will write enable the opcode ROM burning that instruction to it.

The obvious hurdle is the sheer volume of exhaustiveness for a 64b machine! That's in numbers I can't fully imagine! To simplify, I will take advantage of the sliceable design of tomato. I will run the state on a 4bit slice, with the mathematical guarantee that what works for 4b operands must work for 64b operands but mere induction.

Granted, the opcode was always global and identical, it only makes sense to keep a localized version for smaller finite state machine footprint.

Additionally, the clock speed need a clean balance. Too fast risks flashing LEDs too fast to appreciate, and too slow takes forever to resolve a single opcode out of the intended 1000s. The right balance so not to result in difficulty finalizing, will be determined by a digital clock, one that is adjustable, and digital pulses varying frequency cleanly controlled by a rheostat or adjustable capacity.

This way, I only feed in operands and expected results and the solution if right saves that opcodes. Future thoughts may result in better or augmented demos. (Long bus rides seem to help in ideation :)