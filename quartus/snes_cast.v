module snes_cast_top(
	input clk,
	input rst_n,
	input snes_rst_n,
	input [7:0] snes_data,
	input [7:0] snes_address,
	input snes_rd_n,
	input snes_wr_n,
	output [7:0] leds,
	output reg [7:0] FTDI_data,
	input FTDI_rx_full_n,
	input FTDI_tx_empty_n,
	output FTDI_rd_n,
	output reg FTDI_wr_n,
	output FTDI_siwua,
	input FTDI_clk,
	output FTDI_oe_n,
	output unk,
	output FTDI_pwrsav_n
	);

reg [31:0] snes_rst_n_s;
reg        snes_rst_n_ss;
reg write_to_ftdi_n;
wire	  rdempty;
wire	  rdfull;
wire	[13:0]  rdusedw;
wire	  wrempty;
wire	  wrfull;
wire	[12:0]  wrusedw;
wire official_rst_n;
assign official_rst_n = rst_n & snes_rst_n_ss;

assign FTDI_pwrsav_n = 1'b1;
assign FTDI_siwua = 1'b1;
assign FTDI_oe_n = 1'b1;
assign FTDI_rd_n = 1'b1;
assign leds = rdusedw[7:0];

reg [7:0] data,addr;
reg [3:0] seq,oper;
reg       snes_wr_n_meta0,snes_wr_n_meta1,snes_wr_n_meta2,snes_wr_n_sync,snes_wr_n_pipe;
reg       snes_rd_n_meta0,snes_rd_n_meta1,snes_rd_n_meta2,snes_rd_n_sync,snes_rd_n_pipe;
reg [15:0] read_capture,write_capture;
reg latch_it,fifo_action,bad_trigger;
reg [1:0] usb_xfer_count;
reg FTDI_readout;

integer n;
always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
		snes_rst_n_ss <= 1'b0;
	end else begin
		snes_rst_n_s[0] <= snes_rst_n;
		for (n=1;n<32;n=n+1) snes_rst_n_s[n] <= snes_rst_n_s[n-1];	
		if (&snes_rst_n_s) snes_rst_n_ss <= 1'b1;
		if (~|snes_rst_n_s) snes_rst_n_ss <= 1'b0;
	end
end

always @(posedge snes_rd_n or negedge official_rst_n) begin
	if (~official_rst_n) read_capture <= 'b0;
	else read_capture <= {snes_address,snes_data};
end

always @(posedge snes_wr_n or negedge official_rst_n) begin
	if (~official_rst_n) write_capture <= 'b0;
	else write_capture <= {snes_address,snes_data};
end

