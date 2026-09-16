// Minimal nRF8001 electrical bring-up shell.
// It only releases reset after a fixed delay and keeps the ACI bus idle.
module nrf8001_idle #(
    parameter RESET_CYCLES = 62500
) (
    input  wire clk,
    input  wire reset,
    output wire rst_n,
    output wire req_n,
    output wire sck,
    output wire mosi
);
    reg [15:0] count;
    reg        released;

    always @(posedge clk) begin
        if (reset) begin
            count    <= 0;
            released <= 0;
        end else if (!released) begin
            if (count == RESET_CYCLES - 1) released <= 1;
            else count <= count + 1'b1;
        end
    end

    assign rst_n = released;
    assign req_n = 1'b1;
    assign sck   = 1'b0;
    assign mosi  = 1'b0;
endmodule
