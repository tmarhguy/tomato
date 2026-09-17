`timescale 1ns/1ps
module mdio_tb;
reg clk=0;always #10 clk=~clk;
reg reset=1;wire mdc;tri1 mdio;
wire[15:0]id1,id2,bmsr,special;wire present;
mdio_probe dut(clk,reset,mdc,mdio,id1,id2,bmsr,special,present);
integer bit_index=0;reg[13:0]header=0;reg[15:0]data=0;reg drive=0,out=1;
assign mdio=drive?out:1'bz;
always @(posedge mdc)begin
 if(bit_index>=32 && bit_index<=45)header={header[12:0],mdio};
 if(bit_index==45)begin
  if(header[13:5]!==9'b011000001)$fatal(1,"wrong read header/PHY address %b",header);
  case(header[4:0])2:data=16'h0007;3:data=16'hc0f1;1:data=16'h782d;31:data=16'h1058;default:$fatal(1,"bad register");endcase
 end
 bit_index=(bit_index+1)%64;
end
always @(negedge mdc)begin
 drive=bit_index>=47;
 if(bit_index==47)out=0;
 else if(bit_index>=48)out=data[63-bit_index];
end
initial begin repeat(4)@(negedge clk);reset=0;#400000;
 if(!present||id1!=7||id2!=16'hc0f1||bmsr!=16'h782d||special!=16'h1058)$fatal(1,"MDIO registers incorrect %x %x %x %x",id1,id2,bmsr,special);
 $display("PASS MDIO: Clause22 header/address, turnaround, ID and status polling");$finish;end
endmodule
