This ALU has taken several routes since the first abstractions. In the most recent version before this change, I wanted to wire 8 cells of 4b each into a 32b cell. The catch is PCB fabrication do not manufacture only one board. To ensure manufacturing efficiency and reusability, I have sliced the board into 16b macro cells that are designed to support full cascading into 16b x n ALUs. So cascading 4 cells results in a 64b logic unit.

I am handling the concept of flag propagation with critical design as internal boards do not need flag registers or overflow generation. Eliminating those unnecessary inner flag logic chips should not constraint the operation of Tomato by any chance.

The current design of propagating zero flags as Zero In and Zero out per cell handles the notorious zero flag. Others remain trivial by their identities. For instance Carry out flag is Sum(n+1) bit and so on.

The additional consequence of this downgrade for upgrade is the board size reduces from the initial squeezed up 240mm by 240mm design to about half of that (true dimensions is yet to be confirmed). I estimated 120mm by 120mm but with extreme reusability of the fabricated boards with no waste.