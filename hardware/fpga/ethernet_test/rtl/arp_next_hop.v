// Routed-UDP prerequisite, not yet wired into the board top.
// Input replies MUST already pass Ethernet FCS and ARP shape validation.
// One cached next hop; requests for off-subnet IPs resolve the gateway,
// while the caller retains the ORIGINAL destination IP for its IPv4 header.
module arp_next_hop #(
 parameter [47:0] LOCAL_MAC=48'h02544f4d4154,
 parameter [31:0] LOCAL_IP=32'h0a0000fa,
 parameter [31:0] MASK=32'hffffff00,
 parameter [31:0] GATEWAY=32'h0a000001,
 parameter integer TIMEOUT=50000000,
 parameter integer CACHE_TTL=1500000000
)(
 input clk, reset, link,
 input request, input [31:0] destination_ip,
 output reg busy, resolved, failed,
 output reg [31:0] next_hop_ip,
 output reg [47:0] destination_mac,
 output wire arp_send, input arp_accepted,
 input [5:0] arp_index, output reg [7:0] arp_byte,
 input reply_valid,
 input [31:0] reply_sender_ip,reply_target_ip,
 input [47:0] reply_sender_mac,reply_target_mac,reply_ethernet_source
);
 localparam IDLE=0,SEND=1,WAIT_REPLY=2;
 reg [1:0] state=IDLE;
 reg [1:0] attempts=0;
 reg [31:0] timer=0, cache_age=0;
 reg cache_valid=0;
 reg [31:0] cache_ip=0;
 reg [47:0] cache_mac=0;
 wire [31:0] hop=((destination_ip & MASK)==(LOCAL_IP & MASK))?destination_ip:GATEWAY;
 wire match_reply=reply_valid && reply_sender_ip==next_hop_ip &&
    reply_target_ip==LOCAL_IP && reply_target_mac==LOCAL_MAC &&
    reply_sender_mac==reply_ethernet_source && reply_sender_mac!=0 && !reply_sender_mac[40];
 assign arp_send=state==SEND && link;
 always @* begin
  arp_byte=0;
  case(arp_index)
   0,1,2,3,4,5: arp_byte=8'hff;
   6,22:arp_byte=LOCAL_MAC[47:40]; 7,23:arp_byte=LOCAL_MAC[39:32];
   8,24:arp_byte=LOCAL_MAC[31:24]; 9,25:arp_byte=LOCAL_MAC[23:16];
   10,26:arp_byte=LOCAL_MAC[15:8]; 11,27:arp_byte=LOCAL_MAC[7:0];
   12,16:arp_byte=8'h08; 13:arp_byte=8'h06;
   15,21:arp_byte=1; 18:arp_byte=6; 19:arp_byte=4;
   28:arp_byte=LOCAL_IP[31:24];29:arp_byte=LOCAL_IP[23:16];
   30:arp_byte=LOCAL_IP[15:8];31:arp_byte=LOCAL_IP[7:0];
   38:arp_byte=next_hop_ip[31:24];39:arp_byte=next_hop_ip[23:16];
   40:arp_byte=next_hop_ip[15:8];41:arp_byte=next_hop_ip[7:0];
  endcase
 end
 always @(posedge clk) begin
  if(reset || !link) begin
   state<=IDLE;busy<=0;resolved<=0;failed<=0;timer<=0;attempts<=0;
   next_hop_ip<=0;destination_mac<=0;cache_valid<=0;cache_age<=0;
  end else begin
   if(cache_valid) begin
    if(cache_age>=CACHE_TTL-1) cache_valid<=0;
    else cache_age<=cache_age+1;
   end
   case(state)
    IDLE: if(request) begin
     failed<=0;resolved<=0;next_hop_ip<=hop;timer<=0;attempts<=0;
     if(hop==0 || hop==32'hffffffff || hop[31:28]==4'he) begin
      failed<=1;busy<=0;
     end else if(cache_valid && cache_age<CACHE_TTL-1 && cache_ip==hop) begin
      destination_mac<=cache_mac;resolved<=1;busy<=0;
     end else begin state<=SEND;busy<=1;end
    end
    SEND: begin
     if(arp_accepted) begin state<=WAIT_REPLY;timer<=0;attempts<=attempts+1;end
     else if(timer>=TIMEOUT-1) begin state<=IDLE;failed<=1;busy<=0;end
     else timer<=timer+1;
    end
    WAIT_REPLY: begin
     if(match_reply) begin
      cache_valid<=1;cache_age<=0;cache_ip<=next_hop_ip;cache_mac<=reply_sender_mac;
      destination_mac<=reply_sender_mac;resolved<=1;busy<=0;state<=IDLE;
     end else if(timer>=TIMEOUT-1) begin
      timer<=0;
      if(attempts==3) begin failed<=1;busy<=0;state<=IDLE;end
      else state<=SEND;
     end else timer<=timer+1;
    end
   endcase
  end
 end
endmodule
