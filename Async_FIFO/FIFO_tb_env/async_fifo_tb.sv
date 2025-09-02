`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 27.08.2025 15:30:32
// Design Name: 
// Module Name: async_fifo_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//         input wire wclk,wrstn,rclk,rrstn,wen,ren, 
//        input wire [data_width-1:0] wdata,
//        output wire full, empty, overflow, underflow,
//        output reg [data_width-1:0] rdata
             
//////////////////////////////////////////////////////////////////////////////////

import tb_pkg::*;

interface write_interface #(parameter data_width = 8);
    
    logic wclk, wrstn;
    logic wen, full, overflow;
    logic [data_width-1:0] wdata;
    // 1. No write when FIFO is full
    property no_write_when_full;
        @(posedge wclk) disable iff (!wrstn)
            !(wen && full);
    endproperty
    assert_no_write_when_full: assert property(no_write_when_full)
        else $error("[SVA][WRITE] Write attempted when FIFO is FULL!");

endinterface

interface read_interface #(parameter data_width = 8);

    logic rclk, rrstn;
    logic ren, empty, underflow;
    logic [data_width-1:0] rdata;

    // 2. No read when FIFO is empty
    property no_read_when_empty;
        @(posedge rclk) disable iff (!rrstn)
        !(ren && empty);
    endproperty
    assert_no_read_when_empty: assert property(no_read_when_empty)
        else $error("[SVA][READ] Read attempted when FIFO is EMPTY!");

endinterface


module async_fifo_tb;
    write_sequencer wSeq;
    read_sequencer rSeq;
    write_driver wDrv;
    read_driver rDrv;
    write_monitor wMon;
    read_monitor rMon;
    scoreboard sco;
    write_interface wif();
    read_interface rif();
    mailbox #(write_transaction) wrt_seq_to_wrt_drv;
    mailbox #(write_transaction) wrt_mon_to_wrt_sco;
    mailbox #(read_transaction) rd_seq_to_rd_drv;
    mailbox #(read_transaction) rd_mon_to_rd_sco;
    event write_done,read_done;
    ///// DUT instantiation
    async_FIFO DUT(.wclk(wif.wclk), .wrstn(wif.wrstn), .rclk(rif.rclk), .rrstn(rif.rrstn), .wen(wif.wen), .ren(rif.ren), .wdata(wif.wdata), .full(wif.full),
                   .empty(rif.empty), .overflow(wif.overflow), .underflow(rif.underflow), .rdata(rif.rdata)); 
                   
    initial begin
        wrt_seq_to_wrt_drv = new();
        wrt_mon_to_wrt_sco = new();
        rd_seq_to_rd_drv = new();
        rd_mon_to_rd_sco = new();
        
        wSeq = new(wrt_seq_to_wrt_drv);
        wDrv = new(wrt_seq_to_wrt_drv);
        wMon = new(wrt_mon_to_wrt_sco);
        
        rSeq = new(rd_seq_to_rd_drv);
        rDrv = new(rd_seq_to_rd_drv);
        rMon = new(rd_mon_to_rd_sco);
        
        sco = new(wrt_mon_to_wrt_sco,rd_mon_to_rd_sco);
        
        wDrv.wif = wif;
        wMon.wif = wif;
        rDrv.rif = rif;
        rMon.rif = rif;
//        wSeq.write_done = write_done;
//        rSeq.read_done = read_done;
        
    end
    
    initial begin wif.wclk = 0; forever #5 wif.wclk = ~wif.wclk; end
    initial begin rif.rclk = 0;   forever #7 rif.rclk = ~rif.rclk;   end
    
    initial begin
      // assert (active-low)
      wif.wrstn = 0;
      rif.rrstn = 0;
      // wait some cycles for both domains
      repeat (6) @(posedge wif.wclk);
      repeat (6) @(posedge rif.rclk);
      // deassert on a posedge (synchronous release)
      @(posedge wif.wclk); wif.wrstn = 1;
      @(posedge rif.rclk); rif.rrstn = 1;
      $display("[%0t] resets deasserted", $time);
    end
    
    
    initial begin
        @(posedge wif.wrstn);
        @(posedge rif.rrstn);
        fork 
            $display("[ENV] full : %0b || empty : %0b", wif.full,rif.empty);
            wSeq.run();
            rSeq.run();
            wDrv.run();
            rDrv.run();
            wMon.run();
            rMon.run();
            sco.run();
        join_none
        #10000;
//        wait(write_done.triggered);
//        wait(read_done.triggered);
        $display("Finish");
        $finish;
    end
endmodule
