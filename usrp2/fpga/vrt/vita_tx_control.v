
module vita_tx_control
  #(parameter BASE=0,
    parameter WIDTH=32)
   (input clk, input reset, input clear,
    input set_stb, input [7:0] set_addr, input [31:0] set_data,
    
    input [63:0] vita_time,
    output underrun,

    // From vita_tx_deframer
    input [4+64+WIDTH-1:0] sample_fifo_i,
    input sample_fifo_src_rdy_i,
    output sample_fifo_dst_rdy_o,
    
    // To DSP Core
    output [WIDTH-1:0] sample,
    output run,
    input strobe
    );

   assign sample = sample_fifo_i[4+64+WIDTH-1:4+64];

   wire [63:0] send_time = sample_fifo_i[63:0];
   wire        eop = sample_fifo_i[64];
   wire        eob = sample_fifo_i[65];
   wire        sob = sample_fifo_i[66];
   wire        send_at = sample_fifo_i[67];
   wire        now, early, late, too_early;
   
   time_compare 
     time_compare (.time_now(vita_time), .trigger_time(send_time), .now(now), .early(early), 
		   .late(late), .too_early(too_early));
   
   localparam IBS_IDLE = 0;
   localparam IBS_WAIT = 1;  // FIXME do we need this?
   localparam IBS_RUN = 2;
   localparam IBS_UNDERRUN = 3;

   reg [2:0] ibs_state;
   
   always @(posedge clk)
     if(reset | clear)
       ibs_state <= 0;
     else
       case(ibs_state)
	 IBS_IDLE :
	   if(sample_fifo_src_rdy_i)
	     if(~send_at | now)
	       ibs_state <= IBS_RUN;
	     else if(late | too_early)
	       ibs_state <= IBS_UNDERRUN;
	 
	 IBS_RUN :
	   if(strobe)
	     if(~sample_fifo_src_rdy_i)
	       ibs_state <= IBS_UNDERRUN;
	     else if(eob)
	       ibs_state <= IBS_IDLE;
	     // else if(eop)  FIXME do we care if the packet ends?

	 IBS_UNDERRUN :
	   ;
       endcase // case (ibs_state)

   assign sample_fifo_dst_rdy_o = (strobe & (ibs_state == IBS_RUN));  // FIXME also cleanout
   assign run = (ibs_state == IBS_RUN);
   assign underrun = (ibs_state == IBS_UNDERRUN);
   
endmodule // vita_tx_control