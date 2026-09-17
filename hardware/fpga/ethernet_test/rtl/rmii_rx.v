// Receive-only 100Mb/s RMII diagnostic. CRS_DV tail alternation is tolerated.
// Good frames require preamble/SFD, >=64 bytes including FCS, CRC32 residue.
module rmii_rx(input clk, input reset, input enable, input crs_dv,
 input [1:0] rxd, input rxerr,
 output reg [31:0] good, bad, activity,
 output reg [15:0] last_type, last_length);
 reg active=0, low_seen=0, in_frame=0, error_seen=0, crc_good=0;
 reg [5:0] preamble=0;
 reg [1:0] phase=0;
 reg [7:0] shift=0;
 reg [15:0] count=0, etype=0, valid_length=0;
 reg [31:0] crc=32'hffffffff;
 wire [7:0] octet={rxd,shift[7:2]};
 function [31:0] crc_byte;
 input [31:0] c; input [7:0] b; reg [31:0] x; integer i;
 begin x=c;for(i=0;i<8;i=i+1) x=(x>>1)^((x[0]^b[i])?32'hedb88320:0);crc_byte=x;end
 endfunction
 always @(posedge clk) begin
  if(reset) begin good<=0;bad<=0;activity<=0;active<=0;in_frame<=0;low_seen<=0;preamble<=0;phase<=0;error_seen<=0;crc_good<=0;count<=0;last_type<=0;last_length<=0;end
  else if(!enable) begin active<=0;in_frame<=0;low_seen<=0;preamble<=0;end
  else if(!crs_dv && low_seen) begin
   if(active) begin
    if(in_frame && crc_good && count==valid_length && valid_length<=1522 && !error_seen) begin good<=good+1;last_type<=etype;last_length<=valid_length;end
    else bad<=bad+1;
   end
   active<=0;in_frame<=0;preamble<=0;phase<=0;crc_good<=0;error_seen<=0;count<=0;
  end else begin
   low_seen<=!crs_dv;
   if(crs_dv && !active) begin active<=1;activity<=activity+1;end
   if(crs_dv || active) begin
    if(rxerr)error_seen<=1;
    if(!in_frame) begin
     // Preamble dibits are 01; SFD ends with 11, aligned independently of CRS.
     if(rxd==1)begin if(preamble!=63)preamble<=preamble+1;end
     else if(rxd==3 && preamble>=15)begin in_frame<=1;phase<=0;count<=0;crc<=32'hffffffff;end
     else preamble<=0;
    end else begin
     shift<=octet;phase<=phase+1;
     if(phase==3) begin
      if(count!=65535)count<=count+1;
      crc<=crc_byte(crc,octet);
      if(count==12)etype[15:8]<=octet;
      if(count==13)etype[7:0]<=octet;
      if(count>=63 && crc_byte(crc,octet)==32'hdebb20e3)begin crc_good<=1;valid_length<=count+1;end
     end
    end
   end
  end
 end
endmodule
