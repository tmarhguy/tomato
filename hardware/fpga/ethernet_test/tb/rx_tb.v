`timescale 1ns/1ps
module rx_tb;
reg clk=0;always #10 clk=~clk;
reg reset=1,enable=1,dv=0,err=0;reg[1:0]d=0;
wire [31:0] good,bad,activity;wire[15:0] etype,len;
rmii_rx dut(clk,reset,enable,dv,d,err,good,bad,activity,etype,len);
reg[7:0]packet[0:63];integer i,j;
task dibit(input [1:0]value,input valid);begin @(negedge clk);d=value;dv=valid;end endtask
task send_frame(input corrupt,input tail,input error);reg[7:0]b;begin
 for(i=0;i<7;i=i+1)for(j=0;j<4;j=j+1)dibit(1,1);
 for(j=0;j<4;j=j+1)dibit((8'hd5>>(j*2))&3,1);
 for(i=0;i<64;i=i+1)begin
  b=packet[i];if(corrupt&&i==30)b=b^1;
  for(j=0;j<4;j=j+1)begin dibit((b>>(j*2))&3,(tail&&i>60)?j[0]:1);err=error&&i==30;end
 end
 dibit(0,0);err=0;dibit(0,0);repeat(4)@(negedge clk);
end endtask
initial begin
packet[0]=8'hff;
packet[1]=8'hff;
packet[2]=8'hff;
packet[3]=8'hff;
packet[4]=8'hff;
packet[5]=8'hff;
packet[6]=8'h02;
packet[7]=8'h00;
packet[8]=8'h00;
packet[9]=8'h00;
packet[10]=8'h00;
packet[11]=8'h01;
packet[12]=8'h08;
packet[13]=8'h06;
packet[14]=8'h00;
packet[15]=8'h01;
packet[16]=8'h02;
packet[17]=8'h03;
packet[18]=8'h04;
packet[19]=8'h05;
packet[20]=8'h06;
packet[21]=8'h07;
packet[22]=8'h08;
packet[23]=8'h09;
packet[24]=8'h0a;
packet[25]=8'h0b;
packet[26]=8'h0c;
packet[27]=8'h0d;
packet[28]=8'h0e;
packet[29]=8'h0f;
packet[30]=8'h10;
packet[31]=8'h11;
packet[32]=8'h12;
packet[33]=8'h13;
packet[34]=8'h14;
packet[35]=8'h15;
packet[36]=8'h16;
packet[37]=8'h17;
packet[38]=8'h18;
packet[39]=8'h19;
packet[40]=8'h1a;
packet[41]=8'h1b;
packet[42]=8'h1c;
packet[43]=8'h1d;
packet[44]=8'h1e;
packet[45]=8'h1f;
packet[46]=8'h20;
packet[47]=8'h21;
packet[48]=8'h22;
packet[49]=8'h23;
packet[50]=8'h24;
packet[51]=8'h25;
packet[52]=8'h26;
packet[53]=8'h27;
packet[54]=8'h28;
packet[55]=8'h29;
packet[56]=8'h2a;
packet[57]=8'h2b;
packet[58]=8'h2c;
packet[59]=8'h2d;
packet[60]=8'h01;
packet[61]=8'h84;
packet[62]=8'h31;
packet[63]=8'h2b;
repeat(4)@(negedge clk);reset=0;
send_frame(0,0,0);if(good!=1||etype!=16'h0806||len!=64)$fatal(1,"valid CRC frame failed");
send_frame(0,1,0);if(good!=2)$fatal(1,"CRS_DV alternating tail failed");
send_frame(1,0,0);if(good!=2||bad!=1)$fatal(1,"bad CRC accepted");
send_frame(0,0,1);if(good!=2||bad!=2)$fatal(1,"RXERR accepted");
enable=0;send_frame(0,0,0);if(good!=2)$fatal(1,"disabled receiver accepted frame");
$display("PASS RMII: CRC, Ethernet type/length, CRS_DV tail, corrupt frame, RXERR, disable");$finish;
end
endmodule
