I’m expanding Tomato’s ISA beyond its current 52 burned opcodes, and one idea keeps becoming more important:

**the lower I go, the more of the machine I can actually see.**

If I understand exactly what the hardware can do in one cycle, I can design algorithms around its natural operations instead of forcing the machine to imitate conventional instruction sets.

That matters on Tomato because the execution unit can evaluate operations of the form $f(a, b, c) + g(a, b, c) + cin$ in **one cycle**.

A compiler—or even a programmer writing ordinary assembly—may see an expression such as an XOR3 combined with some unusual NAND/NOR function and break it into several familiar instructions. Tomato may already be able to perform that entire expression directly.

That exposes an interesting problem: **assembly itself can become an abstraction barrier.**

Assembly languages are built around operations people have already decided are useful enough to name: `ADD`, `XOR`, `AND`, `NOR`, shifts, branches, and so on. There is no natural mnemonic for every strange function Tomato’s datapath can express, nor should there necessarily be.

But if the hardware can perform those functions natively, restricting access to only the operations we already know how to name leaves part of the machine unexplored.

So instead of asking:

> *What instructions should Tomato have?*

I'm curious to know:

> **What is the most direct way to expose the computation the hardware is already capable of?**

If the doors and the keys already exist, why add another locked door between them? That’s the direction I want to explore as the ISA grows.