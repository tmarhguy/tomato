In the current design, the individual cells of tomato may not seem to undergo reprogramming for each operation, given the philosophy it was based off of: what if computers had the flexibility of an FPGA but without the rigidity of programming for every other operation?

I have considered a latched behaviour for the ALU. This means that each of the opcodes that enters the lut3s will have an 8bit latch, and an additional MSB enable/disable use.

The implication is that if my current operation is ADD, assuming I don't explicitly run a new operation, the ALU will remain a full adder. (MSB) (OPCODE16). I therefore assert an instruction and get the results normally as intended, but if the next operations are still ADD, I only need to pass in the next operands from the register files.

This latch behaviour is importantly a step towards a future version that intrigues me, truly taking advantage of the slices proposed here, where there would be a dedicated latch for each lut3, and the decoder is meant enable/disable one or more lut3s at a time and latch their operations giving FPGA like behaviour without moving away from the original premise of flexibility in computing.

For this current design, I will latch only the 16b global opcode truth table, offering stability for setup and hold or simply put, ensuring operational completeness without a truth table "blackout" while the cells are still resolving a result.