`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.08.2025 15:17:43
// Design Name: 
// Module Name: async_FIFO
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
// 
//////////////////////////////////////////////////////////////////////////////////

module synchronizer #(parameter bits=4) ( input clk ,resetn, input [bits-1:0] signal , output reg [bits-1:0] sync2);
    reg [bits-1:0] sync1;
    always@(posedge clk or negedge resetn)begin
        if(!resetn)begin
            sync1 <= 0;
            sync2 <= 0;
        end
        else begin
            sync1 <= signal;
            sync2 <= sync1;
        end
    end
    initial $display("[DUT] synchronizers working");
endmodule   

module async_FIFO #(parameter data_width=8, add_bits = 3)( 
        input wire wclk,wrstn,rclk,rrstn,wen,ren, 
        input wire [data_width-1:0] wdata,
        output wire full, empty, overflow, underflow,
        output reg [data_width-1:0] rdata
    );
    initial $display("[DUT] instantiated");
    ///// Pointers have an extra bit as MSB is the one that denotes about empty or full
    reg [add_bits : 0] wptr_bin , rptr_bin ;
    wire [add_bits : 0] wptr_gray_sync, rptr_gray_sync ;
    wire [add_bits : 0] wptr_gray , rptr_gray;
    reg [data_width-1:0] fifo [0:(1<<add_bits) - 1]; //// Fifo data structure of size 8
    reg overflow_r, underflow_r; // registered overflow is imp as it can be sampled by tb, safe practice, precise timing, as the event is stored/registered
    //// Write Domain    
    always@(posedge wclk or negedge wrstn)begin
        if(!wrstn) begin
            wptr_bin <= 0;
            overflow_r <= 0;
        end
        else begin
            overflow_r <= (wen && full);
            if(wen & ~full)begin
                fifo[wptr_bin[add_bits-1:0]] <= wdata;
                wptr_bin <= wptr_bin + 1;         
            end
        end
    end    
    assign wptr_gray = wptr_bin ^ (wptr_bin >>1); // Preserving MSB for empty/full logic
    synchronizer #(.bits(add_bits+1)) write_synchronizer ( .clk(rclk), .resetn(rrstn), .signal(wptr_gray), .sync2(wptr_gray_sync) ); // wptr_gray synchronizer to read domain
    assign full = (wptr_gray == {~rptr_gray_sync[add_bits:add_bits-1],  rptr_gray_sync[add_bits-2:0]}); 
    assign overflow = overflow_r;
    
    //// Read Domain
    
    always@(posedge rclk or negedge rrstn)begin
        if(!rrstn) begin
            rptr_bin <= 0;
            rdata <= 0;
            underflow_r <= 0;
        end
        else begin
            underflow_r <= (ren && empty);
            if(ren & ~empty)begin
                rdata <= fifo[rptr_bin[add_bits-1:0]];
                rptr_bin <= rptr_bin + 1;
            end
        end
    end
    assign rptr_gray = rptr_bin ^ (rptr_bin >>1); // Preserving MSB for empty/full logic
    synchronizer #(.bits(add_bits+1)) read_synchronizer( .clk(wclk), .resetn(wrstn), .signal(rptr_gray), .sync2(rptr_gray_sync) ); // rptr_gray synchronizer to write domain
    assign empty = ( rptr_gray == wptr_gray_sync );     
    assign underflow = underflow_r;
endmodule
