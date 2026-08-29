//  A testbench for main_tomato-v1-burn_tb
`timescale 1us/1ns

module main_tomato-v1-burn_tb;
    reg clk;
    reg reset;
    reg [7:0] \kb-data ;
    reg [12:0] \disp-read ;
    reg kb_en;
    wire [31:0] WB_MUX;
    wire [31:0] DISP;
    wire [23:0] pc_out;

  main main0 (
    .clk(clk),
    .reset(reset),
    .\kb-data (\kb-data ),
    .\disp-read (\disp-read ),
    .kb_en(kb_en),
    .WB_MUX(WB_MUX),
    .DISP(DISP),
    .pc_out(pc_out)
  );

    reg [24:0] patterns[0:1];
    integer i;

    initial begin
      patterns[0] = 25'b1_xxxxxxxxxxxxxxxxxxxxxxxx;
      patterns[1] = 25'b0_xxxxxxxxxxxxxxxxxxxxxxxx;

      for (i = 0; i < 2; i = i + 1)
      begin
        reset = patterns[i][24];
        #10;
        if (patterns[i][23:0] !== 24'hx)
        begin
          if (pc_out !== patterns[i][23:0])
          begin
            $display("%d:pc_out: (assertion error). Expected %h, found %h", i, patterns[i][23:0], pc_out);
            $finish;
          end
        end
      end

      $display("All tests passed.");
    end
    endmodule
