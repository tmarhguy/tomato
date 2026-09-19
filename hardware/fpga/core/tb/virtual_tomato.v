// Simulation-only desktop harness. Never included in FPGA synthesis.
module virtual_tomato(
 input clk, reset, pix_clk,
 input [7:0] key, input key_valid, output key_read,
 input [12:0] tile_addr, output [31:0] tile_data,
 output [6:0] ble_addr, output ble_wr, output [7:0] ble_wdata,
 input [31:0] ble_rdata, output halted,
 output [31:0] menu_selection,
 output [15:0] activity_leds
);
 main cpu(.clk(clk),.reset(reset),.kb_data(key),.kb_ready(key_valid),.kb_rd(key_read),
  .tile_rclk(pix_clk),.tile_raddr(tile_addr),.tile_rdata(tile_data),
  .ble_addr(ble_addr),.ble_wr(ble_wr),.ble_wdata(ble_wdata),.ble_rdata(ble_rdata),
  .halted(halted),.activity_leds(activity_leds));
 assign menu_selection=cpu.regs0.mem[20];
 integer i;
 initial begin
  for(i=0;i<16384;i=i+1) cpu.dmem[i]=0;
  for(i=0;i<256;i=i+1) cpu.regs0.mem[i]=0;
  cpu.regs0.bank=0;
  $readmemh("tb/mem/tomato_os.mem",cpu.dmem);
 end
endmodule
