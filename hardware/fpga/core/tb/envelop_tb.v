`timescale 1ns/1ps
module envelop_tb;
    reg clk=0, reset=1;
    always #5 clk=~clk;
    wire halted, kb_rd;
    main uut(.clk(clk),.reset(reset),.kb_data(8'b0),.kb_ready(1'b0),.kb_rd(kb_rd),
        .tile_rclk(clk),.tile_raddr(13'b0),.halted(halted),.ble_rdata(32'd12));
    reg [7:0] packet[0:543];
    integer n,i,k,cycles,fd;
    `include "envelop_vectors.vh"
    task run;
        input [23:0] address;
        begin
            @(negedge clk); reset=1;
            repeat(2) @(posedge clk);
            #1; reset=0;
            #1;
            uut.pc0.pc=address; uut.pc0.seq=0;
            // dmem reads on negedge, IR loads dread on posedge fetch: without
            // preloading, the first fetch after a forced PC latches stale data
            // and skips the entry instruction (e.g. MOV r17,r16 in en_parse),
            // so the subroutine returns to 0 instead of HALT and times out.
            // The #1 lets the negedge dread update settle before overwriting.
            uut.dread=uut.dmem[address];
            uut.regs0.mem[16]=32'h3ff0;
            cycles=0;
            while(!halted && cycles<100000) begin
                @(posedge clk); #1; cycles=cycles+1;
            end
            if(!halted) $fatal(1,"firmware timeout at %h pc=%h",address,uut.pc0.pc);
        end
    endtask
    task feed;
        begin
            for(i=0;i<n;i=i+1) uut.dmem['h2c00+i]=packet[i];
            uut.dmem['h2e8e]=n;
            uut.dmem['h2e8c]=0;
            run(EN_PARSE);
        end
    endtask
    task expect_tx;
        begin
            if(uut.dmem['h2e8c] !== n) $fatal(1,"TX length got %d expected %d",uut.dmem['h2e8c],n);
            for(i=0;i<n;i=i+1)
                if(uut.dmem['h2e20+i] !== packet[i])
                    $fatal(1,"TX[%0d]=%h expected %h",i,uut.dmem['h2e20+i],packet[i]);
        end
    endtask
    initial begin
        for(i=0;i<16384;i=i+1) uut.dmem[i]=0;
        for(i=0;i<256;i=i+1) uut.regs0.mem[i]=0;
        uut.regs0.bank=0;
        $readmemh("tb/mem/tomato_os.mem",uut.dmem);
        uut.dmem['h3ff0]=HALT_WORD;
        uut.regs0.mem[8]='h300000;
        uut.regs0.mem[9]='h780000;
        uut.regs0.mem[10]=80;
        uut.regs0.mem[28]='h2e80;
        uut.regs0.mem[29]='h780100;
        uut.regs0.mem[30]='h2c00;
        uut.regs0.mem[31]='h2e20;
        uut.dmem['h2e84]=2;
        uut.dmem['h2e92]=1;
        load_hello; feed;
        load_hello_ack; expect_tx;
        if(uut.dmem['h2e85]!==1) $fatal(1,"not verified");
        load_reset_contacts; feed;
        load_bad_contact; feed;
        if(uut.dmem['h2e8f]!==0) $fatal(1,"accepted nonprintable contact");
        load_contact; feed;
        if(uut.dmem['h2e8f]!==1 || uut.dmem['h2800]!==7 || uut.dmem['h2804]!==65)
            $fatal(1,"contact projection failed");
        // Validation must reject the final bad register before any earlier
        // SET/STORE executes or sandbox clearing occurs.
        uut.dmem['h2700]=32'h12345678;
        load_invalid_compute; feed;
        if(uut.dmem['h2700]!==32'h12345678 || uut.dmem['h2e2c]!==3)
            $fatal(1,"invalid compute mutated sandbox or missed register error");
        if(uut.regs0.mem[10]!==80) $fatal(1,"compute clobbered OS text width");
        load_reset_contacts; feed;
        load_contact; feed;
        // Fragmentation: no mutation until final CRC byte.
        load_message;
        for(i=0;i<n-1;i=i+1) uut.dmem['h2c00+i]=packet[i];
        uut.dmem['h2e8e]=n-1; uut.dmem['h2e8c]=0;
        run(EN_PARSE);
        if(uut.dmem['h2828]!==0) $fatal(1,"partial frame dispatched");
        uut.dmem['h2c00+n-1]=packet[n-1]; uut.dmem['h2e8e]=n;
        run(EN_PARSE);
        load_ack; expect_tx;
        if(uut.dmem['h2828]!==72 || uut.dmem['h2e90]!==1) $fatal(1,"message/greeting absent");
        uut.dmem['h2e8c]=0;
        run(EN_OUTGOING);
        load_auto_reply; expect_tx;
        // Duplicate ACK again, but never allocate another greeting token.
        load_message; feed;
        load_ack; expect_tx;
        if(uut.dmem['h2e92]!==2) $fatal(1,"duplicate produced another greeting");
        load_wrong_ack; feed;
        if(uut.dmem['h2e90]!==1) $fatal(1,"wrong route acknowledged pending message");
        load_server_ack; feed;
        if(uut.dmem['h2e90]!==0) $fatal(1,"server ack ignored");
        run(REMOTE_FOLLOWUP);
        if(uut.dmem['h2e90]!==2 || uut.dmem['h2e92]!==3 || uut.dmem['h2eac]!==5)
            $fatal(1,"first personality line did not wait in flight");
        load_personality_1; expect_tx;
        load_server_ack_2; feed;
        run(REMOTE_FOLLOWUP);
        load_personality_2; expect_tx;
        if(uut.dmem['h2e90]!==3 || uut.dmem['h2eac]!==4)
            $fatal(1,"second personality line ordering");
        load_server_ack_3; feed;
        run(REMOTE_FOLLOWUP);
        load_personality_3; expect_tx;
        if(uut.dmem['h2e90]!==4 || uut.dmem['h2eac]!==0)
            $fatal(1,"final personality line ordering");
        load_server_ack_4; feed;
        if(uut.dmem['h2e90]!==0 || uut.dmem['h2eac]!==0)
            $fatal(1,"personality sequence did not finish");
        load_long_message; feed;
        if(uut.dmem['h2828]!==120 || uut.dmem['h284d]!==46 || uut.dmem['h2850]!==0)
            $fatal(1,"long message truncation/terminator");
        load_bad_text; feed;
        if(uut.dmem['h2828]!==120 || uut.dmem['h2e8c]!==0) $fatal(1,"bad text accepted/acked");
        load_unknown_route; feed;
        if(uut.dmem['h2e8c]!==0) $fatal(1,"unknown route ACKed");
        load_history; feed;
        if(uut.dmem['h2828]!==72 || uut.dmem['h2e90]!==0) $fatal(1,"history greeting loop");
        load_ping; feed;
        load_pong; expect_tx;
        // CRC error: consume one byte only.
        load_contact; packet[n-1]=packet[n-1]^1; feed;
        if(uut.dmem['h2e8e]!==n-1) $fatal(1,"CRC resync must advance one byte");
        // Resync noise + complete valid frame, not merely a fresh parser.
        load_ping;
        for(i=0;i<n;i=i+1) uut.dmem['h2c01+i]=packet[i];
        uut.dmem['h2c00]=99; uut.dmem['h2e8e]=n+1;
        run(EN_PARSE); run(EN_PARSE);
        load_pong; expect_tx;
        // Send the actual draft and verify exact wire frame.
        uut.dmem['h2e8c]=0; uut.dmem['h2ec0]=111; uut.dmem['h2ec1]=107;
        uut.dmem['h2ec2]=0; uut.dmem['h2e8b]=2;
        run(EN_SEND_DRAFT);
        load_manual; expect_tx;
        if(uut.dmem['h2e8b]!==0 || uut.dmem['h2e90]!==5) $fatal(1,"manual send not pending");
        run(EN_OUTGOING); load_manual; expect_tx;
        run(EN_DRAW);
        if(uut.vga0.lo[2*80+2]!==16'h2f45 || uut.vga0.lo[7*80+2]!==16'hf043)
            $fatal(1,"header/contact label");
        if(uut.vga0.lo[23*80+29][15:12]!==14 || uut.vga0.lo[32*80+33][15:12]!==10)
            $fatal(1,"yellow RX / green TX colors");
        if(uut.vga0.lo[27*80+30]!==16'hf020 || uut.vga0.lo[20*80+24]!==16'hf020)
            $fatal(1,"white spacing/divider regression");
        for(i=0;i<4800;i=i+1)
            if(uut.vga0.hi[i]!==0) $fatal(1,"unexpected wallpaper/large-glyph flags at %d",i);
        fd=$fopen("sim/envelop_frame.mem","w");
        for(i=0;i<4800;i=i+1) $fdisplay(fd,"%08h",{uut.vga0.hi[i],uut.vga0.lo[i]});
        $fclose(fd);
        if(uut.vga0.lo[11*80+2][7:0]!=="A" || uut.vga0.lo[10*80+2][7:0]!==32)
            $fatal(1,"contact name not vertically/horizontally centered");
        if(uut.vga0.lo[25*80+73][7:0]!==8'hd9 || uut.vga0.lo[43*80+77][7:0]!==8'hd9)
            $fatal(1,"message outlines incomplete");
        uut.regs0.mem[3]=0; run(TRIB_OF);
        if(uut.regs0.mem[1]!==0) $fatal(1,"T(0)");
        uut.regs0.mem[3]=2; run(TRIB_OF);
        if(uut.regs0.mem[1]!==1) $fatal(1,"T(2)");
        uut.regs0.mem[3]=10; run(TRIB_OF);
        if(uut.regs0.mem[1]!==81) $fatal(1,"T(10)");
        uut.regs0.mem[3]=38; run(TRIB_OF);
        if(uut.regs0.mem[1]!==2082876103) $fatal(1,"T(38)");
        // Stop at the keyboard wait after painting the real game-over dialog.
        uut.dmem[GO_KEY]=HALT_WORD;
        uut.regs0.mem[4]=S_TT_OVER;
        uut.regs0.mem[24]=32'hf00; uut.regs0.mem[26]=32'he00;
        run(GAME_OVER);
        if(uut.vga0.lo[28*80+26][7:0]!=="G" ||
           uut.vga0.lo[29*80+26][7:0]!==0 ||
           uut.vga0.lo[30*80+26][7:0]!=="E" ||
           uut.vga0.lo[32*80+55][7:0]!==8'hd9)
            $fatal(1,"game-over spacing or bottom-right border");
        load_reset_contacts; feed;
        if(uut.dmem['h2e8f]!==0 || uut.dmem['h2800]!==0 || uut.dmem['h2e90]!==0)
            $fatal(1,"reset did not clear session projection");
        $display("PASS: Envelop firmware handshake, fragments, CRC/resync, contacts, RX, history, dedup, personalized ACK-gated greeting, retry, UI");
        $finish;
    end
endmodule
