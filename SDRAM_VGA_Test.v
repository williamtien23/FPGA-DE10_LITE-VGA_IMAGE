//Simple image driver over vga, stores image in external memory (sdram)
//Author William Tien
//Rev 1.0
//=======================================================
//  This code is generated by Terasic System Builder
//=======================================================

module SDRAM_VGA_Test(

	//////////// CLOCK //////////
	input 		          		ADC_CLK_10,
	input 		          		MAX10_CLK1_50,
	input 		          		MAX10_CLK2_50,

	//////////// SDRAM //////////
	output		    [12:0]		DRAM_ADDR,
	output		     [1:0]		DRAM_BA,
	output		          		DRAM_CAS_N,
	output		          		DRAM_CKE,
	output		          		DRAM_CLK,
	output		          		DRAM_CS_N,
	inout 		    [15:0]		DRAM_DQ,
	output		          		DRAM_LDQM,
	output		          		DRAM_RAS_N,
	output		          		DRAM_UDQM,
	output		          		DRAM_WE_N,

	//////////// SEG7 //////////
	output		     [7:0]		HEX0,
	output		     [7:0]		HEX1,
	output		     [7:0]		HEX2,
	output		     [7:0]		HEX3,
	output		     [7:0]		HEX4,
	output		     [7:0]		HEX5,

	//////////// KEY //////////
	input 		     [1:0]		KEY,

	//////////// LED //////////
	output		     [9:0]		LEDR,

	//////////// SW //////////
	input 		     [9:0]		SW,

	//////////// VGA //////////
	output		     [3:0]		VGA_B,
	output		     [3:0]		VGA_G,
	output		          		VGA_HS,
	output		     [3:0]		VGA_R,
	output		          		VGA_VS
);



//=======================================================
//  REG/WIRE declarations
//=======================================================

//State Machine states
localparam STATE_IDLE		= 8'd0; //Write File States
localparam STATE_FIFO_RD	= 8'd1;
localparam STATE_SDRAM_WR	= 8'd2;
localparam STATE_WRITE 		= 8'd3;
localparam STATE_DELAY	 	= 8'd4;
localparam STATE_EOF	 		= 8'd5;
localparam STATE_SDRAM_RD1	= 8'd1; //Service VGA
localparam STATE_SDRAM_RD2	= 8'd2;

//Qsys System
wire 	sys_clk;
wire	vga_clk;
reg [24:0] 	sdram_av_addr 	= 0;		//SDRAM Avalon-MM Export
reg [1:0] 	sdram_av_be_n 	= 2'b00;
reg 			sdram_av_cs 	= 1;
reg [15:0] 	sdram_av_data 	= 0;
reg 			sdram_av_rd_n 	= 1;
reg 			sdram_av_wr_n 	= 1;
wire [15:0] sdram_za_data;
wire 			sdram_za_valid;
wire 			sdram_za_waitrequest;
reg fifo_av_rd = 0;						//FIFO Avalon-MM Export
wire [15:0] fifo_za_data;
wire fifo_za_waitrequest;

//State Machine
reg [7:0] state = 0;
reg [15:0] counter = 0;
reg [24:0] addr = 0;
reg [15:0] data = 0;
reg file_loaded = 0;
reg [15:0] eof [2:0];
reg service_vga;
reg [15:0] col_ptr =0;
reg [15:0] row_ptr =0;

//VGA
reg vga_reset_n = 0;
reg [11:0] vga_reg;
reg HS_reg = 1;
reg VS_reg = 1;
wire pix_req;
wire [31:0] column;
wire [31:0] row;
wire HS_wire;
wire VS_wire;
assign VGA_R =vga_reg[11:8];
assign VGA_G =vga_reg[7:4];
assign VGA_B =vga_reg[3:0];
assign VGA_HS =HS_reg;
assign VGA_VS =VS_reg;

//VGA Fifo/Queue
reg [3:0] vga_queue_in;
reg pix_en = 0;
reg write_en;
wire [3:0] vga_queue_out;
wire vga_queue_full;
wire [9:0] vga_queue_fill;

//Other
reg [9:0] led = 0;
assign LEDR[6:0] = led[6:0];

mysys u0 (
        .clk_clk              (MAX10_CLK1_50),           //        clk.clk
        .reset_reset_n        (KEY[1]),        				//      reset.reset_n
        .clk100_lag_clk       (DRAM_CLK),       			// clk100_lag.clk
        .clk100_clk           (sys_clk),           		//     clk100.clk
		  .clk25_clk           	(vga_clk),           		//      clk25.clk
        .sdram_av_address       (sdram_av_addr),       	//   sdram_av.address
        .sdram_av_byteenable_n  (sdram_av_be_n),  			//           .byteenable_n
        .sdram_av_chipselect    (sdram_av_cs),    			//           .chipselect
        .sdram_av_writedata     (sdram_av_data),     		//           .writedata
        .sdram_av_read_n        (sdram_av_rd_n),        	//           .read_n
        .sdram_av_write_n       (sdram_av_wr_n),       	//           .write_n
        .sdram_av_readdata      (sdram_za_data),      	//           .readdata
        .sdram_av_readdatavalid (sdram_za_valid), 			//           .readdatavalid
        .sdram_av_waitrequest   (sdram_za_waitrequest),  //           .waitrequest
        .sdram_addr           (DRAM_ADDR),           		//      sdram.addr
        .sdram_ba             (DRAM_BA),             		//           .ba
        .sdram_cas_n          (DRAM_CAS_N),          		//           .cas_n
        .sdram_cke            (DRAM_CKE),            		//           .cke
        .sdram_cs_n           (DRAM_CS_N),           		//           .cs_n
        .sdram_dq             (DRAM_DQ),             		//           .dq
        .sdram_dqm            ({DRAM_UDQM,DRAM_LDQM}),   //           .dqm
        .sdram_ras_n          (DRAM_RAS_N),          		//           .ras_n
        .sdram_we_n           (DRAM_WE_N),           		//           .we_n
		  .fifo_av_readdata       (fifo_za_data),       	//    fifo_av.readdata
        .fifo_av_read           (fifo_av_rd),          	//           .read
        .fifo_av_waitrequest    (fifo_za_waitrequest)    //           .waitrequest
);

