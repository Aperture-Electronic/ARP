// System verilog file
// Ethernet ARP module - AXI Lite control module (registers)

module axi_arp_ctrl
#
(
	parameter AXI_ADDRESS_WIDTH = 0,
	parameter TIMER_PREDIV_WIDTH = 28,
	parameter TIMER_WIDTH = 14
)
(
    // Clock & reset
    input logic aclk,
    input logic aresetn,

    // Control AXI-Lite interface (Slave)
    //  AXI-Lite write address channel
    input logic [AXI_ADDRESS_WIDTH - 1:0]ctrl_s_axi_awaddr,
    input logic ctrl_s_axi_awvalid,
    output logic ctrl_s_axi_awready,

    //  AXI-Lite write data channel
    input logic [31:0]ctrl_s_axi_wdata,
    input logic ctrl_s_axi_wvalid,
    output logic ctrl_s_axi_wready,

    //  AXI-Lite write response channel
    output logic ctrl_s_axi_bvalid,
    input logic ctrl_s_axi_bready,

    //  AXI-Lite read address channel
    input logic [AXI_ADDRESS_WIDTH - 1:0]ctrl_s_axi_araddr,
    input logic ctrl_s_axi_arvalid,
    output logic ctrl_s_axi_arready,

    //  AXI-Lite read data channel
    output logic [31:0]ctrl_s_axi_rdata,
    output logic ctrl_s_axi_rvalid,
    input logic ctrl_s_axi_rready,

	// Control vector output
	output logic global_enable,
	output logic global_auto_resp_en,
	output logic global_auto_cache_en,
	output logic global_cache_no_req_en,
	output logic global_timer_en,
	output logic global_auto_cache_timeout_en,
	output logic global_req_timeout_en,
	output logic [3:0]global_req_resend,

	input logic status_requesting,
	input logic status_timeout,
	input logic [3:0]status_resend_cnt,
	input logic status_responsed,

	output logic [31:0]self_ip,
	output logic [47:0]self_hw,
	output logic [31:0]target_ip,
	output logic [47:0]target_hw,

	output logic transmit_req,
	output logic transmit_annouce,
	output logic transmit_cancel,

	output logic timer_resetn,
	output logic [TIMER_PREDIV_WIDTH - 1:0]timer_prediv,

	input logic [TIMER_WIDTH - 1:0]timer_counter,

	output logic [TIMER_WIDTH - 1:0]transmit_timeout,

	output logic [7:0]cache_crc_poly,
	output logic [7:0]cache_crc_init,
	output logic [7:0]cache_crc_xor,
	output logic cache_crc_inrev,
	output logic cache_crc_outrev,

	output logic [TIMER_WIDTH - 1:0]cache_timeout
);

// Register table
//	|	ADDRESS		|	NAME	|		FUNCTION	 	|
//	|	0x000		|	GLOBAL	|	Global management	|
//		BIT 0: ENABLE (IP function enable)
//		BIT 1: AUTO_RESP (Automatic ARP response enable)
//		BIT 2: AUTO_CACHE (Automatic ARP cache enable)
//		BIT 3: CACHE_NO_REQ (Receive an ARP packet when no request occurs, try to update the cache)
//		BIT 4: TIMER_EN (Timer enable)
//		BIT 5: AUTO_CACHE_TIMEOUT (Automatic ARP cache timeout)
//		BIT 6: REQ_TIMEOUT_EN (Enable ARP requeset timeout)
//		BIT [10:7]: REQ_TO_AUTO_RESEND (ARP request timeout automatic resend count, 0 = NO resend)

//	|	0x004		|	STATUS	|	Status				| (Readonly)
//		BIT 0: REQUSETING (An ARP request is sended, but no response arrived)
//		BIT 1: TIMEOUT (An ARP requset is timeout)
//		BIT [5:2]: RESEND_CNT (ARP requeset timeout resend count)
//		BIT 6: RESPONSED (An ARP response is arrived)
//		BIT 7: WORKING (ARP working, it could be requesting/resending or responding)

//	|	0x008		|	SLF_IP	|	Self IP address		|
//		BIT [31:0]:	SELF IP (Self IP address)

//	|	0x00C		|	SLF_HWL	|	Self Hw address		|
//		BIT [31:0]:	SELF HW[31:0] (Self hardware address)

