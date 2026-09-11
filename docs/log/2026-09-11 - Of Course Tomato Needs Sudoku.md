# Of Course Tomato Needs Sudoku

I have been the biggest fan of Sudoku! In fact, almost always a sudoku puzzle book lies on my table, next to my table, in my bag, or somewhere close enough that stretching my arm would reach it.

<p align="center"><img src="../../web/assets/os/sudoku-book.webp" alt="Sudoku puzzle book on the bench" width="40%" /></p>

So it only makes sense to build **Sudoku into Tomato**.

I hesitated to build it earlier because I genuinely have not had time to finish soldering the microscopic traces of the keyboard matrix onto the FPGA PMOD for extended controls.

Sudoku obviously wants more than four arrow buttons.

But then I noticed I was making the problem larger than it needed to be.

I already have the arrow keys to move around the board. I can simply use another button to **cycle through `1` to `9`**.

Together, that is enough to play Sudoku.

<p align="center"><img src="../../web/assets/os/sudoku-on-tomato.webp" alt="Sudoku on Tomato OS over HDMI" width="70%" /></p>

It is not the final input system I want, and eventually I still want the full keyboard matrix.

But there is no reason the game has to wait for it.

**Sometimes a hardware limitation is not actually a blocker. It just changes the interface.**

<p align="center"><img src="../../web/assets/os/sudoku-book-solved.webp" alt="Solved Sudoku page from the same book" width="40%" /></p>

So, yes. I'm happy to add that Tomato is getting Sudoku.
