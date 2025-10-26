module top_level #(
    parameter int DATA_SIZE = 32,
    parameter int USER_SIZE = 16,
    parameter int NUM_OF_INGRESS_PORTS = 3,
    parameter int ADDR_SIZE = 32,
    parameter int ID_SIZE = 32,
    parameter int AXIS_DATA_SIZE = 32
) (
    input logic clk,
    input logic rst_n,
    // AXI-Stream slave interfaces for axi_stream_queue_manager
    axi_str_inf.slave axis_in_inf[NUM_OF_INGRESS_PORTS],
    // AXI-Lite slave interface for register_memory_axi_lite
    axi_lite_inf.slave #(DATA_SIZE(DATA_SIZE), ADDR_SIZE(ADDR_SIZE), ID_SIZE(ID_SIZE)) axi_if
);

    // Interface declaration for connecting axi_stream_queue_manager to register_memory_axi_lite
    axi_str_inf #(.DATA_SIZE(DATA_SIZE), .USER_SIZE(USER_SIZE)) axis_interconnect(.clk(clk), .rst_n(rst_n));

    // Instantiate axi_stream_queue_manager
    axi_stream_queue_manager #(
        .DATA_SIZE(DATA_SIZE),
        .USER_SIZE(USER_SIZE),
        .NUM_OF_INGRESS_PORTS(NUM_OF_INGRESS_PORTS)
    ) queue_manager (
        .clk(clk),
        .rst_n(rst_n),
        .axis_in_inf(axis_in_inf),
        .axis_out_inf(axis_interconnect.master)
    );

    // Instantiate register_memory_axi_lite
    register_memory_axi_lite #(
        .DATA_SIZE(DATA_SIZE),
        .ADDR_SIZE(ADDR_SIZE),
        .ID_SIZE(ID_SIZE),
        .AXIS_DATA_SIZE(AXIS_DATA_SIZE),
        .USER_SIZE(USER_SIZE)
    ) register_memory (
        .reg_clk(clk),
        .axi_if(axi_if),
        .axis_in_inf(axis_interconnect.slave)
    );

endmodule
