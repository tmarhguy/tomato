//  A testbench for io_controller_tb
`timescale 1us/1ns

module io_controller_tb;
    reg [23:0] mem_addr;
    reg c_wr;
    reg [15:0] kb_data;
    reg [31:0] mem_data_out;
    wire [31:0] io_data_in;
    wire ram_cs;
    wire vram_we;
    wire [15:0] vram_addr;
    wire [15:0] vram_data;
    wire term_we;
    wire [15:0] term_data;

  io_controller io_controller0 (
    .mem_addr(mem_addr),
    .c_wr(c_wr),
    .kb_data(kb_data),
    .mem_data_out(mem_data_out),
    .io_data_in(io_data_in),
    .ram_cs(ram_cs),
    .vram_we(vram_we),
    .vram_addr(vram_addr),
    .vram_data(vram_data),
    .term_we(term_we),
    .term_data(term_data)
  );

