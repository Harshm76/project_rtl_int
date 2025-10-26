
module axi_stream_dmux #(
    parameter DATA_SIZE       = 32,
    parameter USER_SIZE       = 16,
    parameter NUM_EGRESS_PORTS = 3,
    parameter MAX_PKT_SIZE    = 1024
)(
      logic clk,
      logic rst_n,

    // Input: valid packets from parser
      logic [DATA_SIZE-1:0]      valid_pkt_tdata   [0:MAX_PKT_SIZE-1],
      logic [(DATA_SIZE/8)-1:0]  valid_pkt_tkeep   [0:MAX_PKT_SIZE-1],
      logic [USER_SIZE-1:0]      valid_pkt_tuser   [0:MAX_PKT_SIZE-1],
      int                         valid_pkt_num,

    // Output: egress ports as an array
    output axi_str_inf.master #(DATA_SIZE, USER_SIZE) port[NUM_EGRESS_PORTS]
);

    // ---------------- Output buffers ----------------
    logic [DATA_SIZE-1:0]      dmux_buf_tdata   [NUM_EGRESS_PORTS-1:0][0:MAX_PKT_SIZE-1];
    logic [(DATA_SIZE/8)-1:0]  dmux_buf_tkeep   [NUM_EGRESS_PORTS-1:0][0:MAX_PKT_SIZE-1];
    logic [USER_SIZE-1:0]      dmux_buf_tuser   [NUM_EGRESS_PORTS-1:0][0:MAX_PKT_SIZE-1];
    int dmux_buf_cnt[NUM_EGRESS_PORTS];

    // ---------------- D-MUX Logic ----------------
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(int p=0; p<NUM_EGRESS_PORTS; p++) dmux_buf_cnt[p] <= 0;
        end else begin
            for(int i=0; i<valid_pkt_num; i++) begin
                int port_id = valid_pkt_tuser[i][2:0]; // extract port_id from tuser
                if(port_id < NUM_EGRESS_PORTS) begin
                    int cnt = dmux_buf_cnt[port_id];
                    dmux_buf_tdata[port_id][cnt]  <= valid_pkt_tdata[i];
                    dmux_buf_tkeep[port_id][cnt]  <= valid_pkt_tkeep[i];
                    dmux_buf_tuser[port_id][cnt]  <= valid_pkt_tuser[i];
                    dmux_buf_cnt[port_id] <= cnt + 1;
                end
            end
        end
    end

    // ---------------- Drive AXIS outputs ----------------
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(int p=0; p<NUM_EGRESS_PORTS; p++) port[p].tvalid <= 0;
        end else begin
            for(int p=0; p<NUM_EGRESS_PORTS; p++) begin
                if(dmux_buf_cnt[p] > 0) begin
                    int idx = 0; // always send first packet in buffer
                    port[p].tdata  <= dmux_buf_tdata[p][idx];
                    port[p].tkeep  <= dmux_buf_tkeep[p][idx];
                    port[p].tuser  <= dmux_buf_tuser[p][idx];
                    port[p].tvalid <= 1'b1;
                    port[p].tlast  <= 1'b1;

                    // remove sent packet
                    for(int k=0; k<dmux_buf_cnt[p]-1; k++) begin
                        dmux_buf_tdata[p][k] <= dmux_buf_tdata[p][k+1];
                        dmux_buf_tkeep[p][k] <= dmux_buf_tkeep[p][k+1];
                        dmux_buf_tuser[p][k] <= dmux_buf_tuser[p][k+1];
                    end
                    dmux_buf_cnt[p] <= dmux_buf_cnt[p] - 1;
                end else begin
                    port[p].tvalid <= 0;
                end
            end
        end
    end

endmodule
