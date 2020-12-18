// System verilog file
// Ethernet ARP module - ARP transmit module

module axi_arp_transmit
(
    // Clock & reset
    input logic aclk,
    input logic aresetn,

    // Interface for ethernet stream
    output logic [63:0]tx_m_axis_tdata,
    output logic [7:0]tx_m_axis_tkeep,
    output logic tx_m_axis_tvalid,
    output logic tx_m_axis_tuser,
    output logic tx_m_axis_tlast,
    input logic tx_m_axis_tready,

    // Ethernet address parameters
    input logic [31:0]self_ip,
	input logic [47:0]self_hw,
	input logic [31:0]target_ip,
	input logic [47:0]target_hw,
    input logic [15:0]arp_opcode,

    // Transmit control
    input logic request_transmit,

    // Transmit status
    output logic req_transmitting
);

typedef enum reg[1:0] 
{  
    G_IDLE,
    G_TRANSMITING
} GLOBAL_STATE;

GLOBAL_STATE global_state;

typedef enum reg[2:0]
{
    T_IDLE,
    T_PREPARE,
    T_TRANSMIT,
    T_DONE
} TRANSMIT_STATE;

TRANSMIT_STATE transmit_state;

logic [31:0]self_ip_reg;
logic [47:0]self_hw_reg;
logic [31:0]target_ip_reg;
logic [47:0]target_hw_reg;
logic [15:0]arp_opcode_reg;

// Request for transmit
always_ff @(posedge aclk, negedge aresetn) begin
    if (!aresetn) begin
        req_transmitting <= 1'b0;

        global_state <= G_IDLE;
    end
    else begin
        case (global_state)
            G_IDLE: begin
                if (request_transmit) begin
                    // Request for transmit
                    // Enbuffer the parameters
                    self_ip_reg <= self_ip;
                    self_hw_reg <= self_hw;
                    target_ip_reg <= target_ip;
                    target_hw_reg <= target_hw;
                    arp_opcode_reg <= arp_opcode; 

                    req_transmitting <= 1'b1; // Go to busy status
                    global_state <= G_TRANSMITING;
                end
            end
            G_TRANSMITING: begin
                if (transmit_state == T_DONE) begin
                    req_transmitting <= 1'b0;

                    global_state <= G_IDLE;
                end
            end
        endcase
    end
end

// Ethernet package cache
logic [63:0]ethernet_package_cache[5:0];

logic [2:0]cache_transmitted;

// Export AXI Stream interface
always_ff @(posedge aclk, negedge aresetn) begin
    if (!aresetn) begin
        tx_m_axis_tdata <= 64'b0;
        tx_m_axis_tkeep <= 8'b0;
        tx_m_axis_tvalid <= 1'b0;
        tx_m_axis_tuser <= 1'b0;

        transmit_state <= T_IDLE;

        ethernet_package_cache[0] <= 64'b0;
        ethernet_package_cache[1] <= 64'b0;
        ethernet_package_cache[2] <= 64'b0;
        ethernet_package_cache[3] <= 64'b0;
        ethernet_package_cache[4] <= 64'b0;
        ethernet_package_cache[5] <= 64'b0;

        cache_transmitted <= 3'd0;
    end
    else begin
        case (transmit_state)
            T_IDLE: begin
                if (request_transmit) begin
                    transmit_state <= T_PREPARE;
                end
            end
            T_PREPARE: begin
                // Prepare for ethernet package
                // [0] => [SELF_HW_ADDRESS[15:0]|TARGET_HW_ADDRESS[47:0]]
                ethernet_package_cache[0] <= {self_hw_reg[15:0], target_hw_reg};
                // [1] => [HARDWARE_TYPE|ETH_FRAME_TYPE|SELF_HW_ADDRESS[47:16]]
                // 0001H for ethernet network, 0806H for ARP packages
                ethernet_package_cache[1] <= {16'h0001, 16'h0806, self_hw_reg[47:16]};
                // [2] => [SELF_HW_ADDRESS[15:0]|OPCODE|PROT_ADDR_LEN|HW_ADDR_LEN|PROTOCOL_TYPE]
                // 0800H for IP address
                ethernet_package_cache[2] <= {self_hw_reg[15:0], arp_opcode_reg, 8'd4, 8'd6, 16'h0800};
                // [3] => [SELF_IP_ADDRESS|SELF_HW_ADDRESS[47:16]]
                ethernet_package_cache[3] <= {self_ip_reg, self_hw_reg[47:16]};
                // [4] => [TARGET_IP_ADDRESS[15:0]|TARGET_HW_ADDRESS]
                ethernet_package_cache[4] <= {target_ip_reg[15:0], target_hw_reg};
                // [5] => [EMPTY|TARGET_IP_ADDRESS[31:0]]
                ethernet_package_cache[5] <= {48'b0, target_ip_reg[31:16]};

                // Reset transmit counter
                cache_transmitted <= 3'd0;

                // Go to next state
                transmit_state <= T_TRANSMIT;
            end
            T_TRANSMIT: begin
                if (tx_m_axis_tready) begin
                    if (cache_transmitted == 3'd5) begin
                        tx_m_axis_tlast <= 1'b1; // Last package to send
                        tx_m_axis_tkeep <= 8'h03;

                        transmit_state <= T_DONE;
                    end
                    else begin
                        tx_m_axis_tlast <= 1'b0;
                        tx_m_axis_tkeep <= 8'hFF;
                    end
                    
                    tx_m_axis_tdata <= ethernet_package_cache[cache_transmitted];
                    tx_m_axis_tuser <= 1'b0;
                    tx_m_axis_tvalid <= 1'b1;
                end
            end
            T_DONE: begin
                if (tx_m_axis_tready) begin
                    tx_m_axis_tvalid <= 1'b0; // All packages transmitted
                    tx_m_axis_tkeep <= 8'b0;
                    tx_m_axis_tlast <= 1'b0;
                    transmit_state <= T_IDLE;
                end
            end
        endcase
    end
end

endmodule
