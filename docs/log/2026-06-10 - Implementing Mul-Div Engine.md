Today's goal is integrating the multiply-divide engine. I am considering a few ideas. 74xx284/85 can compute the lower and upper products, so I will use them and sequence to compute 32b by 32b -> 64b in 4 cycles at most. That cleanly resolves Multiply. The immediate decoder means that the multiply has access to all the different immediate variants that most ISAs have.

The divide is tricky (generally), I am considering Newton-Raphson. for approximation and refinement. Other options are if there's a way to find 1/b after which I can simply reuse the multiply block to divide. Another option is if I had a "magic number", computed at assembly, but that defeats the purpose of live divide.

If in the case I use a lookup table, luckily, the ALU + micro opcode is a powerful LUT which I can take advantage of to divide. I will explore the most efficient algorithm and reuse components as much as possible.

There is a barrel shifter which could be used in a naïve sub and conditional shift, but that will take an eternity from a CPU perspective. By EOD, I will resolve and settle for one, tentatively.