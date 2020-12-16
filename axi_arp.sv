// System verilog file
// Ethernet ARP control module
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

module axi_arp(
    // Clock & reset
    input logic aclk,
    input logic aresetn,

    // Control AXI-Lite interface (Slave)
    //  AXI-Lite write address channel
    input logic [31:0]ctrl_saxi_awaddr,
    input logic ctrl_saxi_awvalid,
    output logic ctrl_saxi_awready,

    //  AXI-Lite write data channel
    input logic [31:0]ctrl_saxi_wdata,
    input logic ctrl_saxi_wvalid,
    output logic ctrl_saxi_wready,

    //  AXI-Lite write response channel
    output logic ctrl_saxi_bvalid,
    input logic ctrl_saxi_bready

    //  AXI-Lite read address channel
    input logic [31:0]ctrl_saxi_araddr,
    input logic ctrl_saxi_arvalid,
    output logic ctrl_saxi_arready,

    //  AXI-Lite read data channel
    output logic [31:0]ctrl_saxi_rdata,
    output logic ctrl_saxi_rvalid,
    output logic ctrl_saxi_rready,

    // Receive AXI-Stream interface

    // Transmit AXI-Stream interface

    // Cache BRAM control interface

    // ARP query AXI-Lite interface
    //  AXI-Lite read address channel
    input logic [31:0]query_saxi_araddr,
    input logic query_saxi_arvalid,
    output logic query_saxi_arready,

    //  AXI-Lite read data channel
    output logic [63:0]query_saxi_rdata,
    output logic query_saxi_rvalid,
    input logic query_saxi_rready
);

endmodule