//	|	0x010		|	SLF_HWH	|	Self Hw address		|
//		BIT [31:0]:	SELF HW[47:32] (Self hardware address)

//	|	0x014		|	TAR_IP	|	Target IP address	|
//		BIT [31:0]: TARGET IP (Target IP address to request)

//	|	0x018		|	TAR_HWL	|	Target Hw address	|
//		BIT [31:0]:	TARGET HW[31:0] (Target hardware address to request, default is FF:FF:FF:FF:FF:FF)

//	|	0x01C		|	TAR_HWH	|	Target Hw address(H)|
//		BIT [15:0]:	TARGET HW[47:32]

//	|	0x020		|	TRANSMIT|	Transmit control	| (Set to 1 for start)
//		BIT 0: ARP_REQ (ARP request)
//		BIT 1: ARP_ANNOUCE (ARP announcement)
//		BIT 2: CANCEL (Cancel current ARP request)

//	|	0x024		|	TIMCTR	|	Timer control		|
//		BIT 0: TMR_RSTN (Timer reset, 0 = reset)
//		BIT [31:(31 - TIMER_PREDIV_WIDTH + 1)]: TMR_PREDIV[TIMER_PREDIV_WIDTH - 1:0] (Timer pre divider counter preset)

//	|	0x028		|	TIMCNT	|	Timer counter		| (Readonly)
//		BIT[TIMER_WIDTH - 1:0]: TMR_CNT (Timer counter (current time))

//	|	0x02C		|	TX_TMO	|	Transmit timeout	|
//		BIT[TIMER_WIDTH - 1:0]: TX_TMO (Transmit timeout)

//	|	0x030		|	CA_CRC |	CRC parameter for cache hash |
//		BIT[7:0]: CRC_POLY (CRC polynomial)
//		BIT[15:8]: CRC_INIT (CRC initial)
//		BIT[23:16]: CRC_XOR (CRC output xor)
//		BIT[24]: CRC_IN_REV (CRC input reverse)
//		BIT[25]: CRC_OUT_REV (CRC output reverse)

//	|	0x034		|	CA_TMO	|	Cache timeout		|
//		BIT[TIMER_WIDTH - 1:0]: CA_TMO (Cache timeout)

// AXI registers
logic [10:0]global_reg;
logic [6:0]status_reg;

logic [31:0]self_ip_reg;
logic [31:0]self_hwl_reg;
logic [15:0]self_hwh_reg;

logic [31:0]target_ip_reg;
logic [31:0]target_hwl_reg;
logic [15:0]target_hwh_reg;

logic [2:0]transmit_reg;

logic [31:0]timctr_reg;
logic [TIMER_WIDTH - 1:0]timcnt_reg;

logic [TIMER_WIDTH - 1:0]transmit_timeout_reg;

logic [25:0]cache_crc_reg;

logic [TIMER_WIDTH - 1:0]cache_timeout_reg;

// AXI write address section
always_ff @(posedge aclk, negedge aresetn) begin
	if (!aresetn) begin
		ctrl_s_axi_awready <= 1'b0;
	end
	else begin
		if (ctrl_s_axi_awvalid) begin
			ctrl_s_axi_awready <= 1'b1;
		end
		else begin
			ctrl_s_axi_awready <= 1'b0;
		end
	end
end

logic [AXI_ADDRESS_WIDTH - 1:0]axi_awaddr_buffer;
always_ff @(posedge aclk, negedge aresetn) begin
	if (!aresetn) begin
		axi_awaddr_buffer <= 'b0;
	end
	else begin
		if (ctrl_s_axi_awvalid && ctrl_s_axi_awready) begin
			axi_awaddr_buffer <= ctrl_s_axi_awaddr;
		end
	end
end

// AXI write data section
always_ff @(posedge aclk, negedge aresetn) begin
	if (!aresetn) begin
		ctrl_s_axi_wready <= 1'b0;
	end
	else begin
		if (ctrl_s_axi_wvalid) begin
			ctrl_s_axi_wready <= 1'b1;
		end
		else begin
			ctrl_s_axi_wready <= 1'b0;
		end
	end
end

logic axi_writing_waddr;
logic axi_writing_waddr_wdata_valid;
assign axi_writing_wdata_valid = ctrl_s_axi_wvalid && ctrl_s_axi_wready;
assign axi_writing_waddr_wdata_valid = 
	ctrl_s_axi_awvalid && ctrl_s_axi_awready && 
	ctrl_s_axi_wvalid && ctrl_s_axi_wready;

