`timescale 1ns/1ps
module arp_next_hop_tb;
 reg clk=0; always #10 clk=~clk;
 reg reset=1,link=1,request=0,accepted=0,rv=0;
 reg [31:0] dip=0,sip=0,tip=32'h0a0000fa;
 reg [47:0] smac=48'h02aabbccddee,tmac=48'h02544f4d4154,esrc=48'h02aabbccddee;
 reg [5:0] idx=0; wire [7:0] data;
 wire busy,resolved,failed,sendarp;wire [31:0] hop;wire [47:0] mac;
 arp_next_hop #(.TIMEOUT(100),.CACHE_TTL(1000)) dut(clk,reset,link,request,dip,busy,resolved,failed,hop,mac,sendarp,accepted,idx,data,rv,sip,tip,smac,tmac,esrc);
 task tick;begin @(negedge clk);end endtask
 task start(input [31:0] target);begin dip=target;request=1;tick;request=0;tick;end endtask
 task accept;begin accepted=1;tick;accepted=0;tick;end endtask
 task reply(input [31:0] sender);begin sip=sender;rv=1;tick;rv=0;tick;end endtask
 integer i,n;
 initial begin
  tick;reset=0;tick;
  start(32'h08080808);
  if(hop!==32'h0a000001 || !sendarp) $fatal(1,"off-subnet must ARP gateway");
  for(i=0;i<42;i=i+1) begin idx=i;#1;$write("%02x",data);end
  $display("");
  accept;
  reply(32'h08080808);if(resolved) $fatal(1,"accepted remote IP ARP");
  tmac=0;reply(32'h0a000001);if(resolved) $fatal(1,"accepted wrong target MAC");tmac=48'h02544f4d4154;
  esrc=0;reply(32'h0a000001);if(resolved) $fatal(1,"accepted mismatched source");esrc=smac;
  reply(32'h0a000001);if(!resolved || mac!==smac) $fatal(1,"gateway resolution");
  start(32'h01010101);if(!resolved || sendarp) $fatal(1,"gateway cache not reused");
  start(32'h0a0000ba);if(hop!==32'h0a0000ba || !sendarp) $fatal(1,"LAN must ARP peer");
  accept;reply(32'h0a0000ba);if(!resolved) $fatal(1,"LAN resolution");
  repeat(1002)tick;
  start(32'h0a0000ba);if(!sendarp) $fatal(1,"stale cache reused");
  link=0;tick;link=1;tick;if(busy || resolved) $fatal(1,"link down did not fence state");
  start(32'h08080808);n=0;
  while(!failed) begin if(sendarp)begin accept;n=n+1;end else tick;end
  if(n!=3 || busy) $fatal(1,"retry bound %d",n);
  start(32'h08080808);repeat(105)tick;if(!failed || busy) $fatal(1,"TX backpressure unbounded");
  $display("PASS gateway/peer ARP, source checks, cache/expiry, link loss, 3 retries, TX timeout");$finish;
 end
 initial begin #1000000;$fatal(1,"watchdog");end
endmodule
