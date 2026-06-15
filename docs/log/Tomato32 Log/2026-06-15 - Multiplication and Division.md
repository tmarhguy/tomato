One of the biggest hurdles in this build has been implementing hardware multiplication and division. The standard naive approach—sequencing operations to `shift -> add -> accumulate` (or `shift -> subtract` for division)—is functionally easy but architecturally painful.

**The Pros:** It reuses the existing ALU and shifter, which is fantastic news for fabrication and routing.

**The Challenges:** It takes forever! A naïve `shift -> add` loop clocks in at roughly 32 cycles. At that speed, the computer is slower at multiplying than I am when I’m half-asleep!

#### The Proposition: Priority Encoder & Feedback Loop

To solve this, I’m moving away from naïve sequencing toward a high-speed, sparse-math architecture.

1. **The Setup:** The ALU compares both inputs. We load the **smallest number** into the multiplier register (the one feeding the Priority Encoder) and the largest into the multiplicand register.
    
2. **The Jump:** The Priority Encoder instantly identifies the lowest significant bit (the first `1`). It directs the barrel shifter to shift the multiplicand by that bit-index—essentially performing a $2^n$ multiplication in a single cycle.
    
3. **The Feedback Loop:** Since the encoder is purely combinational and has no memory, I’ve added a 16-bit feedback loop. An adder subtracts the last shifted value from the multiplier, "clearing" the bit we just processed. This updated value is latched and fed back into the encoder for the next cycle.
    

#### The Advantages

- **Space Efficiency:** A classic hardware-heavy Wallace Tree or Array Multiplier would take more space than the entire core ALU itself, introducing hundreds of components for a speed gain I don’t actually need.
    
- **Amortized Complexity:** By using the Priority Encoder to "jump" over zeros, the performance is $O(1)$ in the best case and $O(16)$ in the absolute worst case—all without a mountain of extra gates.
    
- **Dual-Purpose Logic:** I can tune this same architecture to divide using the same `shift -> conditionally subtract` rhythm. This means Tomato32 can multiply and divide with incredible efficiency—averaging under 5–10 cycles—without ever needing a 60+ cycle loop or a hundred extra chips.
    

#### The Cons

Honestly? This is the most efficient design I can conceive for this build. If new ideas hit, I’ll pivot, but for now, the math is solid. It just makes sense.

**Next Steps:** Test the full loop in _Digital_ simulation. I need to verify the timing and latching before I commit to the physical build.