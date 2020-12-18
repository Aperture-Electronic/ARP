// System verilog file
// Ethernet ARP module
// Features: 
//  1. AXI-Lite control interface
//  2. Standard AXI-Stream ethernet receive & transmit interface
//  3. Reconfigurable ARP cache\
//      a) Automatic ARP cache refresh
//      b) Automatic ARP cache timeout control (timeout can be set)
//      c) Controlled ARP cache clear/update
//  4. Reconfigurable timebase timer (32b)
//  5. AXI-Lite interface for ARP cache query
/*
    =~=AXI-Stream=~=[recv               tran]=~=~AXI-Stream=
    ===BRAM bus=====|cache  ARP Core   query|===AXI-Lite====
    ===AXI-Lite=====[ctrl            clk/rst]---Vector------
*/

module axi_arp
#(
    parameter AXI_CTRL_REGISTER_COUNT = 13,
    parameter AXI_CTRL_ADDRESS_WIDTH = $clog2(AXI_CTRL_REGISTER_COUNT * 4)
)
(
    // Clock & reset
    input logic aclk,
    input logic aresetn,

    // Control AXI-Lite interface (Slave)
    //  AXI-Lite write address channel
    input logic [AXI_CTRL_ADDRESS_WIDTH - 1:0]ctrl_s_axi_awaddr,
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
    input logic [31:0]ctrl_s_axi_araddr,
    input logic ctrl_s_axi_arvalid,
    output logic ctrl_s_axi_arready,

    //  AXI-Lite read data channel
    output logic [31:0]ctrl_s_axi_rdata,
    output logic ctrl_s_axi_rvalid,
    input logic ctrl_s_axi_rready,

    // Receive AXI-Stream interface
    input logic [63:0]rx_s_axis_tdata,
    input logic [7:0]rx_s_axis_tkeep,
    input logic rx_s_axis_tvalid,
    input logic rx_s_axis_tuser,
    input logic rx_s_axis_tlast,

    // Transmit AXI-Stream interface
    output logic [63:0]tx_m_axis_tdata,
    output logic [7:0]tx_m_axis_tkeep,
    output logic tx_m_axis_tvalid,
    output logic tx_m_axis_tuser,
    output logic tx_m_axis_tlast,
    input logic tx_m_axis_tready,

    // Cache BRAM control interface
    output logic cache_bram_clk,
    output logic cache_bram_aresetn,
    output logic cache_bram_en,
    output logic cache_bram_wen,
    output logic [7:0]cache_bram_addr,
    output logic [63:0]cache_bram_wrdata,
    input logic [63:0]cache_bram_rddata,

    // ARP query AXI-Lite interface
    //  AXI-Lite read address channel
    input logic [31:0]query_s_axi_araddr,
    input logic query_s_axi_arvalid,
    output logic query_s_axi_arready,

    //  AXI-Lite read data channel
    output logic [63:0]query_s_axi_rdata,
    output logic query_s_axi_rvalid,
    input logic query_s_axi_rready
);

    axi_arp_ctrl axi_ctrl
    (
        .*,
        .global_enable(),
        .global_auto_resp_en(),
        .global_auto_cache_en(),
        .global_cache_no_req_en(),
        .global_timer_en(),
        .global_auto_cache_timeout_en(),
        .global_req_timeout_en(),
        .global_req_resend(),

        .status_requesting(),
        .status_timeout(),
        .status_resend_cnt(),
        .status_responsed(),

        .self_ip(),
        .self_hw(),
        .target_ip(),
        .target_hw(),

        .transmit_req(),
        .transmit_annouce(),
        .transmit_cancel(),

        .timer_resetn(),
        .timer_prediv(),

        .timer_counter(),

        .transmit_timeout(),

        .cache_crc_poly(),
        .cache_crc_init(),
        .cache_crc_xor(),
        .cache_crc_inrev(),
        .cache_crc_outrev(),

        .cache_timeout()
    );
    
    defparam axi_ctrl.AXI_ADDRESS_WIDTH = AXI_CTRL_ADDRESS_WIDTH;
    
    axi_arp_transmit transmiter
    (
        .*,
        .self_ip(),
        .self_hw(),
        .target_ip(),
        .target_hw(),
        .arp_opcode(),
        
        .request_transmit(),
        .req_transmitting()
    );

endmodule
