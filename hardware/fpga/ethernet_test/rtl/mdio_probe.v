// Clause22 read-only poll at 1MHz MDC. PHY strapped address1 on Nexys A7.
module mdio_probe(input clk,input reset,output reg mdc,inout mdio,
 output reg [15:0] id1,id2,bmsr,special,output reg present);
 reg [5:0] divider=0,bitno=0;
 reg [1:0] which=0;
 reg [15:0] value=0;
 reg ack=0;
 wire [4:0] addr=which==0?2:which==1?3:which==2?1:31;
 wire [63:0] command={32'hffffffff,2'b01,2'b10,5'd1,addr,2'b11,16'hffff};
 assign mdio=bitno<46?command[63-bitno]:1'bz;
 always @(posedge clk)begin
  if(reset)begin divider<=0;bitno<=0;which<=0;mdc<=0;present<=0;id1<=0;id2<=0;bmsr<=0;special<=0;value<=0;ack<=0;end
  else if(divider==24)begin
   divider<=0;mdc<=!mdc;
   if(!mdc)begin
    if(bitno==47)ack<=!mdio;
    if(bitno>=48)value<={value[14:0],mdio};
   end else if(bitno==63)begin
    bitno<=0;which<=which+1;
    if(ack)case(which)
     0:begin id1<=value;present<=value==16'h0007;end
     1:id2<=value;
     2:bmsr<=value;
     3:special<=value;
    endcase
    else present<=0;
   end else bitno<=bitno+1;
  end else divider<=divider+1;
 end
endmodule