vga_controller u1 ( 
			.pixel_clk(vga_clk), 
			.reset_n(vga_reset_n), 
			.h_sync(HS_Wire), 
			.v_sync(VS_Wire),
			.disp_ena(pix_req),
			.column(column),
			.row(row)
);

vga_buffer u2 (
		.data(vga_queue_in),
		.rdclk(vga_clk),
		.rdreq(pix_req),
		.wrclk(sys_clk),
		.wrreq(write_en),
		.q(vga_queue_out),
		.rdempty(LEDR[9]),
		.wrfull(vga_queue_full),
		.wrusedw(vga_queue_fill)
);

//=======================================================
//  Structural coding
//=======================================================

//VGA
always @ (posedge vga_clk) begin
	if(pix_en) begin
		vga_reg[11:0] <= {3{vga_queue_out}};
	end
	else begin
		vga_reg[11:0] <= 12'd0;
	end
		
	pix_en <= pix_req; //Delay by 1 cycle
	HS_reg <= HS_wire;
	VS_reg <= VS_wire;
end

//Control	
always @ (posedge sys_clk) begin
//----------Run script to load file into sdram----------
	if(file_loaded == 0) begin			
		case(state)
			STATE_IDLE:
			begin
				if(fifo_za_waitrequest) begin	
					led[0] <= 1;
					state <= STATE_IDLE;
				end
				else begin
					led[0] <= 0;
					counter <= 0;
					fifo_av_rd <= 1;
					state <= STATE_FIFO_RD;
				end
			end
			
			STATE_FIFO_RD: //Read has 2 cycle latency 
			begin
				fifo_av_rd <= 0;
				if(counter == 1) begin 
					eof[0] <= fifo_za_data;
					eof[1] <= eof[0];
					eof[2] <= eof[1];
					sdram_av_data <= eof[2];
					state <= STATE_SDRAM_WR;
				end
				else begin
					counter <= counter+1;
					state <= STATE_FIFO_RD;
				end
			end
			
			STATE_SDRAM_WR:
			begin
				sdram_av_wr_n <= 0;
				counter <= 0;
				state <= STATE_EOF;
			end

			STATE_EOF:
			begin
				sdram_av_wr_n <= 1;
				if(eof[2] == 16'hFFAC && eof[1] == 16'h1005 && eof[0] == 16'hAFEE) begin
					file_loaded <= 1;
					addr <= 153864;
					//addr <= 584; //3 + 1162/2 worth of header data 
				end
				sdram_av_addr <= sdram_av_addr+1;
				state <= STATE_IDLE; 
			end
			
			default: state <= STATE_EOF;
		endcase
	end
	
//-----Control passed to system after script is done writing file-----
	else begin
		case(state)
			STATE_IDLE:
			begin
				write_en <= 0;
				sdram_av_rd_n <= 1;
				if(sdram_za_waitrequest || ~service_vga)
					state <= STATE_IDLE;
				else begin
					state <= STATE_SDRAM_RD1;
					sdram_av_rd_n <= 0;
					sdram_av_addr <= addr;
				end
					
			end
			
			STATE_SDRAM_RD1:
			begin
				sdram_av_rd_n <= 1;
				if(sdram_za_valid)begin
					data <= sdram_za_data;
					write_en <= 1;
					vga_queue_in <= (sdram_za_data[7:0]/16);
					state <= STATE_SDRAM_RD2;
					
					if(col_ptr == 319) begin		//Handle data Index	
						if(row_ptr == 479) begin
							addr <= 153864;
							row_ptr <= 0;
						end
						else begin
							addr <= (153864 - 320*row_ptr);
							row_ptr <= row_ptr+1;
						end
						col_ptr <= 0;
					end
					else begin
						addr <= addr+1;
						col_ptr <= col_ptr+1;
					end
				end
			end
			
			STATE_SDRAM_RD2:
			begin
				if(vga_queue_full)begin
					write_en <= 0;
					sdram_av_rd_n <= 1;
				end
				else begin
					vga_queue_in <= (data[15:8]/16);
					write_en <= 1;
					state <= STATE_IDLE;
					sdram_av_rd_n <= 1;
				end
			end
		endcase
		
		//Service VGA Handler
		if(vga_queue_fill[9] && vga_queue_fill[8])begin
			vga_reset_n <= 1;
			service_vga <= 0;
		end
		else if (~vga_queue_fill[9]) begin//less than half in queue
			service_vga <= 1;
		end
		else begin
			//Hold service status
		end
	end
end 	

endmodule