wire [7:0]FTDI_out;
crossfifo cc (
	.aclr(~official_rst_n),
	.data({8'hFF,seq,oper,data,addr}),
	.rdclk(FTDI_clk),
	.rdreq(FTDI_readout),
	.wrclk(clk),
	.wrreq(fifo_action),
	.q(FTDI_out),
	.rdempty(rdempty),
	.rdfull(rdfull),
	.rdusedw(rdusedw),
	.wrempty(wrempty),
	.wrfull(wrfull),
	.wrusedw(wrusedw));
assign unk = bad_trigger | |usb_xfer_count;
always @(posedge clk or negedge official_rst_n) begin
	if (~official_rst_n) begin
		snes_wr_n_meta0 <= 1'b0;
		snes_wr_n_meta1 <= 1'b0;
		snes_wr_n_meta2 <= 1'b0;
		snes_wr_n_sync <= 1'b0;
		snes_wr_n_pipe <= 1'b0;
		snes_rd_n_meta0 <= 1'b0;
		snes_rd_n_meta1 <= 1'b0;
		snes_rd_n_meta2 <= 1'b0;
		snes_rd_n_sync <= 1'b0;
		snes_rd_n_pipe <= 1'b0;
		data           <= 'b0;
		addr           <= 'b0;
		fifo_action    <= 'b0;
		latch_it       <= 1'b0;
		bad_trigger    <= 1'b0;
		seq            <= 4'b0;
		oper           <= 4'b0;
	end else begin
		fifo_action <= 'b0;
		bad_trigger <= 1'b0;
		oper        <= 'b0;
		//-------------------------------
		// Critical Metastability Paths--
		//-------------------------------
		snes_wr_n_meta0 <= snes_wr_n;
		snes_wr_n_meta1 <= snes_wr_n_meta0;
		snes_wr_n_meta2 <= snes_wr_n_meta1;
		snes_wr_n_sync <= snes_wr_n_meta2 | snes_wr_n_meta1 | snes_wr_n_meta0;
		snes_wr_n_pipe <= snes_wr_n_sync;
		
		snes_rd_n_meta0 <= snes_rd_n;
		snes_rd_n_meta1 <= snes_rd_n_meta0;
		snes_rd_n_meta2 <= snes_rd_n_meta1;
		snes_rd_n_sync <= snes_rd_n_meta2 | snes_rd_n_meta1 | snes_rd_n_meta0;
		snes_rd_n_pipe <= snes_rd_n_sync;
		//-------------------------------
		//-------------------------------

		if (latch_it == 1'b1 && snes_wr_n_sync == 1'b1 && snes_wr_n_pipe == 1'b0) begin 
			fifo_action <= 'b1;
			data <= write_capture[7:0];
			addr <= write_capture[15:8];
			seq     <= seq+1;
			
			if (&write_capture[15:8]) begin
				oper[3] <= 1'b1;
				addr    <= 'b0;
			end
			
			if (&write_capture[7:0]) begin
				oper[2] <= 1'b1;
				data    <= 'b0;
			end
			
			oper[0] <= 1'b1;
			
			if ((data + 8'b00000001) != write_capture[7:0]) bad_trigger <= 1'b1;
			
		end
		
		if (latch_it == 1'b1 && snes_rd_n_sync == 1'b1 && snes_rd_n_pipe == 1'b0) begin 
			fifo_action <= 'b1;
			data <= read_capture[7:0];
			addr <= read_capture[15:8];
			seq     <= seq+1;
			
			if (&read_capture[15:8]) begin
				oper[3] <= 1'b1;
				addr    <= 'b0;
			end
			
			if (&read_capture[7:0]) begin
				oper[2] <= 1'b1;
				data    <= 'b0;
			end
			
			oper[1] <= 1'b1;
		end
		
		if (snes_wr_n_sync && snes_rd_n_sync ) latch_it <= 1'b1;
	end
end

parameter REG_LOAD   =  2'b00;
parameter REG_LOADED =  2'b01;
parameter REG_SENDING = 2'b10;
reg [1:0] ftdi_state;
always @(posedge FTDI_clk or negedge official_rst_n) begin
	if (~official_rst_n) begin
		write_to_ftdi_n   <= 1'b1;
		usb_xfer_count <= 2'b0;
		FTDI_data      <= 8'b0;
		ftdi_state     <= REG_LOAD;
	end else begin
		write_to_ftdi_n <= 1'b1;
		if (~FTDI_tx_empty_n && write_to_ftdi_n) write_to_ftdi_n <= 1'b0;
		if (~FTDI_wr_n) usb_xfer_count <= usb_xfer_count + 2'b01;
		
		case (ftdi_state)
		REG_LOAD:
			if (~rdempty) begin 
				ftdi_state <= REG_LOADED;
				FTDI_data <= FTDI_out;
			end
		REG_LOADED:
			if (~FTDI_tx_empty_n) begin
				write_to_ftdi_n <= 1'b0;
				ftdi_state <= REG_SENDING;
			end
		REG_SENDING:
			begin
				if (~FTDI_tx_empty_n) write_to_ftdi_n <= 1'b0;
				if (~FTDI_tx_empty_n && ~rdempty) FTDI_data  <= FTDI_out;
				if (~FTDI_tx_empty_n &&  rdempty) ftdi_state <= REG_LOAD;
				if (FTDI_tx_empty_n) ftdi_state <= REG_LOADED;
			end
		default:
			ftdi_state <= REG_LOAD;
		endcase
		
	end
end

always @(*) begin
	FTDI_readout = 0;
	FTDI_wr_n    = 1;
	case (ftdi_state)
		REG_LOAD:
		if (~rdempty) FTDI_readout = 1;
		REG_SENDING: begin
			if (~FTDI_tx_empty_n && ~rdempty) FTDI_readout = 1;
			if (~FTDI_tx_empty_n) FTDI_wr_n = 0;
		end
	endcase
end

endmodule
