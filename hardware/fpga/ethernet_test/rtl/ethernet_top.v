module ethernet_top(input clk,input cpu_resetn,input eth_crsdv,input eth_rxerr,input [1:0] eth_rxd,
 output eth_refclk,eth_rstn,eth_txen,output [1:0] eth_txd,output eth_mdc,inout eth_mdio,
 output [3:0] led,output reg uart_tx,
 output reg [3:0] dvi_r,dvi_g,dvi_b,output reg dvi_hs,dvi_vs,dvi_de,output dvi_clk);
 reg [1:0] div=0;
 always @(posedge clk)div<=div+1;
 wire net_clk,pix_clk;
 BUFG nbuf(.I(div[0]),.O(net_clk));
 BUFG pbuf(.I(div[1]),.O(pix_clk));
 ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) nclk(.C(net_clk),.CE(1'b1),.D1(1'b1),.D2(1'b0),.R(1'b0),.S(1'b0),.Q(eth_refclk));
 ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) pclk(.C(pix_clk),.CE(1'b1),.D1(1'b1),.D2(1'b0),.R(1'b0),.S(1'b0),.Q(dvi_clk));
 reg [22:0] startup=0;
 always @(posedge net_clk)begin if(!cpu_resetn)startup<=0;else if(!startup[22])startup<=startup+1;end
  assign eth_rstn=startup[22]; // ~84ms reset with reference clock continuously running.
  wire reset=!eth_rstn;
 wire [15:0] id1,id2,bmsr,special;
 wire present;
 mdio_probe probe(net_clk,reset,eth_mdc,eth_mdio,id1,id2,bmsr,special,present);
 wire link=present&&bmsr[2];
 wire speed100=special[3];
 wire [31:0] good,bad,activity;
 wire [15:0] last_type,last_length;
  rmii_rx rx(net_clk,reset,link&&speed100,eth_crsdv,eth_rxd,eth_rxerr,good,bad,activity,last_type,last_length);
  // Static-IP ARP/UDP echo endpoint + RMII serializer: laptop <-> FPGA
  // messaging without DHCP/TCP/TLS. See rtl/lan_min.v and tools/tomato_lan.py.
  wire tx_start, tx_valid, tx_last, tx_accept, tx_busy, tx_done;
  wire [7:0] tx_data;
  wire [31:0] tx_frames, rx_udp_ok, arp_ok, tx_dropped;
  wire [31:0] last_src_ip;
  wire [15:0] last_udp_len;
  wire [63:0] last_head;
  wire tx_enable = link && speed100;
  lan_min #(.FPGA_IP(32'h0A0000FA)) echo(net_clk,reset,tx_enable,eth_crsdv,eth_rxd,eth_rxerr,
   tx_start,tx_data,tx_valid,tx_last,tx_accept,tx_busy,tx_done,
   tx_frames,rx_udp_ok,arp_ok,tx_dropped,last_src_ip,last_udp_len,last_head);
  // Link loss aborts an in-flight TX; UDP senders retry.
  rmii_tx transmitter(net_clk,reset||!tx_enable,tx_start,tx_busy,tx_done,
   tx_data,tx_valid,tx_last,tx_accept,eth_txen,eth_txd);
 reg [25:0] heartbeat=0;
 always @(posedge net_clk)heartbeat<=heartbeat+1;
  assign led={good!=0||tx_frames!=0,link,present,heartbeat[25]};
 function [7:0] hexchar;input [3:0] nib;begin hexchar=nib<10?48+nib:55+nib;end endfunction
 // Diagnostic UART snapshots are taken in the receive domain.
  reg [15:0] uid1=0,uid2=0,utype=0,ulen=0;
  reg [31:0] ugood=0,ubad=0,uactivity=0;
  reg ulink=0,uspeed=0;
  // Echo-path snapshot for the alternating second UART line.
  reg [31:0] utx=0,urxudp=0,uarp=0,udrop=0,usrc=0;
  reg line_sel=0;
 function [7:0] serial_char;input [6:0] index;begin
 serial_char=32;
 case(index)
 0:serial_char=8'd84;
 1:serial_char=8'd79;
 2:serial_char=8'd77;
 3:serial_char=8'd65;
 4:serial_char=8'd84;
 5:serial_char=8'd79;
 6:serial_char=8'd32;
 7:serial_char=8'd69;
 8:serial_char=8'd84;
 9:serial_char=8'd72;
 10:serial_char=8'd32;
 11:serial_char=8'd80;
 12:serial_char=8'd72;
 13:serial_char=8'd89;
 14:serial_char=8'd61;
 15:serial_char=8'd48;
 16:serial_char=8'd48;
 17:serial_char=8'd48;
 18:serial_char=8'd48;
 19:serial_char=8'd58;
 20:serial_char=8'd48;
 21:serial_char=8'd48;
 22:serial_char=8'd48;
 23:serial_char=8'd48;
 24:serial_char=8'd32;
 25:serial_char=8'd76;
 26:serial_char=8'd73;
 27:serial_char=8'd78;
 28:serial_char=8'd75;
 29:serial_char=8'd61;
 30:serial_char=8'd48;
 31:serial_char=8'd32;
 32:serial_char=8'd49;
 33:serial_char=8'd48;
 34:serial_char=8'd48;
 35:serial_char=8'd77;
 36:serial_char=8'd61;
 37:serial_char=8'd48;
 38:serial_char=8'd32;
 39:serial_char=8'd71;
 40:serial_char=8'd79;
 41:serial_char=8'd79;
 42:serial_char=8'd68;
 43:serial_char=8'd61;
 44:serial_char=8'd48;
 45:serial_char=8'd48;
 46:serial_char=8'd48;
 47:serial_char=8'd48;
 48:serial_char=8'd48;
 49:serial_char=8'd48;
 50:serial_char=8'd48;
 51:serial_char=8'd48;
 52:serial_char=8'd32;
 53:serial_char=8'd66;
 54:serial_char=8'd65;
 55:serial_char=8'd68;
 56:serial_char=8'd61;
 57:serial_char=8'd48;
 58:serial_char=8'd48;
 59:serial_char=8'd48;
 60:serial_char=8'd48;
 61:serial_char=8'd48;
 62:serial_char=8'd48;
 63:serial_char=8'd48;
 64:serial_char=8'd48;
 65:serial_char=8'd32;
 66:serial_char=8'd65;
 67:serial_char=8'd67;
 68:serial_char=8'd84;
 69:serial_char=8'd61;
 70:serial_char=8'd48;
 71:serial_char=8'd48;
 72:serial_char=8'd48;
 73:serial_char=8'd48;
 74:serial_char=8'd48;
 75:serial_char=8'd48;
 76:serial_char=8'd48;
 77:serial_char=8'd48;
 78:serial_char=8'd32;
 79:serial_char=8'd84;
 80:serial_char=8'd89;
 81:serial_char=8'd80;
 82:serial_char=8'd69;
 83:serial_char=8'd61;
 84:serial_char=8'd48;
 85:serial_char=8'd48;
 86:serial_char=8'd48;
 87:serial_char=8'd48;
 88:serial_char=8'd32;
 89:serial_char=8'd76;
 90:serial_char=8'd69;
 91:serial_char=8'd78;
 92:serial_char=8'd61;
 93:serial_char=8'd48;
 94:serial_char=8'd48;
 95:serial_char=8'd48;
 96:serial_char=8'd48;
 97:serial_char=8'd13;
 98:serial_char=8'd10;
 endcase
 if(index>=15 && index<19)serial_char=hexchar(uid1 >> ((18-index)*4));
 if(index>=20 && index<24)serial_char=hexchar(uid2 >> ((23-index)*4));
 if(index>=44 && index<52)serial_char=hexchar(ugood >> ((51-index)*4));
 if(index>=57 && index<65)serial_char=hexchar(ubad >> ((64-index)*4));
 if(index>=70 && index<78)serial_char=hexchar(uactivity >> ((77-index)*4));
 if(index>=84 && index<88)serial_char=hexchar(utype >> ((87-index)*4));
 if(index>=93 && index<97)serial_char=hexchar(ulen >> ((96-index)*4));
 if(index==30)serial_char=ulink?49:48;
 if(index==37)serial_char=uspeed?49:48;
 end endfunction
  function [7:0] echo_char;input [6:0] index;begin
  echo_char=32;
  case(index)
  0:echo_char=8'd84;
  1:echo_char=8'd79;
  2:echo_char=8'd77;
  3:echo_char=8'd65;
  4:echo_char=8'd84;
  5:echo_char=8'd79;
  6:echo_char=8'd32;
  7:echo_char=8'd69;
  8:echo_char=8'd67;
  9:echo_char=8'd72;
  10:echo_char=8'd79;
  11:echo_char=8'd32;
  12:echo_char=8'd84;
  13:echo_char=8'd88;
  14:echo_char=8'd61;
  23:echo_char=8'd32;
  24:echo_char=8'd82;
  25:echo_char=8'd88;
  26:echo_char=8'd85;
  27:echo_char=8'd68;
  28:echo_char=8'd80;
  29:echo_char=8'd61;
  38:echo_char=8'd32;
  39:echo_char=8'd65;
  40:echo_char=8'd82;
  41:echo_char=8'd80;
  42:echo_char=8'd61;
  51:echo_char=8'd32;
  52:echo_char=8'd68;
  53:echo_char=8'd82;
  54:echo_char=8'd79;
  55:echo_char=8'd80;
  56:echo_char=8'd61;
  65:echo_char=8'd32;
  66:echo_char=8'd83;
  67:echo_char=8'd82;
  68:echo_char=8'd67;
  69:echo_char=8'd61;
  97:echo_char=8'd13;
  98:echo_char=8'd10;
  endcase
  if(index>=15 && index<23)echo_char=hexchar(utx >> ((22-index)*4));
  if(index>=30 && index<38)echo_char=hexchar(urxudp >> ((37-index)*4));
  if(index>=43 && index<51)echo_char=hexchar(uarp >> ((50-index)*4));
  if(index>=57 && index<65)echo_char=hexchar(udrop >> ((64-index)*4));
  if(index>=70 && index<78)echo_char=hexchar(usrc >> ((77-index)*4));
  end endfunction
  reg [25:0] interval=0;
 reg [8:0] baud=0;
 reg [9:0] txshift=10'h3ff;
 reg [3:0] bits_left=0;
 reg [6:0] char_index=0;
 reg sending=0;
 always @(posedge net_clk)begin
  if(reset)begin interval<=0;sending<=0;bits_left<=0;uart_tx<=1;end
  else if(!sending)begin
   if(interval==49999999)begin
    interval<=0;sending<=1;char_index<=0;bits_left<=0;baud<=0;
     uid1<=id1;uid2<=id2;ulink<=link;uspeed<=speed100;ugood<=good;ubad<=bad;uactivity<=activity;utype<=last_type;ulen<=last_length;
     utx<=tx_frames;urxudp<=rx_udp_ok;uarp<=arp_ok;udrop<=tx_dropped;usrc<=last_src_ip;
     line_sel<=!line_sel;
   end else interval<=interval+1;
  end else if(baud==0)begin
   baud<=433;
   if(bits_left==0)begin
    if(char_index==99)begin sending<=0;uart_tx<=1;end
     else begin txshift<={1'b1,line_sel?echo_char(char_index):serial_char(char_index)};uart_tx<=0;bits_left<=9;char_index<=char_index+1;end
   end else begin uart_tx<=txshift[0];txshift<={1'b1,txshift[9:1]};bits_left<=bits_left-1;end
  end else baud<=baud-1;
 end
 // Snapshot crossing: pixel requests a stable receive-domain snapshot once/frame.
 reg [9:0] h=0,v=0;
 reg request_toggle=0;
 always @(posedge pix_clk)begin
  if(!cpu_resetn)begin h<=0;v<=0;end
  else if(h==799)begin h<=0;if(v==524)begin v<=0;request_toggle<=!request_toggle;end else v<=v+1;end
  else h<=h+1;
 end
 reg [1:0] req_sync=0;
 reg ack=0;
 reg [291:0] snapshot=0;
 always @(posedge net_clk)begin
  req_sync<={req_sync[0],request_toggle};
  if(req_sync[1]!=ack)begin snapshot<={tx_frames,rx_udp_ok,arp_ok,tx_dropped,present,link,speed100,1'b0,id1,id2,good,bad,activity,last_type,last_length};ack<=req_sync[1];end
 end
 reg [2:0] ack_sync=0;
 reg seen=0;
 reg [291:0] display=0;
 always @(posedge pix_clk)begin ack_sync<={ack_sync[1:0],ack};if(ack_sync[2]!=seen)begin display<=snapshot;seen<=ack_sync[2];end end
 wire dpresent=display[163],dlink=display[162],dspeed=display[161];
 wire [31:0] did=display[159:128],dgood=display[127:96],dbad=display[95:64],dact=display[63:32];
 wire [15:0] dtype=display[31:16],dlen=display[15:0];
 wire [31:0] dtx=display[291:260],dudp=display[259:228],darp=display[227:196],ddrop=display[195:164];
 reg [7:0] glyph;
 wire [5:0] row=v[9:4],col=h[9:4];
 always @* begin glyph=32;
 case({row,col})
 12'd130:glyph=8'd84;
 12'd131:glyph=8'd79;
 12'd132:glyph=8'd77;
 12'd133:glyph=8'd65;
 12'd134:glyph=8'd84;
 12'd135:glyph=8'd79;
 12'd136:glyph=8'd32;
 12'd137:glyph=8'd69;
 12'd138:glyph=8'd84;
 12'd139:glyph=8'd72;
 12'd140:glyph=8'd69;
 12'd141:glyph=8'd82;
 12'd142:glyph=8'd78;
 12'd143:glyph=8'd69;
 12'd144:glyph=8'd84;
 12'd145:glyph=8'd32;
 12'd146:glyph=8'd83;
 12'd147:glyph=8'd69;
 12'd148:glyph=8'd78;
 12'd149:glyph=8'd68;
 12'd150:glyph=8'd32;
 12'd151:glyph=8'd47;
 12'd152:glyph=8'd32;
 12'd153:glyph=8'd82;
 12'd154:glyph=8'd69;
 12'd155:glyph=8'd67;
 12'd156:glyph=8'd69;
 12'd157:glyph=8'd73;
 12'd158:glyph=8'd86;
 12'd159:glyph=8'd69;
 12'd258:glyph=8'd76;
 12'd259:glyph=8'd65;
 12'd260:glyph=8'd78;
 12'd261:glyph=8'd32;
 12'd262:glyph=8'd84;
 12'd263:glyph=8'd69;
 12'd264:glyph=8'd83;
 12'd265:glyph=8'd84;
 12'd266:glyph=8'd32;
 12'd267:glyph=8'd32;
 12'd268:glyph=8'd49;
 12'd269:glyph=8'd48;
 12'd270:glyph=8'd46;
 12'd271:glyph=8'd48;
 12'd272:glyph=8'd46;
 12'd273:glyph=8'd48;
 12'd274:glyph=8'd46;
 12'd275:glyph=8'd50;
 12'd276:glyph=8'd53;
 12'd277:glyph=8'd48;
 12'd278:glyph=8'd58;
 12'd279:glyph=8'd53;
 12'd280:glyph=8'd48;
 12'd281:glyph=8'd48;
 12'd282:glyph=8'd48;
 12'd386:glyph=8'd80;
 12'd387:glyph=8'd72;
 12'd388:glyph=8'd89;
 12'd389:glyph=8'd32;
 12'd390:glyph=8'd73;
 12'd391:glyph=8'd68;
 12'd514:glyph=8'd76;
 12'd515:glyph=8'd73;
 12'd516:glyph=8'd78;
 12'd517:glyph=8'd75;
 12'd642:glyph=8'd49;
 12'd643:glyph=8'd48;
 12'd644:glyph=8'd48;
 12'd645:glyph=8'd77;
 12'd646:glyph=8'd32;
 12'd647:glyph=8'd77;
 12'd648:glyph=8'd79;
 12'd649:glyph=8'd68;
 12'd650:glyph=8'd69;
 12'd770:glyph=8'd86;
 12'd771:glyph=8'd65;
 12'd772:glyph=8'd76;
 12'd773:glyph=8'd73;
 12'd774:glyph=8'd68;
 12'd775:glyph=8'd32;
 12'd776:glyph=8'd82;
 12'd777:glyph=8'd88;
 12'd898:glyph=8'd66;
 12'd899:glyph=8'd65;
 12'd900:glyph=8'd68;
 12'd901:glyph=8'd32;
 12'd902:glyph=8'd82;
 12'd903:glyph=8'd88;
 12'd1026:glyph=8'd84;
 12'd1027:glyph=8'd88;
 12'd1028:glyph=8'd32;
 12'd1029:glyph=8'd70;
 12'd1030:glyph=8'd82;
 12'd1031:glyph=8'd65;
 12'd1032:glyph=8'd77;
 12'd1033:glyph=8'd69;
 12'd1034:glyph=8'd83;
 12'd1154:glyph=8'd85;
 12'd1155:glyph=8'd68;
 12'd1156:glyph=8'd80;
 12'd1157:glyph=8'd32;
 12'd1158:glyph=8'd82;
 12'd1159:glyph=8'd88;
 12'd1282:glyph=8'd65;
 12'd1283:glyph=8'd82;
 12'd1284:glyph=8'd80;
 12'd1285:glyph=8'd32;
 12'd1286:glyph=8'd82;
 12'd1287:glyph=8'd69;
 12'd1288:glyph=8'd80;
 12'd1289:glyph=8'd76;
 12'd1290:glyph=8'd73;
 12'd1291:glyph=8'd69;
 12'd1292:glyph=8'd83;
 12'd1410:glyph=8'd66;
 12'd1411:glyph=8'd85;
 12'd1412:glyph=8'd83;
 12'd1413:glyph=8'd89;
 12'd1414:glyph=8'd32;
 12'd1415:glyph=8'd68;
 12'd1416:glyph=8'd82;
 12'd1417:glyph=8'd79;
 12'd1418:glyph=8'd80;
 12'd1419:glyph=8'd83;
 12'd1730:glyph=8'd76;
 12'd1731:glyph=8'd65;
 12'd1732:glyph=8'd78;
 12'd1733:glyph=8'd32;
 12'd1734:glyph=8'd79;
 12'd1735:glyph=8'd78;
 12'd1736:glyph=8'd76;
 12'd1737:glyph=8'd89;
 12'd1738:glyph=8'd32;
 12'd1739:glyph=8'd45;
 12'd1740:glyph=8'd32;
 12'd1741:glyph=8'd78;
 12'd1742:glyph=8'd79;
 12'd1743:glyph=8'd32;
 12'd1744:glyph=8'd67;
 12'd1745:glyph=8'd76;
 12'd1746:glyph=8'd79;
 12'd1747:glyph=8'd85;
 12'd1748:glyph=8'd68;
 12'd1749:glyph=8'd32;
 12'd1750:glyph=8'd79;
 12'd1751:glyph=8'd82;
 12'd1752:glyph=8'd32;
 12'd1753:glyph=8'd69;
 12'd1754:glyph=8'd78;
 12'd1755:glyph=8'd67;
 12'd1756:glyph=8'd82;
 12'd1757:glyph=8'd89;
 12'd1758:glyph=8'd80;
 12'd1759:glyph=8'd84;
 12'd1760:glyph=8'd73;
 12'd1761:glyph=8'd79;
 12'd1762:glyph=8'd78;
 endcase
 if(row==6 && col>=17 && col<25)glyph=hexchar(did >> ((24-col)*4));
 if(row==12 && col>=17 && col<25)glyph=hexchar(dgood >> ((24-col)*4));
 if(row==14 && col>=17 && col<25)glyph=hexchar(dbad >> ((24-col)*4));
 if(row==16 && col>=17 && col<25)glyph=hexchar(dtx >> ((24-col)*4));
 if(row==18 && col>=17 && col<25)glyph=hexchar(dudp >> ((24-col)*4));
 if(row==20 && col>=17 && col<25)glyph=hexchar(darp >> ((24-col)*4));
 if(row==22 && col>=17 && col<25)glyph=hexchar(ddrop >> ((24-col)*4));
 if(row==8)case(col)
 17:glyph=(dlink)?8'd85:8'd68;
 18:glyph=(dlink)?8'd80:8'd79;
 19:glyph=(dlink)?8'd32:8'd87;
 20:glyph=(dlink)?8'd32:8'd78;
 endcase if(row==10)case(col)
 17:glyph=(dspeed)?8'd89:8'd78;
 18:glyph=(dspeed)?8'd69:8'd79;
 19:glyph=(dspeed)?8'd83:8'd32;
 endcase if(row==25)case(col)
 2:glyph=(dudp!=0 && dtx!=0)?8'd85:8'd87;
 3:glyph=(dudp!=0 && dtx!=0)?8'd68:8'd65;
 4:glyph=(dudp!=0 && dtx!=0)?8'd80:8'd73;
 5:glyph=(dudp!=0 && dtx!=0)?8'd32:8'd84;
 6:glyph=(dudp!=0 && dtx!=0)?8'd82:8'd73;
 7:glyph=(dudp!=0 && dtx!=0)?8'd69:8'd78;
 8:glyph=(dudp!=0 && dtx!=0)?8'd67:8'd71;
 9:glyph=(dudp!=0 && dtx!=0)?8'd69:8'd32;
 10:glyph=(dudp!=0 && dtx!=0)?8'd73:8'd70;
 11:glyph=(dudp!=0 && dtx!=0)?8'd86:8'd79;
 12:glyph=(dudp!=0 && dtx!=0)?8'd69:8'd82;
 13:glyph=(dudp!=0 && dtx!=0)?8'd68:8'd32;
 14:glyph=(dudp!=0 && dtx!=0)?8'd32:8'd85;
 15:glyph=(dudp!=0 && dtx!=0)?8'd47:8'd68;
 16:glyph=(dudp!=0 && dtx!=0)?8'd32:8'd80;
 17:glyph=(dudp!=0 && dtx!=0)?8'd82:8'd32;
 18:glyph=(dudp!=0 && dtx!=0)?8'd69:8'd84;
 19:glyph=(dudp!=0 && dtx!=0)?8'd80:8'd69;
 20:glyph=(dudp!=0 && dtx!=0)?8'd76:8'd83;
 21:glyph=(dudp!=0 && dtx!=0)?8'd89:8'd84;
 22:glyph=(dudp!=0 && dtx!=0)?8'd32:8'd32;
 23:glyph=(dudp!=0 && dtx!=0)?8'd83:8'd32;
 24:glyph=(dudp!=0 && dtx!=0)?8'd69:8'd32;
 25:glyph=(dudp!=0 && dtx!=0)?8'd78:8'd32;
 26:glyph=(dudp!=0 && dtx!=0)?8'd84:8'd32;
 endcase
 end
 wire [7:0] font_bits;
 font_rom font(pix_clk,{glyph,v[3:1]},font_bits);
 reg [2:0] column_delay=0;
 reg de_delay=0,hs_delay=1,vs_delay=1,green_delay=0;
 always @(posedge pix_clk)begin
  column_delay<=h[3:1];de_delay<=h<640&&v<480;
  hs_delay<=!(h>=656&&h<752);vs_delay<=!(v>=490&&v<492);
  green_delay<=(row==25 && dudp!=0 && dtx!=0);
  dvi_de<=de_delay;dvi_hs<=hs_delay;dvi_vs<=vs_delay;
  dvi_r<=de_delay?(font_bits[column_delay]?(green_delay?4'h3:4'hf):4'h0):0;
  dvi_g<=de_delay?(font_bits[column_delay]?4'hf:4'h1):0;
  dvi_b<=de_delay?(font_bits[column_delay]?(green_delay?4'h6:4'hf):4'h2):0;
 end
endmodule