// Response request
logic axi_need_resp; // A write operation is assigned, need response
always_ff @(posedge aclk, negedge aresetn) begin
	if (!aresetn) begin
		axi_need_resp <= 1'b0;	
	end
	else begin
		if (axi_writing_waddr_wdata_valid) begin // The address is now valid on the bus
			axi_need_resp <= 1'b1;
		end
		else if (axi_writing_wdata_valid) begin // The address is assigned in previous command
			axi_need_resp <= 1'b1;
		end
		else begin
			axi_need_resp <= 1'b0;
		end
	end
end

logic [AXI_ADDRESS_WIDTH - 1:0]axi_waddr;
always_comb begin
	if (axi_writing_waddr_wdata_valid) begin
		axi_waddr = ctrl_s_axi_awaddr; // The address is now available on the interface
	end
	else begin
		axi_waddr = axi_awaddr_buffer; // The address is assigned in previous command
	end
end

logic axi_wren; // AXI write operation
assign axi_wren = axi_writing_waddr_wdata_valid || axi_writing_wdata_valid;

// AXI write response section
always_ff @(posedge aclk, negedge aresetn) begin
	if (!aresetn) begin
		ctrl_s_axi_bvalid <= 1'b0;
	end
	else begin
		if (axi_need_resp) begin	// When need to response
			ctrl_s_axi_bvalid <= 1'b1;
		end

		if (ctrl_s_axi_bvalid && ctrl_s_axi_bready) begin	// When response was received
			ctrl_s_axi_bvalid <= 1'b0;
		end
	end
end

// AXI read address section
always_ff @(posedge aclk, negedge aresetn) begin
	if (!aresetn) begin
		ctrl_s_axi_arready <= 1'b0;
	end
	else begin
		if (ctrl_s_axi_arvalid) begin
			ctrl_s_axi_arready <= 1'b1;
		end
		else begin
			ctrl_s_axi_arready <= 1'b0;
		end
	end
end

logic [AXI_ADDRESS_WIDTH - 1:0]axi_raddr;
logic axi_need_read; // A read address operation is assigned, need read
always_ff @(posedge aclk, negedge aresetn) begin
	if (!aresetn) begin
		axi_raddr <= 'b0;
		axi_need_read <= 1'b0;
	end
	else begin
		if (ctrl_s_axi_arvalid && ctrl_s_axi_arready) begin
			axi_raddr <= ctrl_s_axi_araddr;
			axi_need_read <= 1'b1;
		end
		else begin
		    axi_need_read <= 1'b0;
		end
	end
end

// AXI read data section
logic axi_wait_for_read; // Read assigned, waiting for master ready signal
logic [31:0]axi_data_to_read;
always_ff @(posedge aclk, negedge aresetn) begin
	if (!aresetn) begin
		ctrl_s_axi_rvalid <= 1'b0;
		ctrl_s_axi_rdata <= 32'b0;

		axi_wait_for_read <= 1'b0;
	end
	else begin
	    if (axi_wait_for_read) begin
            if (ctrl_s_axi_rready) begin
                ctrl_s_axi_rdata <= axi_data_to_read;
                ctrl_s_axi_rvalid <= 1'b1;
                axi_wait_for_read <= 1'b0; // Exit wait for read mode
            end
	    end
	    else begin
            if (axi_need_read && ctrl_s_axi_rready) begin
               // Ready signal is assigned, read now
               ctrl_s_axi_rdata <= axi_data_to_read;
               ctrl_s_axi_rvalid <= 1'b1; // Valid signal will assign now 
            end
            else if (axi_need_read) begin
                // Wait ready signal for read
                axi_wait_for_read <= 1'b1; // Enter wait for read mode 
                ctrl_s_axi_rvalid <= 1'b0; // Valid signal will wait reay signal 
            end
            else begin
                ctrl_s_axi_rvalid <= 1'b0;
            end
	    end
	end
end

