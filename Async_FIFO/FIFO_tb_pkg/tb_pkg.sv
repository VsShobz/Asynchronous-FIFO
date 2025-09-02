`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 27.08.2025 15:32:42
// Design Name: 
// Module Name: tb_pkg
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//  clk
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_pkg_dummy();
endmodule

package tb_pkg;
    
    ////////// AGENT - Write
    localparam data_width=8,add_bits=3;
    class write_transaction ;
        rand bit wen;
        randc logic [data_width-1:0] wdata;
        // deep copy
        function write_transaction copy();
            copy = new();
            copy.wen = this.wen;
            copy.wdata = this.wdata;    
        endfunction
        
        // displaying
        function void display();
            $display("write_enable : %0b | write_Data : %0h" , wen, wdata);
        endfunction       
        
        //constraints
        constraint c_wen {wen dist {1 := 60, 0 := 40};}
    endclass
        
    class write_sequencer;
        write_transaction t;
        mailbox #(write_transaction) wrt_seq_to_wrt_drv;
        function new(mailbox #(write_transaction) wrt_seq_to_wrt_drv);
            this.wrt_seq_to_wrt_drv = wrt_seq_to_wrt_drv;
        endfunction
        event write_done;
        task run();
            $display("[write_GEN] starting the process");
            for(int i=0;i<10;i++)begin
                t=new();
                assert(t.randomize()) else $display ("Write Randomization unsuccessful");
                $display("[write_GEN] : Data sent = %0h | Write_Enable = %0b | i :%0d " ,t.wdata,t.wen, i);             
                wrt_seq_to_wrt_drv.put(t.copy());
            end
            -> write_done;
        endtask   
    endclass
    
    class write_driver;
        write_transaction t;
        virtual write_interface wif;
        mailbox #(write_transaction) wrt_seq_to_wrt_drv;
        function new (mailbox #(write_transaction) wrt_seq_to_wrt_drv);
            this.wrt_seq_to_wrt_drv = wrt_seq_to_wrt_drv;
            t=new();
        endfunction
        task run();
            wif.wen = 0;
            wif.wdata = 0;
            forever begin
                wrt_seq_to_wrt_drv.get(t);
                @(posedge wif.wclk);
                wif.wen <= t.wen;
                wif.wdata <= t.wdata;  
                $display("[write_DRV] : write data received : %0h" , t.wdata);
                @(posedge wif.wclk);
                wif.wen <= 0;
                repeat(4) @(posedge wif.wclk);
            end     
        endtask
    endclass
    
    class write_monitor;
        write_transaction t;
        virtual write_interface wif; 
        mailbox #(write_transaction) wrt_mon_to_wrt_sco;
        function new (mailbox #(write_transaction) wrt_mon_to_wrt_sco);
            this.wrt_mon_to_wrt_sco = wrt_mon_to_wrt_sco;
        endfunction
        task run();
            forever begin
                @(posedge wif.wclk);
                if(wif.wen && !wif.full)begin
                    t=new();
                    t.wen = wif.wen;
                    t.wdata = wif.wdata;
                    wrt_mon_to_wrt_sco.put(t.copy());
                    $display("[write_MON] write data sent : %0h" , wif.wdata);
                end
            end
        endtask         
    endclass
        
    ///////// AGENT - read
    class read_transaction ;
        rand bit ren;
        logic [data_width-1:0] rdata; //(output)
        // deep copy
        function read_transaction copy();
            copy = new();
            copy.ren = this.ren;
            copy.rdata = this.rdata;    
        endfunction
        
        // displaying
        function void display();
            $display("read_enable : %0b " , ren);
        endfunction       
        
        // constraints
        constraint c_ren {ren dist {1 := 60, 0 := 40};}
    endclass
    
    class read_sequencer;
        read_transaction t;
        mailbox #(read_transaction) rd_seq_to_rd_drv;
        function new(mailbox #(read_transaction) rd_seq_to_rd_drv);
            this.rd_seq_to_rd_drv = rd_seq_to_rd_drv;
        endfunction
        event read_done;
        task run();
            for(int i=0;i<10;i++)begin
                t=new();
                assert(t.randomize()) else $display ("Read Randomization unsuccessful");
                $display("[read_GEN] Read enable : %0b || i :%0d " , t.ren , i);
                rd_seq_to_rd_drv.put(t.copy());
            end
            -> read_done;
        endtask   
    endclass
           
    class read_driver;
        read_transaction t;
        virtual read_interface rif;
        mailbox #(read_transaction) rd_seq_to_rd_drv;
        function new (mailbox #(read_transaction) rd_seq_to_rd_drv);
            this.rd_seq_to_rd_drv = rd_seq_to_rd_drv;
            t=new();
        endfunction
        task run();
            rif.ren = 0;
            forever begin
                rd_seq_to_rd_drv.get(t);
                @(posedge rif.rclk);
                rif.ren <= t.ren;
                @(posedge rif.rclk);
                rif.ren <= 0;
                repeat(4) @(posedge rif.rclk);
            end     
        endtask
    endclass
    
    class read_monitor;
        read_transaction t;
        virtual read_interface rif;
        mailbox #(read_transaction) rd_mon_to_rd_sco;
        function new (mailbox #(read_transaction) rd_mon_to_rd_sco);
            this.rd_mon_to_rd_sco = rd_mon_to_rd_sco;
        endfunction
        task run();
            forever begin
                @(posedge rif.rclk);    
                if(rif.ren && !rif.empty)begin
                    $display("[read_MON] Empty : %0b" , rif.empty );
                    @(posedge rif.rclk); 
                    t=new();
                    t.ren = rif.ren;
                    t.rdata = rif.rdata;
                    rd_mon_to_rd_sco.put(t);
                    $display("[read_MON] Data read : %0h , Empty : %0b" , rif.rdata, rif.empty );
                end
            end
        endtask         
    endclass
    
    class scoreboard;
        write_transaction wt;
        read_transaction rt;
        mailbox #(write_transaction) wrt_mon_to_wrt_sco;
        mailbox #(read_transaction) rd_mon_to_rd_sco;
        function new (mailbox #(write_transaction) wrt_mon_to_wrt_sco, mailbox #(read_transaction) rd_mon_to_rd_sco);
            this.wrt_mon_to_wrt_sco = wrt_mon_to_wrt_sco;
            wt = new();
            this.rd_mon_to_rd_sco = rd_mon_to_rd_sco;
            rt = new();
        endfunction       
        logic [data_width-1:0] ref_q[$]; ///// An unbounded queue to store data - FIFO
        task run();
            fork
                // Writer path
                forever begin
                    wrt_mon_to_wrt_sco.get(wt);
                    ref_q.push_back(wt.wdata);
                    if(ref_q.size() == (1<<add_bits))  $display("[SCO][ERROR] FIFO full - OVERFLOW");
                    else $display("[SCO] Data %0h pushed to ref queue" , wt.wdata);
                end
                forever begin
                    rd_mon_to_rd_sco.get(rt);
                    if(ref_q.size()==0) $display("[SCO][ERROR] Read happened but ref_q empty - UNDERFLOW");
                    else begin
                        logic [data_width-1:0] exp = ref_q.pop_front();
                        if(rt.rdata == exp) $display("[SCO][PASS] Read %0h matched " , rt.rdata);
                        else $display("[SCO][FAIL] Expected %0h || Read %0h " , exp , rt.rdata );
                    end
                end
            join_none
        endtask
        
    endclass

endpackage
