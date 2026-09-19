`timescale 1ns/1ps
module nrf8001_aci_tb;
 reg clk=0,reset=1,wr=0,rdy_n=1,miso=0;
 reg [6:0] addr=0;
 reg [7:0] wdata=0;
 wire [31:0] rdata;
 wire rst_n,req_n,sck,mosi;
 reg [7:0] reply[0:32],captured[0:32];
 integer i,j;
 always #5 clk=~clk;
 nrf8001_aci #(.RESET_CYCLES(4),.SETTLE_CYCLES(4),
   .TIMEOUT_CYCLES(400),.HALF_CYCLES(4)) dut(.*);
 task write_reg;
  input [6:0] a; input [7:0] d;
  begin @(negedge clk);addr=a;wdata=d;wr=1;
   @(negedge clk);wr=0;addr=0;end
 endtask
 task slave;
  input integer bytes;
  integer b,k;
  begin
   wait(!req_n);
   @(negedge clk);rdy_n=0;
   for(b=0;b<bytes;b=b+1) begin
    captured[b]=0;
    for(k=0;k<8;k=k+1) begin
     miso=reply[b][k];
     @(posedge sck); captured[b][k]=mosi;
     @(negedge sck);
    end
   end
   if(!req_n) $fatal(1,"transaction did not stop at expected length");
   @(negedge clk);rdy_n=1;
   wait(dut.done);
  end
 endtask
 initial begin
  for(i=0;i<33;i=i+1) reply[i]=0;
  repeat(2) @(negedge clk);
  if(rst_n || !req_n || sck) $fatal(1,"reset levels");
  reset=0;
  wait(!dut.busy);
  write_reg(32,8'ha5);write_reg(33,8'h31);write_reg(1,2);
  reply[0]=8'hff;reply[1]=4;reply[2]=8'h81;reply[3]=2;reply[4]=0;reply[5]=3;
  fork write_reg(0,1);slave(6); join
  if(captured[0]!==2 || captured[1]!==8'ha5 || captured[2]!==8'h31 || captured[3]!==0)
   $fatal(1,"LSB-first command or zero padding wrong %h %h %h",captured[0],captured[1],captured[2]);
  if(dut.evt_len!==4 || dut.evt[0]!==8'h81 || dut.evt[3]!==3) $fatal(1,"event unpack");
  // Command dominates length, maximum host command.
  write_reg(0,2);write_reg(1,31);
  for(i=0;i<31;i=i+1) write_reg(32+i,i+1);
  for(i=0;i<33;i=i+1) reply[i]=0;
  fork write_reg(0,1);slave(32); join
  for(i=1;i<32;i=i+1) if(captured[i]!==i) $fatal(1,"long command index %d",i);
  // Event dominates length: 31 event bytes means 33 wire bytes.
  write_reg(0,2);write_reg(1,0);
  reply[1]=31;
  for(i=2;i<33;i=i+1) reply[i]=i+64;
  fork write_reg(0,1);slave(33); join
  if(dut.evt_len!==31 || dut.evt[30]!==96) $fatal(1,"max event lost last byte");
  // Missing RDY times out without clocking anything, releases REQ.
  write_reg(0,2);write_reg(0,1);
  wait(dut.done);
  if(!dut.fault || !req_n || sck || mosi) $fatal(1,"RDY timeout");
  write_reg(0,4);
  @(negedge clk);
  if(rst_n || dut.fault) $fatal(1,"soft reset");
  $display("PASS: nrf8001 ACI LSB-first SPI, bidirectional lengths, padding, timeout, reset");
  $finish;
 end
 initial begin #500000; $fatal(1,"test timeout");end
endmodule