// AXI registers write
always_ff @(posedge aclk, negedge aresetn) begin
	if (!aresetn) begin
		global_reg <= 'b0; 
		status_reg <= 'b0;
		self_ip_reg <= 'b0;
		self_hwl_reg <= 'b0;
		self_hwh_reg <= 'b0;
		target_ip_reg <= 'b0;
		target_hwl_reg <= 'hFFFFFFFF;
		target_hwh_reg <= 'hFFFF;
		transmit_reg <= 'b0;
		timctr_reg <= 'b0;
		transmit_timeout_reg <= 'b0;
		cache_crc_reg <= 'b0;
		cache_timeout_reg <= 'b0;
	end
	else begin
		if (axi_wren) begin
			case (axi_waddr[AXI_ADDRESS_WIDTH - 1:2])
				'h000: global_reg <= ctrl_s_axi_wdata;
				'h001: begin end // Nothing to do
				'h002: self_ip_reg <= ctrl_s_axi_wdata;
				'h003: self_hwl_reg <= ctrl_s_axi_wdata;
				'h004: self_hwh_reg <= ctrl_s_axi_wdata;
				'h005: target_ip_reg <= ctrl_s_axi_wdata;
				'h006: target_hwl_reg <= ctrl_s_axi_wdata;
				'h007: target_hwh_reg <= ctrl_s_axi_wdata;
				'h008: transmit_reg <= ctrl_s_axi_wdata;
				'h009: timctr_reg <= ctrl_s_axi_wdata;
				'h00A: begin end // Nothing to do
				'h00B: transmit_timeout_reg <= ctrl_s_axi_wdata;
				'h00C: cache_crc_reg <= ctrl_s_axi_wdata;
				'h00D: cache_timeout_reg <= ctrl_s_axi_wdata;
			endcase
		end
		else begin
			// Some of registers will automatic reset
			transmit_reg <= 'b0;
		end
	end
end

// AXI registers read
always_comb begin
	case (axi_raddr[AXI_ADDRESS_WIDTH - 1:2])
		'h000: axi_data_to_read = global_reg;
		'h001: axi_data_to_read = status_reg;
		'h002: axi_data_to_read = self_ip_reg;
		'h003: axi_data_to_read = self_hwl_reg;
		'h004: axi_data_to_read = self_hwh_reg;
		'h005: axi_data_to_read = target_ip_reg;
		'h006: axi_data_to_read = target_hwl_reg;
		'h007: axi_data_to_read = target_hwh_reg;
		'h008: axi_data_to_read = transmit_reg;
		'h009: axi_data_to_read = timctr_reg;
		'h00A: axi_data_to_read = timcnt_reg;
		'h00B: axi_data_to_read = transmit_timeout_reg;
		'h00C: axi_data_to_read = cache_crc_reg;
		'h00D: axi_data_to_read = cache_timeout_reg;
		default: axi_data_to_read = 32'b0;
	endcase
end

// Vector ports - registers assignment
assign global_enable = global_reg[0];
assign global_auto_resp_en = global_reg[1];
assign global_auto_cache_en = global_reg[2];
assign global_cache_no_req_en = global_reg[3];
assign global_timer_en = global_reg[4];
assign global_auto_cache_timeout_en = global_reg[5];
assign global_req_timeout_en = global_reg[6];
assign global_req_resend = global_reg[10:7];

assign status_reg[0] = status_requesting;
assign status_reg[1] = status_timeout;
assign status_reg[5:2] = status_resend_cnt;
assign status_reg[6] = status_responsed;

assign self_ip = self_ip_reg;
assign self_hw = {self_hwh_reg[15:0], self_hwl_reg[31:0]};

assign target_ip = target_ip_reg;
assign target_hw = {target_hwh_reg[15:0], self_hwl_reg[31:0]};

assign transmit_req = transmit_reg[0];
assign transmit_annouce = transmit_reg[1];
assign transmit_cancel = transmit_reg[2];

assign timer_resetn = timctr_reg[0];
assign timer_prediv = timctr_reg[31:31 - TIMER_PREDIV_WIDTH + 1];
assign timcnt_reg = timer_counter;

assign transmit_timeout = transmit_timeout_reg;

assign cache_crc_poly = cache_crc_reg[7:0];
assign cache_crc_init = cache_crc_reg[15:8];
assign cache_crc_xor = cache_crc_reg[23:16];
assign cache_crc_inrev = cache_crc_reg[24];
assign cache_crc_outrev = cache_crc_reg[25];

assign cache_timeout = cache_timeout_reg;

endmodule
