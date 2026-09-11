`timescale 1ns/1ps
module compound_tb;
    reg clk=0, reset=1;
    wire halted;
    main uut(.clk(clk),.reset(reset),.kb_data(8'd0),.kb_ready(1'b0),
        .tile_rclk(clk),.tile_raddr(13'd0),.halted(halted));
    always #5 clk=~clk;
    task tick; begin @(posedge clk); #1; end endtask
    integer i,j,n,mask_exec,xor_exec;
    reg [31:0] a,b,c,expect_mask,expect_xor;
    always @(posedge clk) if (!reset && uut.exec) begin
        if (uut.opcode==9'h008) mask_exec=mask_exec+1;
        if (uut.opcode==9'h009) xor_exec=xor_exec+1;
    end
    initial begin
        for(j=0;j<16384;j=j+1) uut.dmem[j]=0;
        $readmemh("tb/mem/compound.mem",uut.dmem,0,2);
        for(i=0;i<1024;i=i+1) begin
            reset=1; tick; tick;
            for(j=0;j<256;j=j+1) uut.regs0.mem[j]=0;
            uut.regs0.bank=0;
            a=$random; b=$random; c=$random;
            if(i==0) begin a=0;b=0;c=0;end
            if(i==1) begin a=32'hffffffff;b=32'hffffffff;c=32'hffffffff;end
            if(i<10 && i>1) begin a=i&1; b=(i>>1)&1; c=(i>>2)&1;end
            uut.regs0.mem[1]=a;uut.regs0.mem[2]=b;uut.regs0.mem[3]=c;
            expect_mask=a+(b&c);expect_xor=(a^b^c)+(a&b&c);
            mask_exec=0;xor_exec=0;reset=0;n=0;
            while(!halted && n<100) begin tick;n=n+1;end
            if(!halted || uut.regs0.mem[4]!==expect_mask || uut.regs0.mem[5]!==expect_xor)
                $fatal(1,"compound result mismatch vector %0d",i);
            if(mask_exec!=1 || xor_exec!=1) $fatal(1,"compound instruction used multiple execute cycles");
        end
        $display("PASS: compound 1024 vectors, each opcode one execute cycle");
        $finish;
    end
endmodule
