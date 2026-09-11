`timescale 1ns/1ps
module exhibit_tb;
    reg clk=0,reset=1;
    reg [7:0] kb_data=0;
    reg kb_ready=0;
    wire kb_rd,halted;
    main #(.CPU_HZ(1000000)) uut(.clk(clk),.reset(reset),.kb_data(kb_data),.kb_ready(kb_ready),
        .kb_rd(kb_rd),.halted(halted),.tile_rclk(clk),.tile_raddr(13'd0));
    always #5 clk=~clk;
    always @(posedge clk) if(kb_rd) kb_ready<=0;
    task tick;begin @(posedge clk);#1;end endtask
    task wait_n;input integer n;integer j;begin for(j=0;j<n;j=j+1) tick;end endtask
    task key;
        input [7:0] value;input integer settle;integer guard;
        begin
            kb_data=value;kb_ready=1;guard=0;
            while(kb_ready && guard<500000) begin tick;guard=guard+1;end
            if(kb_ready) $fatal(1,"key not consumed");
            wait_n(settle);
        end
    endtask
    task capture;
        input [1023:0] path;integer fd,j;
        begin
            if($test$plusargs("CAPTURE")) begin
                fd=$fopen(path,"w");
                for(j=0;j<4800;j=j+1) $fdisplay(fd,"%08h",{uut.vga0.hi[j],uut.vga0.lo[j]});
                $fclose(fd);
            end
        end
    endtask
    integer i;
    reg [8*81-1:0] solution;
    initial begin
        for(i=0;i<256;i=i+1) uut.regs0.mem[i]=0;
        uut.regs0.bank=0;
        for(i=0;i<16384;i=i+1) uut.dmem[i]=0;
        for(i=0;i<8192;i=i+1) begin uut.vga0.lo[i]=0;uut.vga0.hi[i]=0;end
        $readmemh("tb/mem/tomato_os.mem",uut.dmem);
        tick;tick;reset=0;wait_n(200000);
        repeat(3) key(8'h1e,20000); // wrap from top -> Sudoku (index 9)
        key(8'h0d,200000);
        if(uut.dmem[14'hf00]!==5) $fatal(1,"Sudoku not initialized");
        key(8'h0d,50000);
        if(uut.dmem[14'hf00]!==5) $fatal(1,"fixed clue edited");
        key(8'h10,50000);key(8'h10,50000);
        for(i=1;i<=10;i=i+1) begin
            key(8'h0d,50000);
            if(uut.dmem[14'hf02] !== (i%10)) $fatal(1,"Sudoku skipped digit %0d",i);
            if(i==3 && uut.vga0.lo[31*80+48][7:0]!=="C") $fatal(1,"duplicate not marked");
        end
        capture("/tmp/tomato-sudoku.tiles");
        solution="534678912672195348198342567859761423426853791713924856961537284287419635345286179";
        for(i=0;i<81;i=i+1) uut.dmem[14'hf00+i]=solution[(80-i)*8 +: 8]-8'd48;
        key(8'h1f,400000);
        if(uut.vga0.lo[48*80+8][7:0]!=="P") $fatal(1,"valid Sudoku solution rejected");
        uut.dmem[14'hf02]=5;
        key(8'h1f,100000);
        if(uut.vga0.lo[48*80+8][7:0]==="P") $fatal(1,"invalid full board marked complete");
        // Move beyond bottom row to the Back action.
        repeat(9) key(8'h1f,50000);
        key(8'h0d,200000);
        if(uut.regs0.mem[20]!==9) $fatal(1,"Sudoku return lost focus");
        $display("PASS: Sudoku clues, sequential digits, conflicts, win and exit");
        key(8'h1f,20000);key(8'h0d,200000);
        if(uut.regs0.mem[18]!==13 || uut.regs0.mem[19]!==13) $fatal(1,"MASKADD exhibit mismatch");
        key(8'h1e,50000);key(8'h10,50000);
        if(uut.regs0.mem[18]!==2 || uut.regs0.mem[19]!==2) $fatal(1,"XORAND exhibit mismatch");
        capture("/tmp/tomato-alu.tiles");
        key(8'h0d,200000);
        key(8'h1f,20000);key(8'h0d,200000); // ALU Studio -> Racer
        if(uut.regs0.mem[28]!==1) $fatal(1,"Racer not launched");
        key(8'h10,120000);
        if(uut.regs0.mem[28]!==2) $fatal(1,"Racer right failed");
        key(8'h11,120000);
        if(uut.regs0.mem[28]!==1) $fatal(1,"Racer left failed");
        capture("/tmp/tomato-racer.tiles");
        uut.regs0.mem[29]=1;uut.regs0.mem[30]=39;
        key(8'h1e,100000);
        if(uut.vga0.lo[28*80+26][7:0]!=="C") $fatal(1,"Racer collision missing");
        key(8'h0d,200000);
        if(uut.regs0.mem[31]!==0) $fatal(1,"Racer restart failed");
        key(8'h0d,200000);
        if(uut.vga0.lo[15*80+9][7:0]!=="S") $fatal(1,"Racer did not return");
        if(halted) $fatal(1,"OS halted");
        $display("PASS: exhibit custom operations and Racer steering/collision/restart/exit");
        $finish;
    end
endmodule
